#!/usr/bin/env bash
# ==============================================================================
# Gestor y cambiador automático de Wallpaper para Hyprland / Wayland
# - Selecciona wallpapers aleatorios (.png, .jpg, .jpeg, .webp)
# - Suma la carpeta genérica con las carpetas del tema activo (<dir>/<tema>/),
#   si existen; así el tema agrupa fondos propios sin ocultar la colección
#   general del usuario
# - Modo daemon: rota periódicamente (por defecto cada 30 min / 1800 seg)
# - Transición sin parpadeo: espera a que el nuevo swaybg mapee su superficie
#   en todos los monitores activos (`hyprctl layers -j`) antes de cerrar el
#   anterior, serializado con flock y combinado con `wallpaper-no-anim`.
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

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME_DIR/hypr_current_wallpaper"
PID_FILE="$RUNTIME_DIR/hypr_wallpaper_daemon.pid"
LOCK_FILE="$RUNTIME_DIR/hypr_wallpaper.lock"

DEFAULT_INTERVAL=1800 # 30 minutos

active_theme() {
    local active_link="$HYPR_DIR/themes/active"
    local resolved
    resolved="$(readlink -f "$active_link" 2>/dev/null || true)"
    [ -d "$resolved" ] || return 0
    basename "$resolved"
}

fallback_color() {
    case "$(active_theme || true)" in
        cyber-teal-light) printf '#f2f6f7' ;;
        mr-robot-light)   printf '#edf1f4' ;;
        mr-robot)         printf '#05080b' ;;
        *)                printf '#0c1012' ;;
    esac
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

# Obtener lista de todos los wallpapers disponibles: las carpetas del tema
# activo se suman a las globales (no las reemplazan).
get_wallpapers() {
    local -a dirs=()
    local theme
    theme="$(active_theme || true)"
    if [ -n "$theme" ]; then
        dirs+=(
            "$USER_WALLPAPERS/$theme"
            "$PICTURES_ES/$theme"
            "$PICTURES_EN/$theme"
            "$HYPR_DIR/themes/$theme/wallpapers"
        )
    fi
    dirs+=("$USER_WALLPAPERS" "$PICTURES_ES" "$PICTURES_EN" "$REPO_WALLPAPERS")

    collect_from_dirs "${dirs[@]}"
}

# Espera a que el nuevo proceso swaybg mapee su capa `wallpaper` en todos los
# monitores activos de Hyprland (evita el flash negro con PNGs grandes).
wait_for_swaybg_mapped() {
    local target_pid="$1"
    if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        sleep 0.5
        kill -0 "$target_pid" 2>/dev/null
        return $?
    fi

    local expected mapped i
    expected="$(hyprctl monitors -j 2>/dev/null | jq '[.[] | select(.disabled | not)] | length' 2>/dev/null || echo 1)"
    [[ "$expected" =~ ^[0-9]+$ ]] && [ "$expected" -gt 0 ] || expected=1

    # Poll cada 50 ms hasta 6 s (suficiente incluso para PNGs 4K de 20+ MB)
    for (( i = 0; i < 120; i++ )); do
        kill -0 "$target_pid" 2>/dev/null || return 1
        mapped="$(
            hyprctl layers -j 2>/dev/null | jq --argjson pid "$target_pid" '
                [ .. | objects | select(.namespace? == "wallpaper" and .pid? == $pid) ] | length
            ' 2>/dev/null || echo 0
        )"
        if [[ "$mapped" =~ ^[0-9]+$ ]] && [ "$mapped" -ge "$expected" ]; then
            # Margen de un frame para asegurar presentación antes de cerrar el fondo previo
            sleep 0.08
            return 0
        fi
        sleep 0.05
    done

    kill -0 "$target_pid" 2>/dev/null
}

# Aplica una imagen de fondo específica (serializado con flock)
apply_wallpaper() {
    local wall="$1"
    if [ ! -f "$wall" ]; then
        return 1
    fi

    command -v swaybg >/dev/null 2>&1 || return 1

    (
        flock -x 9

        local bg_color new_pid pid
        local -a old_pids=()
        bg_color="$(fallback_color)"

        mapfile -t old_pids < <(pgrep -x swaybg 2>/dev/null || true)

        setsid swaybg -i "$wall" -m fill -c "$bg_color" >/dev/null 2>&1 </dev/null 9>&- &
        new_pid=$!

        if wait_for_swaybg_mapped "$new_pid"; then
            echo "$wall" > "$STATE_FILE"
            for pid in "${old_pids[@]}"; do
                [ -n "$pid" ] && [ "$pid" != "$new_pid" ] && kill "$pid" 2>/dev/null || true
            done
        else
            # Imagen corrupta o fallo al arrancar swaybg: conservar el fondo anterior
            kill "$new_pid" 2>/dev/null || true
            return 1
        fi
    ) 9>"$LOCK_FILE"
}

# Elige un wallpaper aleatorio (sin repetir el actual si hay más de uno)
apply_random() {
    local wall_list=()
    mapfile -t wall_list < <(get_wallpapers)
    local total=${#wall_list[@]}

    if [ "$total" -eq 0 ]; then
        rm -f "$STATE_FILE"
        if command -v swaybg >/dev/null 2>&1; then
            local bg_color
            bg_color="$(fallback_color)"
            pkill -x swaybg 2>/dev/null || true
            setsid swaybg -c "$bg_color" >/dev/null 2>&1 </dev/null &
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
        local w
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

    local sleep_pid=""
    cleanup() {
        [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 0
    }
    on_usr1() {
        [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null || true
    }

    trap 'cleanup' EXIT INT TERM
    trap 'on_usr1' USR1

    # Primer fondo al inicio
    apply_random

    while true; do
        sleep "$interval" &
        sleep_pid=$!
        wait "$sleep_pid" 2>/dev/null || true
        sleep_pid=""
        apply_random
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
