#!/usr/bin/env bash
# Historial de portapapeles con cliphist + fuzzel.
set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Hyprland "Portapapeles" "Falta cliphist"
    fi
    exit 1
fi

if ! command -v fuzzel >/dev/null 2>&1; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Hyprland "Portapapeles" "Falta fuzzel"
    fi
    exit 1
fi

SELECTION="$(cliphist list | fuzzel --dmenu --prompt 'Portapapeles: ' --width 70)" || exit 0

[ -n "$SELECTION" ] || exit 0
printf '%s\n' "$SELECTION" | cliphist decode | wl-copy
