#!/usr/bin/env bash
# Captura una región, la copia al portapapeles y abre swappy para anotar/ofuscar.
# Con --raw guarda y copia directamente sin abrir swappy.
set -euo pipefail

# XDG_PICTURES_DIR no se exporta en la sesión de Hyprland, así que se resuelve
# con xdg-user-dir (lee ~/.config/user-dirs.dirs) para respetar «Imágenes».
PICTURES="${XDG_PICTURES_DIR:-}"
if [ -z "$PICTURES" ] && command -v xdg-user-dir >/dev/null 2>&1; then
    PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || true)"
fi
[ -n "$PICTURES" ] || PICTURES="$HOME/Imágenes"
DIR="$PICTURES/Screenshots"
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
