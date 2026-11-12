#!/usr/bin/env bash
# scripts/hyprland.sh - Perfil opcional Hyprland para Debian Stable.
#
# Instala el stack Hyprland (desde stable-backports) y despliega la
# configuración del repo en ~/.config con symlinks idempotentes.
# No reemplaza GNOME: Hyprland se agrega como sesión adicional en GDM.
#
# Uso:
#   make hyprland
#   bash scripts/hyprland.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR_SRC="$REPO_DIR/hypr"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

BACKPORTS_FILE="/etc/apt/sources.list.d/debian-backports.sources"

# shellcheck source=scripts/hyprland-packages.sh
source "$REPO_DIR/scripts/hyprland-packages.sh"
BACKPORTS_PKGS=("${HYPR_BACKPORTS_PKGS[@]}")
MAIN_PKGS=("${HYPR_MAIN_PKGS[@]}")

die() { echo -e "\n\033[31m✘ $*\033[0m" >&2; exit 1; }
ok()  { echo -e "  \033[32m✔\033[0m $*"; }
warn(){ echo -e "  \033[33m⚠\033[0m $*"; }

echo "================================================================="
echo "==> Perfil opcional Hyprland (Debian Stable)"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Preflight: usuario, sudo y Debian Stable
# ------------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    die "No ejecutes este script como root. Usá: make hyprland"
fi

command -v sudo >/dev/null 2>&1 || die "sudo no está disponible."
command -v apt-get >/dev/null 2>&1 || die "apt-get no está disponible (¿es Debian?)."

# Gate inicial por os-release; la suite exacta se valida después de apt-get update.
# shellcheck disable=SC1091
[ -r /etc/os-release ] || die "No se pudo leer /etc/os-release."
. /etc/os-release
[ "${ID:-}" = "debian" ] || die "Este repositorio solo soporta Debian Stable. Sistema detectado: ${PRETTY_NAME:-desconocido}"

if [ ! -f "$BACKPORTS_FILE" ]; then
    die "No existe $BACKPORTS_FILE. Ejecutá 'make host' antes de instalar Hyprland."
fi
ok "Backports de Stable configurados."

sudo -v || die "Se requieren privilegios de sudo para instalar paquetes."

# ------------------------------------------------------------------------------
# 2. Repositorios y disponibilidad
# ------------------------------------------------------------------------------
echo "==> Actualizando índices APT..."
sudo apt-get update -y

# Detección exacta de Stable: la coma evita confundir 'stable' con 'stable-backports'.
if ! apt-cache policy 2>/dev/null | grep -q 'o=Debian,a=stable,'; then
    die "Este repositorio solo soporta Debian Stable. Sistema detectado: ${PRETTY_NAME:-desconocido}"
fi
ok "Debian Stable detectado."

echo "==> Verificando disponibilidad en stable-backports..."
# `apt-cache policy <paquete>` no muestra los campos de release (o=, a=), solo la
# suite en la tabla de versiones (p. ej. "trixie-backports/main"). Por eso se
# detecta el origen por el sufijo de backports de esa línea.
for pkg in "${BACKPORTS_PKGS[@]}"; do
    if ! apt-cache policy "$pkg" 2>/dev/null | grep -q -- '-backports/'; then
        die "El paquete '$pkg' no está disponible en stable-backports. Revisá los repositorios con 'make verify'."
    fi
done
ok "Stack Hyprland disponible en stable-backports."

# ------------------------------------------------------------------------------
# 3. Instalación
# ------------------------------------------------------------------------------
echo "==> Instalando Hyprland y componentes (stable-backports)..."
sudo apt-get install -y -t stable-backports "${BACKPORTS_PKGS[@]}"

echo "==> Instalando utilidades del escritorio (Stable main)..."
sudo apt-get install -y "${MAIN_PKGS[@]}"

# ------------------------------------------------------------------------------
# 4. Verificación de binarios y archivos de sesión
# ------------------------------------------------------------------------------
echo "==> Verificando instalación..."
REQUIRED_BINS=("${HYPR_REQUIRED_BINS[@]}")
missing=()
for bin in "${REQUIRED_BINS[@]}"; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ "${#missing[@]}" -gt 0 ]; then
    die "Faltan binarios tras la instalación: ${missing[*]}"
