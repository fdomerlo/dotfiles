#!/usr/bin/env bash
# ==============================================================================
# Luz nocturna (filtro de luz azul) con `hyprsunset`.
#
# Uso:
#   nightlight-toggle.sh    # alterna entre 4000K (cálido) y 6500K (neutro)
#
# hyprsunset se controla por IPC con `hyprctl hyprsunset temperature <K>`.
# Se evita `identity` porque su estado no se puede consultar y se mezcla con la
# temperatura; 6500K es prácticamente neutro y sí se puede consultar.
# El estado real para Waybar queda en $XDG_RUNTIME_DIR/hypr-nightlight.state.
# ==============================================================================
set -euo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RUNTIME/hypr-nightlight.state"
WARM=4000
NEUTRAL=6500

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "$@" 2>/dev/null || true
}

if ! command -v hyprsunset >/dev/null 2>&1; then
    notify "Luz nocturna" "Falta hyprsunset"
    exit 1
fi

# Arrancarlo si el autostart no lo hizo (p. ej. tras reiniciarlo a mano).
if ! pgrep -x hyprsunset >/dev/null 2>&1; then
    setsid hyprsunset -t "$NEUTRAL" >/dev/null 2>&1 </dev/null &
    for _ in $(seq 1 20); do
        pgrep -x hyprsunset >/dev/null 2>&1 && break
        sleep 0.05
    done
fi

if [ -f "$STATE" ]; then
    hyprctl hyprsunset temperature "$NEUTRAL" >/dev/null 2>&1 || true
    rm -f "$STATE"
    notify "Luz nocturna desactivada" "${NEUTRAL}K"
else
    hyprctl hyprsunset temperature "$WARM" >/dev/null 2>&1 || true
    : >"$STATE"
    notify "Luz nocturna activada" "${WARM}K"
fi
