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

# Paquetes que en Debian Stable viven en stable-backports.
BACKPORTS_PKGS=(
    hyprland
    xdg-desktop-portal-hyprland
    hyprpaper
    hypridle
    hyprlock
    hyprpolkitagent
    hyprland-guiutils
)

# Paquetes disponibles en Stable main.
MAIN_PKGS=(
    waybar
    wofi
    mako-notifier
    grim
    slurp
    wl-clipboard
    cliphist
    swaybg
    brightnessctl
    playerctl
    pipewire-audio
    pipewire-pulse
    wireplumber
    kitty
    nautilus
    pavucontrol
    libnotify-bin
    network-manager-gnome
    blueman
    xdg-desktop-portal-gtk
    qt6ct
    qt5ct
    qtwayland5
    xwayland
    adwaita-icon-theme
    papirus-icon-theme
    bibata-cursor-theme
    gnome-themes-extra
    fonts-jetbrains-mono
    fonts-firacode
    fonts-noto-core
    fonts-font-awesome
)

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
REQUIRED_BINS=(
    Hyprland hyprctl hyprpaper hypridle hyprlock
    waybar wofi mako grim slurp wl-copy cliphist swaybg
    brightnessctl playerctl wpctl kitty nautilus pavucontrol
    nm-applet blueman-applet qt6ct
)
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
for f in "$HYPR_SRC"/conf/*.conf; do
    link_file "$f" "$CONFIG_HOME/hypr/conf/$(basename "$f")"
done
for f in "$HYPR_SRC"/hypridle.conf "$HYPR_SRC"/hyprlock.conf "$HYPR_SRC"/hyprpaper.conf; do
    link_file "$f" "$CONFIG_HOME/hypr/$(basename "$f")"
done
for f in "$HYPR_SRC"/scripts/*.sh; do
    link_file "$f" "$CONFIG_HOME/hypr/scripts/$(basename "$f")"
done
for f in "$HYPR_SRC"/waybar/*; do
    link_file "$f" "$CONFIG_HOME/waybar/$(basename "$f")"
done
for f in "$HYPR_SRC"/wofi/*; do
    link_file "$f" "$CONFIG_HOME/wofi/$(basename "$f")"
done
link_file "$HYPR_SRC/mako/config" "$CONFIG_HOME/mako/config"

mkdir -p "$CONFIG_HOME/hypr/wallpapers"
if [ -f "$HYPR_SRC/wallpapers/default.png" ]; then
    link_file "$HYPR_SRC/wallpapers/default.png" "$CONFIG_HOME/hypr/wallpapers/default.png"
fi
ok "Directorio de wallpapers: $CONFIG_HOME/hypr/wallpapers"

if [ ! -d /usr/share/icons/Bibata-Modern-Ice ]; then
    warn "El tema de cursor 'Bibata-Modern-Ice' no está presente; Hyprland usará el cursor por defecto."
fi

# ------------------------------------------------------------------------------
# 6. Agente polkit de usuario
# ------------------------------------------------------------------------------
# No se habilita globalmente: el servicio se inicia solo desde autostart.conf
# dentro de la sesión Hyprland, para no interferir con el agente de GNOME.
if [ -f /usr/lib/systemd/user/hyprpolkitagent.service ]; then
    ok "hyprpolkitagent disponible (se inicia desde autostart.conf en Hyprland)."
else
    warn "No se encontró la unidad hyprpolkitagent.service; el agente podría no iniciarse."
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

Atajos principales:
  Super+Return  terminal (kitty)      Super+D       lanzador (wofi)
  Super+Q       cerrar ventana        Super+L       bloquear (hyprlock)
  Super+Shift+V historial portapapeles
  Print         captura de región     Shift+Print   captura completa

EOF
