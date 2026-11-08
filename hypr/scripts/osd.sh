#!/usr/bin/env bash
# ==============================================================================
# Volumen y brillo con OSD (swayosd) y respaldo directo si no está disponible.
#
# Uso:
#   osd.sh volume raise|lower|mute
#   osd.sh mic mute
#   osd.sh brightness raise|lower
# ==============================================================================
set -euo pipefail

action="${1:-}"
sub="${2:-}"

if command -v swayosd-client >/dev/null 2>&1 && pgrep -x swayosd-server >/dev/null 2>&1; then
    case "$action:$sub" in
        volume:raise) exec swayosd-client --output-volume raise ;;
        volume:lower) exec swayosd-client --output-volume lower ;;
        volume:mute)  exec swayosd-client --output-volume mute-toggle ;;
        mic:mute)     exec swayosd-client --input-volume mute-toggle ;;
        brightness:raise) exec swayosd-client --brightness raise ;;
        brightness:lower) exec swayosd-client --brightness lower ;;
    esac
fi

# Respaldo sin OSD (o si swayosd-server no está corriendo).
case "$action:$sub" in
    volume:raise) exec wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    volume:lower) exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    volume:mute)  exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    mic:mute)     exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    brightness:raise) exec brightnessctl set 5%+ ;;
    brightness:lower) exec brightnessctl set 5%- ;;
    *)
        echo "Uso: $0 {volume raise|lower|mute|mic mute|brightness raise|lower}" >&2
        exit 2
        ;;
esac
