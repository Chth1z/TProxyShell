#!/system/bin/sh
SKIPUNZIP=1

BOX_PATH="/data/adb/box"
MOD_CONFIG="$BOX_PATH/conf/config.json"
MOD_SETTINGS="$BOX_PATH/settings.ini"

TMP_DIR="$BOX_PATH/tmp_install"

print_line() { ui_print "***************************************"; }
print_title() { 
  print_line
  ui_print "      TProxyShell      "
  print_line
}

keytest() {
  ui_print "- Press Vol Key: "
  ui_print "   [Vol Up]   : $1"
  ui_print "   [Vol Down] : $2"
  
  local loop=0
  local key_result=""
  
  while true; do
      if getevent -c 1 2>&1 | grep -q "00"; then continue; else break; fi
  done

  while true; do

    getevent -l -c 1 2>&1 > /data/local/tmp/keycheck
    
    if grep -q "KEY_VOLUMEUP" /data/local/tmp/keycheck || grep -q "0073" /data/local/tmp/keycheck; then
      key_result="UP"
      break
    elif grep -q "KEY_VOLUMEDOWN" /data/local/tmp/keycheck || grep -q "0072" /data/local/tmp/keycheck; then
      key_result="DOWN"
      break
    fi
    
    loop=$((loop + 1))
    if [ $loop -gt 100 ]; then
       break
    fi
  done
  
  rm -f /data/local/tmp/keycheck
  
  if [ "$key_result" = "UP" ]; then
    return 0
  else
    return 1
  fi
}

print_title

ui_print "- Initializing installation..."

ui_print "- Updating Core binaries & Scripts..."
mkdir -p "$BOX_PATH/bin"
mkdir -p "$BOX_PATH/scripts"
mkdir -p "$BOX_PATH/conf"

unzip -o "$ZIPFILE" "bin/*" -d "$BOX_PATH" >&2
unzip -o "$ZIPFILE" "scripts/*" -d "$BOX_PATH" >&2

ui_print "- Extracting module files..."
unzip -o "$ZIPFILE" "module.prop" "service.sh" "action.sh" "webroot/*" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "conf/*" -d "$TMP_DIR" >&2

KEEP_CONFIG=0

if [ -f "$MOD_CONFIG" ] || [ -f "$MOD_SETTINGS" ]; then
  ui_print " "
  ui_print "Detected existing configuration!"
  
  if keytest "Preserve current config (Recommended)" "Reset to default"; then
    KEEP_CONFIG=1
    ui_print "Action: KEEP User Config"
  else
    KEEP_CONFIG=0
    ui_print "Action: RESET Config (Backup old)"
  fi
else
  ui_print "- No existing config found. Installing default."
fi

mkdir -p "$TMP_DIR/conf"

if [ "$KEEP_CONFIG" -eq 1 ]; then
    
    if [ -f "$MOD_CONFIG" ]; then
        ui_print "- Preserving config.json..."
        if [ -f "$TMP_DIR/conf/config.json" ]; then
            cp -f "$TMP_DIR/conf/config.json" "$BOX_PATH/conf/config.json.example"
        fi
    else
        if [ -f "$TMP_DIR/conf/config.json" ]; then
            cp -f "$TMP_DIR/conf/config.json" "$MOD_CONFIG"
        fi
    fi

    if [ -f "$MOD_SETTINGS" ]; then
        ui_print "- Preserving settings.ini..."
        if [ -f "$TMP_DIR/settings.ini" ]; then
            cp -f "$TMP_DIR/settings.ini" "$BOX_PATH/settings.ini.example"
        fi
    else
        if [ -f "$TMP_DIR/settings.ini" ]; then
            cp -f "$TMP_DIR/settings.ini" "$MOD_SETTINGS"
        fi
    fi

else
    if [ -f "$MOD_CONFIG" ]; then
        ui_print "- Backing up old config.json to .bak..."
        cp -f "$MOD_CONFIG" "$MOD_CONFIG.bak"
    fi
    ui_print "- Installing default config.json..."
    cp -f "$TMP_DIR/conf/config.json" "$MOD_CONFIG"

    if [ -f "$MOD_SETTINGS" ]; then
        ui_print "- Backing up old settings.ini to .bak..."
        cp -f "$MOD_SETTINGS" "$MOD_SETTINGS.bak"
    fi
    
    if [ -f "$TMP_DIR/settings.ini" ]; then
        ui_print "- Installing default settings.ini..."
        cp -f "$TMP_DIR/settings.ini" "$MOD_SETTINGS"
    else
        ui_print "Warning: settings.ini not found in ZIP!"
    fi
fi

rm -rf "$TMP_DIR"

ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

set_perm_recursive "$BOX_PATH" 0 0 0755 0644
set_perm_recursive "$BOX_PATH/bin" 0 0 0755 0755
set_perm_recursive "$BOX_PATH/scripts" 0 0 0755 0755

if [ -f "$MOD_SETTINGS" ]; then
    set_perm "$MOD_SETTINGS" 0 0 0644
fi

print_line
ui_print "   Installation Successful!   "
ui_print "   Reboot to apply changes.   "
print_line
