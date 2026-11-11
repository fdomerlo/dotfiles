#!/usr/bin/env bash
# ==============================================================================
# Menú de apagado y sesión para Hyprland (Fuzzel, con fallback a Wofi)
# ==============================================================================
set -euo pipefail

OP_LOCK="󰌾  Bloquear pantalla"
OP_LOGOUT="󰍃  Cerrar sesión"
OP_SUSPEND="󰤄  Suspender"
OP_REBOOT="󰑐  Reiniciar"
OP_SHUTDOWN="󰐥  Apagar"

if command -v fuzzel >/dev/null 2>&1; then
    CHOSEN=$(printf "%s\n%s\n%s\n%s\n%s\n" \
        "$OP_LOCK" \
        "$OP_LOGOUT" \
        "$OP_SUSPEND" \
        "$OP_REBOOT" \
        "$OP_SHUTDOWN" | fuzzel --dmenu \
                                --prompt "Sistema: " \
                                --width 28 \
                                --lines 5) || exit 0
else
    CHOSEN=$(printf "%s\n%s\n%s\n%s\n%s\n" \
        "$OP_LOCK" \
        "$OP_LOGOUT" \
        "$OP_SUSPEND" \
        "$OP_REBOOT" \
        "$OP_SHUTDOWN" | wofi --dmenu \
                              --prompt "Sistema:" \
                              --width 320 \
                              --height 270 \
                              --location center \
                              --insensitive) || exit 0
fi

case "$CHOSEN" in
    *"$OP_LOCK"*)
        hyprlock
        ;;
    *"$OP_LOGOUT"*)
        hyprctl dispatch exit
        ;;
    *"$OP_SUSPEND"*)
        systemctl suspend
        ;;
    *"$OP_REBOOT"*)
        systemctl reboot
        ;;
    *"$OP_SHUTDOWN"*)
        systemctl poweroff
        ;;
esac
