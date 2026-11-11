#!/usr/bin/env bash
# ==============================================================================
# Menú de apagado y sesión para Hyprland (Fuzzel)
# ==============================================================================
set -euo pipefail

OP_LOCK="󰌾  Bloquear pantalla"
OP_LOGOUT="󰍃  Cerrar sesión"
OP_SUSPEND="󰤄  Suspender"
OP_REBOOT="󰑐  Reiniciar"
OP_SHUTDOWN="󰐥  Apagar"

CHOSEN=$(printf "%s\n%s\n%s\n%s\n%s\n" \
    "$OP_LOCK" \
    "$OP_LOGOUT" \
    "$OP_SUSPEND" \
    "$OP_REBOOT" \
    "$OP_SHUTDOWN" | fuzzel --dmenu \
                            --prompt "Sistema: " \
                            --width 28 \
                            --lines 5) || exit 0

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
