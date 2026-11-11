#!/usr/bin/env bash
# ==============================================================================
# Ciclo de workspaces por monitor, con wrap.
#
# Uso: workspace-cycle.sh next|prev [--move]
#
# Recorre los WS_PER_MONITOR workspaces del monitor enfocado, calculados igual
# que en workspaces-init.sh: el monitor i (ordenado por x) usa
# i*5+1 .. i*5+5, es decir 1-5 en el primero, 6-10 en el segundo, y así.
# Vuelve al primero/último al llegar al extremo (5→1 y 10→6).
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

# Índice (0-based, ordenado por x) y workspace activo del monitor enfocado.
read -r index current < <(
    hyprctl monitors -j |
        jq -r '
            map(select(.disabled | not)) | sort_by(.x)
            | to_entries[] | select(.value.focused)
            | "\(.key) \(.value.activeWorkspace.id)"
        '
)

if [ -z "${index:-}" ] || [ -z "${current:-}" ]; then
    exit 1
fi

first=$((index * WS_PER_MONITOR + 1))
target=""

for ((i = 0; i < WS_PER_MONITOR; i++)); do
    if [ "$((first + i))" = "$current" ]; then
        if [ "$direction" = "next" ]; then
            target=$((first + (i + 1) % WS_PER_MONITOR))
        else
            target=$((first + (i - 1 + WS_PER_MONITOR) % WS_PER_MONITOR))
        fi
        break
    fi
done

# Si el workspace actual no pertenece al rango del monitor (p. ej. uno especial
# o uno fuera de rango), next va al primero y prev al último.
if [ -z "$target" ]; then
    if [ "$direction" = "next" ]; then
        target="$first"
    else
        target=$((first + WS_PER_MONITOR - 1))
    fi
fi

if [ "$mode" = "--move" ]; then
    hyprctl dispatch movetoworkspacesilent "$target" >/dev/null
else
    hyprctl dispatch workspace "$target" >/dev/null
fi
