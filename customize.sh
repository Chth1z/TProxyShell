#!/system/bin/sh

# Description: Installation script for TProxyShell module
# Handles upgrade, fresh install, and configuration preservation

SKIPUNZIP=1

# --- Directory Structure ---
readonly BOX_DIR="/data/adb/box"
readonly CONF_DIR="$BOX_DIR/conf"
readonly BIN_DIR="$BOX_DIR/bin"
readonly SCRIPTS_DIR="$BOX_DIR/scripts"
readonly RUN_DIR="$BOX_DIR/run"

readonly TMP_BACKUP="/data/local/tmp/box_backup_$(date +%s)"

# --- UI Functions ---

ui_print() { 
    echo "$1" 
}

ui_error() {
    ui_print "ERROR: $1"
}

ui_success() {
    ui_print "√ $1"
}

# --- User Input Handling ---

# Interactive choice with volume buttons
# Args: $1=title, $2=default_action (true/false)
# Returns: 0 for Yes/Keep, 1 for No/Reset
choose_action() {
    local title="$1"
    local default_action="$2"
    local wait_time=10
    
    ui_print " "
    ui_print "● $title"
    ui_print " "
    ui_print "  [ Vol + ] : Yes / Keep"
    ui_print "  [ Vol - ] : No / Reset"
    ui_print " "
    ui_print "  > Waiting for input ($wait_time s)..."

    # Clear input buffer
    while read -r dummy; do :; done < /dev/input/event0 2>/dev/null &
    local clear_pid=$!
    sleep 0.1
    kill "$clear_pid" 2>/dev/null

    local start_time
    start_time=$(date +%s)

    while true; do
        local current_time elapsed
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        # Check timeout
        if [ $elapsed -ge $wait_time ]; then
            if [ "$default_action" = "true" ]; then
                ui_print "  > Timeout. Default: [Keep Config]"
                return 0
            else
                ui_print "  > Timeout. Default: [Reset Config]"
                return 1
            fi
        fi

        # Check for key events
        local key_event
        key_event=$(timeout 0.1 getevent -lc 1 2>&1 || true)

        if echo "$key_event" | grep -q "KEY_VOLUMEUP"; then
            ui_print "  > Selected: [Keep Config]"
            return 0
        elif echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
            ui_print "  > Selected: [Reset Config]"
            return 1
        fi
    done
}

# --- File Operations ---

# Backup existing configuration
backup_config() {
    ui_print "- Backing up configuration..."
    
    rm -rf "$TMP_BACKUP"
    mkdir -p "$TMP_BACKUP" || {
        ui_error "Failed to create backup directory"
        return 1
    }
    
    local backed_up=0
    
    if [ -f "$CONF_DIR/settings.ini" ]; then
        cp -f "$CONF_DIR/settings.ini" "$TMP_BACKUP/" && {
            ui_print "  > settings.ini backed up"
            backed_up=$((backed_up + 1))
        }
    fi
    
    if [ -f "$CONF_DIR/config.json" ]; then
        cp -f "$CONF_DIR/config.json" "$TMP_BACKUP/" && {
            ui_print "  > config.json backed up"
            backed_up=$((backed_up + 1))
        }
    fi
    
    if [ $backed_up -eq 0 ]; then
        ui_error "No configuration files found to backup"
        return 1
    fi
    
    ui_success "Configuration backed up successfully"
    return 0
}

# Restore backed up configuration
restore_config() {
    ui_print "- Restoring configuration..."
    
    [ ! -d "$TMP_BACKUP" ] && {
        ui_error "Backup directory not found"
        return 1
    }
    
    local restored=0
    
    if [ -f "$TMP_BACKUP/settings.ini" ]; then
        cp -f "$TMP_BACKUP/settings.ini" "$CONF_DIR/" && {
            ui_print "  > settings.ini restored"
            restored=$((restored + 1))
        }
    fi
    
    if [ -f "$TMP_BACKUP/config.json" ]; then
        cp -f "$TMP_BACKUP/config.json" "$CONF_DIR/" && {
            ui_print "  > config.json restored"
            restored=$((restored + 1))
        }
    fi
    
    # Clean up backup
    rm -rf "$TMP_BACKUP"
    
    if [ $restored -eq 0 ]; then
        ui_error "No configuration files restored"
        return 1
    fi
    
    ui_success "Configuration restored successfully"
    return 0
}

# --- Installation Steps ---

