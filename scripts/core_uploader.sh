#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Process supervisor for the debug image.
# Launches fluent-bit, collects crash symbols, jemalloc heap profiles, and an
# RSS memory timeline, then uploads everything to S3 on exit.
#
# Signals:
#   SIGUSR1  - Take a live core snapshot via gcore (requires SYS_PTRACE)
#   SIGUSR2  - Bundle & upload current jemalloc heap profiles and RSS mid-run
#   SIGCONT  - Forward to fluent-bit to dump internal stats
#
# Env vars:
#   S3_BUCKET          - S3 bucket for uploads (optional; artifacts written to /cores regardless)
#   S3_KEY_PREFIX      - S3 key prefix (default: issue)
#   HOST_NAME          - hostname used in artifact names (default: system hostname)
#   EFS_WAIT           - seconds to wait after upload for EFS sync (default: 0)
#   RSS_INTERVAL       - seconds between RSS samples (default: 5)
#   FLB_CONF_FILE      - fluent-bit config path (default: /fluent-bit/etc/fluent-bit.conf)
#   FLB_EXTRA_ARGS     - extra fluent-bit args, e.g. "-R /path/to/parser.conf" (init image)

S3_BUCKET="${S3_BUCKET:-}"
S3_KEY_PREFIX="${S3_KEY_PREFIX:-issue}"
HOST_NAME="${HOST_NAME:-$(cat /proc/sys/kernel/hostname)}"
EFS_WAIT="${EFS_WAIT:-0}"
RSS_INTERVAL="${RSS_INTERVAL:-5}"

FLB_PID=""
RSS_PID=""

CORES_DIR="/cores"
FLB_CMD="/fluent-bit/bin/fluent-bit \
    -e /fluent-bit/firehose.so \
    -e /fluent-bit/cloudwatch.so \
    -e /fluent-bit/kinesis.so \
    -c ${FLB_CONF_FILE:-/fluent-bit/etc/fluent-bit.conf} \
    ${FLB_EXTRA_ARGS:-}"

# Write a log line to stdout with a script prefix.
log() {
    echo "[core_uploader] $*"
}

# Print a human-readable file size.
human_size() {
    local bytes
    bytes=$(stat -c %s "$1" 2>/dev/null) || { echo "?"; return; }
    awk -v b="$bytes" 'BEGIN{
        split("B K M G T",u);
        i=1; while (b>=1024 && i<5) { b=b/1024; i++ }
        printf (i==1 ? "%dB" : "%.1f%sB"), b, u[i]
    }'
}

# Generate a timestamped artifact filename prefix.
# Args: $1 = label (e.g. "crash", "snapshot", "heaps")
make_prefix() {
    local label="$1"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    echo "${label}_$(basename "$S3_KEY_PREFIX")_${ts}_host-${HOST_NAME}"
}

# Upload a file to S3. No-op if S3_BUCKET is unset.
upload_to_s3() {
    local file="$1"

    if [ -z "$S3_BUCKET" ]; then
        return
    fi

    local dest="s3://${S3_BUCKET}/${S3_KEY_PREFIX}/${HOST_NAME}/$(basename "$file")"
    log "Uploading $file ($(human_size "$file")) -> $dest"
    aws s3 cp "$file" "$dest" --quiet 2>/dev/null && \
        log "Upload succeeded" || \
        log "Upload failed"
}

# Extract stacktrace with gdb, zip core + executable + stacktrace into $CORES_DIR/<prefix>.all.zip.
# Args: $1 = path to core file, $2 = filename prefix
process_core() {
    local core_path="$1"
    local prefix="$2"

    if [ ! -f "$core_path" ]; then
        log "No core file at $core_path"
        return 1
    fi

    log "Processing core file: $core_path"

    mv "$core_path" "$CORES_DIR/${prefix}.core"

    cp /fluent-bit/bin/fluent-bit "$CORES_DIR/${prefix}.executable"
    gdb -batch \
        -ex 'thread apply all bt full' \
        -ex 'quit' \
        /fluent-bit/bin/fluent-bit "$CORES_DIR/${prefix}.core" \
        > "$CORES_DIR/${prefix}.stacktrace" 2>&1

    log "$(wc -l < "$CORES_DIR/${prefix}.stacktrace") lines written to ${prefix}.stacktrace"
    log "  core       : $(human_size "$CORES_DIR/${prefix}.core")"
    log "  executable : $(human_size "$CORES_DIR/${prefix}.executable")"
    log "  stacktrace : $(human_size "$CORES_DIR/${prefix}.stacktrace")"

    zip -jm "$CORES_DIR/${prefix}.all.zip" \
        "$CORES_DIR/${prefix}.core" \
        "$CORES_DIR/${prefix}.executable" \
        "$CORES_DIR/${prefix}.stacktrace"

    log "Bundle zipped: ${prefix}.all.zip ($(human_size "$CORES_DIR/${prefix}.all.zip"))"
}

