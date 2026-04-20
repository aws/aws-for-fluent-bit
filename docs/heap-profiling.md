# Heap Profiling and Memory Analysis

The debug image includes two complementary tools for investigating memory growth:

- **jemalloc heap profiles** — allocation-level snapshots showing what is holding memory and where it was allocated
- **RSS timeline** — a lightweight time-series of process memory sampled from `/proc`, useful for spotting growth trends before diving into profiles

Both are collected automatically by `core_uploader.sh` and uploaded to S3 alongside crash artifacts.

## Contents

- [MALLOC_CONF reference](#malloc_conf-reference)
  - [Simple configuration](#simple-configuration)
  - [Advanced configuration](#advanced-configuration)
- [How heap profiles are collected](#how-heap-profiles-are-collected)
- [Analyzing heap profiles with jeprof](#analyzing-heap-profiles-with-jeprof)
  - [Prerequisites](#prerequisites)
  - [Unpack the bundle](#unpack-the-bundle)
  - [Basic usage](#basic-usage)
  - [Useful jeprof commands](#useful-jeprof-commands)
  - [Comparing two profiles (growth analysis)](#comparing-two-profiles-growth-analysis)
- [Analyzing the RSS timeline](#analyzing-the-rss-timeline)
  - [File format](#file-format)
  - [Quick inspection](#quick-inspection)
  - [Plotting with Python](#plotting-with-python)
  - [Correlating RSS with heap profiles](#correlating-rss-with-heap-profiles)

---

## MALLOC_CONF reference

jemalloc is configured via the `MALLOC_CONF` environment variable as a comma-separated list of `key:value` options. The debug image has profiling compiled in but it is **off by default** — you must set `MALLOC_CONF` to activate it.

### Simple configuration

Start here. Enables high-water-mark dumps and a leak report on exit:

```
MALLOC_CONF=prof:true,prof_gdump:true,prof_leak:true,prof_final:true
```

This produces a profile every time the heap reaches a new peak, plus a final snapshot on shutdown. Good for most leak investigations without tuning anything.

### Advanced configuration

The full set of profiling options (see [jemalloc docs](https://jemalloc.net/jemalloc.3.html#opt.prof) for the complete reference):

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prof` | bool | `false` | Master switch. Must be `true` for any profiling to work |
| `prof_active` | bool | `true` | Whether profiling is actively sampling. Can be toggled at runtime via `mallctl` without restarting |
| `prof_thread_active_init` | bool | `true` | Whether new threads start with profiling active. Set `true` to profile worker threads from their first allocation |
| `lg_prof_sample` | int | `19` | Log2 of the average byte interval between allocation samples. `19` ≈ 512 KiB. Lower = more accurate, higher CPU cost |
| `prof_gdump` | bool | `false` | Dump a profile every time the heap reaches a new high-water mark |
| `prof_accum` | bool | `false` | Track cumulative allocated/deallocated bytes in addition to live heap. Enables seeing total allocation volume vs in-use |
| `prof_leak` | bool | `false` | Dump a profile on exit showing live (leaked) allocations |
| `prof_final` | bool | `false` | Dump a final profile on exit regardless of whether leaks are detected |
| `lg_prof_interval` | int | `-1` (off) | Dump every time cumulative allocated bytes crosses a 2^N boundary. `32` ≈ every 4 GiB, `28` ≈ every 256 MiB. Useful when memory is freed and re-allocated rather than monotonically growing |
| `prof_prefix` | string | `/tmp/jeprof` | Output path prefix. Files are written as `<prefix>.<pid>.<seq>.heap` |
| `background_thread` | bool | `false` | Run a background thread for memory decay and purging, keeping these off the hot path for cleaner profile timings |
| `abort_conf` | bool | `false` | Abort on unrecognised options — useful to catch typos in `MALLOC_CONF` |

Example combining interval dumps with a leak report for a long-running investigation:

```
MALLOC_CONF=prof:true,prof_active:true,prof_thread_active_init:true,prof_leak:true,prof_final:true,lg_prof_interval:32,prof_accum:true,prof_prefix:/tmp/jeprof,lg_prof_sample:17,background_thread:true,abort_conf:true
```

This produces two meaningful artifacts per run:
1. Interval dumps (`.i.heap`) — one every 4 GiB allocated (`lg_prof_interval:32`), typically 2–4 over a 15-minute run
2. A final heap dump (`.f.heap`) at exit via `prof_final`

Diff the first interval dump against the final to isolate growth:
```bash
jeprof --base=jeprof.<pid>.0.i.heap ./fluent-bit jeprof.<pid>.<N>.f.heap
```

Key choices explained:
- `prof_thread_active_init:true` — profiles worker threads from their first allocation, not just the main thread
- `prof_accum:true` — tracks cumulative alloc/dealloc so you can see total allocated vs in-use, not just the live heap
- `lg_prof_sample:17` — samples every 128 KiB (vs the default 512 KiB) for more accurate call stacks with low overhead
- `background_thread:true` — moves memory decay and purging off the hot path, giving cleaner profile timings
- `prof_prefix:/tmp/jeprof` — explicit path so `core_uploader.sh` can find the files reliably

---

## How heap profiles are collected

The debug image builds Fluent Bit with jemalloc profiling compiled in (`--enable-prof --enable-prof-libunwind`). Profiling is off by default — set `MALLOC_CONF` to activate it (see above).

jemalloc writes snapshots to `/tmp/jeprof.<pid>.<seq>.heap`. At shutdown, `core_uploader.sh` bundles all `.heap` files with the Fluent Bit executable and uploads them to S3. Send `SIGUSR2` to trigger an upload mid-run without stopping Fluent Bit. See [debug.md](debug.md) for the full lifecycle and signal reference.

---

## Analyzing heap profiles with jeprof

### Prerequisites

`jeprof` is bundled with jemalloc. On Amazon Linux:

```bash
yum install -y jemalloc-devel   # provides jeprof
```

Or use the version from the jemalloc source tree if the package version is old:

```bash
git clone https://github.com/jemalloc/jemalloc.git
# jeprof is at jemalloc/bin/jeprof (a Perl script, no build needed)
```

You also need `perl` and `graphviz` (`dot`) for graph output:

```bash
yum install -y perl graphviz
```

### Unpack the bundle

The S3 upload is a zip named like:

```
heaps_<basename(S3_KEY_PREFIX)>_<YYYYMMDD-HHMMSS>_host-<hostname>.all.zip
```

For example, with `S3_KEY_PREFIX=team/TICKET-123`:

```
heaps_TICKET-123_20260420-153000_host-ip-10-0-0-1.all.zip
```

Unpack it:

```bash
unzip heaps_TICKET-123_20260420-153000_host-ip-10-0-0-1.all.zip -d heap-analysis/
cd heap-analysis/
```

The zip contains:
- One or more `jeprof.<pid>.<seq>.heap` files
- `fluent-bit` — the exact binary that produced the profiles (required for symbol resolution)

### Basic usage

Inspect a single profile as text:

```bash
jeprof --text ./fluent-bit jeprof.12345.0001.heap
```

Generate a call-graph PDF (most useful for visualizing allocation hotspots):

```bash
jeprof --pdf ./fluent-bit jeprof.12345.0001.heap > heap.pdf
```

Generate an SVG (easier to share):

```bash
jeprof --svg ./fluent-bit jeprof.12345.0001.heap > heap.svg
```

### Useful jeprof commands

| Flag | Output |
|------|--------|
| `--text` | Flat text table sorted by self bytes |
| `--pdf` | Call graph as PDF |
| `--svg` | Call graph as SVG |
| `--callgrind` | Callgrind format for KCachegrind |
| `--show_bytes` | Show raw bytes instead of percentages |
| `--nodecount=N` | Limit graph to top N nodes (default 80) |
| `--focus=<regex>` | Only show nodes matching regex |
| `--ignore=<regex>` | Exclude nodes matching regex |

Example — focus on Fluent Bit plugin allocations:

```bash
jeprof --pdf --focus=flb ./fluent-bit jeprof.12345.0001.heap > heap-flb.pdf
```

### Comparing two profiles (growth analysis)

The most useful technique for leak hunting is diffing an early profile against a later one. jemalloc profiles are cumulative, so the diff shows net allocation growth between the two points:

```bash
jeprof --pdf --base=jeprof.12345.0001.heap ./fluent-bit jeprof.12345.0050.heap > growth.pdf
```

Positive values in the diff are allocations that grew. Negative values are memory that was freed. Focus on large positive values — those are the leak candidates.

For a quick text summary of the top growers:

```bash
jeprof --text --base=jeprof.12345.0001.heap ./fluent-bit jeprof.12345.0050.heap | head -40
```

---

## Analyzing the RSS timeline

### File format

`rss_<prefix>.tsv` is a tab-separated file uploaded alongside heap profiles:

```
epoch_s	rss_kib	vmsize_kib	threads	pid
1745000000	512000	1024000	32	12345
1745000005	513200	1024000	32	12345
...
```

| Column | Description |
|--------|-------------|
| `epoch_s` | Unix timestamp (seconds) |
| `rss_kib` | Resident Set Size in KiB (physical memory in use) |
| `vmsize_kib` | Virtual memory size in KiB |
| `threads` | Thread count |
| `pid` | Fluent Bit PID |

Sampled every `RSS_INTERVAL` seconds (default: 5). Set `RSS_INTERVAL=60` on the container for lower overhead during long runs.

### Quick inspection

Print the first and last few rows to see the memory range:

```bash
head -5 rss.tsv
tail -5 rss.tsv
```

Check peak RSS:

```bash
sort -t$'\t' -k2 -rn rss.tsv | head -3
```

Compute growth from first to last sample (in MiB):

```bash
awk -F'\t' 'NR==2{start=$2} END{printf "Growth: %.1f MiB\n", ($2-start)/1024}' rss.tsv
```

### Plotting with Python

A quick matplotlib plot to visualize RSS over time:

```python
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime

df = pd.read_csv("rss.tsv", sep="\t")
df["time"] = pd.to_datetime(df["epoch_s"], unit="s")
df["rss_mib"] = df["rss_kib"] / 1024

fig, ax = plt.subplots(figsize=(12, 4))
ax.plot(df["time"], df["rss_mib"], linewidth=1)
ax.set_xlabel("Time")
ax.set_ylabel("RSS (MiB)")
ax.set_title("Fluent Bit RSS over time")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
plt.tight_layout()
plt.savefig("rss.png", dpi=150)
print("Saved rss.png")
```

Run with:

```bash
pip install pandas matplotlib
python plot_rss.py
```

### Correlating RSS with heap profiles

Each `.heap` file has a sequence number in its name (`jeprof.<pid>.<seq>.heap`). jemalloc writes profiles in order, so you can correlate sequence numbers with the RSS timeline by timestamp.

The heap file `mtime` gives the wall-clock time it was written:

```bash
ls -lt jeprof.*.heap   # newest last
```

Cross-reference with the RSS timeline to find which RSS level corresponds to each profile snapshot. This helps you identify which profile captures the point where memory started growing unexpectedly.

---

For `S3_BUCKET`, `S3_KEY_PREFIX`, `HOST_NAME`, and other container-level variables see [debug.md](debug.md#configuration).
