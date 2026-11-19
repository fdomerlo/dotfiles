#!/usr/bin/env bash
# ==============================================================================
# Estado del servicio de fondo de OpenCode para Waybar (JSON).
# Solo se muestra cuando `opencode serve --service` está corriendo; si está
# apagado emite texto vacío y Waybar lo oculta con hide-empty-text.
# ==============================================================================
set -euo pipefail

pid="$(pgrep -u "$USER" -f '(^|/)opencode[[:space:]]+serve[[:space:]]+--service([[:space:]]|$)' 2>/dev/null | head -n1 || true)"

if [ -n "$pid" ]; then
    rss_kb="$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    rss_mb=""
    if [[ "${rss_kb:-}" =~ ^[0-9]+$ ]]; then
        rss_mb="$(( (rss_kb + 512) / 1024 ))"
    fi

    state_file="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/service.json"
    url=""
    if [ -r "$state_file" ] && command -v jq >/dev/null 2>&1; then
        url="$(jq -r '.url // empty' "$state_file" 2>/dev/null || true)"
    fi

    if [ -n "$url" ] && [ -n "$rss_mb" ]; then
        detail="$url · ${rss_mb} MiB RAM"
    elif [ -n "$url" ]; then
        detail="$url"
    elif [ -n "$rss_mb" ]; then
        detail="${rss_mb} MiB RAM"
    else
        detail="PID $pid"
    fi

    tooltip="Servicio OpenCode activo (${detail})"$'\n'"Click izq.: menú IA · Click der.: detener servicio"
    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg text "󰚩 IA" --arg cls "active" --arg tip "$tooltip" \
            '{text: $text, class: $cls, tooltip: $tip}'
    else
        printf '{"text": "󰚩 IA", "class": "active", "tooltip": "Servicio OpenCode activo (%s)\\nClick izq.: menú IA · Click der.: detener servicio"}\n' "$detail"
    fi
else
    printf '{"text": "", "class": "idle"}\n'
fi
