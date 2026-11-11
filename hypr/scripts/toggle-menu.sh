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
restore_mouse() {
    hyprctl keyword input:follow_mouse 1 >/dev/null 2>&1 || true
}
trap restore_mouse EXIT INT TERM
hyprctl keyword input:follow_mouse 2 >/dev/null 2>&1 || true

"$@" || true