fi
ok "Binarios requeridos presentes."

[ -x /usr/libexec/hyprpolkitagent ] || die "No se encontró /usr/libexec/hyprpolkitagent."
[ -f /usr/share/wayland-sessions/hyprland.desktop ] || die "No se encontró la sesión Hyprland para el display manager."
[ -f /usr/share/xdg-desktop-portal/portals/hyprland.portal ] || die "No se encontró el portal de Hyprland."
ok "Sesión de GDM y portal de escritorio presentes."

# ------------------------------------------------------------------------------
# 5. Despliegue de configuración (symlinks idempotentes con backup)
# ------------------------------------------------------------------------------
echo "==> Desplegando configuración en $CONFIG_HOME..."
STAMP="$(date +%Y%m%d%H%M%S)"

link_file() {
    local src="$1" dest="$2"
    [ -e "$src" ] || die "Falta el archivo de configuración en el repo: $src"

    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mv "$dest" "$dest.bak.$STAMP"
        warn "Backup: $dest.bak.$STAMP"
    fi
    ln -s "$src" "$dest"
    ok "$dest"
}

link_file "$HYPR_SRC/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"

# Los paths clásicos son symlinks a hypr/themes/active/…; asegurar un tema
# válido antes de desplegar para que readlink -f no encuentre enlaces roto
# (por ejemplo, en un clon nuevo o después de un git clean).
THEMES_DIR="$HYPR_SRC/themes"
ACTIVE_THEME_LINK="$THEMES_DIR/active"
if [ ! -d "$ACTIVE_THEME_LINK" ]; then
    ln -sfn mr-robot "$ACTIVE_THEME_LINK"
    warn "Tema activo ausente; se configuró mr-robot por defecto."
fi

