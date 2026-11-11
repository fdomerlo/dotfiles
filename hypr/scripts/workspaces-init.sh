#!/usr/bin/env bash
# ==============================================================================
# Mapeo dinámico de workspaces por monitor (5 por salida).
#
# Asigna WS_PER_MONITOR workspaces a cada salida conectada, en orden
# izquierda→derecha según su posición x:
#
#   1 monitor  : la salida conectada   → 1-5
#   2 monitores: la de la izquierda    → 1-5
#                la de la derecha      → 6-10
#
# Los rangos se aplican en caliente con `hyprctl keyword workspace` y
# persistent:true, así Hyprland crea los workspaces y Waybar los muestra
# siempre (no hace falta persistent-workspaces en la barra).
#
# Por qué un script y no reglas en workspaces.conf: una regla
# `workspace = N, monitor:HDMI-A-1` reserva el ID N para ese monitor aunque
# esté desconectado. Hyprland elige el default de cada monitor con
# CMonitor::findAvailableDefaultWS(), que salta todo ID atado a otro monitor;
# en una notebook con reglas para HDMI-A-1/HDMI-A-2 (1-5 y 6-10) el primer
# workspace libre terminaba siendo 11.
#
# Uso:
#   workspaces-init.sh            # aplica una vez
#   workspaces-init.sh --watch    # aplica y re-aplica al conectar/desconectar
# ==============================================================================
set -euo pipefail

WS_PER_MONITOR=5

for bin in hyprctl jq; do
    command -v "$bin" >/dev/null 2>&1 || exit 1
done

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"
SOCK_DIR="$RUNTIME/hypr/$SIG"

# exec-once puede adelantarse a la creación de los sockets IPC.
wait_for_sockets() {
    [ -n "$SIG" ] || return 1
    local _
    for _ in $(seq 1 100); do
        if [ -S "$SOCK_DIR/.socket.sock" ] && [ -S "$SOCK_DIR/.socket2.sock" ]; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

# Salidas activas: de izquierda a derecha, según la x del monitor.
monitors() {
    hyprctl monitors -j |
        jq -r 'map(select(.disabled | not)) | sort_by(.x) | .[].name'
}

active_workspace() {
    hyprctl monitors -j |
        jq -r --arg m "$1" '.[] | select(.name == $m) | .activeWorkspace.id'
}

focused_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
}

apply() {
    local names=() focused="" idx name base n id rule current
    mapfile -t names < <(monitors)
    [ "${#names[@]}" -gt 0 ] || return 1

    focused="$(focused_monitor)"

    # 1. Una regla por workspace: persistent (siempre visible) y default en el
    #    primero del rango. `hyprctl keyword workspace` dispara
    #    ensurePersistentWorkspacesPresent(), así que el workspace se crea ya.
    for idx in "${!names[@]}"; do
        name="${names[$idx]}"
        base=$((idx * WS_PER_MONITOR + 1))
        for ((n = 0; n < WS_PER_MONITOR; n++)); do
            id=$((base + n))
            rule="$id, monitor:$name, persistent:true"
            if [ "$n" -eq 0 ]; then
                rule="$rule, default:true"
            fi
            hyprctl keyword workspace "$rule" >/dev/null
        done
    done

    # 2. Si un monitor quedó fuera de su rango (p. ej. el workspace 11 que
    #    Hyprland creaba en la notebook), llevarlo al primero del rango. Los
    #    monitores que ya están dentro no se tocan: conectar un monitor no
    #    debe resetear el workspace que el usuario está usando.
    for idx in "${!names[@]}"; do
        name="${names[$idx]}"
        base=$((idx * WS_PER_MONITOR + 1))
        current="$(active_workspace "$name")"
        if [[ "$current" =~ ^-?[0-9]+$ ]] &&
            [ "$current" -ge "$base" ] && [ "$current" -lt $((base + WS_PER_MONITOR)) ]; then
            continue
        fi
        hyprctl dispatch focusmonitor "$name" >/dev/null
        hyprctl dispatch workspace "$base" >/dev/null
    done

    # 3. Devolver el foco al monitor que estaba enfocado.
    if [ -n "$focused" ] && [ "$(focused_monitor)" != "$focused" ]; then
        hyprctl dispatch focusmonitor "$focused" >/dev/null || true
    fi
}

# Re-aplica al enchufar/desenchufar un monitor (dock, proyector, etc.) y
# después de cualquier `hyprctl reload`: recargar la config limpia las reglas
# `workspace` cargadas en caliente, así que hay que volver a aplicarlas.
watch_events() {
    local sock="$SOCK_DIR/.socket2.sock" line
    [ -S "$sock" ] || return 1
    socat -U - "UNIX-CONNECT:$sock" |
        while IFS= read -r line; do
            case "$line" in
                monitoradded* | monitorremoved* | monitoraddedv2* | configreloaded*) apply || true ;;
            esac
        done
}

case "${1:-}" in
    "" | --once) ;;
    --watch) ;;
    *)
        echo "uso: $0 [--watch]" >&2
        exit 2
        ;;
esac

wait_for_sockets || exit 1

apply || true

if [ "${1:-}" = "--watch" ]; then
    if ! command -v socat >/dev/null 2>&1; then
        echo "workspaces-init: falta socat para --watch" >&2
        exit 1
    fi
    watch_events
fi