# Extract module files to MODPATH
extract_module_files() {
    ui_print "- Extracting module files..."
    
    unzip -o "$ZIPFILE" -x 'META-INF/*' -x 'bin/*' -x 'conf/*' -x 'scripts/*' -d "$MODPATH" >&2 || {
        ui_error "Failed to extract module files"
        return 1
    }
    
    # Set permissions for module scripts
    [ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
    [ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
    
    ui_success "Module files extracted"
    return 0
}

# Deploy core files to /data/adb/box
deploy_core_files() {
    ui_print "- Deploying core files to $BOX_DIR..."
    
    # Create directory structure
    mkdir -p "$BOX_DIR" "$CONF_DIR" "$RUN_DIR" "$BIN_DIR" "$SCRIPTS_DIR" || {
        ui_error "Failed to create directory structure"
        return 1
    }
    
    # Extract core files
    unzip -o "$ZIPFILE" "bin/*" "scripts/*" "conf/*" -d "$BOX_DIR" >&2 || {
        ui_error "Failed to extract core files"
        return 1
    }
    
    ui_success "Core files deployed"
    return 0
}

# Set file permissions
set_file_permissions() {
    ui_print "- Setting file permissions..."
    
    # Set directory permissions
    set_perm_recursive "$BOX_DIR" 0 0 0755 0644 || {
        ui_error "Failed to set base directory permissions"
        return 1
    }
    
    # Scripts must be executable
    set_perm_recursive "$SCRIPTS_DIR" 0 0 0755 0755 || {
        ui_error "Failed to set scripts permissions"
        return 1
    }
    
    # Binaries must be executable
    set_perm_recursive "$BIN_DIR" 0 0 0755 0755 || {
        ui_error "Failed to set binary permissions"
        return 1
    }
    
    # Config files should be readable only
    set_perm_recursive "$CONF_DIR" 0 0 0755 0644 || {
        ui_error "Failed to set config permissions"
        return 1
    }
    
    # Run directory needs write access
    set_perm_recursive "$RUN_DIR" 0 0 0755 0777 || {
        ui_error "Failed to set run directory permissions"
        return 1
    }
    
    # Ensure critical files are executable
    [ -f "$BIN_DIR/sing-box" ] && set_perm "$BIN_DIR/sing-box" 0 0 0755
    [ -f "$SCRIPTS_DIR/tproxy.sh" ] && set_perm "$SCRIPTS_DIR/tproxy.sh" 0 0 0755
    [ -f "$SCRIPTS_DIR/start.sh" ] && set_perm "$SCRIPTS_DIR/start.sh" 0 0 0755
    
    ui_success "Permissions set correctly"
    return 0
}

# Clean up old installation
cleanup_old_installation() {
    ui_print "- Cleaning up old version..."
    
    # Remove old scripts and binaries
    rm -rf "$SCRIPTS_DIR"
    rm -rf "$BIN_DIR"
    
    # Remove old logs and PID files
    rm -f "$RUN_DIR/"*.log
    rm -f "$RUN_DIR/"*.pid
    
    ui_print "  > Old version cleaned up"
    return 0
}

# --- Main Installation Flow ---

main() {
    # Step 1: Extract module files
    if ! extract_module_files; then
        ui_error "Installation failed at module extraction"
        exit 1
    fi
    
    # Step 2: Determine configuration strategy
    local KEEP_CONFIG=false
    
    if [ -f "$CONF_DIR/settings.ini" ] || [ -f "$CONF_DIR/config.json" ]; then
        ui_print "- Existing configuration detected"
        
        if choose_action "Keep existing configuration?" "true"; then
            KEEP_CONFIG=true
            
            # Backup configuration
            if ! backup_config; then
                ui_error "Configuration backup failed"
                ui_print "  > Proceeding with fresh configuration"
                KEEP_CONFIG=false
            fi
        else
            KEEP_CONFIG=false
        fi
    else
        ui_print "- No existing configuration found"
        KEEP_CONFIG=false
    fi
    
    # Step 3: Clean up old installation
    cleanup_old_installation
    
    # Step 4: Remove old config if not keeping
    if [ "$KEEP_CONFIG" = false ]; then
        rm -rf "$CONF_DIR"
        ui_print "  > Old configuration removed"
    fi
    
    # Step 5: Deploy core files
    if ! deploy_core_files; then
        ui_error "Installation failed at core file deployment"
        exit 1
    fi
    
    # Step 6: Restore configuration if keeping
    if [ "$KEEP_CONFIG" = true ]; then
        if ! restore_config; then
            ui_error "Configuration restoration failed"
            ui_print "  > Default configuration will be used"
        fi
    else
        ui_print "- Using default configuration"
    fi
    
    # Step 7: Set file permissions
    if ! set_file_permissions; then
        ui_error "Installation failed at permission setting"
        exit 1
    fi
    
    # Installation complete
    ui_print " "
    ui_print " Installation Successful!"
    ui_print " "
    ui_print "  > Module installed to: $MODPATH"
    ui_print "  > Core files deployed to: $BOX_DIR"
    
    if [ "$KEEP_CONFIG" = true ]; then
        ui_print "  > Configuration: Preserved"
    else
        ui_print "  > Configuration: Default"
    fi
    
    ui_print " "
}

# Execute main installation
main