for f in "$HYPR_SRC"/conf/*.conf; do
    link_file "$f" "$CONFIG_HOME/hypr/conf/$(basename "$f")"
done
for f in "$HYPR_SRC"/hypridle.conf "$HYPR_SRC"/hyprlock.conf; do
    link_file "$f" "$CONFIG_HOME/hypr/$(basename "$f")"
done
for f in "$HYPR_SRC"/scripts/*.sh; do
    link_file "$f" "$CONFIG_HOME/hypr/scripts/$(basename "$f")"
done
for f in "$HYPR_SRC"/waybar/*; do
    link_file "$f" "$CONFIG_HOME/waybar/$(basename "$f")"
done
for f in "$HYPR_SRC"/fuzzel/*; do
    link_file "$f" "$CONFIG_HOME/fuzzel/$(basename "$f")"
done
for f in "$HYPR_SRC"/foot/*; do
    link_file "$f" "$CONFIG_HOME/foot/$(basename "$f")"
done
for f in "$HYPR_SRC"/swappy/*; do
    link_file "$f" "$CONFIG_HOME/swappy/$(basename "$f")"
done
for f in "$HYPR_SRC"/swaync/*; do
    link_file "$f" "$CONFIG_HOME/swaync/$(basename "$f")"
done
link_file "$HYPR_SRC/xdg-desktop-portal/hyprland-portals.conf" "$CONFIG_HOME/xdg-desktop-portal/hyprland-portals.conf"

mkdir -p "$CONFIG_HOME/hypr/wallpapers"
if [ -f "$HYPR_SRC/wallpapers/default.png" ]; then
    link_file "$HYPR_SRC/wallpapers/default.png" "$CONFIG_HOME/hypr/wallpapers/default.png"
fi
ok "Directorio de wallpapers: $CONFIG_HOME/hypr/wallpapers"

# Modo oscuro GTK3/GTK4 y cursor Adwaita para aplicaciones en Hyprland.
# Se converge el archivo existente en lugar de solo agregar claves: así una
# instalación previa con «Adwaita-dark» o «prefer-dark-theme=0» (modelo viejo)
# queda alineada con el actual, «Adwaita» + color-scheme prefer-dark.
set_gtk_setting() {
    local file="$1" key="$2" value="$3"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        grep -q '^\[Settings\]' "$file" || sed -i '1i [Settings]' "$file"
        sed -i "/^\[Settings\]/a ${key} = ${value}" "$file"
    fi
}

for gtk_ver in gtk-3.0 gtk-4.0; do
    mkdir -p "$CONFIG_HOME/$gtk_ver"
    settings="$CONFIG_HOME/$gtk_ver/settings.ini"
    [ -f "$settings" ] || printf '[Settings]\n' >"$settings"
    set_gtk_setting "$settings" gtk-theme-name Adwaita
    set_gtk_setting "$settings" gtk-application-prefer-dark-theme 1
    set_gtk_setting "$settings" gtk-cursor-theme-name Adwaita
    set_gtk_setting "$settings" gtk-cursor-theme-size 24
done

# Nerd Fonts: style.css de Waybar usa "Symbols Nerd Font" para los glifos de los
# módulos (launcher, CPU, memoria, reloj, etc.). Debian no empaqueta Nerd Fonts,
# así que se descarga el paquete oficial de símbolos si no está instalado.
NERD_FONT_DIR="$HOME/.local/share/fonts"
if fc-list : family 2>/dev/null | grep -qi "Symbols Nerd Font"; then
    ok "Symbols Nerd Font ya está instalada."
else
    echo "==> Instalando Symbols Nerd Font (glifos de Waybar)..."
    NERD_TMP="$(mktemp -d)"
    if curl -fsSL -o "$NERD_TMP/symbols.zip" \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip \
        && unzip -oq "$NERD_TMP/symbols.zip" -d "$NERD_TMP"; then
        mkdir -p "$NERD_FONT_DIR"
        cp -f "$NERD_TMP"/SymbolsNerdFont*.ttf "$NERD_FONT_DIR"/
        fc-cache -f "$NERD_FONT_DIR" >/dev/null 2>&1 || true
        ok "Symbols Nerd Font instalada en $NERD_FONT_DIR"
    else
        warn "No se pudo descargar Symbols Nerd Font; los iconos de Waybar se verán como cuadros."
    fi
    rm -rf "$NERD_TMP"
fi

# ------------------------------------------------------------------------------
# 6. Agente polkit de usuario y servicios systemd
# ------------------------------------------------------------------------------
# No se habilita globalmente: el servicio se inicia solo desde autostart.conf
# dentro de la sesión Hyprland, para no interferir con el agente de GNOME.
if [ -f /usr/lib/systemd/user/hyprpolkitagent.service ]; then
    ok "hyprpolkitagent disponible (se inicia desde autostart.conf en Hyprland)."
else
    warn "No se encontró la unidad hyprpolkitagent.service; el agente podría no iniciarse."
fi

# El paquete Debian habilita waybar.service, que arranca con
# graphical-session.target (GNOME) y falla en bucle porque GNOME no soporta
# wlr-layer-shell. Waybar se inicia solo desde autostart.conf en Hyprland,
# esperando los sockets IPC con scripts/start-waybar.sh.
if systemctl --user is-enabled waybar.service 2>/dev/null | grep -qv "masked"; then
    systemctl --user disable --now waybar.service 2>/dev/null || true
    systemctl --user mask waybar.service 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 7. Resultado y próximos pasos
# ------------------------------------------------------------------------------
echo
echo "================================================================="
echo "✔ Perfil Hyprland instalado y configurado."
echo "================================================================="
cat <<EOF

Próximos pasos:
  1. Cerrá sesión y elegí la sesión "Hyprland" en GDM.
  2. Para volver a GNOME, elegí "GNOME" (o "GNOME on Xorg") en GDM.
  3. Verificá el estado con: make verify
  4. Wallpaper opcional: colocá una imagen en
     $CONFIG_HOME/hypr/wallpapers/default.png
     y recargá con $CONFIG_HOME/hypr/scripts/wallpaper.sh

Atajos y gestos principales:
  Super                abrir/cerrar lanzador     Super+D       lanzador (fuzzel)
  Super+Return         terminal (foot)           Super+L       bloquear (hyprlock)
  Super+Shift+Return   terminal con tmux         Super+Q       cerrar ventana
  Alt+Tab              cambiar de ventana        Super+N       notificaciones (swaync)
  Super+grave          scratchpad (terminal)     Super+F1      cheatsheet de atajos
  Super+Shift+V        historial portapapeles    Print         captura + swappy
  3 dedos horizontal   cambiar workspace         3 dedos arriba lanzador (fuzzel)

EOF
