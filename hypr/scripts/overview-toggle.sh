#!/usr/bin/env bash
# ==============================================================================
# Abre o cierra el Overview tipo Activities (Quickshell).
# Si el shell residente no está activo, lo inicia vía start-quickshell.sh.
# ==============================================================================
set -euo pipefail

command -v qs >/dev/null 2>&1 || exit 0

if qs ipc call overview toggle >/dev/null 2>&1; then
    exit 0
fi

if [ -x "$HOME/.config/hypr/scripts/start-quickshell.sh" ]; then
    setsid "$HOME/.config/hypr/scripts/start-quickshell.sh" >/dev/null 2>&1 </dev/null &
else
    qs -n -d >/dev/null 2>&1 || true
fi

for _ in $(seq 1 40); do
    if qs ipc call overview toggle >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.1
done

exit 1
