# Debug Image

The `debug` and `init-debug` images run Fluent Bit under `core_uploader.sh`, a process supervisor that collects crash symbols, heap profiles, and a memory timeline, then uploads them to S3.

## Building

```bash
# Standard debug image
make debug

# With the init process (multi-config support)
make init-debug
```

Defaults are derived from `linux.version` based on `BUILD_VERSION`:

| Variable | Default |
|----------|---------|
| `BUILD_VERSION` | `3` |
| `AL_TAG` | Resolved from `linux.version` (e.g. `2023`) |
| `FLB_VERSION` | Resolved from `linux.version` (e.g. `v4.2.2`) |
| `FLB_REPOSITORY` | Resolved from `linux.version` (e.g. `https://github.com/fluent/fluent-bit.git`) |

These produce `amazon/aws-for-fluent-bit:debug-al2023` and `amazon/aws-for-fluent-bit:init-debug-al2023`.

To build against Amazon Linux 2:

```bash
BUILD_VERSION=2 make debug
```

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_BUCKET` | *(none)* | S3 bucket for uploading artifacts. If unset, artifacts are written to `/cores` only |
| `S3_KEY_PREFIX` | `issue` | Folder prefix within the bucket — set to something meaningful like a ticket ID |
| `HOST_NAME` | System hostname | Used in S3 key path and artifact filenames |
| `EFS_WAIT` | `0` | Seconds to wait after final upload before container exit, to allow EFS transfers to complete |
| `RSS_INTERVAL` | `5` | Seconds between RSS memory samples |
| `MALLOC_CONF` | *(none)* | jemalloc configuration string. Required to enable heap profiling. See [heap-profiling.md](heap-profiling.md) |
| `FLB_CONF_FILE` | `/fluent-bit/etc/fluent-bit.conf` | Fluent Bit config path. Set automatically by `init-debug`; override if using a custom config |
| `FLB_EXTRA_ARGS` | *(none)* | Extra Fluent Bit arguments, e.g. `-R /path/to/parser.conf`. Set automatically by `init-debug` |

## How it works

`core_uploader.sh` is the container entrypoint. It launches Fluent Bit as a child process, polls its memory via `/proc`, and waits for it to exit. On exit (crash or graceful shutdown):

1. Stops the RSS poller and copies `/tmp/rss.tsv` to `/cores` with a timestamped filename
2. Checks `/cores` for a core dump — if found, extracts a stacktrace with `gdb` and zips everything
3. Bundles any jemalloc heap profiles from `/tmp/jeprof.*.heap` with the Fluent Bit executable
4. Uploads all artifacts to S3 (if `S3_BUCKET` is set)
5. Waits `EFS_WAIT` seconds if set, then exits

### Signal handling

| Signal | Behavior |
|--------|----------|
| `SIGTERM` / `SIGINT` | Forwarded to Fluent Bit for graceful shutdown |
| `SIGCONT` | Forwarded to Fluent Bit, which responds by [dumping internal stats](https://docs.fluentbit.io/manual/administration/troubleshooting#dump-internals-and-signal) (input status, storage layer, chunk counts) to stdout |
| `SIGUSR1` | Takes a live core snapshot via `gcore` (requires `SYS_PTRACE`), processes it, and uploads immediately without stopping Fluent Bit |
| `SIGUSR2` | Bundles and uploads current jemalloc heap profiles mid-run without stopping Fluent Bit |

To send signals from outside the container:

```bash
# Docker
docker kill --signal=SIGUSR1 <container_id>
docker kill --signal=SIGUSR2 <container_id>
docker kill --signal=SIGCONT <container_id>

# Kubernetes
kubectl exec -n <namespace> <pod> -- kill -USR1 1
kubectl exec -n <namespace> <pod> -- kill -USR2 1
kubectl exec -n <namespace> <pod> -- kill -CONT 1
```

### init-debug differences

The `init-debug` image runs `fluent_bit_init_process` first to generate a merged config from S3 or local config files, then extracts the generated config path and hands off to `core_uploader.sh`. All signal handling, RSS polling, and heap profiling work identically to the standard debug image.

See the [init process use case guide](../use_cases/init-process-for-fluent-bit/README.md) for details on multi-config support.

## S3 upload path

Artifacts are uploaded to:

```
s3://{S3_BUCKET}/{S3_KEY_PREFIX}/{HOST_NAME}/{filename}
```

For example:

```
s3://my-bucket/TICKET-123/ip-10-0-0-1/crash_TICKET-123_20260420-153000_host-ip-10-0-0-1.all.zip
s3://my-bucket/TICKET-123/ip-10-0-0-1/heaps_TICKET-123_20260420-153000_host-ip-10-0-0-1.all.zip
s3://my-bucket/TICKET-123/ip-10-0-0-1/rss_TICKET-123_20260420-153000_host-ip-10-0-0-1.tsv
```

## Artifacts

| Artifact | When produced | Contents |
|----------|--------------|----------|
| `crash_<prefix>.all.zip` | Fluent Bit crashes (core dump found) | Core file, stacktrace, Fluent Bit executable |
| `snapshot_<prefix>.all.zip` | SIGUSR1 received | Same as crash bundle, taken from a live process |
| `heaps_<prefix>.all.zip` | On exit | All `/tmp/jeprof.*.heap` files + Fluent Bit executable |
| `heaps-midrun_<prefix>.all.zip` | SIGUSR2 received | Same contents as heaps bundle, point-in-time mid-run snapshot |
| `rss_<prefix>.tsv` | Always (and on SIGUSR2) | Tab-separated RSS/VmSize/thread count timeline |

Artifact filename prefix format: `<label>_<S3_KEY_PREFIX basename>_<YYYYMMDD-HHMMSS>_host-<HOST_NAME>`

## Deployment requirements

To capture core dumps, the container needs:

- `ulimit -c unlimited` (or `--ulimit core=-1` in Docker)
- `SYS_PTRACE` capability for SIGUSR1 live snapshots and `gdb` stacktrace extraction

Example Docker run:

```bash
docker run \
    --ulimit core=-1 \
    --cap-add SYS_PTRACE \
    -v /host/cores:/cores \
    -e S3_BUCKET=my-bucket \
    -e S3_KEY_PREFIX=TICKET-123 \
    amazon/aws-for-fluent-bit:debug-al2023
```

For ECS and EKS deployment examples see the [core dump tutorial](../troubleshooting/tutorials/remote-core-dump/README.md).

## Further reading

- [heap-profiling.md](heap-profiling.md) — configuring jemalloc heap profiling and analyzing `.heap` files and the RSS timeline
- [valgrind.md](valgrind.md) — the `debug-valgrind` image for deeper memory analysis with Valgrind
- [Core dump tutorial](../troubleshooting/tutorials/remote-core-dump/README.md) — platform-specific deployment setup (ECS EC2, ECS Fargate, EKS)
