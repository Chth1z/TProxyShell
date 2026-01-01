#!/system/bin/sh

BOX_DIR="/data/adb/box"
SCRIPTS_DIR="$BOX_DIR/scripts"
BOX_SCRIPT="$SCRIPTS_DIR/start.sh"
RUN_DIR="$BOX_DIR/run"
LOG_FILE="$RUN_DIR/box.log"

log() {
    local timestamp="$(date +"%H:%M:%S")"
    if [ ! -d "$RUN_DIR" ]; then mkdir -p "$RUN_DIR"; fi
    echo "${timestamp} [Service] $1" >> "$LOG_FILE"
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

wait_count=0
max_wait=60
network_ready=false

log "System booted. Waiting for network (timeout: ${max_wait}s)..."

while [ $wait_count -lt $max_wait ]; do
    if ip route show | grep -q "default"; then
        network_ready=true
        break
    fi
    sleep 1
    wait_count=$((wait_count + 1))
done

if [ "$network_ready" = true ]; then
    log "Network detected after ${wait_count}s."
else
    log "Network check timed out (${max_wait}s). Starting service anyway..."
fi

sleep 2

if [ -f "$BOX_SCRIPT" ]; then
    chmod +x "$BOX_SCRIPT"
    
    log "Triggering start.sh..."

    nohup sh "$BOX_SCRIPT" start >/dev/null 2>&1 &
else
    log "Error: Startup script not found at $BOX_SCRIPT"
fi