#!/system/bin/sh
BOX_SCRIPT="/data/adb/box/scripts/start.sh"

export INTERACTIVE=1

if [ -f "$BOX_SCRIPT" ]; then
    /system/bin/sh "$BOX_SCRIPT" toggle
else
    echo "Error: Script not found: $BOX_SCRIPT"
fi