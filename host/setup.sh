#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SUITE=$(bash "$REPO_DIR/scripts/detect-suite.sh" 2>/dev/null || echo "stable")
SUITE_LABEL=$(bash "$REPO_DIR/scripts/detect-suite.sh" --label 2>/dev/null || echo "Stable")

echo "================================================================="
echo "==> [Debian $SUITE_LABEL] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# ------------------------------------------------------------------------------
# 1. Configuración de Repositorios Oficiales según Suite
# ------------------------------------------------------------------------------
if [ "$SUITE" = "stable" ]; then
    echo "==> Configurando repositorios extendidos para Debian Stable (Backports & FastTrack)..."

    # Debian Backports (formato canónico DEB822)
    BACKPORTS_FILE="/etc/apt/sources.list.d/debian-backports.sources"
    DEB_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
    if [ ! -f "$BACKPORTS_FILE" ]; then
        cat > "$BACKPORTS_FILE" << EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: stable-backports
Components: main contrib non-free non-free-firmware
Signed-By: $DEB_KEYRING
EOF
        echo "  ✔ Debian Backports configurado (stable-backports)."
    else
        # Asegurar que no esté deshabilitado
        sed -i '/^Enabled:[[:space:]]*No/d' "$BACKPORTS_FILE" || true
        if [ -f "$DEB_KEYRING" ] && grep -q '^Signed-By:[[:space:]]*$' "$BACKPORTS_FILE"; then
            sed -i "s|^Signed-By:[[:space:]]*$|Signed-By: $DEB_KEYRING|" "$BACKPORTS_FILE"
        fi
    fi

    # Debian FastTrack (paquetes upstream de rápido movimiento para Debian Stable)
    CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || echo "")
    if [ -n "$CODENAME" ]; then
        FASTTRACK_KEYRING="/usr/share/keyrings/fasttrack-archive-keyring.gpg"
        if [ ! -f "$FASTTRACK_KEYRING" ]; then
            if apt-get install -y fasttrack-archive-keyring 2>/dev/null; then
                echo "  ✔ Paquete fasttrack-archive-keyring instalado vía APT."
            else
                echo "  Descargando keyring oficial de Debian FastTrack..."
                curl -fsSL "https://fasttrack.debian.net/debian-fasttrack/pubkey.gpg" | gpg --dearmor -o "$FASTTRACK_KEYRING" 2>/dev/null || true
            fi
        fi

        FASTTRACK_FILE="/etc/apt/sources.list.d/debian-fasttrack.sources"
        if [ -f "$FASTTRACK_KEYRING" ] && [ ! -f "$FASTTRACK_FILE" ]; then
            cat > "$FASTTRACK_FILE" << EOF
Types: deb deb-src
URIs: https://fasttrack.debian.net/debian-fasttrack/
Suites: ${CODENAME}-fasttrack
Components: main contrib
Signed-By: $FASTTRACK_KEYRING
EOF
            echo "  ✔ Debian FastTrack configurado (${CODENAME}-fasttrack)."
        fi
    fi
else
    echo "==> Entorno Debian Testing detectado: gestionando paquetes nativos de upstream..."
    # Si migró desde Stable, purgar FastTrack para prevenir errores 404 o dependencias rotas
    if [ -f "/etc/apt/sources.list.d/debian-fasttrack.sources" ]; then
        echo "  Limpiando debian-fasttrack.sources obsoleto..."
        rm -f "/etc/apt/sources.list.d/debian-fasttrack.sources"
    fi
fi

echo "==> Actualizando repositorios APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ------------------------------------------------------------------------------
# 2. Soporte para AppImage (FUSE 2 para Stable / Fallback Auto-extraíble para Testing)
# ------------------------------------------------------------------------------
APPIMAGE_FUSE_PKGS=()
FUSE2_DISPONIBLE=false

# 1. Comprobar si existe alguna variante de FUSE 2 (Compatible con Debian Stable/Bookworm/Trixie)
for fpkg in libfuse2t64 libfuse2; do
    if apt-cache show "$fpkg" &>/dev/null; then
        APPIMAGE_FUSE_PKGS+=("$fpkg")
        FUSE2_DISPONIBLE=true
        break
    fi
done

# 2. Si no hay FUSE 2 (Como en Debian Testing/Forky), dependemos de fuse3 y del fallback de extracción
if [ "$FUSE2_DISPONIBLE" = false ]; then
    if apt-cache show "fuse3" &>/dev/null; then
        APPIMAGE_FUSE_PKGS+=("fuse3")
    fi
    
    # Configurar el fallback global para AppImages en sistemas sin FUSE 2
    # Esto le dice a los AppImages clásicos que se auto-extraigan y corran usando FUSE 3 de fondo
    if ! grep -q "APPIMAGE_EXTRACT_AND_RUN" /etc/environment 2>/dev/null; then
        echo "Configurando fallback de extracción para AppImages (Debian Testing)..."
        echo "APPIMAGE_EXTRACT_AND_RUN=1" | sudo tee -a /etc/environment > /dev/null
    fi
fi

echo "==> Instalando paquetes base, CLI moderna, soporte Flatpak y AppImage..."
apt-get install -y \
  git curl wget jq unzip zip \
  ca-certificates gnupg lsb-release \
  build-essential \
  ripgrep fd-find fzf bat btop direnv wl-clipboard \
  fonts-firacode fonts-jetbrains-mono fonts-noto-core \
  flatpak gnome-software-plugin-flatpak xdg-desktop-portal-gnome \
  libglib2.0-bin \
  fuse3 "${APPIMAGE_FUSE_PKGS[@]}" \
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
echo "✔ Host setup completado (Debian $SUITE_LABEL + Flatpak + AppImage + Podman Rootless)."
echo "================================================================="
