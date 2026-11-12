#!/usr/bin/env bash
# ==============================================================================
# Abre o cierra el Overview tipo Activities (Quickshell).
# Si el daemon de Quickshell no está activo, lo inicia y espera su IPC.
# ==============================================================================
set -euo pipefail

command -v qs >/dev/null 2>&1 || exit 0

if qs ipc call overview toggle >/dev/null 2>&1; then
    exit 0
fi

qs -n -d >/dev/null 2>&1 || true
for _ in $(seq 1 30); do
    if qs ipc call overview toggle >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.1
done

exit 1
