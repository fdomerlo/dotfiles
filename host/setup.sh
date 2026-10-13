#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================="
echo "==> [Debian Trixie] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

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
  gnome-shell-extension-dashtodock \
  libglib2.0-bin \
  uidmap dbus-user-session iptables

echo "==> Instalando Podman y herramientas de contenedores..."
apt-get install -y \
  podman \
  buildah \
  skopeo \
  podman-compose \
  slirp4netns \
  catatonit

echo "==> Verificando rangos subuid y subgid para $TARGET_USER..."
if ! grep -q "^${TARGET_USER}:" /etc/subuid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${TARGET_USER}:" /etc/subgid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subgid
fi

echo "==> Habilitando systemd linger para $TARGET_USER..."
loginctl enable-linger "$TARGET_USER"

echo "================================================================="
echo "✔ Host setup completado. Siguiente paso: configurar Podman Rootless."
echo "================================================================="
