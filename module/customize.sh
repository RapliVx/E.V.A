#!/system/bin/sh

# --- E.V.A Mngr ---
# Author: @RapliVx

ui_print " "
ui_print " ==================================="
ui_print "        E.V.A - M A N A G E R       "
ui_print "            - Version 1.0 -         "
ui_print " ==================================="
ui_print " "
sleep 0.2

ui_print " [ E.V.A SUBSYSTEM CHECK ]"

if [ -e "/proc/sys/kernel/sched_eva_pid" ]; then
    EVA_MODE=$(cat /proc/sys/kernel/sched_eva_smart_mode 2>/dev/null)
    EVA_NICE=$(cat /proc/sys/kernel/sched_eva_nice 2>/dev/null)
    EVA_AUTO=$(cat /proc/sys/kernel/sched_eva_auto_detect 2>/dev/null)
    
    ui_print " - STATUS      : Supported"
    ui_print " - SMART MODE  : $EVA_MODE"
    ui_print " - NICE BOOST  : $EVA_NICE"
    if [ "$EVA_AUTO" == "1" ]; then
        ui_print " - AUTO DETECT : Enabled"
    else
        ui_print " - AUTO DETECT : Disabled"
    fi
else
    ui_print " - STATUS  : NOT SUPPORTED"
    ui_print " "
    ui_print " ==================================="
    ui_print "    ! FATAL ERROR: E.V.A MISSING !  "
    ui_print " ==================================="
    abort " Installation cancelled: Your kernel does not yet support E.V.A Optimizer."
fi

ui_print " "
sleep 0.3

ui_print " [ E.V.A PACKAGE SYNC ]"
FILTER_FILE="$MODPATH/PackageList.txt"
TARGET_LIST="$(cat "$ZIPFILE" 2>/dev/null | unzip -p "$ZIPFILE" "PackageList.txt" 2>/dev/null)"
FILTERED_PKGS="$(cmd package list packages --user 0 | grep -Eo "$TARGET_LIST")"

if [ -n "$FILTERED_PKGS" ]; then
    echo "$FILTERED_PKGS" | while read -r line; do
        ui_print " > SYNCING : ${line#package:}"
    done
else
    ui_print " > STATUS  : Manual Sync Required"
fi
echo "$FILTERED_PKGS" | sed 's/package://g' > "$FILTER_FILE"
sleep 0.3

ui_print " ==================================="
ui_print "     UNIT-01 : READY TO LAUNCH      "
ui_print " ==================================="
ui_print " "
