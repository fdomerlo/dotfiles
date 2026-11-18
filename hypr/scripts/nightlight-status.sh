#!/usr/bin/env bash
# ==============================================================================
# Estado de la luz nocturna para Waybar (JSON).
# Mientras el filtro está aplicado muestra el icono de luna; si no, texto vacío.
# ==============================================================================
set -euo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RUNTIME/hypr-nightlight.state"

if [ -f "$STATE" ] && pgrep -x hyprsunset >/dev/null 2>&1; then
    printf '{"text": "", "class": "on", "tooltip": "Luz nocturna activa (4000K)\\nClick para desactivar"}\n'
else
    printf '{"text": "", "class": "off"}\n'
fi
