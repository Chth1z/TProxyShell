#!/system/bin/sh

# Description: Manages sing-box core lifecycle and TProxy rules
# Usage: start.sh {start|stop|toggle|restart}

set -e  # Exit on error (except in specific error-handled sections)

# --- Directory Structure ---
readonly BOX_DIR="/data/adb/box"
readonly BIN_DIR="$BOX_DIR/bin"
readonly CONF_DIR="$BOX_DIR/conf"
readonly SCRIPTS_DIR="$BOX_DIR/scripts"
readonly RUN_DIR="$BOX_DIR/run"
readonly MAGISK_MOD_DIR="/data/adb/modules/TProxyShell"

readonly SING_BOX_BIN="$BIN_DIR/sing-box"
readonly CONFIG_FILE="$CONF_DIR/config.json"
readonly SETTINGS_FILE="$CONF_DIR/settings.ini"
readonly TPROXY_SCRIPT="$SCRIPTS_DIR/tproxy.sh"

readonly PID_FILE="$RUN_DIR/sing-box.pid"
readonly LOG_FILE="$RUN_DIR/box.log"
readonly PROP_FILE="$MAGISK_MOD_DIR/module.prop"

readonly LOG_MAX_SIZE=1048576  # 1MB
readonly STARTUP_MAX_WAIT=10   # seconds
readonly SHUTDOWN_TIMEOUT=10   # seconds

export PATH="$BIN_DIR:/data/adb/magisk:/data/adb/ksu/bin:$PATH"
export BOX_DIR BIN_DIR CONF_DIR SCRIPTS_DIR RUN_DIR

# --- Logging Functions ---

# Log message with timestamp and optional output to console
log() {
    local timestamp msg
    timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    msg="$1"
    
    [ ! -d "$RUN_DIR" ] && mkdir -p "$RUN_DIR"
    
    printf "%s [Manager] %s\n" "$timestamp" "$msg" >> "$LOG_FILE"
    
    # Output to console if interactive mode
    [ "${INTERACTIVE:-0}" -eq 1 ] && printf "%s [Manager] %s\n" "$timestamp" "$msg"
}

# Log error message
log_error() {
    log "ERROR: $1"
}

# Log warning message
log_warn() {
    log "WARN: $1"
}

# --- Module Status Management ---

# Update module description in module.prop
# Args: $1=status (running|error|stopped), $2=detail (optional)
update_description() {
    local status="$1"
    local detail="${2:-}"
    local pid_info="" desc_text
    
    [ -f "$PID_FILE" ] && [ -s "$PID_FILE" ] && pid_info=" (PID: $(cat "$PID_FILE"))"
    
    case "$status" in
        running)
            desc_text="🥳 RUNNING${pid_info}"
            ;;
        error)
            desc_text="😭 ERROR ${detail:-Unknown}"
            ;;
        stopped)
            desc_text="😴 STOPPED"
            ;;
        *)
            desc_text="😇 UNKNOWN"
            ;;
    esac

    [ -f "$PROP_FILE" ] && {
        sed -i "s|^description=.*|description=${desc_text}|g" "$PROP_FILE" || \
            log_warn "Failed to update module description"
    }
}

# --- Environment Initialization ---

# Initialize runtime environment and rotate logs
init_environment() {
    log "Initializing environment..."
    
    # Create run directory if missing
    if [ ! -d "$RUN_DIR" ]; then
        mkdir -p "$RUN_DIR" || {
            log_error "Failed to create run directory: $RUN_DIR"
            return 1
        }
        chmod 0755 "$RUN_DIR"
    fi
    
    # Rotate logs if size exceeds limit
    if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$LOG_MAX_SIZE" ]; then
        log "Rotating logs (size > ${LOG_MAX_SIZE} bytes)"
        
        [ -f "${LOG_FILE}.2" ] && mv -f "${LOG_FILE}.2" "${LOG_FILE}.3" 2>/dev/null
        [ -f "${LOG_FILE}.1" ] && mv -f "${LOG_FILE}.1" "${LOG_FILE}.2" 2>/dev/null
        mv -f "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null
        
        # Clean old logs (>7 days)
        find "$RUN_DIR" -name "box.log.*" -mtime +7 -delete 2>/dev/null || true
    fi
    
    # Set executable permissions
    [ -f "$SING_BOX_BIN" ] && chmod +x "$SING_BOX_BIN" 2>/dev/null
    [ -f "$TPROXY_SCRIPT" ] && chmod +x "$TPROXY_SCRIPT" 2>/dev/null
    
    # Set permissions for all scripts in SCRIPTS_DIR
    find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    log "Environment initialization complete"
    return 0
}

