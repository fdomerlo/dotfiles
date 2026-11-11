#!/usr/bin/env bash
# ==============================================================================
# Estado de la luz nocturna para Waybar (JSON).
# Solo se muestra mientras el filtro está aplicado; si no, texto vacío.
# ==============================================================================
set -euo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RUNTIME/hypr-nightlight.state"

if [ -f "$STATE" ] && pgrep -x hyprsunset >/dev/null 2>&1; then
    printf '{"text": "NOCHE", "class": "on", "tooltip": "Luz nocturna activa (4000K)\\nClick para desactivar"}\n'
else
    printf '{"text": "", "class": "off"}\n'
fi
