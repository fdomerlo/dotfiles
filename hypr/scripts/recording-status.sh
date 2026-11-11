#!/usr/bin/env bash
# ==============================================================================
# Estado de la grabación para Waybar (JSON).
# Mientras wf-recorder corre muestra "REC"; si no, texto vacío y la barra lo
# oculta con hide-empty-text.
# ==============================================================================
set -euo pipefail

if pgrep -x wf-recorder >/dev/null 2>&1; then
    printf '{"text": "REC", "class": "recording", "tooltip": "Grabando la pantalla\\nClick para detener"}\n'
else
    printf '{"text": "", "class": "idle"}\n'
fi
