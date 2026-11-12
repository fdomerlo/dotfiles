#!/usr/bin/env bash
# ==============================================================================
# Intercambiador de temas de Hyprland.
#
# Los archivos con variantes visuales viven en hypr/themes/<tema>/ y los paths
# clásicos (hypr/waybar/style.css, hypr/conf/appearance.conf, etc.) son
# symlinks a hypr/themes/active/<archivo>. Cambiar de tema solo mueve el symlink
# "active", sin tocar archivos versionados ni ensuciar el working tree.
#
# Uso:
#   theme-switch.sh                 # muestra el tema activo
#   theme-switch.sh list            # lista los temas disponibles
#   theme-switch.sh menu            # selector con fuzzel
#   theme-switch.sh toggle          # alterna al siguiente tema
#   theme-switch.sh <tema>          # aplica un tema
#   theme-switch.sh --no-reload <tema>
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THEMES_DIR="$HYPR_DIR/themes"
ACTIVE_LINK="$THEMES_DIR/active"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

list_themes() {
    find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

current_theme() {
    [ -L "$ACTIVE_LINK" ] || return 1
    basename "$(readlink "$ACTIVE_LINK")"
}

reload_desktop() {
    # Hyprland recarga apariencia, bordes, sombras y animaciones.
    hyprctl reload >/dev/null 2>&1 || true

    # Waybar necesita reinicio: cambia tanto config.jsonc como style.css.
    pkill -x waybar 2>/dev/null || true
    sleep 0.4
    setsid "$HYPR_DIR/scripts/start-waybar.sh" >/dev/null 2>&1 </dev/null &

    # swaync relee el CSS del tema activo.
    swaync-client -rs >/dev/null 2>&1 || true

    # Si el tema tiene fondos propios (o al cambiar de tema), actualizar wallpaper.
    "$HYPR_DIR/scripts/wallpaper.sh" --next >/dev/null 2>&1 || true

    # Aviso breve (si el daemon de notificaciones está disponible).
    notify-send -a "Temas" -t 2000 "Tema aplicado" "$1" >/dev/null 2>&1 || true
}

apply_theme() {
    local theme="$1" reload="${2:-1}"
    local theme_dir="$THEMES_DIR/$theme"

    [ -d "$theme_dir" ] || die "no existe el tema '$theme'"

    # Verificar que el tema tenga todos los archivos esperados.
    local missing=()
    local f
    for f in appearance.conf hyprlock.conf foot/foot.ini fuzzel/fuzzel.ini \
             swaync/style.css waybar/config.jsonc waybar/style.css; do
        [ -e "$theme_dir/$f" ] || missing+=("$f")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "al tema '$theme' le faltan: ${missing[*]}"
    fi

    ln -sfn "$theme" "$ACTIVE_LINK"

    if [ "$reload" = "1" ]; then
        reload_desktop "$theme"
    fi

    printf 'Tema activo: %s\n' "$theme"
}

show_menu() {
    local current choice
    current="$(current_theme || true)"
    if command -v fuzzel >/dev/null 2>&1; then
        choice="$(list_themes | fuzzel --dmenu --prompt "Temas (actual: ${current:-ninguno}): " --width 36 --lines 4 2>/dev/null || true)"
    else
        die "fuzzel no está instalado"
    fi
    [ -n "$choice" ] || exit 0
    apply_theme "$choice" "${1:-1}"
}

toggle_theme() {
    local current themes next
    current="$(current_theme || true)"
    mapfile -t themes < <(list_themes)
    [ "${#themes[@]}" -gt 0 ] || die "no hay temas en $THEMES_DIR"

    next="${themes[0]}"
    local i
    for i in "${!themes[@]}"; do
        if [ "${themes[$i]}" = "$current" ]; then
            next="${themes[$(((i + 1) % ${#themes[@]}))]}"
            break
        fi
    done
    apply_theme "$next" "${1:-1}"
}

reload=1
if [ "${1:-}" = "--no-reload" ]; then
    reload=0
    shift
fi

case "${1:-}" in
    ""|current)
        current_theme || die "no hay un tema activo (falta $ACTIVE_LINK)"
        ;;
    list)
        list_themes
        ;;
    menu)
        show_menu "$reload"
        ;;
    toggle)
        toggle_theme "$reload"
        ;;
    -h|--help)
        sed -n '2,20p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
        ;;
    *)
        apply_theme "$1" "$reload"
        ;;
esac
