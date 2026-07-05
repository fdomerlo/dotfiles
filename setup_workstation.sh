#!/bin/bash
# ==============================================================================
# setup_workstation.sh
# Ejecución básica:
# curl -fsSL https://raw.githubusercontent.com/fdomerlo/dotfiles/main/setup_workstation.sh | bash
# Ejecución con flags de GNOME:
# curl -fsSL <URL> | bash -s -- --full
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
_log() { echo -e "\n${BLUE}==> $1${NC}"; }
_success() { echo -e "${GREEN}✅ $1${NC}"; }

if [ "$EUID" -eq 0 ]; then
    echo -e "\n\033[0;31m[ERROR]\033[0m No ejecutes este script como root. Ejecútalo con tu usuario normal."
    exit 1
fi

# ==============================================================================
# PARSEO DE ARGUMENTOS (FLAGS)
# ==============================================================================
INSTALL_FULL_DESKTOP=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --full) INSTALL_FULL_DESKTOP=true ;;
        *) echo -e "\033[0;31m[ERROR]\033[0m Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# Variable crítica para repositorios DEB822
ARCH=$(dpkg --print-architecture)

# Usuario de GitHub para el clone de dotfiles (independiente del $USER local,
# por si algún día provisionás con un username de sistema distinto)
GITHUB_USER="fdomerlo"

_log "Solicitando privilegios de administrador para la instalación..."
sudo -v

_log "Iniciando aprovisionamiento del entorno..."

# ------------------------------------------------------------------------------
# 1. PAQUETES BASE (todo lo que vive en los repos oficiales de Debian)
# ------------------------------------------------------------------------------
# Se instala todo esto en una sola pasada. curl/gnupg/wget quedan disponibles
# acá porque la sección 2 los necesita para agregar los repos de terceros;
# el resto simplemente viaja gratis en la misma llamada.
_log "Instalando paquetes base..."
BASE_PKGS=(
    zram-tools curl wget git zip unzip stow gnupg htop zsh 
    gnome-boxes dconf-editor devhelp sysprof flatpak
)
sudo apt-get update -qq
sudo apt-get install -y "${BASE_PKGS[@]}"
_success "Paquetes base instalados."

# ------------------------------------------------------------------------------
# 2. MEMORIA VIRTUAL (zRam + Swapfile fallback)
# ------------------------------------------------------------------------------
_log "Configurando zRam y Swapfile fallback..."

echo -e "ALGO=zstd\nPERCENT=50\nPRIORITY=100" | sudo tee /etc/default/zramswap > /dev/null
sudo systemctl restart zramswap.service

# El swapfile va en /home (Ext4), NO en / (Btrfs). Un swapfile sobre Btrfs
# necesita NOCOW (chattr +C) aplicado antes de escribir cualquier byte, sin
# compresión y sin cruzar subvolúmenes — si no, swapon falla o el archivo
# queda corrupto por el copy-on-write. Ext4 no tiene ninguna de estas
# restricciones, así que el método clásico funciona sin tocar nada más.
SWAPFILE="/home/.swapfile"
if [ ! -f "$SWAPFILE" ]; then
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=4096 status=progress
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
    sudo swapon "$SWAPFILE"
    echo "$SWAPFILE none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab > /dev/null
fi
_success "Memoria virtual optimizada."

# ------------------------------------------------------------------------------
# 3. REPOSITORIOS DE TERCEROS (Orden estricto)
# ------------------------------------------------------------------------------
_log "Configurando repositorios..."
sudo install -m 0755 -d /etc/apt/keyrings

# Docker (Con Fallback SRE dinámico)
DOCKER_CODENAME="trixie"
if ! curl -fsSL "https://download.docker.com/linux/debian/dists/$DOCKER_CODENAME/" 2>/dev/null | grep -q "stable"; then
    _log "Repo Docker para '$DOCKER_CODENAME' no disponible aún. Usando 'bookworm' (Fallback)..."
    DOCKER_CODENAME="bookworm"
fi

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo -e "Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: $DOCKER_CODENAME\nComponents: stable\nArchitectures: $ARCH\nSigned-By: /etc/apt/keyrings/docker.gpg" | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg
echo -e "Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: $ARCH\nSigned-By: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null

# Mozilla (Firefox Developer Edition)
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo gpg --yes --dearmor -o /etc/apt/keyrings/packages.mozilla.org.gpg
echo -e "Types: deb\nURIs: https://packages.mozilla.org/apt\nSuites: mozilla\nComponents: main\nSigned-By: /etc/apt/keyrings/packages.mozilla.org.gpg" | sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null
echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo -e "Types: deb\nURIs: https://cli.github.com/packages\nSuites: stable\nComponents: main\nArchitectures: $ARCH\nSigned-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg" | sudo tee /etc/apt/sources.list.d/github-cli.sources > /dev/null

# DBeaver
curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/dbeaver.gpg
echo -e "Types: deb\nURIs: https://dbeaver.io/debs/dbeaver-ce\nSuites: /\nSigned-By: /etc/apt/keyrings/dbeaver.gpg" | sudo tee /etc/apt/sources.list.d/dbeaver.sources > /dev/null

