#!/system/bin/sh

SKIPUNZIP=1
BOX_DIR="/data/adb/box"
CONF_DIR="$BOX_DIR/conf"
BIN_DIR="$BOX_DIR/bin"
SCRIPTS_DIR="$BOX_DIR/scripts"
RUN_DIR="$BOX_DIR/run"

TMP_BACKUP="/data/local/tmp/box_backup_$(date +%s)"

ui_print() { echo "$1"; }

choose_action() {
  local title="$1"
  local default_action="$2" # true=Keep, false=Reset
  local wait_time=10
  
  ui_print " "
  ui_print "*******************************************"
  ui_print " $title"
  ui_print "*******************************************"
  ui_print "  [ Vol + ] : Yes / Keep"
  ui_print "  [ Vol - ] : No / Reset"
  ui_print " "
  ui_print "  > Waiting for input ($wait_time s)..."

  while read -r dummy; do :; done < /dev/input/event0 2>/dev/null &
  kill $! 2>/dev/null

  local start_time=$(date +%s)

  while true; do
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $wait_time ]; then
        if [ "$default_action" = "true" ]; then
            ui_print "  > Timeout. Default: [Keep Config]"
            return 0
        else
            ui_print "  > Timeout. Default: [Reset Config]"
            return 1
        fi
    fi

    key_event=$(timeout 0.1 getevent -lc 1 2>&1)

    if echo "$key_event" | grep -q "KEY_VOLUMEUP"; then
        ui_print "  > Selected: [Keep Config]"
        return 0
    elif echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
        ui_print "  > Selected: [Reset Config]"
        return 1
    fi
  done
}

ui_print "- Starting TProxyShell installation..."

ui_print "- Extracting module files..."
unzip -o "$ZIPFILE" -x 'META-INF/*' -x 'box/*' -d "$MODPATH" >&2

set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

KEEP_CONFIG=true

if [ -f "$CONF_DIR/settings.ini" ] || [ -f "$CONF_DIR/config.json" ]; then
  ui_print "- Old configuration detected."
  if choose_action "Keep existing configuration?" "true"; then
    KEEP_CONFIG=true
  else
    KEEP_CONFIG=false
  fi
else
  KEEP_CONFIG=false
fi

if [ "$KEEP_CONFIG" = true ]; then
  ui_print "- Backing up config to temporary storage..."
  rm -rf "$TMP_BACKUP"
  mkdir -p "$TMP_BACKUP"
  
  [ -f "$CONF_DIR/settings.ini" ] && cp -f "$CONF_DIR/settings.ini" "$TMP_BACKUP/"
  [ -f "$CONF_DIR/config.json" ] && cp -f "$CONF_DIR/config.json" "$TMP_BACKUP/"

  if [ ! -f "$TMP_BACKUP/settings.ini" ] && [ ! -f "$TMP_BACKUP/config.json" ]; then
    ui_print "  ! Warning: Backup failed or no files found. Using default config."
    KEEP_CONFIG=false
  fi
fi

ui_print "- Cleaning up old version..."
rm -rf "$SCRIPTS_DIR"
if [ "$KEEP_CONFIG" = false ]; then
    rm -rf "$CONF_DIR"
fi

mkdir -p "$BOX_DIR"
mkdir -p "$CONF_DIR"
mkdir -p "$RUN_DIR"

ui_print "- Deploying core files to /data/adb/box ..."
unzip -o "$ZIPFILE" "box/*" -d "/data/adb/" >&2

if [ "$KEEP_CONFIG" = true ]; then
  ui_print "- Restoring user configuration..."
  if [ -f "$TMP_BACKUP/settings.ini" ]; then
    cp -f "$TMP_BACKUP/settings.ini" "$CONF_DIR/"
    ui_print "  > settings.ini restored."
  fi
  if [ -f "$TMP_BACKUP/config.json" ]; then
    cp -f "$TMP_BACKUP/config.json" "$CONF_DIR/"
    ui_print "  > config.json restored."
  fi
  rm -rf "$TMP_BACKUP"
else
  ui_print "- Default configuration applied."
fi

ui_print "- Setting file permissions..."

set_perm_recursive "$BOX_DIR" 0 0 0755 0644
set_perm_recursive "$SCRIPTS_DIR" 0 0 0755 0755
set_perm_recursive "$BIN_DIR" 0 0 0755 0755
set_perm_recursive "$CONF_DIR" 0 0 0755 0644
set_perm_recursive "$RUN_DIR" 0 0 0755 0777

if [ -f "$BIN_DIR/sing-box" ]; then
    set_perm "$BIN_DIR/sing-box" 0 0 0755
fi

if [ -f "$SCRIPTS_DIR/tproxy.sh" ]; then
    set_perm "$SCRIPTS_DIR/tproxy.sh" 0 0 0755
fi

ui_print "- Installation successful!"
ui_print "- Recommendation: Reboot your device."