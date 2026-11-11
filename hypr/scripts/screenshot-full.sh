#!/usr/bin/env bash
# Captura la pantalla completa, la guarda y la copia al portapapeles.
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
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)_full.png"

grim "$FILE" || exit 0
wl-copy < "$FILE" || true
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Hyprland "Captura guardada" "$FILE" 2>/dev/null || true
fi
