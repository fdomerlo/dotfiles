#!/usr/bin/env bash

set -euo pipefail

# Default values for flags
DRY_RUN=0
SKIP_SYSTEM=0
SKIP_FLATPAK=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=1 ;;
        --skip-system) SKIP_SYSTEM=1 ;;
        --skip-flatpak) SKIP_FLATPAK=1 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

export DRY_RUN SKIP_SYSTEM SKIP_FLATPAK
export DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to run a script with logging
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")

    echo "==> [STEP] Running $script_name..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY RUN] Would execute: $script_path"
    else
        bash "$script_path"
        echo "==> [STEP] $script_name completed successfully."
    fi
}

# Require non-root execution
if [[ $EUID -eq 0 ]]; then
    echo "Error: This script must not be run as root. It will ask for sudo when needed."
    exit 1
fi

# Ask for sudo validation upfront if system step is not skipped
if [[ "$SKIP_SYSTEM" -eq 0 ]]; then
    echo "==> Asking for sudo password upfront..."
    sudo -v

    # Keep sudo session alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# Orchestrate scripts sequentially
if [[ "$SKIP_SYSTEM" -eq 0 ]]; then
    run_script "$DOTFILES_DIR/scripts/01-system.sh"
fi

run_script "$DOTFILES_DIR/scripts/02-fonts.sh"
run_script "$DOTFILES_DIR/scripts/03-dotfiles.sh"
run_script "$DOTFILES_DIR/scripts/04-toolchains.sh"

if [[ "$SKIP_FLATPAK" -eq 0 ]]; then
    run_script "$DOTFILES_DIR/scripts/05-flatpak.sh"
fi

echo "==> Provisioning complete. You can run scripts/verify.sh to check the installation."
