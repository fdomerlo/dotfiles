#!/usr/bin/env bash
# ==============================================================================
# Ciclo de workspaces entre todos los monitores conectados, con wrap.
#
# Uso: workspace-cycle.sh next|prev [--move]
#
# Recorre los workspaces de todas las salidas activas: con WS_PER_MONITOR=5 y
# N monitores, recorre 1 .. N*5 (p. ej. 1-10 con dos monitores: 1-5 en el
# primero, 6-10 en el segundo). Al llegar al final vuelve al inicio (10→1 y 1→10).
#
# --move mueve la ventana activa al workspace destino sin seguirla (igual que
# Super+Shift+N). Sin --move solo cambia de workspace.
# ==============================================================================
set -euo pipefail

WS_PER_MONITOR=5

direction="${1:-next}"
mode="${2:-}"

case "$direction" in
    next | prev) ;;
    *)
        echo "uso: $0 next|prev [--move]" >&2
        exit 2
        ;;
esac

for bin in hyprctl jq; do
    command -v "$bin" >/dev/null 2>&1 || exit 1
done

# Cantidad de monitores activos (no deshabilitados) y workspace activo actual.
monitors_count=$(hyprctl monitors -j | jq 'map(select(.disabled | not)) | length')
current=$(hyprctl activeworkspace -j | jq -r '.id')

if [ -z "${monitors_count:-}" ] || [ "$monitors_count" -le 0 ]; then
    monitors_count=1
fi

total_workspaces=$((monitors_count * WS_PER_MONITOR))

target=""
if [[ "$current" =~ ^[0-9]+$ ]] && [ "$current" -ge 1 ] && [ "$current" -le "$total_workspaces" ]; then
    if [ "$direction" = "next" ]; then
        target=$(( (current % total_workspaces) + 1 ))
    else
        target=$(( (current - 2 + total_workspaces) % total_workspaces + 1 ))
    fi
else
    # Si el workspace actual está fuera del rango (p. ej. especial o creado a mano):
    if [ "$direction" = "next" ]; then
        target=1
    else
        target="$total_workspaces"
    fi
fi

if [ "$mode" = "--move" ]; then
    hyprctl dispatch movetoworkspacesilent "$target" >/dev/null
else
    hyprctl dispatch workspace "$target" >/dev/null
fi
