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

WIPE_LABEL="󰃢  Limpiar historial"
ITEMS="$(cliphist list || true)"
[ -n "$ITEMS" ] || exit 0

SELECTION="$(printf '%s\n%s\n' "$ITEMS" "$WIPE_LABEL" | fuzzel --dmenu --prompt 'Portapapeles: ' --width 70)" || exit 0
[ -n "$SELECTION" ] || exit 0

if [ "$SELECTION" = "$WIPE_LABEL" ]; then
    cliphist wipe
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Hyprland "Portapapeles" "Historial vaciado" 2>/dev/null || true
    fi
    exit 0
fi

printf '%s\n' "$SELECTION" | cliphist decode | wl-copy
