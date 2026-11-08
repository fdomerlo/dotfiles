#!/usr/bin/env bash
# ==============================================================================
# Caché del estado del panel de swaync.
#
# El clic en la campana de Waybar puede llegar después de que swaync se cerró
# por pérdida de foco. Guardar el estado y el momento del último cambio permite
# que notifications-toggle.sh distinga ese cierre del clic normal.
# ==============================================================================
set -u

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME/swaync-panel-state"
EVENT_LOG="$RUNTIME/swaync-panel-state.log"

state_of() {
    printf '%s' "$1" | jq -r '
        (.class // "")
        | if type == "array" then join(" ") else . end
        | if test("(^| )cc-open( |$)") then "open" else "closed" end
    ' 2>/dev/null
}

write_state() {
    local state="$1" now
    now=$(date +%s%3N)
    printf '%s|%s\n' "$state" "$now" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Estado inicial antes de suscribirse a los cambios.
initial=$(timeout 0.5 swaync-client -swb 2>/dev/null | head -n1)
state=$(state_of "$initial")
[ "$state" = "open" ] || state="closed"
write_state "$state"
printf '%s init %s\n' "$(date '+%F %T.%3N')" "$state" >> "$EVENT_LOG"

# Reconectar la suscripción si swaync se reinicia o todavía no está arriba.
while :; do
    swaync-client -swb 2>/dev/null | while IFS= read -r line; do
        [ -n "$line" ] || continue
        state=$(state_of "$line")
        [ "$state" = "open" ] || state="closed"
        write_state "$state"
        printf '%s %s %s\n' "$(date '+%F %T.%3N')" "$state" "$line" >> "$EVENT_LOG"
    done
    sleep 1
done
