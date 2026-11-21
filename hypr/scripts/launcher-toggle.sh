#!/usr/bin/env bash
# ==============================================================================
# Abre o cierra el Lanzador / Centro Unificado en Rofi 2.0 (Wayland nativo).
# Sin daemon residente: arranca bajo demanda y libera memoria al cerrarse.
#
# Uso:
#   launcher-toggle.sh              # alterna en la pestaña global Todo
#   launcher-toggle.sh todo         # abre o alterna en Todo (buscador global)
#   launcher-toggle.sh apps         # abre o alterna en Apps
#   launcher-toggle.sh dev          # abre en Dev & IA
#   launcher-toggle.sh capturar     # abre en Capturar
#   launcher-toggle.sh estilo       # abre en Estilo
#   launcher-toggle.sh sistema      # abre en Sistema
#   launcher-toggle.sh ventanas     # abre en Ventanas
# ==============================================================================
set -euo pipefail

command -v rofi >/dev/null 2>&1 || exit 0

# Cerrar fuzzel si hubiera algún submenú abierto para evitar superposición de foco.
pkill -x fuzzel 2>/dev/null || true

# Si Rofi ya está abierto, cerrarlo (comportamiento toggle de la tecla Super).
if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi 2>/dev/null || true
    exit 0
fi

tab="${1:-todo}"
case "$tab" in
    todo|all|"") mode="todo" ;;
    apps|drun) mode="apps" ;;
    dev|capturar|estilo|sistema|ventanas) mode="$tab" ;;
    *) mode="todo" ;;
esac

exec rofi -show "$mode"
