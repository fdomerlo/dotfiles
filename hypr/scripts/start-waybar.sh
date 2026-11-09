#!/usr/bin/env bash
# Inicia Waybar cuando los sockets IPC de Hyprland ya existen.
#
# `exec-once` puede lanzar Waybar antes de que Hyprland cree
# $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/{.socket.sock,.socket2.sock}.
# En esa carrera los módulos hyprland/* no conectan y, según el timing, Waybar
# puede no llegar a mostrarse. Esperar ambos sockets hace el arranque estable.

set -u

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"

if [ -z "$SIG" ]; then
    echo "start-waybar: HYPRLAND_INSTANCE_SIGNATURE no está definido" >&2
    exit 1
fi

SOCK_DIR="$RUNTIME/hypr/$SIG"

# Espera hasta 5 s a que existan el socket de comandos y el de eventos.
for _ in $(seq 1 100); do
    if [ -S "$SOCK_DIR/.socket.sock" ] && [ -S "$SOCK_DIR/.socket2.sock" ]; then
        break
    fi
    sleep 0.05
done

if [ ! -S "$SOCK_DIR/.socket.sock" ] || [ ! -S "$SOCK_DIR/.socket2.sock" ]; then
    echo "start-waybar: los sockets IPC de Hyprland no aparecieron en $SOCK_DIR" >&2
fi

# Reparar el arranque de audio antes de que Waybar conecte el módulo
# pulseaudio: si WirePlumber dejó solo Dummy Output, se reinicia una vez.
"$HOME/.config/hypr/scripts/audio-init.sh" || true

# Si systemd u otra instancia ya lo arrancó, no duplicar la barra.
if pgrep -x waybar >/dev/null 2>&1; then
    exit 0
fi

# Al matar Waybar, sus suscripciones a swaync quedan huérfanas (PPID 1).
# Limpiarlas evita acumular un `swaync-client -swb` por cada reinicio.
for pid in $(pgrep -f '^swaync-client -swb$' 2>/dev/null); do
    [ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" = "1" ] && kill "$pid" 2>/dev/null || true
done

exec waybar "$@"
