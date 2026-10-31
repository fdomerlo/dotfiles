#!/usr/bin/env bash
# Historial de portapapeles con cliphist + wofi.
set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1 || ! command -v wofi >/dev/null 2>&1; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Hyprland "Portapapeles" "Faltan cliphist o wofi"
    fi
    exit 1
fi

SELECTION="$(cliphist list | wofi --dmenu --prompt 'Portapapeles')" || exit 0
[ -n "$SELECTION" ] || exit 0
printf '%s\n' "$SELECTION" | cliphist decode | wl-copy
