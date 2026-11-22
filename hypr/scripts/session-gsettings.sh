#!/usr/bin/env bash
# ==============================================================================
# Aplica o restaura claves GSettings (dconf) para portales, Flatpak y apps
# GTK/libadwaita dentro de Hyprland, manteniendo GNOME Shell estándar (sin
# overrides ni extensiones) como fallback limpio al cerrar Hyprland.
#
# Uso:
#   session-gsettings.sh apply   # esquema claro/oscuro, fuentes Debian, cursor Bibata y acento del tema
#   session-gsettings.sh reset   # restaura los defaults estándar de GNOME
# ==============================================================================
set -euo pipefail

command -v gsettings >/dev/null 2>&1 || exit 0

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

active_theme() {
    local link="$HYPR_DIR/themes/active"
    [ -L "$link" ] || return 0
    basename "$(readlink "$link")"
}

# Acento de libadwaita por tema: asi Nautilus, Configuracion y Flatpaks dejan
# de quedar azules cuando el escritorio usa otra paleta.
accent_for_theme() {
    case "$1" in
        mr-robot|mr-robot-light)     printf 'slate' ;;
        cyber-teal|cyber-teal-light) printf 'teal' ;;
        *)                           printf 'blue' ;;
    esac
}

# Esquema claro/oscuro por tema. Los temas *-light declaran prefer-light y el
# resto prefer-dark para que libadwaita y las apps GTK acompañen el escritorio.
scheme_for_theme() {
    case "$1" in
        cyber-teal-light|mr-robot-light) printf 'prefer-light' ;;
        *)                               printf 'prefer-dark' ;;
    esac
}

config_home() {
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Escribe una clave en un .ini estilo GTK solo si cambia (idempotente).
set_ini_setting() {
    local file="$1" key="$2" value="$3"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        grep -qE "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${value}[[:space:]]*$" "$file" \
            || sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        grep -q '^\[Settings\]' "$file" || sed -i '1i [Settings]' "$file"
        sed -i "/^\[Settings\]/a ${key} = ${value}" "$file"
    fi
}

# GTK3/GTK4: sin esto, gtk-application-prefer-dark-theme=1 fuerza modo oscuro
# incluso cuando color-scheme dice prefer-light.
apply_gtk_scheme() {
    local theme scheme prefer_dark ver dir settings
    theme="$(active_theme)"
    scheme="$(scheme_for_theme "$theme")"
    prefer_dark=1
    [ "$scheme" = "prefer-light" ] && prefer_dark=0

    for ver in gtk-3.0 gtk-4.0; do
        dir="$(config_home)/$ver"
        settings="$dir/settings.ini"
        mkdir -p "$dir"
        [ -f "$settings" ] || printf '[Settings]\n' >"$settings"
        set_ini_setting "$settings" gtk-application-prefer-dark-theme "$prefer_dark"
    done
}

set_if_changed() {
    local schema="$1" key="$2" expected="$3" value="$4"
    local current
    current="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [ "$current" != "$expected" ]; then
        gsettings set "$schema" "$key" "$value" 2>/dev/null || true
    fi
}

apply_hyprland() {
    local fc_families theme scheme
    fc_families="$(fc-list : family 2>/dev/null || true)"
    theme="$(active_theme)"
    scheme="$(scheme_for_theme "$theme")"

    set_if_changed org.gnome.desktop.interface color-scheme "'$scheme'" "$scheme"
    set_if_changed org.gnome.desktop.interface gtk-theme "'Adwaita'" "Adwaita"

    local accent
    accent="$(accent_for_theme "$theme")"
    set_if_changed org.gnome.desktop.interface accent-color "'$accent'" "$accent"

    apply_gtk_scheme

    if grep -iqE '(^|,)Inter(,|$)' <<<"$fc_families"; then
        set_if_changed org.gnome.desktop.interface font-name "'Inter 11'" "Inter 11"
    fi
    if grep -iqE '(^|,)Atkinson Hyperlegible(,|$)' <<<"$fc_families"; then
        set_if_changed org.gnome.desktop.interface document-font-name "'Atkinson Hyperlegible 12'" "Atkinson Hyperlegible 12"
    fi
    if grep -iqE '(^|,)JetBrains Mono(,|$)' <<<"$fc_families"; then
        set_if_changed org.gnome.desktop.interface monospace-font-name "'JetBrains Mono 11'" "JetBrains Mono 11"
    fi

    if [ -d /usr/share/icons/Bibata-Modern-Classic ] || [ -d "$HOME/.local/share/icons/Bibata-Modern-Classic" ]; then
        set_if_changed org.gnome.desktop.interface cursor-theme "'Bibata-Modern-Classic'" "Bibata-Modern-Classic"
        set_if_changed org.gnome.desktop.interface cursor-size "24" "24"
    fi
}

reset_gnome() {
    local key
    for key in font-name document-font-name monospace-font-name cursor-theme cursor-size color-scheme gtk-theme accent-color; do
        gsettings reset org.gnome.desktop.interface "$key" 2>/dev/null || true
    done
}

case "${1:-apply}" in
    apply) apply_hyprland ;;
    reset) reset_gnome ;;
    *)
        echo "Uso: $0 {apply|reset}" >&2
        exit 2
        ;;
esac
