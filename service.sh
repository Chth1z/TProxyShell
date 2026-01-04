#!/system/bin/sh

# Description: Manages service startup during system boot
# Runs as Magisk/KernelSU service

readonly BOX_DIR="/data/adb/box"
readonly SCRIPTS_DIR="$BOX_DIR/scripts"
readonly BOX_SCRIPT="$SCRIPTS_DIR/start.sh"
readonly RUN_DIR="$BOX_DIR/run"
readonly LOG_FILE="$RUN_DIR/box.log"

readonly BOOT_DELAY=5  # seconds to wait after boot_completed
readonly MAX_BOOT_WAIT=300  # maximum 5 minutes to wait for boot

# --- Logging ---

log() {
    local timestamp msg
    timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    msg="$1"
    
    [ ! -d "$RUN_DIR" ] && mkdir -p "$RUN_DIR"
    printf "%s [Service] %s\n" "$timestamp" "$msg" >> "$LOG_FILE"
}

log_error() {
    log "ERROR: $1"
}

# --- Boot Detection ---

# Wait for system boot to complete
wait_for_boot() {
    log "Waiting for system boot completion..."
    
    local waited=0
    
    while [ "$waited" -lt "$MAX_BOOT_WAIT" ]; do
        # Check if boot is completed
        if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; then
            log "System boot completed (waited ${waited}s)"
            return 0
        fi
        
        sleep 1
        waited=$((waited + 1))
    done
    
    log_error "Timeout waiting for boot completion after ${MAX_BOOT_WAIT}s"
    return 1
}

# --- Main Execution ---

main() {
    log "TProxyShell Boot Service Starting"
    
    # Wait for boot completion
    if ! wait_for_boot; then
        log_error "Boot timeout, attempting to start anyway..."
    fi
    
    # Additional delay for system stabilization
    log "Waiting ${BOOT_DELAY}s for system stabilization..."
    sleep "$BOOT_DELAY"
    
    # Verify startup script exists
    if [ ! -f "$BOX_SCRIPT" ]; then
        log_error "Startup script not found: $BOX_SCRIPT"
        exit 1
    fi
    
    # Set executable permission
    chmod +x "$BOX_SCRIPT" 2>/dev/null || {
        log_error "Failed to set executable permission on $BOX_SCRIPT"
        exit 1
    }
    
    # Start service in background
    log "Launching service startup script..."
    nohup sh "$BOX_SCRIPT" start >/dev/null 2>&1 &
    
    local pid=$!
    log "Service startup initiated (PID: $pid)"
}

# Execute main function
main
