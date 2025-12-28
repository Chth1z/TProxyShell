#!/system/bin/sh

BOX_DIR="/data/adb/box"
MAGISK_MOD_DIR="/data/adb/modules/SingBox_TProxy"
if [ -d "/data/adb/modules_update/SingBox_TProxy" ]; then
    MAGISK_MOD_DIR="/data/adb/modules_update/SingBox_TProxy"
fi

BIN_DIR="$BOX_DIR/bin"
CONF_DIR="$BOX_DIR/conf"
SCRIPTS_DIR="$BOX_DIR/scripts"
PID_FILE="$BOX_DIR/singbox.pid"
LOG_FILE="$BOX_DIR/box.log"
PROP_FILE="$MAGISK_MOD_DIR/module.prop"

export PATH="$BIN_DIR:/data/adb/magisk:/data/adb/ksu/bin:$PATH"

TEE_CMD="tee"
if ! command -v tee >/dev/null 2>&1; then
    TEE_CMD="busybox tee"
fi

log() {
    local msg="$(date +"%H:%M:%S") [Manager] $1"
    echo "$msg" >> "$LOG_FILE"
    if [ "${INTERACTIVE:-0}" -eq 1 ]; then
        echo "$msg"
    fi
}

update_description() {
    local status="$1"
    local pid_info=""
    [ -f "$PID_FILE" ] && pid_info=" (PID: $(cat "$PID_FILE"))"
    
    if [ "$status" == "running" ]; then
        sed -i "s/^description=.*/description=🥳 Running${pid_info}/g" "$PROP_FILE"
    else
        sed -i "s/^description=.*/description=😭 Stopped/g" "$PROP_FILE"
    fi
}

start_core() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        log "Core is already running."
        return 0
    fi

    ulimit -n 65536
    ulimit -l unlimited

    nohup "$BIN_DIR/sing-box" run -c "$CONF_DIR/config.json" -D "$BIN_DIR" > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    if [ -f "/proc/$pid/oom_score_adj" ]; then
        echo -1000 > "/proc/$pid/oom_score_adj"
    fi

    local retries=0
    while [ $retries -lt 15 ]; do
        if kill -0 $pid 2>/dev/null; then
             if netstat -unlp 2>/dev/null | grep -q "$pid"; then
                 log "Core started successfully."
                 return 0
             fi
        else
             log "Core process died unexpectedly."
             rm "$PID_FILE"
             return 1
        fi
        sleep 1
        retries=$((retries + 1))
    done
    
    log "Core started (Warning: Port check timed out, but PID exists)."
    return 0
}

stop_core() {
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null
        rm "$PID_FILE"
    fi
    killall sing-box 2>/dev/null
}

run_tproxy() {
    local action=$1
    local cmd="sh $SCRIPTS_DIR/tproxy.sh $action"
    
    if [ "${INTERACTIVE:-0}" -eq 1 ]; then
        $cmd 2>&1 | $TEE_CMD -a "$LOG_FILE"
    else
        $cmd >> "$LOG_FILE" 2>&1
    fi
}

do_start() {
    log "Starting service..."
    
    sh "$SCRIPTS_DIR/tproxy.sh" stop >> "$LOG_FILE" 2>&1
    stop_core
    
    if start_core; then
        log "Core is up. Applying iptables..."
        
        run_tproxy "start"
        if [ $? -eq 0 ]; then
            update_description "running"
            log "Service started successfully."
        else
            log "Failed to apply iptables rules."
            stop_core
            update_description "stopped"
        fi
    else
        update_description "stopped"
        log "Failed to start core."
    fi
}

do_stop() {
    run_tproxy "stop"
    stop_core
    update_description "stopped"
    log "Service stopped."
}

case "$1" in
    start) do_start ;;
    stop) do_stop ;;
    toggle) 
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            do_stop
        else
            do_start
        fi
        ;;
    *) echo "Usage: $0 {start|stop|toggle}" ;;
esac
