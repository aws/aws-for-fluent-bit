# Valgrind Debugging

The `debug-valgrind` image runs Fluent Bit under [Valgrind](https://valgrind.org/) for memory debugging. It supports three modes and optional S3 upload of results.

## Building

```bash
make debug-valgrind
```

Defaults are derived from `linux.version` based on `BUILD_VERSION`:

| Variable | Default |
|----------|---------|
| `BUILD_VERSION` | `3` |
| `AL_TAG` | Resolved from `linux.version` (e.g. `2023`) |
| `FLB_VERSION` | Resolved from `linux.version` (e.g. `v4.2.2`) |
| `FLB_REPOSITORY` | Resolved from `linux.version` (e.g. `https://github.com/fluent/fluent-bit.git`) |

This produces `amazon/aws-for-fluent-bit:debug-valgrind-al2023`.

To build against Amazon Linux 2 and Fluent Bit 1.9.10:

```bash
BUILD_VERSION=2 make debug-valgrind
```

This produces `amazon/aws-for-fluent-bit:debug-valgrind-al2`.

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VALGRIND_MODE` | `memcheck` | `memcheck`, `massif`, or `dhat` |
| `S3_BUCKET` | *(none)* | S3 bucket for uploading results. If unset, results stay local only |
| `S3_KEY_PREFIX` | `valgrind-results` | Folder prefix within the bucket |
| `HOST_NAME` | System hostname | Used in the S3 key path to identify the source pod/container |
| `SHUTDOWN_TIMEOUT` | `60` | Seconds to wait for valgrind to exit after SIGTERM before SIGKILL |

## How it works

The entrypoint script ([`valgrind_uploader.sh`](../scripts/valgrind_uploader.sh)) launches Fluent Bit under valgrind and waits for a SIGTERM or SIGINT (e.g. container shutdown, pod termination). On signal:

1. Forwards SIGTERM to valgrind so it can write its output
2. Waits up to `SHUTDOWN_TIMEOUT` seconds for a clean exit
3. Falls back to SIGKILL if valgrind doesn't exit in time
4. Logs which output files are available locally
5. Uploads output files to S3 (if `S3_BUCKET` is set)

If valgrind exits on its own (e.g. Fluent Bit crashes), results are uploaded immediately.

### Modes

Each mode runs a different valgrind tool and produces different output files:

**memcheck** (default) — Leak detection at exit. Tracks every allocation and reports leaks when Fluent Bit shuts down. Writes a detailed report to `/tmp/valgrind.log` including "definitely lost", "possibly lost", and "still reachable" summaries.

**massif** — Heap profiling over time. Takes periodic snapshots of heap usage to show how memory grows. Writes profiling data to `/tmp/massif.out`. Valgrind diagnostics go to stderr (container logs) since massif doesn't support `--log-file`.

**dhat** — Allocation lifetime tracking. Records every allocation's size, lifetime, and call stack to identify short-lived allocations (churn) vs long-lived ones (potential leaks). Writes allocation data to `/tmp/dhat.out` and valgrind diagnostics to `/tmp/valgrind.log`.

## S3 upload path

Results are uploaded to:

```
s3://{S3_BUCKET}/{S3_KEY_PREFIX}/{HOST_NAME}/{filename}-{YYYYMMDD-HHMMSS}
```

With defaults, this looks like:

```
s3://{S3_BUCKET}/valgrind-results/{hostname}/valgrind.log-20260415-031500
```

## Reading results

- **memcheck**: Review `/tmp/valgrind.log` for leak summaries. Look for "definitely lost" and "possibly lost" blocks.
- **massif**: Use `ms_print /tmp/massif.out` to visualize heap usage over time, or load into [massif-visualizer](https://github.com/KDE/massif-visualizer).
- **dhat**: Open `/tmp/dhat.out` in the [DHAT viewer](https://valgrind.org/docs/manual/dh-manual.html#dh-manual.viewer) (bundled with valgrind source) to analyze allocation lifetimes.
