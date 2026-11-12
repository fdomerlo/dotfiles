#!/usr/bin/env bash
# ==============================================================================
# Gestor y cambiador automático de Wallpaper para Hyprland / Wayland
# - Selecciona wallpapers aleatorios (.png, .jpg, .jpeg, .webp)
# - Prioriza carpetas específicas del tema activo (<dir>/<tema>/); si están
#   vacías o no existen, cae a las carpetas globales
# - Modo daemon: rota periódicamente (por defecto cada 30 min / 1800 seg)
# - Transición suave sin parpadeo negro
# - Admite cambio a demanda con --next o enviando señal SIGUSR1
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_WALLPAPERS="$HYPR_DIR/wallpapers"
USER_WALLPAPERS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpapers"
PICTURES_ES="$HOME/Imágenes/Wallpapers"
PICTURES_EN="$HOME/Pictures/Wallpapers"

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr_current_wallpaper"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr_wallpaper_daemon.pid"

DEFAULT_INTERVAL=1800 # 30 minutos

active_theme() {
    local active_link="$HYPR_DIR/themes/active"
    local resolved
    resolved="$(readlink -f "$active_link" 2>/dev/null || true)"
    [ -d "$resolved" ] || return 0
    basename "$resolved"
}

collect_from_dirs() {
    local found=()
    local d file
    for d in "$@"; do
        if [ -d "$d" ]; then
            while IFS= read -r -d '' file; do
                found+=("$file")
            done < <(find -L "$d" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0 2>/dev/null)
        fi
    done
    if [ ${#found[@]} -gt 0 ]; then
        printf "%s\n" "${found[@]}" | sort -u
    fi
}

# Obtener lista de todos los wallpapers disponibles (por tema primero, luego globales)
get_wallpapers() {
    local theme
    theme="$(active_theme || true)"
    if [ -n "$theme" ]; then
        local themed=""
        themed="$(collect_from_dirs \
            "$USER_WALLPAPERS/$theme" \
            "$PICTURES_ES/$theme" \
            "$PICTURES_EN/$theme" \
            "$HYPR_DIR/themes/$theme/wallpapers")"
        if [ -n "$themed" ]; then
            printf '%s\n' "$themed"
            return 0
        fi
    fi

    collect_from_dirs "$USER_WALLPAPERS" "$PICTURES_ES" "$PICTURES_EN" "$REPO_WALLPAPERS"
}

# Aplica una imagen de fondo específica
apply_wallpaper() {
    local wall="$1"
    if [ ! -f "$wall" ]; then
        return 1
    fi

    # Guardar la imagen aplicada como actual
    echo "$wall" > "$STATE_FILE"

    if command -v swaybg >/dev/null 2>&1; then
        local old_pids
        old_pids=$(pgrep -x swaybg || true)
        swaybg -i "$wall" -m fill -c '#0c1012' >/dev/null 2>&1 &
        sleep 0.5
        if [ -n "$old_pids" ]; then
            kill $old_pids 2>/dev/null || true
        fi
        return 0
    fi

    return 1
}

# Elige un wallpaper aleatorio (sin repetir el actual si hay más de uno)
apply_random() {
    local wall_list=()
    mapfile -t wall_list < <(get_wallpapers)
    local total=${#wall_list[@]}

    if [ "$total" -eq 0 ]; then
        if command -v swaybg >/dev/null 2>&1; then
            pkill -x swaybg 2>/dev/null || true
            swaybg -c '#0c1012' >/dev/null 2>&1 &
        fi
        return 0
    fi

    local current=""
    if [ -f "$STATE_FILE" ]; then
        current=$(cat "$STATE_FILE" 2>/dev/null || true)
    fi

    local candidate=""
    if [ "$total" -eq 1 ]; then
        candidate="${wall_list[0]}"
    else
        local filtered=()
        for w in "${wall_list[@]}"; do
            if [ "$w" != "$current" ]; then
                filtered+=("$w")
            fi
        done
        if [ ${#filtered[@]} -gt 0 ]; then
            candidate="${filtered[RANDOM % ${#filtered[@]}]}"
        else
            candidate="${wall_list[RANDOM % total]}"
        fi
    fi

    apply_wallpaper "$candidate"
}

# Bucle en segundo plano (daemon)
run_daemon() {
    local interval="${1:-$DEFAULT_INTERVAL}"

    # Prevenir instancias duplicadas
    if [ -f "$PID_FILE" ]; then
        local prev_pid
        prev_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$prev_pid" ] && kill -0 "$prev_pid" 2>/dev/null; then
            echo "El daemon de wallpapers ya está en ejecución (PID $prev_pid)."
            exit 0
        fi
    fi
    echo "$$" > "$PID_FILE"
    trap 'rm -f "$PID_FILE"; exit 0' EXIT INT TERM

    # Atrapa SIGUSR1 para cambiar inmediatamente de fondo a demanda
    trap 'apply_random' USR1

    # Primer fondo al inicio
    apply_random

    while true; do
        sleep "$interval" &
        # Si `wait` se interrumpe por SIGUSR1, el trap ya aplicó el cambio:
        # solo se rota por temporizador cuando el sleep termina normalmente.
        if wait $!; then
            apply_random
        fi
    done
}

# Solicita al daemon el cambio inmediato o ejecuta si no hay daemon activo
trigger_next() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -USR1 "$pid"
            exit 0
        fi
    fi
    apply_random
}

case "${1:-}" in
    --daemon|-d)
        run_daemon "${2:-$DEFAULT_INTERVAL}"
        ;;
    --next|-n|--random|-r)
        trigger_next
        ;;
    "")
        apply_random
        ;;
    *)
        if [ -f "$1" ]; then
            apply_wallpaper "$1"
        else
            echo "Uso: $0 [--daemon [segundos] | --next | /ruta/a/imagen]"
            exit 1
        fi
        ;;
esac
