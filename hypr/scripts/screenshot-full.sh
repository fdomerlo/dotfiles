#!/usr/bin/env bash
# Captura la pantalla completa, la guarda y la copia al portapapeles.
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)_full.png"

grim "$FILE" || exit 0
wl-copy < "$FILE" || true
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Hyprland "Captura guardada" "$FILE" 2>/dev/null || true
fi
