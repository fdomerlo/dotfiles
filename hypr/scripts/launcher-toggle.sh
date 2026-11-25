#!/usr/bin/env bash
# ==============================================================================
# Abre o cierra el Lanzador / Menú Unificado en Quickshell.
# Si el shell residente no está activo, lo inicia vía start-quickshell.sh.
#
# Uso:
#   launcher-toggle.sh              # alterna el popup en la última/primera pestaña
#   launcher-toggle.sh apps         # abre o alterna en la pestaña Apps
#   launcher-toggle.sh sistema      # abre o alterna en la pestaña Sistema
# ==============================================================================
set -euo pipefail

command -v qs >/dev/null 2>&1 || exit 0

# Cerrar fuzzel si hubiera algún submenú abierto para evitar superposición de foco.
pkill -x fuzzel 2>/dev/null || true

tab="${1:-}"
invoke_ipc() {
    if [ -n "$tab" ]; then
        qs ipc call launcher openTab "$tab" >/dev/null 2>&1
    else
        qs ipc call launcher toggle >/dev/null 2>&1
    fi
}

if invoke_ipc; then
    exit 0
fi

if [ -x "$HOME/.config/hypr/scripts/start-quickshell.sh" ]; then
    setsid "$HOME/.config/hypr/scripts/start-quickshell.sh" >/dev/null 2>&1 </dev/null &
else
    qs -n -d >/dev/null 2>&1 || true
fi

for _ in $(seq 1 40); do
    if invoke_ipc; then
        exit 0
    fi
    sleep 0.1
done

exit 1
