#!/usr/bin/env bash
# ==============================================================================
# Lanza un TUI en foot flotante, centrado y al 85% del monitor enfocado.
#
# Uso:
#   tui-float.sh <comando> [args...]
#
# Hyprland aplica float/center/dim_around mediante la clase «tui-float», pero
# el tamaño de esa regla no alcanza para foot: foot fija su propio tamaño
# inicial (initial-window-size-pixels en foot.ini) y su primer commit gana
# sobre la regla. Por eso acá se calcula el porcentaje del monitor enfocado y
# se pasa con --window-size-pixels, que es portable entre máquinas.
#
# El porcentaje se puede ajustar por invocación con TUI_FLOAT_PCT.
# ==============================================================================
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <comando> [args...]" >&2
    exit 2
fi

pct="${TUI_FLOAT_PCT:-85}"
size=""
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    read -r mw mh <<<"$(hyprctl monitors -j |
        jq -r '.[] | select(.focused) | "\(.width) \(.height)"' | head -n1)"
    if [ -n "${mw:-}" ] && [ -n "${mh:-}" ]; then
        size="$((mw * pct / 100))x$((mh * pct / 100))"
    fi
fi

args=(--app-id=tui-float)
[ -n "$size" ] && args+=(--window-size-pixels="$size")

exec "${TUI_FLOAT_TERMINAL:-foot}" "${args[@]}" -e "$@"
