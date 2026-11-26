#!/usr/bin/env bash
# ==============================================================================
# Conmutador de modo claro / oscuro (Tema único Cyber-Teal Material 3).
#
# La estructura base vive unificada en hypr/conf/appearance.conf y
# hypr/quickshell/Theme.qml. Solo las paletas por polaridad (dark / light) viven
# en hypr/themes/<modo>/, enlazadas vía hypr/themes/active.
#
# En Quickshell el cambio ocurre en caliente por IPC (`qs ipc call theme setMode`)
# con ColorAnimation suave, sin reiniciar el shell.
#
# Uso:
#   theme-switch.sh                 # muestra el modo activo (dark / light)
#   theme-switch.sh list            # lista los modos disponibles
#   theme-switch.sh menu            # selector con fuzzel
#   theme-switch.sh toggle          # alterna dark <-> light
#   theme-switch.sh <dark|light>    # aplica un modo
#   theme-switch.sh --no-reload <modo>
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$HYPR_DIR/.." && pwd)"
THEMES_DIR="$HYPR_DIR/themes"
ACTIVE_LINK="$THEMES_DIR/active"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

normalize_mode() {
    case "$1" in
        dark|cyber-teal|mr-robot)                        printf 'dark' ;;
        light|light-stone|cyber-teal-light|mr-robot-light) printf 'light' ;;
        *)                                               printf '%s' "$1" ;;
    esac
}

sync_btop_theme() {
    local mode="$1"
    local btop_themes="${XDG_CONFIG_HOME:-$HOME/.config}/btop/themes"
    local src="$REPO_DIR/shell/btop/themes/neutral.theme"
    if [ "$mode" = "light" ] && [ -f "$REPO_DIR/shell/btop/themes/neutral-light.theme" ]; then
        src="$REPO_DIR/shell/btop/themes/neutral-light.theme"
    fi
    [ -f "$src" ] || return 0
    mkdir -p "$btop_themes"
    ln -sfn "$src" "$btop_themes/neutral.theme"
    pkill -USR2 -x btop 2>/dev/null || true
}

list_themes() {
    find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

current_theme() {
    [ -L "$ACTIVE_LINK" ] || return 1
    basename "$(readlink "$ACTIVE_LINK")"
}

reload_desktop() {
    local mode="$1"

    # Hyprland recarga colores de bordes, sombras y blur desde colors.conf.
    hyprctl reload >/dev/null 2>&1 || true

    # Quickshell: cambio en caliente sin reiniciar (ColorAnimation Material 3).
    if command -v qs >/dev/null 2>&1; then
        if ! qs ipc call theme setMode "$mode" >/dev/null 2>&1; then
            setsid "$HYPR_DIR/scripts/start-quickshell.sh" >/dev/null 2>&1 </dev/null &
        fi
    fi

    # Esquema claro/oscuro y acento teal en GTK/libadwaita y Qt6CT.
    "$HYPR_DIR/scripts/session-gsettings.sh" apply >/dev/null 2>&1 || true

    # Rotar al wallpaper acorde a la nueva polaridad.
    "$HYPR_DIR/scripts/wallpaper.sh" --next >/dev/null 2>&1 || true

    local label="Modo Oscuro"
    [ "$mode" = "light" ] && label="Modo Claro"
    notify-send -a "Apariencia" -t 1800 "Tema aplicado" "$label (Cyber-Teal M3)" >/dev/null 2>&1 || true
}

apply_theme() {
    local theme reload="${2:-1}"
    theme="$(normalize_mode "$1")"
    local theme_dir="$THEMES_DIR/$theme"

    [ -d "$theme_dir" ] || die "no existe el modo '$theme' (disponibles: dark, light)"

    local missing=()
    local f
    for f in colors.conf hyprlock.conf soc-console.conf foot/foot.ini fuzzel/fuzzel.ini; do
        [ -e "$theme_dir/$f" ] || missing+=("$f")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "al modo '$theme' le faltan: ${missing[*]}"
    fi

    ln -sfn "$theme" "$ACTIVE_LINK"
    sync_btop_theme "$theme"

    if [ "$reload" = "1" ]; then
        reload_desktop "$theme"
    fi

    printf 'Modo activo: %s\n' "$theme"
}

show_menu() {
    local current choice
    current="$(current_theme || true)"
    if command -v fuzzel >/dev/null 2>&1; then
        choice="$(printf 'dark\nlight\n' | fuzzel --dmenu --prompt "Apariencia (actual: ${current:-ninguno}): " --width 36 --lines 2 2>/dev/null || true)"
    else
        die "fuzzel no está instalado"
    fi
    [ -n "$choice" ] || exit 0
    apply_theme "$choice" "${1:-1}"
}

toggle_theme() {
    local current next
    current="$(current_theme || true)"
    if [ "$current" = "light" ]; then
        next="dark"
    else
        next="light"
    fi
    apply_theme "$next" "${1:-1}"
}

reload=1
if [ "${1:-}" = "--no-reload" ]; then
    reload=0
    shift
fi

case "${1:-}" in
    ""|current)
        current_theme || die "no hay un modo activo (falta $ACTIVE_LINK)"
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
