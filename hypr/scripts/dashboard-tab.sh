#!/usr/bin/env bash
# ==============================================================================
# Abre el Dashboard de Quickshell en una pestaña concreta (0–4).
#   0 Apps · 1 Dashboard · 2 Media · 3 Dev & IA · 4 Sistema
# A diferencia de dashboard-toggle.sh, siempre abre o cambia de pestaña:
# no cierra el panel si ya estaba abierto en esa misma pestaña.
# ==============================================================================
set -euo pipefail

tab="${1:-1}"
case "$tab" in
    0|1|2|3|4) ;;
    *) tab=1 ;;
esac

command -v qs >/dev/null 2>&1 || exit 0

if qs ipc call dashboard showTab "$tab" >/dev/null 2>&1; then
    exit 0
fi

if [ -x "$HOME/.config/hypr/scripts/start-quickshell.sh" ]; then
    setsid "$HOME/.config/hypr/scripts/start-quickshell.sh" >/dev/null 2>&1 </dev/null &
    for _ in $(seq 1 30); do
        if qs ipc call dashboard showTab "$tab" >/dev/null 2>&1; then
            exit 0
        fi
        sleep 0.1
    done
fi
