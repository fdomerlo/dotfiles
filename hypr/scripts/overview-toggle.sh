#!/usr/bin/env bash
# ==============================================================================
# Abre o cierra el selector rápido de ventanas y workspaces en Rofi 2.0.
# Sin daemon residente: arranca bajo demanda y libera memoria al cerrarse.
# ==============================================================================
set -euo pipefail

command -v rofi >/dev/null 2>&1 || exit 0

pkill -x fuzzel 2>/dev/null || true

if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi 2>/dev/null || true
    exit 0
fi

exec rofi -show ventanas
