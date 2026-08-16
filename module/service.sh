#!/bin/sh

MODPATH="${0%/*}"
PROP="$MODPATH/module.prop"

# Tunggu sampai boot selesai
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# Jalankan evadaemon Rust di background
if [ -f "$MODPATH/evadaemon" ]; then
    chmod +x "$MODPATH/evadaemon"
    nohup "$MODPATH/evadaemon" "$MODPATH/PackageList.txt" > /dev/null 2>&1 &
fi

while true; do
    # 1. Menentukan State dari E.V.A Kernel
    if [ -e "/proc/sys/kernel/sched_eva_pid" ]; then
        EVA_ENABLE=$(cat /proc/sys/kernel/sched_eva_enable 2>/dev/null)
        EVA_PID=$(cat /proc/sys/kernel/sched_eva_pid 2>/dev/null)
        
        if [ "$EVA_ENABLE" != "1" ]; then
            state="EvaDisabled"
        elif [ "$EVA_PID" != "0" ] && [ -n "$EVA_PID" ]; then
            state="EvaActive"
        else
            state="EvaStandby"
        fi
    else
        state="Offline"
    fi

    # 2. Update module.prop menggunakan style regex
    current_desc="$(grep '^description=' "$PROP" 2>/dev/null)"
    
    case "$state" in
        EvaActive)
            if ! echo "$current_desc" | grep -q "Active"; then
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ✨ Active (PID: ${EVA_PID}) ] /g" "$PROP"
            fi
            ;;
        EvaStandby)
            if ! echo "$current_desc" | grep -q "Standby"; then
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ 😴 Standby (Auto-Detect) ] /g" "$PROP"
            fi
            ;;
        EvaDisabled)
            if ! echo "$current_desc" | grep -q "Disabled"; then
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ⏸️ Disabled ] /g" "$PROP"
            fi
            ;;
        *)
            if ! echo "$current_desc" | grep -q "Offline"; then
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ❌ Kernel Unsupported ] /g" "$PROP"
            fi
            ;;
    esac
    
    sleep 5
done
