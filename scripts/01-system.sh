#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating APT repositories..."
sudo apt-get update -y

echo "==> Installing core utilities..."
CORE_PKGS=(
    build-essential
    curl
    wget
    git
    zsh
    flatpak
    fontconfig
    jq
    unzip
    ca-certificates
    libssl-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    libsqlite3-dev
    libffi-dev
)
sudo apt-get install -y "${CORE_PKGS[@]}"

echo "==> Installing firmware and Mesa GPU packages for AMD..."
AMD_PKGS=(
    firmware-amd-graphics
    libgl1-mesa-dri
    mesa-vulkan-drivers
)
sudo apt-get install -y "${AMD_PKGS[@]}"

echo "==> Configuring systemd-zram-generator..."
sudo apt-get install -y systemd-zram-generator

if [ ! -f /etc/systemd/zram-generator.conf ]; then
    echo "==> Creating /etc/systemd/zram-generator.conf..."
    cat <<EOF | sudo tee /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
fi
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service || true

echo "==> Configuring zRAM sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/99-zram.conf
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
sudo sysctl --system

echo "==> Configuring fallback swapfile..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    echo "/swapfile none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab
    sudo swapon -a
else
    echo "/swapfile already exists."
fi

echo "==> Enabling fstrim.timer..."
sudo systemctl enable --now fstrim.timer

echo "==> System setup complete."
