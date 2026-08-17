#!/bin/sh
set -eu

GKI_ROOT=$(pwd)

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates E.V.A to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the E.V.A environment to the latest version."
}

initialize_variables() {
    if test -d "$GKI_ROOT/kernel/sched"; then
         SCHED_DIR="$GKI_ROOT/kernel/sched"
    else
         echo '[ERROR] "kernel/sched" directory not found. Are you in the kernel root?'
         exit 127
    fi

    SCHED_MAKEFILE=$SCHED_DIR/Makefile
    
    KCONFIG_TARGET=$GKI_ROOT/init/Kconfig
}

# Reverts modifications made by this script
perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$SCHED_DIR/eva" ] && rm "$SCHED_DIR/eva" && echo "[-] Symlink removed."
    grep -q "# E.V.A" "$SCHED_MAKEFILE" && sed -i '/# E.V.A/d' "$SCHED_MAKEFILE"
    grep -q "eva/" "$SCHED_MAKEFILE" && sed -i '/eva\//d' "$SCHED_MAKEFILE" && echo "[-] Makefile reverted."
    
    # Revert Kconfig source inclusion
    grep -q "kernel/sched/eva/Kconfig" "$KCONFIG_TARGET" && sed -i '/kernel\/sched\/eva\/Kconfig/d' "$KCONFIG_TARGET" && echo "[-] Kconfig reverted."

    if [ -d "$GKI_ROOT/EVA" ]; then
        rm -rf "$GKI_ROOT/EVA" && echo "[-] EVA directory deleted."
    fi
}

# Sets up or update EVA environment
setup_eva() {
    echo "[+] Setting up E.V.A..."
    test -d "$GKI_ROOT/EVA" || git clone https://github.com/RapliVx/E.V.A EVA && echo "[+] Repository cloned."
    cd "$GKI_ROOT/EVA"
    git stash && echo "[-] Stashed current changes."
    
    # Ensure backward compatibility with POSIX grep
    if git status | grep -q 'v[0-9]\+\(\.[0-9]\+\)*'; then
        git checkout main && echo "[-] Switched to main branch."
    fi
    git pull && echo "[+] Repository updated."
    
    if [ -z "${1-}" ]; then
        LATEST_TAG=$(git describe --abbrev=0 --tags 2>/dev/null || echo "")
        if [ -n "$LATEST_TAG" ]; then
            git checkout "$LATEST_TAG" && echo "[-] Checked out latest tag ($LATEST_TAG)."
        else
            git checkout main && echo "[-] Checked out main."
        fi
    else
        git checkout "$1" && echo "[-] Checked out $1." || echo "[-] Checkout default branch"
    fi
    
    cd "$SCHED_DIR"
    ln -sf "$(realpath --relative-to="$SCHED_DIR" "$GKI_ROOT/EVA/kernel")" "eva" && echo "[+] Symlink created."
    
    # Add entries in Makefile
    if ! grep -q "obj-y += eva/" "$SCHED_MAKEFILE"; then
        echo "" >> "$SCHED_MAKEFILE"
        echo "# E.V.A" >> "$SCHED_MAKEFILE"
        echo "obj-y += eva/" >> "$SCHED_MAKEFILE"
        echo "[+] Modified Makefile."
    fi
    
    if ! grep -q "source \"kernel/sched/eva/Kconfig\"" "$KCONFIG_TARGET"; then
        echo "source \"kernel/sched/eva/Kconfig\"" >> "$KCONFIG_TARGET"
        echo "[+] Modified Kconfig."
    fi
    
    echo '[+] Done.'
}

# Process command-line arguments
if [ "$#" -eq 0 ]; then
    initialize_variables
    setup_eva
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    display_usage
elif [ "$1" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_eva "$@"
fi
