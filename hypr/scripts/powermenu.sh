#!/usr/bin/env bash
# ==============================================================================
# Menú de apagado y sesión para Hyprland (Fuzzel)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

OP_LOCK="󰌾  Bloquear pantalla"
OP_LOGOUT="󰍃  Cerrar sesión"
OP_SUSPEND="󰤄  Suspender"
OP_HIBERNATE="󰒲  Hibernar"
OP_REBOOT="󰑐  Reiniciar"
OP_SHUTDOWN="󰐥  Apagar"

CHOSEN=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n" \
    "$OP_LOCK" \
    "$OP_LOGOUT" \
    "$OP_SUSPEND" \
    "$OP_HIBERNATE" \
    "$OP_REBOOT" \
    "$OP_SHUTDOWN" | fuzzel --dmenu \
                            --prompt "Sistema: " \
                            --width 28 \
                            --lines 6) || exit 0

case "$CHOSEN" in
    *"$OP_LOCK"*)
        pidof hyprlock || hyprlock
        ;;
    *"$OP_LOGOUT"*)
        hyprctl dispatch 'hl.dsp.exit()'
        ;;
    *"$OP_SUSPEND"*)
        "$SCRIPT_DIR/idle-suspend.sh"
        ;;
    *"$OP_HIBERNATE"*)
        if ! systemctl hibernate 2>/dev/null; then
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical -a "Sistema" "Hibernación no disponible" \
                    "Verificá Secure Boot desactivado en UEFI/BIOS, /swapfile >= RAM y 'make host'."
            fi
            exit 1
        fi
        ;;
    *"$OP_REBOOT"*)
        systemctl reboot
        ;;
    *"$OP_SHUTDOWN"*)
        systemctl poweroff
        ;;
esac