# --- Resource Validation ---

# Check integrity of required files
check_resource_integrity() {
    log "Checking resource integrity..."
    
    local required_files="$SING_BOX_BIN $CONFIG_FILE $SETTINGS_FILE $TPROXY_SCRIPT"
    local missing_files=""
    
    for file in $required_files; do
        if [ ! -f "$file" ]; then
            local filename
            filename="$(basename "$file")"
            log_error "Critical file missing: $file"
            missing_files="$missing_files $filename"
        fi
    done
    
    if [ -n "$missing_files" ]; then
        update_description "error" "Missing:$missing_files"
        return 1
    fi
    
    # Verify sing-box binary is executable
    if [ ! -x "$SING_BOX_BIN" ]; then
        log_error "sing-box binary is not executable"
        update_description "error" "Binary Not Executable"
        return 1
    fi
    
    log "Resource integrity check passed"
    return 0
}

# Validate sing-box configuration
check_config_validity() {
    log "Validating configuration..."
    
    local check_output check_result
    
    # Run sing-box config check
    check_output=$("$SING_BOX_BIN" check -c "$CONFIG_FILE" -D "$RUN_DIR" 2>&1)
    check_result=$?
    
    if [ $check_result -ne 0 ]; then
        log_error "Configuration validation failed!"
        log_error "Details: $check_output"
        update_description "error" "Invalid Config"
        return 1
    fi
    
    log "Configuration validation passed"
    return 0
}

# --- Core Process Management ---

