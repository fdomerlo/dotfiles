#!/usr/bin/env bash
# ==============================================================================
# Inicia y supervisa Quickshell como shell residente de la sesión Hyprland.
#
# - Espera a que existan los sockets IPC de Hyprland antes de lanzar `qs`.
# - Repara audio (audio-init.sh) antes de que Quickshell conecte a PipeWire.
# - Usa un lock (flock) para garantizar una única instancia por sesión.
# - Si `qs` termina de forma inesperada mientras Hyprland sigue vivo, lo
#   reinicia con respaldo (máx. 5 caídas en 30 s) para evitar bucles infinitos.
#
# Uso:
#   start-quickshell.sh             # inicia el supervisor (idempotente)
#   start-quickshell.sh --restart   # detiene la instancia actual y relanza
#   start-quickshell.sh --stop      # detiene supervisor y quickshell
# ==============================================================================
set -u

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME/quickshell-supervisor.lock"
PID_FILE="$RUNTIME/quickshell-supervisor.pid"

stop_existing() {
    if [ -r "$PID_FILE" ]; then
        local old_pid
        old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
            for _ in $(seq 1 20); do
                kill -0 "$old_pid" 2>/dev/null || break
                sleep 0.05
            done
        fi
        rm -f "$PID_FILE"
    fi
    if command -v qs >/dev/null 2>&1; then
        qs kill >/dev/null 2>&1 || true
    fi
    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
    for _ in $(seq 1 25); do
        pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1 || break
        sleep 0.05
    done
}

case "${1:-}" in
    --stop)
        stop_existing
        exit 0
        ;;
    --restart)
        stop_existing
        ;;
    "")
        ;;
    *)
        echo "Uso: $0 [--restart|--stop]" >&2
        exit 2
        ;;
esac

command -v qs >/dev/null 2>&1 || exit 0

SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [ -z "$SIG" ]; then
    echo "start-quickshell: HYPRLAND_INSTANCE_SIGNATURE no está definido" >&2
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

# Asegurar que PipeWire/WirePlumber no quede en Dummy Output al conectar.
if [ -x "$HOME/.config/hypr/scripts/audio-init.sh" ]; then
    "$HOME/.config/hypr/scripts/audio-init.sh" || true
fi

# Instancia única del supervisor.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

printf '%s\n' "$$" > "$PID_FILE"

QS_CHILD=""
cleanup() {
    if [ -n "$QS_CHILD" ] && kill -0 "$QS_CHILD" 2>/dev/null; then
        kill "$QS_CHILD" 2>/dev/null || true
        wait "$QS_CHILD" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup INT TERM HUP

crash_times=()

while :; do
    # Salir limpiamente si la sesión Hyprland terminó.
    [ -S "$SOCK_DIR/.socket.sock" ] || break

    qs -n &
    QS_CHILD=$!
    wait "$QS_CHILD"
    rc=$?
    QS_CHILD=""

    # Si Hyprland cerró o la salida fue limpia por señal, no relanzar.
    [ -S "$SOCK_DIR/.socket.sock" ] || break
    [ "$rc" -eq 0 ] && break

    now="$(date +%s)"
    kept=()
    for t in "${crash_times[@]}"; do
        if [ $((now - t)) -lt 30 ]; then
            kept+=("$t")
        fi
    done
    kept+=("$now")
    crash_times=("${kept[@]}")

    if [ "${#crash_times[@]}" -ge 5 ]; then
        echo "start-quickshell: demasiados reinicios en 30 s; deteniendo supervisor." >&2
        break
    fi

    sleep 1
done

rm -f "$PID_FILE"
