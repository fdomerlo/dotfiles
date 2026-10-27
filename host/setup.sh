#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================="
echo "==> [Debian Testing] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# ------------------------------------------------------------------------------
# 1. Configuración de Repositorios Oficiales y Pinning Híbrido (Testing)
# ------------------------------------------------------------------------------
echo "==> Configurando repositorios DEB822 y APT Pinning para [Debian Testing]..."

# 1. Neutralización de /etc/apt/sources.list legacy si contiene líneas activas
if [ -f /etc/apt/sources.list ] && grep -vE '^[[:space:]]*(#|$)' /etc/apt/sources.list >/dev/null 2>&1; then
    echo "  Neutralizando /etc/apt/sources.list legacy (backup en /etc/apt/sources.list.bak)..."
    cp -a /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "# Migrado a DEB822 en /etc/apt/sources.list.d/debian.sources" > /etc/apt/sources.list
fi

# 2. Eliminación defensiva de fuentes exclusivas de Stable si existieran
rm -f /etc/apt/sources.list.d/debian-fasttrack.sources \
      /etc/apt/sources.list.d/debian-backports.sources

# 3. Escritura canónica de /etc/apt/sources.list.d/debian.sources en formato DEB822
mkdir -p /etc/apt/sources.list.d
cat > /etc/apt/sources.list.d/debian.sources << 'EOF'
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: testing testing-updates unstable
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: testing-security stable-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
echo "  ✔ /etc/apt/sources.list.d/debian.sources configurado (DEB822 híbrido)."

# 4. Escritura de /etc/apt/preferences.d/00-testing-pinning.pref
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/00-testing-pinning.pref << 'EOF'
Package: *
Pin: release a=testing
Pin-Priority: 900

Package: *
Pin: release a=testing-security
Pin-Priority: 900

Package: *
Pin: release a=testing-updates
Pin-Priority: 900

Package: *
Pin: release a=stable-security
Pin-Priority: 500

Package: *
Pin: release a=unstable
Pin-Priority: 100
EOF
echo "  ✔ /etc/apt/preferences.d/00-testing-pinning.pref configurado."

echo "==> Actualizando repositorios APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ------------------------------------------------------------------------------
# 2. Soporte para AppImage y Paquetes Base (Filtro "Sieve" para Testing)
# ------------------------------------------------------------------------------
APPIMAGE_FUSE_PKGS=("fuse3")

# Comprobar de forma opcional si libfuse2t64 está disponible en caché
if apt-cache policy libfuse2t64 2>/dev/null | grep -qE "Candidato:|Candidate:" | grep -v "(ninguno\|none)"; then
    APPIMAGE_FUSE_PKGS+=("libfuse2t64")
fi

# Asegurar siempre APPIMAGE_EXTRACT_AND_RUN=1 en /etc/environment
if ! grep -q "^APPIMAGE_EXTRACT_AND_RUN=1" /etc/environment 2>/dev/null; then
    echo "Configurando APPIMAGE_EXTRACT_AND_RUN=1 en /etc/environment..."
    sed -i '/^APPIMAGE_EXTRACT_AND_RUN=/d' /etc/environment 2>/dev/null || true
    echo "APPIMAGE_EXTRACT_AND_RUN=1" >> /etc/environment
fi

echo "==> Instalando paquetes base, guardarraíles Sieve, CLI moderna, soporte Flatpak y AppImage..."
apt-get install -y \
  git curl wget jq unzip zip \
  ca-certificates gnupg lsb-release \
  build-essential \
  apt-listbugs apt-listchanges needrestart \
  ripgrep fd-find fzf bat btop direnv wl-clipboard \
  fonts-firacode fonts-jetbrains-mono fonts-noto-core \
  flatpak gnome-software-plugin-flatpak xdg-desktop-portal-gnome \
  libglib2.0-bin \
  "${APPIMAGE_FUSE_PKGS[@]}" \
  uidmap dbus-user-session iptables

# ------------------------------------------------------------------------------
# 3. Configuración de Flathub para Aplicaciones de Escritorio
# ------------------------------------------------------------------------------
echo "==> Configurando repositorio Flathub (aplicaciones de escritorio)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || \
  echo "  ⚠️ No se pudo registrar Flathub en este momento (verifica conexión de red)."

# ------------------------------------------------------------------------------
# 4. Directorio Dedicado para AppImages y Herramientas Portables
# ------------------------------------------------------------------------------
APPIMAGE_DIR="$USER_HOME/Aplicaciones"
mkdir -p "$APPIMAGE_DIR"
chown "$TARGET_USER:$TARGET_USER" "$APPIMAGE_DIR"
chmod 755 "$APPIMAGE_DIR"

# ------------------------------------------------------------------------------
# 5. Podman y Contenedores Rootless (crun + pasta/passt)
# ------------------------------------------------------------------------------
echo "==> Instalando Podman y herramientas de contenedores (crun + passt/pasta)..."
apt-get install -y \
  podman \
  crun \
  buildah \
  skopeo \
  podman-compose \
  passt \
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
echo "✔ Host setup completado ([Debian Testing] + Flatpak + AppImage + Podman Rootless)."
echo "================================================================="
