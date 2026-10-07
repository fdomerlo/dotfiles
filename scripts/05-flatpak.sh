#!/usr/bin/env bash

set -euo pipefail

echo "==> Configuring Flatpak and installing user-scope apps..."

# Configure Flathub remote in user mode
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> Installing core developer graphical utilities via Flatpak (user scope)..."

FLATPAK_APPS=(
    com.visualstudio.code
    io.dbeaver.DBeaverCommunity
)

for app in "${FLATPAK_APPS[@]}"; do
    echo "Installing $app..."
    flatpak install --user -y flathub "$app"
done

echo "==> Flatpak setup complete."
