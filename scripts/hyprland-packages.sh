#!/usr/bin/env bash
# ==============================================================================
# Lista canónica de paquetes y binarios del escritorio Hyprland.
# Fuente única compartida por scripts/hyprland.sh, scripts/update.sh,
# scripts/verify.sh y shell/devctl para evitar divergencias.
# Los listados APT se leen desde packages/apt-backports.txt y
# packages/apt-hyprland.txt.
# ==============================================================================

_HYPR_PKG_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/packages.sh
source "$_HYPR_PKG_REPO_DIR/scripts/lib/packages.sh"

# Paquetes que en Debian Stable viven en stable-backports.
HYPR_BACKPORTS_PKGS=()
read_manifest "$_HYPR_PKG_REPO_DIR/packages/apt-backports.txt" HYPR_BACKPORTS_PKGS

# Paquetes disponibles en Stable main.
HYPR_MAIN_PKGS=()
read_manifest "$_HYPR_PKG_REPO_DIR/packages/apt-hyprland.txt" HYPR_MAIN_PKGS

# Binarios esenciales esperados en PATH tras instalar el perfil Hyprland.
HYPR_REQUIRED_BINS=(
    Hyprland hyprctl hypridle hyprlock hyprpicker hyprsunset
    waybar fuzzel grim slurp swappy wf-recorder wl-copy cliphist swaybg
    swaync swaync-client swayosd-server swayosd-client
    brightnessctl playerctl wpctl foot zathura imv-wayland seahorse nautilus pavucontrol
    nm-applet blueman-applet qt6ct socat fdfind gnome-calculator tesseract qs
)
