#!/usr/bin/env bash
# ==============================================================================
# Estado JSON de notificaciones de Quickshell para el módulo de Waybar
# (puente temporal hasta la Fase 3 cuando Waybar migre a Quickshell).
# ==============================================================================
set -u

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell-notif-state.json"

if [ -r "$STATE_FILE" ]; then
    cat "$STATE_FILE"
    exit 0
fi

if command -v qs >/dev/null 2>&1; then
    out="$(qs ipc call notifications status 2>/dev/null || true)"
    if [ -n "$out" ]; then
        printf '%s\n' "$out"
        exit 0
    fi
fi

printf '{"text":"","alt":"none","tooltip":"Sin notificaciones","class":["none"]}\n'
