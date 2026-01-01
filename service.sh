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

sleep 5

log "System boot completed. Starting service..."

if [ -f "$BOX_SCRIPT" ]; then
    chmod +x "$BOX_SCRIPT"

    nohup sh "$BOX_SCRIPT" start >/dev/null 2>&1 &
else
    log "Error: Startup script not found at $BOX_SCRIPT"
fi