# Process a core file and upload the resulting zip.
# Args: $1 = path to core file, $2 = label
process_and_upload() {
    local core_path="$1"
    local label="$2"
    local prefix
    prefix=$(make_prefix "$label")

    if process_core "$core_path" "$prefix"; then
        upload_to_s3 "$CORES_DIR/${prefix}.all.zip"
    fi
}

# Bundle all jemalloc heap profiles from /tmp with the executable.
# Profiles are cumulative — each bundle contains all .heap files since startup.
upload_heap_profiles() {
    local label="${1:-heaps}"
    local heap_files
    heap_files=$(ls /tmp/jeprof.*.heap 2>/dev/null)
    if [ -z "$heap_files" ]; then
        log "No heap profiles found in /tmp — skipping bundle"
        return
    fi

    local prefix
    prefix=$(make_prefix "$label")
    local bundle="$CORES_DIR/${prefix}.all.zip"

    local heap_count
    heap_count=$(echo "$heap_files" | wc -l | tr -d ' ')
    log "Bundling $heap_count heap profile(s) into $(basename "$bundle")"
    cp /fluent-bit/bin/fluent-bit "$CORES_DIR/${prefix}.executable"
    # shellcheck disable=SC2086
    zip -jq "$bundle" $heap_files "$CORES_DIR/${prefix}.executable"
    rm -f "$CORES_DIR/${prefix}.executable"
    log "Bundle zipped: $(basename "$bundle") ($(human_size "$bundle"))"
    upload_to_s3 "$bundle"
}

# Poll fluent-bit RSS from /proc and write a TSV to /tmp/rss.tsv.
# Runs as a background subshell; killed when fluent-bit exits.
# Args: $1 = fluent-bit PID, $2 = poll interval (seconds)
start_rss_poller() {
    local pid="$1"
    local interval="$2"
    local outfile="/tmp/rss.tsv"
    printf "epoch_s\trss_kib\tvmsize_kib\tthreads\tpid\n" > "$outfile"
    (
        while kill -0 "$pid" 2>/dev/null; do
            local status rss vm thr
            status=$(cat /proc/$pid/status 2>/dev/null) || { sleep "$interval"; continue; }
            rss=$(echo "$status" | awk '/^VmRSS:/{print $2}')
            vm=$(echo  "$status" | awk '/^VmSize:/{print $2}')
            thr=$(echo "$status" | awk '/^Threads:/{print $2}')
            printf "%s\t%s\t%s\t%s\t%s\n" \
                "$(date +%s)" "${rss:-0}" "${vm:-0}" "${thr:-0}" "$pid" >> "$outfile"
            sleep "$interval"
        done
    ) &
    RSS_PID=$!
}

# Stop the RSS poller background subshell if still running.
stop_rss_poller() {
    if [[ -n "$RSS_PID" ]] && kill -0 "$RSS_PID" 2>/dev/null; then
        kill "$RSS_PID" 2>/dev/null
        wait "$RSS_PID" 2>/dev/null
    fi
    RSS_PID=""
}

# Copy RSS timeline to /cores with a timestamped name and upload to S3.
upload_rss() {
    local f="/tmp/rss.tsv"
    if [ ! -f "$f" ] || [ "$(wc -l < "$f")" -le 1 ]; then
        log "No RSS samples to upload"
        return
    fi
    local dest_name
    dest_name="$(make_prefix "rss").tsv"
    cp "$f" "$CORES_DIR/$dest_name"
    log "Uploading RSS timeline ($(wc -l < "$f" | tr -d ' ') samples)"
    upload_to_s3 "$CORES_DIR/$dest_name"
}

