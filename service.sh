#!/system/bin/sh

BOX_SCRIPT="/data/adb/box/scripts/start.sh"

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done

wait_count=0
while [ $wait_count -lt 60 ]; do
    if ip route show table 0 | grep -q "default"; then
        break
    fi
    sleep 1
    wait_count=$((wait_count + 1))
done

sleep 2

if [ -f "$BOX_SCRIPT" ]; then
  chmod +x "$BOX_SCRIPT"
  nohup sh "$BOX_SCRIPT" start >/dev/null 2>&1 &
fi