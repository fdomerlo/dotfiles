#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/lockscreen-switch.sh - Selector de estilo de pantalla de bloqueo
#
# Cambia el symlink ~/.config/hypr/hyprlock.conf entre la configuración del tema
# activo (Opción A · HUD Táctico) y los presets independientes ubicados en
# hypr/lockscreens/*.conf, sin modificar archivos versionados en el repo.
#
# Uso:
#   lockscreen-switch.sh              # muestra el preset activo
#   lockscreen-switch.sh current      # ídem
#   lockscreen-switch.sh list         # lista los presets disponibles
#   lockscreen-switch.sh menu         # selector interactivo con fuzzel
#   lockscreen-switch.sh <preset>     # aplica un preset (theme, soc-console, ...)
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRESETS_DIR="$HYPR_DIR/lockscreens"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_LINK="$CONFIG_HOME/hypr/hyprlock.conf"
THEME_DEFAULT="$HYPR_DIR/hyprlock.conf"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Hyprlock" -t 2500 "$@" 2>/dev/null || true
    fi
}

preset_label() {
    case "$1" in
        theme)        printf 'HUD Táctico por tema (Opción A)' ;;
        soc-console)  printf 'SOC Console (telemetría + journal + auth)' ;;
        matrix-soc)   printf 'Matrix SOC (Opción C · tarjeta + feed completo)' ;;
        minimal-tech) printf 'Minimal Tech (Opción B · candado limpio)' ;;
        classic)      printf 'Clásico (reloj, clave, usuario)' ;;
        *)            printf '%s' "$1" ;;
    esac
}

list_presets() {
    printf 'theme\n'
    if [ -d "$PRESETS_DIR" ]; then
        find "$PRESETS_DIR" -mindepth 1 -maxdepth 1 -name '*.conf' -printf '%f\n' \
            | sed 's/\.conf$//' | sort
    fi
}

current_preset() {
    if [ ! -L "$TARGET_LINK" ] && [ ! -e "$TARGET_LINK" ]; then
        printf 'theme'
        return 0
    fi
    local resolved
    resolved="$(readlink -f "$TARGET_LINK" 2>/dev/null || true)"
    if [[ "$resolved" == "$PRESETS_DIR/"*.conf ]]; then
        basename "$resolved" .conf
    else
        printf 'theme'
    fi
}

apply_preset() {
    local name="${1%.conf}" src
    if [ "$name" = "theme" ]; then
        src="$THEME_DEFAULT"
    else
        src="$PRESETS_DIR/${name}.conf"
    fi

    [ -e "$src" ] || die "No existe el preset '$name' ($src)"

    mkdir -p "$(dirname "$TARGET_LINK")"
    if [ -e "$TARGET_LINK" ] && [ ! -L "$TARGET_LINK" ]; then
        mv "$TARGET_LINK" "$TARGET_LINK.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sfn "$src" "$TARGET_LINK"

    notify "Pantalla de bloqueo" "Estilo aplicado: $(preset_label "$name")"
    printf 'Lockscreen activo: %s (%s)\n' "$name" "$src"
}

show_menu() {
    command -v fuzzel >/dev/null 2>&1 || die "fuzzel no está instalado"
    local cur p lbl
    cur="$(current_preset)"
    local -a opts=()

    while IFS= read -r p; do
        [ -n "$p" ] || continue
        lbl="$(preset_label "$p")"
        if [ "$p" = "$cur" ]; then
            opts+=("✔  [$p] $lbl")
        else
            opts+=("   [$p] $lbl")
        fi
    done < <(list_presets)

    local choice
    choice="$(printf '%s\n' "${opts[@]}" | fuzzel --dmenu \
        --prompt "Lockscreen (actual: $cur): " \
        --width 58 \
        --lines "${#opts[@]}" 2>/dev/null || true)"
    [ -n "$choice" ] || exit 0

    local chosen
    chosen="$(sed -E 's/^[^[]*\[([^]]+)\].*$/\1/' <<<"$choice")"
    [ -n "$chosen" ] || exit 0
    apply_preset "$chosen"
}

case "${1:-current}" in
    ""|current)
        cur="$(current_preset)"
        printf '%s (%s)\n' "$cur" "$(preset_label "$cur")"
        ;;
    list)
        list_presets
        ;;
    menu)
        show_menu
        ;;
    set)
        [ -n "${2:-}" ] || die "Uso: $0 set <preset>"
        apply_preset "$2"
        ;;
    -h|--help)
        sed -n '2,18p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
        ;;
    *)
        apply_preset "$1"
        ;;
esac
