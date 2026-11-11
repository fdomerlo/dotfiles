#!/usr/bin/env bash
# Captura una región, la copia al portapapeles y abre swappy para anotar/ofuscar.
# Con --raw guarda y copia directamente sin abrir swappy.
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)_region.png"

REGION="$(slurp)" || exit 0
[ -n "$REGION" ] || exit 0
grim -g "$REGION" "$FILE" || exit 0

wl-copy < "$FILE" || true

if [ "${1:-}" != "--raw" ] && command -v swappy >/dev/null 2>&1; then
    swappy -f "$FILE" -o "$FILE" || true
    wl-copy < "$FILE" || true
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Hyprland "Captura guardada" "$FILE" 2>/dev/null || true
fi
