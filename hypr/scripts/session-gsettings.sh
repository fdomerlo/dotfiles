#!/usr/bin/env bash
# ==============================================================================
# Aplica o restaura claves GSettings (dconf) para portales, Flatpak y apps
# GTK/libadwaita dentro de Hyprland, manteniendo GNOME Shell estándar (sin
# overrides ni extensiones) como fallback limpio al cerrar Hyprland.
#
# Uso:
#   session-gsettings.sh apply   # modo oscuro, fuentes Debian y cursor Bibata
#   session-gsettings.sh reset   # restaura los defaults estándar de GNOME
# ==============================================================================
set -euo pipefail

command -v gsettings >/dev/null 2>&1 || exit 0

set_if_changed() {
    local schema="$1" key="$2" expected="$3" value="$4"
    local current
    current="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [ "$current" != "$expected" ]; then
        gsettings set "$schema" "$key" "$value" 2>/dev/null || true
    fi
}

apply_hyprland() {
    local fc_families
    fc_families="$(fc-list : family 2>/dev/null || true)"

    set_if_changed org.gnome.desktop.interface color-scheme "'prefer-dark'" "prefer-dark"
    set_if_changed org.gnome.desktop.interface gtk-theme "'Adwaita'" "Adwaita"

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
    for key in font-name document-font-name monospace-font-name cursor-theme cursor-size color-scheme gtk-theme; do
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
