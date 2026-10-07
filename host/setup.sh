#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "================================================================="
echo "==> [Debian Trixie] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Actualizando repositorios APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "==> Instalando paquetes base y dependencias de escritorio..."
apt-get install -y \
  git curl wget jq unzip zip \
  ca-certificates gnupg lsb-release \
  build-essential \
  fonts-firacode fonts-noto-core \
  gnome-shell-extension-dash-to-dock \
  libglib2.0-bin \
  uidmap dbus-user-session iptables

echo "==> Configurando repositorio oficial de Docker CE para Debian..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

DEBIAN_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${DEBIAN_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y

echo "==> Instalando Docker CE y complementos Rootless..."
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras

echo "==> Deshabilitando demonio Docker global (forzar modo Rootless por usuario)..."
systemctl disable --now docker.service docker.socket 2>/dev/null || true

echo "==> Habilitando systemd linger para $TARGET_USER..."
loginctl enable-linger "$TARGET_USER"

echo "================================================================="
echo "✔ Host setup completado. Siguiente paso: configurar Docker Rootless."
echo "================================================================="
