#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================="
echo "==> [Debian Stable] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# ------------------------------------------------------------------------------
# 1. Repositorios extendidos de Debian Stable (Backports)
# ------------------------------------------------------------------------------
echo "==> Configurando repositorios extendidos para Debian Stable (Backports)..."

# Escribe $file solo si su contenido difiere de $content (convergencia idempotente).
write_if_changed() {
    local file="$1"
    local content="$2"
    if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
        printf '%s\n' "$content" > "$file"
        return 0
    fi
    return 1
}

# Debian Backports (formato canónico DEB822), solo si el sistema es Debian Stable.
# La coma final evita confundir 'stable' con 'stable-backports' en apt-cache policy.
# Fallback: en una instalación recién hecha puede no haber listas APT todavía;
# /etc/debian_version numérico (p. ej. 13.1) identifica una release estable.
IS_STABLE=false
if command -v apt-cache &>/dev/null && apt-cache policy 2>/dev/null | grep -q 'o=Debian,a=stable,'; then
    IS_STABLE=true
elif [ -r /etc/debian_version ] && grep -qE '^[0-9]+\.[0-9]+' /etc/debian_version; then
    IS_STABLE=true
fi

if [ "$IS_STABLE" = true ]; then
    BACKPORTS_FILE="/etc/apt/sources.list.d/debian-backports.sources"
    DEB_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
    BACKPORTS_CONTENT=$(cat << EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: stable-backports
Components: main contrib non-free non-free-firmware
Signed-By: $DEB_KEYRING
EOF
)
    if write_if_changed "$BACKPORTS_FILE" "$BACKPORTS_CONTENT"; then
        echo "  ✔ Debian Backports configurado (stable-backports)."
    else
        echo "  ✔ Debian Backports ya actualizado (stable-backports)."
    fi
else
    echo "  ⚠️ No se detectó Debian Stable; se omite Backports."
    echo "     Este repositorio solo soporta configuraciones para Debian Stable."
fi

echo "==> Actualizando repositorios APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ------------------------------------------------------------------------------
# 2. Soporte para AppImage (FUSE 2 nativo / Fallback Auto-extraíble)
# ------------------------------------------------------------------------------
APPIMAGE_FUSE_PKGS=()
FUSE2_DISPONIBLE=false

# Devuelve 0 si el paquete tiene un candidato de instalación real.
has_apt_candidate() {
    local candidate
    candidate=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidato:|Candidate:/ {print; exit}')
    [ -n "$candidate" ] && ! printf '%s\n' "$candidate" | grep -qE '\(ninguno|\(none'
}

# 1. Comprobar si existe un candidato de instalación real para FUSE 2
for fpkg in libfuse2t64 libfuse2; do
    if has_apt_candidate "$fpkg"; then
        APPIMAGE_FUSE_PKGS+=("$fpkg")
        FUSE2_DISPONIBLE=true
        break
    fi
done

# 2. Si no hay FUSE 2, dependemos de fuse3 y del fallback de extracción
if [ "$FUSE2_DISPONIBLE" = false ]; then
    # Verificamos si existe fuse3 (estándar moderno)
    if has_apt_candidate "fuse3"; then
        APPIMAGE_FUSE_PKGS+=("fuse3")
    fi

    # Configurar el fallback global para AppImages en sistemas sin FUSE 2
    if ! grep -q "APPIMAGE_EXTRACT_AND_RUN" /etc/environment 2>/dev/null; then
        echo "Configurando fallback de extracción para AppImages..."
        echo "APPIMAGE_EXTRACT_AND_RUN=1" | tee -a /etc/environment > /dev/null
    fi
fi

echo "==> Preconfigurando Wireshark para captura de paquetes sin root..."
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

echo "==> Instalando paquetes base, CLI moderna, sysadmin, soporte Flatpak y AppImage..."
apt-get install -y \
  git curl wget jq unzip zip \
  ca-certificates gnupg lsb-release \
  build-essential \
  ripgrep fd-find fzf bat btop direnv wl-clipboard chafa \
  zoxide atuin starship tmux \
  zathura zathura-pdf-poppler imv \
  gnome-keyring seahorse libsecret-tools \
  remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret \
  wireshark tshark \
  fonts-firacode fonts-jetbrains-mono fonts-noto-core \
  flatpak gnome-software-plugin-flatpak xdg-desktop-portal-gnome \
  libglib2.0-bin \
  fuse3 "${APPIMAGE_FUSE_PKGS[@]}" \
  uidmap dbus-user-session iptables

if getent group wireshark >/dev/null 2>&1; then
    usermod -aG wireshark "$TARGET_USER" || true
fi

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
echo "✔ Host setup completado (Debian Stable + Backports + Flatpak + AppImage + Podman Rootless)."
echo "================================================================="
