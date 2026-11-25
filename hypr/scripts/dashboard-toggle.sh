#!/usr/bin/env bash
# ==============================================================================
# Alterna el panel central de indicadores (Dashboard) integrado en Quickshell.
# ==============================================================================
set -euo pipefail

command -v qs >/dev/null 2>&1 || exit 0

if qs ipc call dashboard toggle >/dev/null 2>&1; then
    exit 0
fi

if [ -x "$HOME/.config/hypr/scripts/start-quickshell.sh" ]; then
    setsid "$HOME/.config/hypr/scripts/start-quickshell.sh" >/dev/null 2>&1 </dev/null &
    for _ in $(seq 1 30); do
        if qs ipc call dashboard toggle >/dev/null 2>&1; then
            exit 0
        fi
        sleep 0.1
    done
fi
