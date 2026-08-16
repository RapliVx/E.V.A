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

LAST_STATE=""
LAST_PID=""

while true; do
    # 1. Menentukan State dari E.V.A Kernel
    if [ -f "/proc/sys/kernel/sched_eva_pid" ]; then
        read -r EVA_ENABLE < /proc/sys/kernel/sched_eva_enable 2>/dev/null
        read -r EVA_PID < /proc/sys/kernel/sched_eva_pid 2>/dev/null
        
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

    # 2. Update module.prop jika state atau PID berubah
    if { [ "$state" != "$LAST_STATE" ]; } || { [ "$state" = "EvaActive" ] && [ "$EVA_PID" != "$LAST_PID" ]; }; then
        case "$state" in
            EvaActive)
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ✨ Active (PID: ${EVA_PID}) ] /g" "$PROP"
                ;;
            EvaStandby)
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ 😴 Standby (Auto-Detect) ] /g" "$PROP"
                ;;
            EvaDisabled)
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ⏸️ Disabled ] /g" "$PROP"
                ;;
            *)
                sed -Ei "s/^description=(\[.*][[:space:]]*)?/description=[ ❌ Kernel Unsupported ] /g" "$PROP"
                ;;
        esac
        LAST_STATE="$state"
        LAST_PID="$EVA_PID"
    fi
    
    sleep 5
done
