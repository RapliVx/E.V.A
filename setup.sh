#!/bin/bash
# ==============================================================================
# Project E.V.A - Kernel Import Script
# ==============================================================================

set -e

echo "[*] Initializing Project E.V.A Kernel Setup..."

# Ensure the script is executed in the root of a kernel tree
if [ ! -f "Makefile" ] || ! grep -q "^VERSION =" Makefile; then
    echo "[!] ERROR: This script must be run from the root of your kernel source tree."
    exit 1
fi

REPO_URL="https://raw.githubusercontent.com/RapliVx/E.V.A/main"

echo "[*] Creating required directories..."
mkdir -p kernel/sched
mkdir -p include/linux/sched

echo "[*] Downloading E.V.A source files..."
curl -sL "$REPO_URL/kernel/kernel/sched/eva.c" -o kernel/sched/eva.c
curl -sL "$REPO_URL/kernel/include/linux/sched/eva.h" -o include/linux/sched/eva.h

if [ ! -f "kernel/sched/eva.c" ] || [ ! -s "kernel/sched/eva.c" ]; then
    echo "[!] ERROR: Failed to download eva.c. Please check your internet connection."
    exit 1
fi

echo "[*] Patching kernel/sched/Makefile..."
if ! grep -q "eva.o" kernel/sched/Makefile; then
    echo "obj-\$(CONFIG_SCHED_EVA) += eva.o" >> kernel/sched/Makefile
    echo "    -> Successfully added eva.o to kernel/sched/Makefile"
else
    echo "    -> E.V.A is already present in kernel/sched/Makefile. Skipping."
fi

echo "[*] Patching Kconfig..."
KCONFIG_TARGET="init/Kconfig"
if [ -f "kernel/Kconfig.preempt" ]; then
    KCONFIG_TARGET="kernel/Kconfig.preempt"
fi

if ! grep -q "config SCHED_EVA" "$KCONFIG_TARGET"; then
    cat << 'EOF' >> "$KCONFIG_TARGET"

config SCHED_EVA
	bool "Enhanced Visual-render Affinity (E.V.A)"
	default y
	help
	  E.V.A optimizes game rendering threads by aggressively pinning them
	  to big/prime cores and applying optimal nice values, overriding the
	  CFS scheduler. Activated on-demand via sysctl.
EOF
    echo "    -> Successfully added CONFIG_SCHED_EVA to $KCONFIG_TARGET"
else
    echo "    -> CONFIG_SCHED_EVA is already present in $KCONFIG_TARGET. Skipping."
fi

echo "[*] E.V.A Kernel Setup Completed Successfully!"
echo "[*] Please ensure CONFIG_SCHED_EVA=y is enabled in your kernel defconfig."
