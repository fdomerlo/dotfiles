#!/usr/bin/env bash
# ==============================================================================
# Lista canónica de paquetes y binarios del perfil opcional Hyprland.
# Fuente única compartida por scripts/hyprland.sh, scripts/update.sh,
# scripts/verify.sh y shell/devctl para evitar divergencias.
# ==============================================================================

# Paquetes que en Debian Stable viven en stable-backports.
HYPR_BACKPORTS_PKGS=(
    hyprland
    xdg-desktop-portal-hyprland
    hypridle
    hyprlock
    hyprpolkitagent
    hyprland-guiutils
    hyprpicker
    hyprsunset
    quickshell
)

# Paquetes disponibles en Stable main.
HYPR_MAIN_PKGS=(
    waybar
    fuzzel
    sway-notification-center
    swayosd
    grim
    slurp
    swappy
    wl-clipboard
    cliphist
    swaybg
    brightnessctl
    playerctl
    pipewire-audio
    pipewire-pulse
    wireplumber
    foot
    chafa
    zathura
    zathura-pdf-poppler
    imv
    gnome-keyring
    seahorse
    libsecret-tools
    nautilus
    gnome-calculator
    fd-find
    tesseract-ocr
    tesseract-ocr-spa
    wf-recorder
    pavucontrol
    libnotify-bin
    network-manager-gnome
    network-manager-openvpn
    network-manager-openvpn-gnome
    blueman
    xdg-desktop-portal-gtk
    qt6ct
    qt5ct
    qtwayland5
    xwayland
    adwaita-icon-theme
    gnome-themes-extra
    fonts-jetbrains-mono
    fonts-firacode
    fonts-noto-core
    fonts-font-awesome
    socat
    curl
    unzip
)

# Binarios esenciales esperados en PATH tras instalar el perfil Hyprland.
HYPR_REQUIRED_BINS=(
    Hyprland hyprctl hypridle hyprlock hyprpicker hyprsunset
    waybar fuzzel grim slurp swappy wf-recorder wl-copy cliphist swaybg
    swaync swaync-client swayosd-server swayosd-client
    brightnessctl playerctl wpctl foot zathura imv-wayland seahorse nautilus pavucontrol
    nm-applet blueman-applet qt6ct socat fdfind gnome-calculator tesseract qs
)
