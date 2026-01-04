#!/system/bin/sh

# Description: Interactive control script for manual service management
# Usage: Called by user or automation tools

readonly BOX_SCRIPT="/data/adb/box/scripts/start.sh"

export INTERACTIVE=1

# --- Error Handling ---

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# --- Main Execution ---

main() {
    local action="${1:-toggle}"
    
    # Validate script exists
    [ -f "$BOX_SCRIPT" ] || error_exit "Script not found at $BOX_SCRIPT"
    
    # Ensure script is executable
    chmod +x "$BOX_SCRIPT" 2>/dev/null || error_exit "Failed to set executable permission"
    
    # Validate action
    case "$action" in
        start|stop|toggle|restart)
            ;;
        *)
            echo "Usage: $(basename "$0") {start|stop|toggle|restart}" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  start   - Start the service" >&2
            echo "  stop    - Stop the service" >&2
            echo "  toggle  - Toggle service state (default)" >&2
            echo "  restart - Restart the service" >&2
            exit 1
            ;;
    esac
    
    # Execute action
    /system/bin/sh "$BOX_SCRIPT" "$action"
}

# Execute main function
main "$@"
