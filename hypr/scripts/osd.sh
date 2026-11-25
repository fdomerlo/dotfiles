#!/usr/bin/env bash
# ==============================================================================
# Volumen, brillo e indicadores de teclado (Caps/Num Lock) con OSD en
# Quickshell y respaldo directo con wpctl / brightnessctl.
#
# Uso:
#   osd.sh volume raise|lower|mute
#   osd.sh mic mute
#   osd.sh brightness raise|lower
#   osd.sh lock caps|num
# ==============================================================================
set -euo pipefail

action="${1:-}"
sub="${2:-}"

notify_osd() {
    command -v qs >/dev/null 2>&1 || return 0
    # Llamada síncrona (~15 ms): en background puede cerrarse antes de escribir
    # en el socket IPC si el proceso padre termina de inmediato.
    qs ipc call osd "$@" >/dev/null 2>&1 || true
}

read_wpctl() {
    local target="$1" raw val muted pct
    raw="$(wpctl get-volume "$target" 2>/dev/null || true)"
    [ -n "$raw" ] || return 1
    val="$(LC_ALL=C awk '{print $2}' <<< "$raw")"
    muted="false"
    case "$raw" in
        *MUTED*) muted="true" ;;
    esac
    pct="$(LC_ALL=C awk -v v="${val:-0}" 'BEGIN { printf "%d", (v * 100) + 0.5 }')"
    printf '%s %s\n' "$pct" "$muted"
}

read_brightness() {
    local line pct
    line="$(brightnessctl -m 2>/dev/null | head -n1 || true)"
    [ -n "$line" ] || return 1
    pct="$(LC_ALL=C awk -F',' '{gsub(/%/, "", $4); print $4}' <<< "$line")"
    [ -n "$pct" ] || return 1
    printf '%s\n' "$pct"
}

read_lock_state() {
    local kind="$1" field led_name val=""
    if [ "$kind" = "caps" ]; then
        field="capsLock"
        led_name="capslock"
    else
        field="numLock"
        led_name="numlock"
    fi

    # Dar un margen breve para que XKB/Hyprland actualice el estado tras la tecla.
    sleep 0.05

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        val="$(hyprctl devices -j 2>/dev/null | jq -r --arg f "$field" '
            (.keyboards // [])
            | (map(select(.main == true)) + .)
            | .[0][$f] // empty
        ' 2>/dev/null || true)"
        if [ "$val" = "true" ] || [ "$val" = "false" ]; then
            printf '%s\n' "$val"
            return 0
        fi
    fi

    local led
    for led in /sys/class/leds/*::"${led_name}"/brightness; do
        [ -r "$led" ] || continue
        if [ "$(cat "$led" 2>/dev/null || echo 0)" = "1" ]; then
            printf 'true\n'
        else
            printf 'false\n'
        fi
        return 0
    done
    return 1
}

case "$action:$sub" in
    volume:raise)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
        if read -r pct muted < <(read_wpctl @DEFAULT_AUDIO_SINK@); then
            notify_osd showVolume "$pct" "$muted"
        fi
        ;;
    volume:lower)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        if read -r pct muted < <(read_wpctl @DEFAULT_AUDIO_SINK@); then
            notify_osd showVolume "$pct" "$muted"
        fi
        ;;
    volume:mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        if read -r pct muted < <(read_wpctl @DEFAULT_AUDIO_SINK@); then
            notify_osd showVolume "$pct" "$muted"
        fi
        ;;
    mic:mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if read -r _ muted < <(read_wpctl @DEFAULT_AUDIO_SOURCE@); then
            notify_osd showMic "$muted"
        fi
        ;;
    brightness:raise)
        brightnessctl set 5%+ >/dev/null
        if pct="$(read_brightness)"; then
            notify_osd showBrightness "$pct"
        fi
        ;;
    brightness:lower)
        brightnessctl set 5%- >/dev/null
        if pct="$(read_brightness)"; then
            notify_osd showBrightness "$pct"
        fi
        ;;
    lock:caps|lock:num)
        if state="$(read_lock_state "$sub")"; then
            notify_osd showLock "$sub" "$state"
        fi
        ;;
    *)
        echo "Uso: $0 {volume raise|lower|mute|mic mute|brightness raise|lower|lock caps|num}" >&2
        exit 2
        ;;
esac
