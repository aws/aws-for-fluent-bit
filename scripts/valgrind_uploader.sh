#!/bin/bash
# Runs fluent-bit under valgrind (massif, memcheck, or dhat) and uploads results to S3.
#
# The script waits for an external SIGTERM/SIGINT (e.g. container shutdown),
# forwards it to valgrind, waits for valgrind to write its output, then uploads.
#
# Env vars:
#   VALGRIND_MODE      - "memcheck" (default), "massif", or "dhat"
#   S3_BUCKET          - required for upload
#   S3_KEY_PREFIX      - S3 folder prefix (default: valgrind-results)
#   HOST_NAME          - optional, defaults to hostname
#   SHUTDOWN_TIMEOUT   - max wait for valgrind exit after SIGTERM (default 60)

VALGRIND_MODE="${VALGRIND_MODE:-memcheck}"
S3_BUCKET="${S3_BUCKET:-}"
S3_KEY_PREFIX="${S3_KEY_PREFIX:-valgrind-results}"
HOST_NAME="${HOST_NAME:-$(cat /proc/sys/kernel/hostname)}"
SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-60}"

VALGRIND_PID=""
UPLOADED=0
CAUGHT_SIGNAL=0

OUTPUT_FILES=(/tmp/massif.out /tmp/valgrind.log /tmp/dhat.out)
FLB_CMD="/fluent-bit/bin/fluent-bit \
    -e /fluent-bit/firehose.so \
    -e /fluent-bit/cloudwatch.so \
    -e /fluent-bit/kinesis.so \
    -c /fluent-bit/etc/fluent-bit.conf"

# Log with prefix.
log() {
    echo "[valgrind_uploader] $*"
}

# Lists valgrind output files in /tmp.
print_local_files() {
    log "Output files available locally:"
    for f in "${OUTPUT_FILES[@]}"; do
        [ -f "$f" ] && echo -e "[valgrind_uploader]\t$f"
    done
}

# Upload output files to S3. Idempotent.
upload() {
    if [ "$UPLOADED" -eq 1 ]; then
        return
    fi
    UPLOADED=1

    print_local_files

    if [ -z "$S3_BUCKET" ]; then
        log "S3_BUCKET not set, skipping upload"
        return
    fi

    local dest="s3://${S3_BUCKET}/${S3_KEY_PREFIX}/${HOST_NAME}"
    local ts=$(date +%Y%m%d-%H%M%S)

    for f in "${OUTPUT_FILES[@]}"; do
        if [ -f "$f" ]; then
            local base=$(basename "$f")
            log "Uploading $f -> ${dest}/${base}-${ts}"
            aws s3 cp "$f" "${dest}/${base}-${ts}" --quiet 2>/dev/null && \
                log "Upload succeeded: ${base}-${ts}" || \
                log "Upload failed: ${base}-${ts}"
        fi
    done
}

# SIGTERM valgrind, wait up to SHUTDOWN_TIMEOUT, then SIGKILL.
stop_valgrind() {
    if [ -z "$VALGRIND_PID" ] || ! kill -0 "$VALGRIND_PID" 2>/dev/null; then
        return
    fi

    log "Sending SIGTERM to valgrind (PID $VALGRIND_PID)"
    kill -TERM "$VALGRIND_PID" 2>/dev/null

    local elapsed=0
    while kill -0 "$VALGRIND_PID" 2>/dev/null && [ "$elapsed" -lt "$SHUTDOWN_TIMEOUT" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if kill -0 "$VALGRIND_PID" 2>/dev/null; then
        log "Valgrind did not exit after ${SHUTDOWN_TIMEOUT}s, sending SIGKILL"
        kill -KILL "$VALGRIND_PID" 2>/dev/null
        wait "$VALGRIND_PID" 2>/dev/null
    else
        wait "$VALGRIND_PID" 2>/dev/null
        log "Valgrind exited cleanly"
    fi
}

# Deferred signal handler — sets flag for the wait loop to act on.
handle_signal() {
    log "Caught signal"
    CAUGHT_SIGNAL=1
}

# Forward SIGCONT to valgrind so fluent-bit dumps its internal stats.
handle_sigcont() {
    if [ -n "$VALGRIND_PID" ] && kill -0 "$VALGRIND_PID" 2>/dev/null; then
        kill -CONT "$VALGRIND_PID" 2>/dev/null
    fi
}

# Heap profiling over time. Diagnostics go to stderr (massif doesn't support --log-file).
start_massif() {
    valgrind \
        --tool=massif \
        --massif-out-file=/tmp/massif.out \
        --time-unit=ms \
        --detailed-freq=20 \
        --max-snapshots=200 \
        --threshold=0.5 \
        --stacks=no \
        --alloc-fn=flb_malloc \
        --alloc-fn=flb_calloc \
        --alloc-fn=flb_realloc \
        --log-fd=2 \
        `# --pages-as-heap=yes tracks mmap/brk instead of malloc` \
        $FLB_CMD &
}

# Allocation lifetime tracking.
start_dhat() {
    valgrind \
        --tool=dhat \
        --dhat-out-file=/tmp/dhat.out \
        --num-callers=20 \
        --log-file=/tmp/valgrind.log \
        $FLB_CMD &
}

# Leak detection at exit.
start_memcheck() {
    valgrind \
        --leak-check=full \
        --show-leak-kinds=definite,possible \
        --error-limit=no \
        --track-origins=yes \
        --verbose \
        --log-file=/tmp/valgrind.log \
        --num-callers=30 \
        --keep-debuginfo=yes \
        --leak-resolution=high \
        --freelist-vol=100000000 \
        $FLB_CMD &
}

# Block until valgrind exits or a signal arrives.
# Polls with short sleeps so trapped signals are delivered between iterations.
wait_for_shutdown() {
    log "Valgrind running (PID $VALGRIND_PID), waiting for shutdown signal"

    while kill -0 "$VALGRIND_PID" 2>/dev/null; do
        # Interruptible sleep allows signal delivery between iterations.
        sleep 1

        if [ "$CAUGHT_SIGNAL" -eq 1 ]; then
            log "Signal received, initiating shutdown"
            trap '' SIGTERM SIGINT
            stop_valgrind
            upload
            exit 0
        fi
    done

    wait "$VALGRIND_PID" 2>/dev/null
    log "Valgrind exited on its own (exit code: $?)"
    upload
}

# Entry point.
main() {
    trap handle_signal SIGTERM SIGINT
    trap handle_sigcont SIGCONT

    log "Starting in ${VALGRIND_MODE} mode (PID $$)"

    case "$VALGRIND_MODE" in
        massif)   start_massif ;;
        dhat)     start_dhat ;;
        *)        start_memcheck ;;
    esac

    VALGRIND_PID=$!
    wait_for_shutdown
}

main "$@"
