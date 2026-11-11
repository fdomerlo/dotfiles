#!/usr/bin/env bash
# ==============================================================================
# Búsqueda de archivos: `fd` + `fuzzel --dmenu`, abre el elegido con `xdg-open`.
#
# Uso:
#   file-search.sh [directorio]
#
# Sin argumento busca desde $HOME. El prompt contiene "Archivo:" para que
# toggle-menu.sh reconozca el menú y la misma tecla lo abra y lo cierre.
# ==============================================================================
set -euo pipefail

FD="$(command -v fd || command -v fdfind || true)"
if [ -z "$FD" ]; then
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "Búsqueda de archivos" "Falta fd-find"
    exit 1
fi

if ! command -v fuzzel >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "Búsqueda de archivos" "Falta fuzzel"
    exit 1
fi

ROOT="${1:-$HOME}"

# --absolute-path evita reconstruir la ruta después de fuzzel. Se incluyen los
# ocultos (dotfiles) pero se excluyen directorios que inundan el resultado.
# --max-results acota el costo de recorrer $HOME sin demorar la apertura.
SELECTED="$(
    "$FD" --type f --hidden --absolute-path \
        --exclude .git --exclude .cache \
        --exclude .local/share/Trash --exclude .local/state \
        --max-results 5000 \
        . "$ROOT" 2>/dev/null |
        fuzzel --dmenu --prompt 'Archivo: ' --width 70 --lines 20
)" || exit 0

[ -n "$SELECTED" ] || exit 0

setsid xdg-open "$SELECTED" >/dev/null 2>&1 </dev/null &
