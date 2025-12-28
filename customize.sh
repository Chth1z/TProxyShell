#!/system/bin/sh
SKIPUNZIP=1
BOX_PATH="/data/adb/box"

ui_print "- Installing SingBox TProxy Module..."

mkdir -p "$BOX_PATH/bin"
mkdir -p "$BOX_PATH/scripts"
mkdir -p "$BOX_PATH/conf"

ui_print "- Extracting Core & Scripts..."
unzip -o "$ZIPFILE" "bin/*" -d "$BOX_PATH" >&2
unzip -o "$ZIPFILE" "scripts/*" -d "$BOX_PATH" >&2

ui_print "- Handling Configuration..."
mkdir -p "$BOX_PATH/tmp_conf"
unzip -o "$ZIPFILE" "conf/*" -d "$BOX_PATH/tmp_conf" >&2

if [ -f "$BOX_PATH/conf/config.json" ]; then
    ui_print "- User config detected."
    cp -f "$BOX_PATH/tmp_conf/conf/config.json" "$BOX_PATH/conf/config.json.example"
    ui_print "- Existing config preserved. Default saved as config.json.example"
else
    ui_print "- Initializing default configuration..."
    cp -f "$BOX_PATH/tmp_conf/conf/config.json" "$BOX_PATH/conf/config.json"
fi
rm -rf "$BOX_PATH/tmp_conf"

ui_print "- Extracting Module files..."
unzip -o "$ZIPFILE" "module.prop" "service.sh" "action.sh" "webroot/*" -d "$MODPATH" >&2

ui_print "- Setting Permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

set_perm_recursive "$BOX_PATH" 0 0 0755 0644
set_perm_recursive "$BOX_PATH/bin" 0 0 0755 0755
set_perm_recursive "$BOX_PATH/scripts" 0 0 0755 0755

ui_print "- Installation complete!"