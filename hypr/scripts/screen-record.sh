#!/usr/bin/env bash
# ==============================================================================
# Grabación de pantalla completa con `wf-recorder` (alterna inicio/parada).
#
# Uso:
#   screen-record.sh          # alterna: si graba, detiene; si no, empieza
#   screen-record.sh stop     # detiene si está grabando
#
# Guarda en la carpeta Vídeos del usuario (XDG) + /Grabaciones. La parada usa
# SIGINT para que wf-recorder cierre el contenedor y deje el archivo válido.
# ==============================================================================
set -euo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# Guarda la ruta del archivo en curso para poder informarla al detener.
STATE="$RUNTIME/hypr-recording.state"

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "$@" 2>/dev/null || true
}

is_recording() { pgrep -x wf-recorder >/dev/null 2>&1; }

stop_recording() {
    local file=""
    [ -f "$STATE" ] && file="$(cat "$STATE" 2>/dev/null || true)"

    pkill -INT -x wf-recorder 2>/dev/null || true
    # Esperar el cierre ordenado (wf-recorder finaliza el MP4 al salir).
    for _ in $(seq 1 50); do
        is_recording || break
        sleep 0.1
    done
    rm -f "$STATE"

    if [ -n "$file" ] && [ -s "$file" ]; then
        notify "Grabación finalizada" "$file"
    else
        notify "Grabación finalizada" "No se generó el archivo"
    fi
}

start_recording() {
    if ! command -v wf-recorder >/dev/null 2>&1; then
        notify "Grabación de pantalla" "Falta wf-recorder"
        exit 1
    fi

    local dir file
    dir="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
    [ -n "$dir" ] || dir="$HOME/Vídeos"
    dir="$dir/Grabaciones"
    mkdir -p "$dir"

    file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_grabacion.mp4"
    printf '%s\n' "$file" >"$STATE"

    setsid wf-recorder -f "$file" --pixel-format yuv420p \
        >/dev/null 2>&1 </dev/null &

    sleep 0.6
    if ! is_recording; then
        rm -f "$STATE"
        notify "Grabación de pantalla" "wf-recorder no pudo iniciar"
        exit 1
    fi

    notify "Grabación iniciada" "$file"
}

case "${1:-toggle}" in
    stop)
        is_recording && stop_recording || true
        ;;
    toggle | start)
        if is_recording; then
            stop_recording
        else
            start_recording
        fi
        ;;
    *)
        echo "Uso: $0 [toggle|start|stop]" >&2
        exit 2
        ;;
esac
