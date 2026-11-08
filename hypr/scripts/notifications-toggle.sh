#!/usr/bin/env bash
# ==============================================================================
# Alterna el centro de notificaciones de swaync desde el módulo de Waybar.
#
# En swaync 0.11 + Hyprland el primer clic abre el panel, pero el segundo puede
# cerrarlo por pérdida de foco y volver a abrirlo al ejecutarse este on-click.
# El caché de estado con timestamp evita esa carrera.
# ==============================================================================
set -u

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME/swaync-panel-state"
DEBUG_LOG="$RUNTIME/swaync-toggle.log"
RECENT_CLOSE_MS=300

state=""
ts=""
[ -r "$STATE_FILE" ] && IFS='|' read -r state ts < "$STATE_FILE"

# Arrancar el listener si la sesión ya estaba iniciada sin él.
if ! pgrep -f '[s]waync-state.sh' >/dev/null 2>&1; then
    setsid "$HOME/.config/hypr/scripts/swaync-state.sh" >/dev/null 2>&1 < /dev/null &
    sleep 0.05
    state=""
    ts=""
    [ -r "$STATE_FILE" ] && IFS='|' read -r state ts < "$STATE_FILE"
fi

# Si el caché dice cerrado, confirmar en vivo por si quedó desactualizado.
if [ "$state" != "open" ]; then
    live=$(timeout 0.2 swaync-client -swb 2>/dev/null | head -n1)
    case "$live" in
        *cc-open*) state="open" ;;
    esac
fi

now=$(date +%s%3N)
printf '%s state=%s ts=%s now=%s\n' \
    "$(date '+%F %T.%3N')" "$state" "${ts:-}" "$now" >> "$DEBUG_LOG"

if [ "$state" = "open" ]; then
    swaync-client -cp -sw >/dev/null 2>&1
elif [ -n "$ts" ] && [ $((now - ts)) -ge 0 ] && [ $((now - ts)) -lt "$RECENT_CLOSE_MS" ]; then
    printf '%s skip (cerrado hace %sms)\n' \
        "$(date '+%F %T.%3N')" "$((now - ts))" >> "$DEBUG_LOG"
else
    swaync-client -op -sw >/dev/null 2>&1
fi
