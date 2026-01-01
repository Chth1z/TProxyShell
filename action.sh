#!/system/bin/sh

BOX_SCRIPT="/data/adb/box/scripts/start.sh"

export INTERACTIVE=1

if [ -f "$BOX_SCRIPT" ]; then

    chmod +x "$BOX_SCRIPT"

    ACTION="${1:-toggle}"
    
    /system/bin/sh "$BOX_SCRIPT" "$ACTION"
else
    echo "Error: Script not found at $BOX_SCRIPT" >&2
    exit 1
fi