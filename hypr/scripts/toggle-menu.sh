#!/usr/bin/env bash
# ==============================================================================
# Alterna (muestra/oculta) un menú de fuzzel identificado por un marcador.
#
# Uso:
#   toggle-menu.sh <marcador> <comando> [args...]
#
# Si ya hay un lanzador abierto cuyo argv contiene <marcador>, lo cierra. Si no,
# ejecuta <comando>. Permite que una misma tecla abra y cierre el menú, como
# el gesto de Super en GNOME.
# ==============================================================================
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <marcador> <comando> [args...]" >&2
    exit 2
fi

marker="$1"
shift

# Solo se inspeccionan procesos llamados exactamente "fuzzel": así el
# shell que contiene el marcador en su propia línea de comandos no se mata a sí mismo.
find_launcher() {
    local pid
    for pid in $(pgrep -x fuzzel 2>/dev/null || true); do
        if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -Fq -- "$marker"; then
            printf '%s\n' "$pid"
            return 0
        fi
    done
    return 1
}

if pid="$(find_launcher)"; then
    kill "$pid" 2>/dev/null || true
    exit 0
fi

# Mientras fuzzel está abierto (con keyboard-focus=on-demand), desacoplar el
# foco de teclado del movimiento del puntero (follow_mouse=2): así mover el
# mouse no cierra el menú, pero hacer clic en otra ventana o presionar ESC sí.
# Se guarda el valor vigente (local.lua puede haberlo cambiado) y se restaura
# al salir, en lugar de asumir 1.
read_follow_mouse() {
    local val=""
    val="$(hyprctl getoption input.follow_mouse 2>/dev/null | awk '/^int:/ { print $2; exit }' || true)"
    if [ -z "$val" ]; then
        val="$(hyprctl getoption input:follow_mouse 2>/dev/null | awk '/^int:/ { print $2; exit }' || true)"
    fi
    if [[ "$val" =~ ^[0-3]$ ]]; then
        printf '%s' "$val"
    fi
}

previous_follow_mouse="$(read_follow_mouse)"

restore_mouse() {
    if [ -n "${previous_follow_mouse:-}" ]; then
        hyprctl eval "hl.config({ input = { follow_mouse = $previous_follow_mouse } })" >/dev/null 2>&1 || true
    fi
}
trap restore_mouse EXIT INT TERM
hyprctl eval "hl.config({ input = { follow_mouse = 2 } })" >/dev/null 2>&1 || true

"$@" || true