# Process crash core, heap profiles, and RSS on exit.
handle_crash_core() {
    stop_rss_poller

    local core_path
    core_path=$(ls "$CORES_DIR"/core* 2>/dev/null | head -1)
    if [ -n "$core_path" ]; then
        process_and_upload "$core_path" "crash"
    else
        log "No crash core file found"
    fi

    upload_heap_profiles "heaps"
    upload_rss

    if [ "$EFS_WAIT" -gt 0 ] 2>/dev/null; then
        log "Waiting ${EFS_WAIT}s for EFS transfers to complete"
        sleep "$EFS_WAIT"
    fi
}

# Forward SIGTERM/SIGINT to fluent-bit for graceful shutdown.
handle_sigterm() {
    if [ -n "$FLB_PID" ] && kill -0 "$FLB_PID" 2>/dev/null; then
        log "Forwarding SIGTERM to Fluent Bit (PID $FLB_PID)"
        kill -TERM "$FLB_PID" 2>/dev/null
    fi
}

# Forward SIGCONT to fluent-bit so it dumps internal stats.
handle_sigcont() {
    if [ -n "$FLB_PID" ] && kill -0 "$FLB_PID" 2>/dev/null; then
        kill -CONT "$FLB_PID" 2>/dev/null
    fi
}

# Take a live core snapshot via gcore. Requires SYS_PTRACE capability.
handle_sigusr1() {
    if [ -z "$FLB_PID" ] || ! kill -0 "$FLB_PID" 2>/dev/null; then
        log "SIGUSR1: Fluent Bit not running, ignoring"
        return
    fi

    log "SIGUSR1: Taking live snapshot of Fluent Bit (PID $FLB_PID)"

    local tmp_core="$CORES_DIR/gcore_tmp"
    gcore -o "$tmp_core" "$FLB_PID" >/dev/null 2>&1

    if [ ! -f "${tmp_core}.$FLB_PID" ]; then
        log "SIGUSR1: gcore failed — is SYS_PTRACE enabled?"
        return
    fi

    process_and_upload "${tmp_core}.$FLB_PID" "snapshot"
    log "SIGUSR1: Snapshot complete"
}

# Bundle and upload heap profiles and RSS mid-run without stopping fluent-bit.
handle_sigusr2() {
    log "SIGUSR2: Uploading current heap profiles"
    upload_heap_profiles "heaps-midrun"
    upload_rss
    log "SIGUSR2: Heap upload complete"
}

# Block until fluent-bit exits, re-waiting after signal interrupts, then collect artifacts.
wait_for_shutdown() {
    log "Fluent Bit running (PID $FLB_PID), waiting for exit"

    local flb_exit_code=0
    while kill -0 "$FLB_PID" 2>/dev/null; do
        wait "$FLB_PID" 2>/dev/null
        flb_exit_code=$?
    done

    local kill_exit=$?
    if [ $kill_exit -ne 0 ]; then
        log "Warning: kill -0 exited with $kill_exit"
    fi

    log "Fluent Bit exited (exit code: $flb_exit_code)"
    handle_crash_core
}

# Entry point.
main() {
    trap handle_sigterm SIGTERM SIGINT
    trap handle_sigcont SIGCONT
    trap handle_sigusr1 SIGUSR1
    trap handle_sigusr2 SIGUSR2

    log "Starting (PID $$)"

    if [ -z "$S3_BUCKET" ]; then
        log "Note: S3_BUCKET not set — artifacts written to /cores only"
    fi
    if [ "$S3_KEY_PREFIX" = "issue" ]; then
        log "Note: Set S3_KEY_PREFIX to a useful identifier (e.g. team name, ticket ID)"
    fi

    cd "$CORES_DIR"
    $FLB_CMD &
    FLB_PID=$!

    start_rss_poller "$FLB_PID" "$RSS_INTERVAL"
    wait_for_shutdown
}

main "$@"