# Check if core process is running
is_core_running() {
    [ -f "$PID_FILE" ] && [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# Start sing-box core process
start_core() {
    if is_core_running; then
        log "Core is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    log "Starting sing-box core..."
    
    # Set resource limits
    ulimit -n 65536 2>/dev/null || log_warn "Failed to set file descriptor limit"
    ulimit -l unlimited 2>/dev/null || log_warn "Failed to set locked memory limit"

    # Read TCP port from settings for validation
    local tcp_port
    if [ -f "$SETTINGS_FILE" ]; then
        tcp_port=$(grep "^PROXY_TCP_PORT=" "$SETTINGS_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | head -n1)
    fi
    tcp_port="${tcp_port:-1536}"
    
    # Start core with proper user:group (root:net_admin = 0:3005)
    if command -v busybox >/dev/null 2>&1; then
        log "Starting with GID 3005 (net_admin) using busybox"
        nohup busybox setuidgid 0:3005 "$SING_BOX_BIN" run \
            -c "$CONFIG_FILE" \
            -D "$RUN_DIR" \
            >/dev/null 2>&1 &
    else
        log_warn "busybox not found, starting as root:root"
        nohup "$SING_BOX_BIN" run \
            -c "$CONFIG_FILE" \
            -D "$RUN_DIR" \
            >/dev/null 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait for process to stabilize
    local waited=0
    while [ $waited -lt "$STARTUP_MAX_WAIT" ]; do
        # Check if process is still alive
        if ! kill -0 "$pid" 2>/dev/null; then
            log_error "Core process died during startup"
            rm -f "$PID_FILE"
            return 1
        fi
        
        # Check if port is listening (using netstat or ss)
        if netstat -tunlp 2>/dev/null | grep -q ":${tcp_port}.*LISTEN" || \
           ss -tunlp 2>/dev/null | grep -q ":${tcp_port}.*LISTEN"; then
            log "Core started successfully (PID: $pid, Port: $tcp_port)"
            return 0
        fi
        
        sleep 0.5
        waited=$((waited + 1))
    done
    
    # Timeout reached
    log_warn "Core started but port $tcp_port not listening after ${STARTUP_MAX_WAIT}s"
    log_warn "Process may still be initializing, continuing anyway..."
    return 0
}

# Stop sing-box core process
stop_core() {
    log "Stopping core..."
    
    # Stop by PID file
    if [ -f "$PID_FILE" ] && [ -s "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log "Sending SIGTERM to PID $pid"
            kill "$pid" 2>/dev/null
            
            # Wait for graceful shutdown
            local wait_count=0
            while kill -0 "$pid" 2>/dev/null && [ $wait_count -lt "$SHUTDOWN_TIMEOUT" ]; do
                sleep 0.5
                wait_count=$((wait_count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Process $pid did not stop gracefully, sending SIGKILL"
                kill -9 "$pid" 2>/dev/null
                sleep 0.5
            fi
        fi
    fi
    
    # Cleanup any remaining processes
    if pgrep -f "sing-box.*run.*$CONFIG_FILE" >/dev/null 2>&1; then
        log_warn "Found orphaned sing-box processes, cleaning up..."
        pkill -9 -f "sing-box.*run.*$CONFIG_FILE" 2>/dev/null || \
            killall -9 sing-box 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log "Core stopped"
}

# --- TProxy Management ---

# Execute TProxy script
run_tproxy() {
    local action="$1"
    log "Executing TProxy script: $action"
    
    [ ! -f "$TPROXY_SCRIPT" ] && {
        log_error "TProxy script not found: $TPROXY_SCRIPT"
        return 1
    }
    
    # Execute script and capture output
    set +e  # Don't exit on error
    sh "$TPROXY_SCRIPT" "$action" >> "$LOG_FILE" 2>&1
    local ret=$?
    set -e
    
    if [ $ret -eq 0 ]; then
        log "TProxy $action completed successfully"
        return 0
    else
        log_error "TProxy $action failed (exit code: $ret)"
        return 1
    fi
}

# --- Main Service Operations ---

# Start service
do_start() {
    log "Starting TProxyShell Service"
    
    # Initialize environment
    if ! init_environment; then
        update_description "error" "Init Failed"
        exit 1
    fi

    # Check resources
    if ! check_resource_integrity; then
        exit 1
    fi

    # Clean up any existing state
    log "Cleaning up previous state..."
    run_tproxy "stop" >/dev/null 2>&1 || true
    stop_core
    
    # Validate configuration
    if ! check_config_validity; then
        exit 1
    fi
    
    # Start core
    if ! start_core; then
        update_description "error" "Core Start Failed"
        exit 1
    fi
    
    # Apply TProxy rules
    if ! run_tproxy "start"; then
        log_error "Failed to apply iptables rules, rolling back..."
        stop_core
        run_tproxy "stop" >/dev/null 2>&1 || true
        update_description "error" "Iptables Failed"
        exit 1
    fi
    
    # Update status
    update_description "running"
    log "Service started successfully"
}

# Stop service
do_stop() {
    log "Stopping TProxyShell Service"
    
    # Remove TProxy rules
    run_tproxy "stop" || log_warn "TProxy cleanup encountered errors"
    
    # Stop core
    stop_core
    
    # Update status
    update_description "stopped"
    log "Service stopped"
}

# Toggle service (start if stopped, stop if running)
do_toggle() {
    if is_core_running; then
        do_stop
    else
        do_start
    fi
}

# --- Main Entry Point ---

main() {
    local action="${1:-}"
    
    case "$action" in
        start)
            do_start
            ;;
        stop)
            do_stop
            ;;
        toggle)
            do_toggle
            ;;
        restart)
            log "Restarting service..."
            do_stop
            sleep 2
            do_start
            ;;
        *)
            echo "Usage: $0 {start|stop|toggle|restart}"
            echo ""
            echo "Commands:"
            echo "  start   - Start the service"
            echo "  stop    - Stop the service"
            echo "  toggle  - Toggle service state"
            echo "  restart - Restart the service"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
