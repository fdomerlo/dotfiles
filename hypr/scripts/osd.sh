#!/usr/bin/env bash
# ==============================================================================
# Volumen y brillo con OSD en Quickshell y respaldo directo con wpctl /
# brightnessctl si el shell no está disponible.
#
# Uso:
#   osd.sh volume raise|lower|mute
#   osd.sh mic mute
#   osd.sh brightness raise|lower
# ==============================================================================
set -euo pipefail

action="${1:-}"
sub="${2:-}"

notify_osd() {
    command -v qs >/dev/null 2>&1 || return 0
    qs ipc call osd "$@" >/dev/null 2>&1 &
}

read_wpctl() {
    local target="$1" raw val muted pct
    raw="$(wpctl get-volume "$target" 2>/dev/null || true)"
    [ -n "$raw" ] || return 1
    val="$(awk '{print $2}' <<< "$raw")"
    muted="false"
    case "$raw" in
        *MUTED*) muted="true" ;;
    esac
    pct="$(awk -v v="${val:-0}" 'BEGIN { printf "%d", (v * 100) + 0.5 }')"
    printf '%s %s\n' "$pct" "$muted"
}

read_brightness() {
    local line pct
    line="$(brightnessctl -m 2>/dev/null | head -n1 || true)"
    [ -n "$line" ] || return 1
    pct="$(awk -F',' '{gsub(/%/, "", $4); print $4}' <<< "$line")"
    [ -n "$pct" ] || return 1
    printf '%s\n' "$pct"
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
    *)
        echo "Uso: $0 {volume raise|lower|mute|mic mute|brightness raise|lower}" >&2
        exit 2
        ;;
esac
