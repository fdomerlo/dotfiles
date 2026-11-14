#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

echo "================================================================="
echo "==> Manteniendo GNOME estándar (fallback) y directorios de trabajo"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Directorios dedicados (Proyectos y Aplicaciones / AppImages)
# ------------------------------------------------------------------------------
echo "==> Verificando directorios de Proyectos y Aplicaciones (AppImages)..."
PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
mkdir -p "$PROJECTS_DIR"

APPIMAGE_DIR="${XDG_APPLICATIONS_DIR:-$HOME/Aplicaciones}"
mkdir -p "$APPIMAGE_DIR"

if command -v xdg-user-dirs-update &>/dev/null; then
    xdg-user-dirs-update --set PROJECTS "$PROJECTS_DIR" 2>/dev/null || true
fi

USER_DIRS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
if [ -f "$USER_DIRS_CONF" ]; then
    if ! grep -q "^XDG_PROJECTS_DIR=" "$USER_DIRS_CONF"; then
        echo "XDG_PROJECTS_DIR=\"$PROJECTS_DIR\"" >> "$USER_DIRS_CONF"
    fi
fi
echo "    ✔ Directorio de proyectos: $PROJECTS_DIR"
echo "    ✔ Directorio de aplicaciones: $APPIMAGE_DIR"

# ------------------------------------------------------------------------------
# 2. Limpieza de personalizaciones y extensiones de GNOME (volver al estándar)
# ------------------------------------------------------------------------------
echo "==> Asegurando GNOME Shell estándar (sin extensiones ni overrides extra)..."

if command -v gsettings &>/dev/null; then
    for key in font-name document-font-name monospace-font-name cursor-theme cursor-size color-scheme gtk-theme; do
        gsettings reset org.gnome.desktop.interface "$key" 2>/dev/null || true
    done
    for key in titlebar-font button-layout; do
        gsettings reset org.gnome.desktop.wm.preferences "$key" 2>/dev/null || true
    done
    for key in maximize unmaximize; do
        gsettings reset org.gnome.desktop.wm.keybindings "$key" 2>/dev/null || true
    done
    for key in disable-extension-version-validation enabled-extensions disabled-extensions; do
        gsettings reset org.gnome.shell "$key" 2>/dev/null || true
    done
    echo "    ✔ Claves GSettings de GNOME restauradas a valores por defecto."
fi

if command -v dconf &>/dev/null; then
    dconf reset -f /org/gnome/shell/extensions/ 2>/dev/null || true
fi

USER_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
LEGACY_EXTS=(
    "AlphabeticalAppGrid@stuarthayhurst"
    "Vitals@CoreCoding.com"
    "dash-to-dock@micxgx.gmail.com"
    "tiling-assistant@leleat-on-github"
)
removed_ext=0
for uuid in "${LEGACY_EXTS[@]}"; do
    if [ -e "$USER_EXT_DIR/$uuid" ]; then
        rm -rf "${USER_EXT_DIR:?}/$uuid"
        removed_ext=$((removed_ext + 1))
    fi
done
[ "$removed_ext" -gt 0 ] && echo "    ✔ Eliminadas $removed_ext extensión(es) de usuario heredadas."

# Remover Adwaita Sans descargada fuera de Debian si estuviera presente
FONT_DIR="$HOME/.local/share/fonts"
if [ -f "$FONT_DIR/AdwaitaSans-Regular.ttf" ] || [ -f "$FONT_DIR/AdwaitaSans-Italic.ttf" ]; then
    rm -f "$FONT_DIR/AdwaitaSans-Regular.ttf" "$FONT_DIR/AdwaitaSans-Italic.ttf"
    command -v fc-cache &>/dev/null && fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
    echo "    ✔ Eliminada Adwaita Sans (externa) de $FONT_DIR."
fi

# Purgar paquete APT dash-to-dock si sigue instalado
if command -v dpkg &>/dev/null && dpkg -s gnome-shell-extension-dashtodock &>/dev/null; then
    if sudo -n true 2>/dev/null; then
        echo "==> Purgando paquete gnome-shell-extension-dashtodock..."
        sudo apt-get purge -y gnome-shell-extension-dashtodock || true
    else
        echo "    ⚠ Pendiente desinstalar paquete APT: sudo apt-get purge -y gnome-shell-extension-dashtodock"
    fi
fi

echo "================================================================="
echo "✔ GNOME Shell mantenido mínimo y estándar (fallback limpio)."
echo "================================================================="
