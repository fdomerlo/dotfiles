#!/usr/bin/env bash
# ==============================================================================
# Selector de color: `hyprpicker` copia el color del píxel elegido al
# portapapeles (y lo informa con una notificación).
#
# Uso:
#   color-picker.sh
# ==============================================================================
set -euo pipefail

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "$@" 2>/dev/null || true
}

if ! command -v hyprpicker >/dev/null 2>&1; then
    notify "Selector de color" "Falta hyprpicker"
    exit 1
fi

# -a copia el color automáticamente al hacer clic; además se imprime en stdout.
COLOR="$(hyprpicker -a 2>/dev/null)" || exit 0
[ -n "$COLOR" ] || exit 0

# Refuerzo del portapapeles: -a ya copia, pero así también funciona si el
# portapapeles de hyprpicker no está disponible.
command -v wl-copy >/dev/null 2>&1 && printf '%s' "$COLOR" | wl-copy 2>/dev/null || true

notify "Color copiado" "$COLOR"
printf '%s\n' "$COLOR"
