#!/usr/bin/env bash
# ==============================================================================
# Estado del servicio de fondo de OpenCode para Waybar (JSON).
#
# El indicador queda siempre visible: verde cuando el servicio corre y atenuado
# cuando está apagado. Así se puede encender desde la propia barra (clic derecho
# alterna encendido/apagado) sin depender del menú.
# ==============================================================================
set -euo pipefail

pid="$(pgrep -u "$USER" -f '(^|/)opencode[[:space:]]+serve[[:space:]]+--service([[:space:]]|$)' 2>/dev/null | head -n1 || true)"

text="󰚩 IA"

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

    class="active"
    tooltip="Servicio OpenCode activo (${detail})"$'\n'"Click izq.: menú IA · Click der.: detener servicio"
else
    class="idle"
    tooltip="Servicio OpenCode apagado"$'\n'"Click izq.: menú IA · Click der.: iniciar servicio"
fi

if command -v jq >/dev/null 2>&1; then
    jq -nc --arg text "$text" --arg cls "$class" --arg tip "$tooltip" \
        '{text: $text, class: $cls, tooltip: $tip}'
else
    escaped_tooltip="${tooltip//$'\n'/\\n}"
    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' \
        "$text" "$class" "$escaped_tooltip"
fi
