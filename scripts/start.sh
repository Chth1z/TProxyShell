#!/system/bin/sh

BOX_DIR="/data/adb/box"
BIN_DIR="$BOX_DIR/bin"
CONF_DIR="$BOX_DIR/conf"
SCRIPTS_DIR="$BOX_DIR/scripts"
RUN_DIR="$BOX_DIR/run"

PID_FILE="$RUN_DIR/sing-box.pid"
LOG_FILE="$RUN_DIR/box.log"

MAGISK_MOD_DIR="/data/adb/modules/TProxyShell"
if [ -d "/data/adb/modules_update/TProxyShell" ]; then
    MAGISK_MOD_DIR="/data/adb/modules_update/TProxyShell"
fi
PROP_FILE="$MAGISK_MOD_DIR/module.prop"

export PATH="$BIN_DIR:/data/adb/magisk:/data/adb/ksu/bin:$PATH"
export BOX_DIR BIN_DIR CONF_DIR SCRIPTS_DIR RUN_DIR

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

log() {
    local timestamp="$(date +"%H:%M:%S")"
    local msg="$1"
    if [ ! -d "$RUN_DIR" ]; then mkdir -p "$RUN_DIR"; fi
    echo "${timestamp} [Manager] ${msg}" >> "$LOG_FILE"
    if [ "${INTERACTIVE:-0}" -eq 1 ]; then
        echo "${timestamp} [Manager] ${msg}"
    fi
}

update_description() {
    local status="$1"
    local detail="$2"
    local pid_info=""
    
    [ -f "$PID_FILE" ] && pid_info=" (PID: $(cat "$PID_FILE"))"
    
    local desc_text=""
    case "$status" in
        running) desc_text="🥳 Running${pid_info}" ;;
        error)   desc_text="❌ Error: ${detail}" ;;
        *)       desc_text="💤 Stopped" ;;
    esac

    if [ -f "$PROP_FILE" ]; then
        sed -i "s/^description=.*/description=${desc_text}/g" "$PROP_FILE"
    fi
}

init_environment() {
    if [ ! -d "$RUN_DIR" ]; then
        mkdir -p "$RUN_DIR"
        chmod 0755 "$RUN_DIR"
    fi
    
    if [ -f "$LOG_FILE" ] && [ $(wc -c < "$LOG_FILE") -gt 1048576 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.bak"
    fi
    
    chmod +x "$BIN_DIR/sing-box" 2>/dev/null
    chmod +x "$SCRIPTS_DIR/"*.sh 2>/dev/null
}

check_resource_integrity() {
    log "Checking resource integrity..."
    
    local required_files="$BIN_DIR/sing-box $CONF_DIR/config.json $CONF_DIR/settings.ini $SCRIPTS_DIR/tproxy.sh"
    
    for file in $required_files; do
        if [ ! -f "$file" ]; then
            local filename=$(basename "$file")
            log "Critical file missing: $file"
            update_description "error" "Missing $filename"
            return 1
        fi
    done
    
    log "Integrity check passed."
    return 0
}

check_config_validity() {
    log "Verifying configuration logic..."
    
    local check_out
    check_out=$("$BIN_DIR/sing-box" check -c "$CONF_DIR/config.json" -D "$RUN_DIR" 2>&1)
    local ret=$?
    
    if [ $ret -ne 0 ]; then
        log "Config check failed!"
        log "Details: $check_out"
        update_description "error" "Invalid Config"
        return 1
    fi
    return 0
}

start_core() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        log "Core is already running."
        return 0
    fi

    ulimit -n 65536
    ulimit -l unlimited

    log "Starting sing-box core with GID 3005 (net_admin)..."
    
    if command -v busybox >/dev/null 2>&1; then
        nohup busybox setuidgid 0:3005 "$BIN_DIR/sing-box" run -c "$CONF_DIR/config.json" -D "$RUN_DIR" > /dev/null 2>&1 &
    else
        log "Warning: busybox not found, running as default root:root"
        nohup "$BIN_DIR/sing-box" run -c "$CONF_DIR/config.json" -D "$RUN_DIR" > /dev/null 2>&1 &
    fi
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
    if [ -f "/proc/$pid/oom_score_adj" ]; then
        echo -1000 > "/proc/$pid/oom_score_adj"
    fi

    sleep 2
    if kill -0 $pid 2>/dev/null; then
        log "Core started successfully (PID: $pid)."
        return 0
    else
        log "Core process died immediately."
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_core() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
            local wait_count=0
            while kill -0 "$pid" 2>/dev/null && [ $wait_count -lt 10 ]; do
                sleep 0.1
                wait_count=$((wait_count + 1))
            done
            kill -9 "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    killall sing-box 2>/dev/null
}

run_tproxy() {
    local action=$1
    log "Executing TProxy script: $action"
    
    sh "$SCRIPTS_DIR/tproxy.sh" "$action" >> "$LOG_FILE" 2>&1
    local ret=$?
    
    if [ $ret -eq 0 ]; then
        return 0
    else
        log "TProxy script failed (exit code: $ret)"
        return 1
    fi
}

do_start() {
    log ">>> Starting Service <<<"
    init_environment

    if ! check_resource_integrity; then
        exit 1
    fi

    run_tproxy "stop" >/dev/null 2>&1
    stop_core
    
    if ! check_config_validity; then
        exit 1
    fi
    
    if ! start_core; then
        update_description "error" "Core Start Failed"
        exit 1
    fi
    
    if run_tproxy "start"; then
        update_description "running"
        log "Service started successfully."
    else
        log "Failed to apply iptables rules. Rolling back..."
        stop_core
        update_description "error" "Iptables Failed"
        exit 1
    fi
}

do_stop() {
    log ">>> Stopping Service <<<"
    run_tproxy "stop"
    stop_core
    update_description "stopped"
    log "Service stopped."
}

case "$1" in
    start)  do_start ;;
    stop)   do_stop ;;
    toggle)
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            do_stop
        else
            do_start
        fi
        ;;
    *) echo "Usage: $0 {start|stop|toggle}"; exit 1 ;;
esac