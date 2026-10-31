#!/usr/bin/env bash
# Captura una región, la guarda y la copia al portapapeles.
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)_region.png"

REGION="$(slurp)" || exit 0
[ -n "$REGION" ] || exit 0
grim -g "$REGION" "$FILE" || exit 0

wl-copy < "$FILE" || true
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Hyprland "Captura guardada" "$FILE" 2>/dev/null || true
fi
