#!/usr/bin/env bash
# ==============================================================================
# Ciclo de workspaces por monitor, con wrap.
#
# Uso: workspace-cycle.sh next|prev [--move]
#
# Recorre solo los workspaces asignados al monitor enfocado, según
# ~/.config/hypr/conf/workspaces.conf (1-5 en HDMI-A-1, 6-10 en HDMI-A-2) y
# vuelve al primero/último al llegar al extremo.
#
# --move mueve la ventana activa al workspace destino sin seguirlas (igual que
# Super+Shift+N). Sin --move solo cambia de workspace.
# ==============================================================================
set -euo pipefail

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

read -r monitor current < <(
    hyprctl monitors -j |
        jq -r '.[] | select(.focused) | "\(.name) \(.activeWorkspace.id)"'
)

if [ -z "${monitor:-}" ] || [ -z "${current:-}" ]; then
    exit 1
fi

conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf/workspaces.conf"

# Extrae los IDs numéricos que workspaces.conf asigna a este monitor.
mapfile -t ids < <(
    awk -F',' -v mon="$monitor" '
        /^[[:space:]]*workspace[[:space:]]*=/ {
            id = $1
            sub(/^[^=]*=[[:space:]]*/, "", id)
            gsub(/[[:space:]]/, "", id)
            m = $2
            sub(/^[[:space:]]*monitor:[[:space:]]*/, "", m)
            gsub(/[[:space:]].*/, "", m)
            if (m == mon && id ~ /^[0-9]+$/) print id
        }
    ' "$conf" | sort -n
)

# Fallback si el monitor no tiene reglas propias: 1..10.
if [ "${#ids[@]}" -eq 0 ]; then
    ids=(1 2 3 4 5 6 7 8 9 10)
fi

count="${#ids[@]}"
target="${ids[0]}"
found=0

for i in "${!ids[@]}"; do
    if [ "${ids[$i]}" = "$current" ]; then
        found=1
        if [ "$direction" = "next" ]; then
            target="${ids[$(((i + 1) % count))]}"
        else
            target="${ids[$(((i - 1 + count) % count))]}"
        fi
        break
    fi
done

# Si el workspace actual no pertenece al monitor (p. ej. uno especial),
# next va al primero y prev al último.
if [ "$found" -eq 0 ]; then
    if [ "$direction" = "next" ]; then
        target="${ids[0]}"
    else
        target="${ids[$((count - 1))]}"
    fi
fi

if [ "$mode" = "--move" ]; then
    hyprctl dispatch movetoworkspacesilent "$target" >/dev/null
else
    hyprctl dispatch workspace "$target" >/dev/null
fi
