#!/usr/bin/env bash
# ==============================================================================
# Scratchpad: terminal flotante en el workspace especial "magic".
#
# Si la terminal del scratchpad no existe, la lanza y espera a que Hyprland la
# registre; luego alterna la visibilidad del workspace especial. Así una sola
# tecla abre y cierra, y la primera pulsación no se pierde al iniciar.
# ==============================================================================
set -euo pipefail

CLASS="scratchpad"

if ! command -v hyprctl >/dev/null 2>&1; then
    exit 1
fi

count_scratchpads() {
    if command -v jq >/dev/null 2>&1; then
        hyprctl clients -j 2>/dev/null |
            jq -r --arg c "$CLASS" '[.[] | select(.class == $c)] | length'
    else
        hyprctl clients 2>/dev/null | grep -c "class: $CLASS" || true
    fi
}

if [ "$(count_scratchpads)" = "0" ]; then
    foot --app-id="$CLASS" >/dev/null 2>&1 &
    for _ in $(seq 1 40); do
        [ "$(count_scratchpads)" != "0" ] && break
        sleep 0.05
    done
fi

hyprctl dispatch togglespecialworkspace magic