# Google Chrome
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo -e "Types: deb\nURIs: http://dl.google.com/linux/chrome/deb/\nSuites: stable\nComponents: main\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/google-chrome.gpg" | sudo tee /etc/apt/sources.list.d/google-chrome.sources > /dev/null

_success "Repositorios inyectados."

# ------------------------------------------------------------------------------
# 4. PAQUETES DE REPOS DE TERCEROS
# ------------------------------------------------------------------------------
_log "Instalando paquetes de repos de terceros..."
REPO_PKGS=(
    gh code dbeaver-ce
    google-chrome-stable firefox-devedition firefox-devedition-l10n-es-ar
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
)
sudo apt-get update -qq
sudo apt-get install -y "${REPO_PKGS[@]}"
_success "Paquetes de terceros instalados."

# ------------------------------------------------------------------------------
# 4.1. RELOCACIÓN DE DOCKER DATA-ROOT (Btrfs / -> Ext4 /home)
# ------------------------------------------------------------------------------
# El paquete docker-ce arranca el servicio automáticamente al instalarse
# (systemd preset de Debian), así que primero lo frenamos para que no
# alcance a crear /var/lib/docker sobre Btrfs con la config default.
_log "Reubicando docker data-root fuera de Btrfs (evitar penalización CoW)..."
sudo systemctl stop docker.service docker.socket 2>/dev/null || true

DOCKER_DATA_ROOT="/home/docker-data"
sudo mkdir -p "$DOCKER_DATA_ROOT"
sudo chown root:root "$DOCKER_DATA_ROOT"
sudo chmod 711 "$DOCKER_DATA_ROOT"

sudo install -d /etc/docker
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi
echo "{\"data-root\": \"$DOCKER_DATA_ROOT\"}" | sudo tee /etc/docker/daemon.json > /dev/null

# Si el postinst del paquete ya escribió algo en la ubicación default
# (fresco, no debería tener imágenes, pero puede tener metadata de init),
# lo migramos en vez de perderlo silenciosamente.
if [ -d /var/lib/docker ] && [ -n "$(sudo ls -A /var/lib/docker 2>/dev/null)" ]; then
    sudo cp -a /var/lib/docker/. "$DOCKER_DATA_ROOT/"
    sudo rm -rf /var/lib/docker
fi
_success "docker data-root -> $DOCKER_DATA_ROOT"

_log "Inyectando repositorio Flathub de manera incondicional..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker.service
sudo chsh -s "$(which zsh)" "$USER"

_log "Verificando docker data-root efectivo..."
sudo docker info --format '{{.DockerRootDir}}' 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4.5. APLICACIONES DEL ECOSISTEMA GNOME (Condicionales)
# ------------------------------------------------------------------------------
if [ "$INSTALL_FULL_DESKTOP" = true ]; then
    _log "[FULL DESKTOP] Instalando aplicaciones de escritorio (Flatpak)..."
    sudo flatpak install -y --noninteractive flathub \
        org.gimp.GIMP \
        org.inkscape.Inkscape \
        net.nokyan.Resources \
        de.haeckerfelix.Fragments
    _success "Apps del Círculo instaladas."
fi

# ------------------------------------------------------------------------------
# 5. OH MY ZSH, GITOPS & DOTFILES
# ------------------------------------------------------------------------------
_log "Instalando Oh My Zsh y configurando GitOps..."

# 1. Instalar Oh My Zsh silenciosamente
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    # 2. Descargar plugins esenciales
    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions" > /dev/null 2>&1 || true
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" > /dev/null 2>&1 || true

    # 3. Eliminar el archivo genérico para evitar conflictos con GNU Stow
    rm -f "$HOME/.zshrc"
fi

# 4. Desplegar configuraciones propias
if [ ! -d "$HOME/.dotfiles" ]; then
    mkdir -p "$HOME/.local/share"
    git clone "https://github.com/${GITHUB_USER}/dotfiles.git" "$HOME/.dotfiles"
fi
# Restow siempre (no solo en el primer clone): si una corrida anterior falló
# entre el clone y el stow, esto re-simboliza sin dejar el estado a medias.
cd "$HOME/.dotfiles"
stow -R configs fonts
_success "Oh My Zsh y Dotfiles instalados y enlazados."

# ------------------------------------------------------------------------------
# 6. RUNTIMES LOCALES
# ------------------------------------------------------------------------------
_log "Instalando runtimes (uv, fnm, sdkman)..."
mkdir -p "$HOME/.local/bin"

env ZDOTDIR="/tmp" curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
curl -s "https://get.sdkman.io?rcupdate=false" | bash

_success "Runtimes listos."

# ------------------------------------------------------------------------------
# 7. CONFIGURACIÓN DE GNOME Y TIPOGRAFÍAS
# ------------------------------------------------------------------------------
_log "Configurando GNOME..."
fc-cache -f -v > /dev/null

gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false

gsettings set org.gnome.desktop.interface font-name 'Google Sans 11'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Mono 11'

PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')
if [ -n "$PROFILE" ]; then
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles/${PROFILE}/ use-system-font false
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles/${PROFILE}/ font 'Fira Mono 11'
fi

_success "Instalación completada. Por favor, cierra sesión o reinicia el equipo para aplicar todos los cambios de Docker y Zsh."