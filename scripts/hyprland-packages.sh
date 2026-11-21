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

# Paquetes núcleo del stack Hyprland (main en Forky; stable-backports en Stable).
HYPR_BACKPORTS_PKGS=()
read_manifest "$_HYPR_PKG_REPO_DIR/packages/apt-backports.txt" HYPR_BACKPORTS_PKGS

# Utilidades y soporte del escritorio en main.
HYPR_MAIN_PKGS=()
read_manifest "$_HYPR_PKG_REPO_DIR/packages/apt-hyprland.txt" HYPR_MAIN_PKGS

# Binarios esenciales esperados en PATH tras instalar el perfil Hyprland.
HYPR_REQUIRED_BINS=(
    Hyprland hyprctl hypridle hyprlock hyprpicker hyprsunset
    waybar rofi fuzzel grim slurp swappy wf-recorder wl-copy cliphist swaybg
    swaync swaync-client swayosd-server swayosd-client
    brightnessctl playerctl wpctl foot zathura imv-wayland seahorse nautilus pavucontrol
    nm-connection-editor blueman-manager qt6ct socat fdfind gnome-calculator tesseract
)
