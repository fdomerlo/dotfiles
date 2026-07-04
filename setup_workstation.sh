#!/bin/bash
# ==============================================================================
# setup_workstation.sh
# Ejecución básica: 
# curl -fsSL https://raw.githubusercontent.com/.../setup_workstation.sh | bash
# Ejecución con flags de GNOME:
# curl -fsSL <URL> | bash -s -- --gnome-core --gnome-dev --gnome-circle
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
INSTALL_GNOME_CORE=false
INSTALL_GNOME_DEV=false
INSTALL_GNOME_CIRCLE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gnome-core) INSTALL_GNOME_CORE=true ;;
        --gnome-dev) INSTALL_GNOME_DEV=true ;;
        --gnome-circle) INSTALL_GNOME_CIRCLE=true ;;
        --all-gnome) INSTALL_GNOME_CORE=true; INSTALL_GNOME_DEV=true; INSTALL_GNOME_CIRCLE=true ;;
        *) echo -e "\033[0;31m[ERROR]\033[0m Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# Variable crítica para repositorios DEB822
ARCH=$(dpkg --print-architecture)

_log "Solicitando privilegios de administrador para la instalación..."
sudo -v

_log "Iniciando aprovisionamiento del entorno..."

# ------------------------------------------------------------------------------
# 1. MEMORIA VIRTUAL (zRam + Swapfile)
# ------------------------------------------------------------------------------
_log "Configurando zRam y Swapfile fallback..."
sudo apt-get update -qq
sudo apt-get install -y zram-tools curl wget git zip unzip stow gnupg fonts-noto gnome-terminal

echo -e "ALGO=zstd\nPERCENT=50\nPRIORITY=100" | sudo tee /etc/default/zramswap > /dev/null
sudo systemctl restart zramswap.service

if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab > /dev/null
fi
_success "Memoria virtual optimizada."

# ------------------------------------------------------------------------------
# 2. REPOSITORIOS (Orden estricto)
# ------------------------------------------------------------------------------
_log "Configurando repositorios..."
sudo install -m 0755 -d /etc/apt/keyrings

# Backports
echo -e "Types: deb deb-src\nURIs: http://deb.debian.org/debian\nSuites: trixie-backports\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg" | sudo tee /etc/apt/sources.list.d/backports.sources > /dev/null
sudo apt-get update -qq

# Fasttrack
sudo apt-get install -y fasttrack-archive-keyring
echo -e "Types: deb\nURIs: https://fasttrack.debian.net/debian\nSuites: trixie-fasttrack trixie-backports-fasttrack\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/fasttrack-archive-keyring.gpg" | sudo tee /etc/apt/sources.list.d/fasttrack.sources > /dev/null

# Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo -e "Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: trixie\nComponents: stable\nArchitectures: $ARCH\nSigned-By: /etc/apt/keyrings/docker.gpg" | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

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
# 3. INSTALACIÓN DE HERRAMIENTAS BASE Y FLATHUB
# ------------------------------------------------------------------------------
_log "Instalando paquetes base..."
sudo apt-get update -qq
DEV_PKGS=(
    htop zsh gh code dbeaver-ce google-chrome-stable
    firefox-devedition firefox-devedition-l10n-es-ar
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    gnome-shell-extension-manager gnome-shell-extension-dashtodock flatpak
)
sudo apt-get install -y "${DEV_PKGS[@]}"

_log "Inyectando repositorio Flathub de manera incondicional..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker.service
sudo chsh -s "$(which zsh)" "$USER"

# ------------------------------------------------------------------------------
# 3.5. APLICACIONES DEL ECOSISTEMA GNOME (Condicionales)
# ------------------------------------------------------------------------------
if [ "$INSTALL_GNOME_CORE" = true ]; then
    _log "[GNOME NÚCLEO] Instalando aplicaciones oficiales (deb)..."
    sudo apt-get install -y gnome-text-editor gnome-calculator gnome-calendar \
                            gnome-system-monitor evince loupe gnome-disk-utility \
                            gnome-weather gnome-clocks gnome-maps baobab
    _success "Apps del Núcleo instaladas."
fi

if [ "$INSTALL_GNOME_DEV" = true ]; then
    _log "[GNOME DESARROLLO] Instalando herramientas de ingeniería (deb)..."
    sudo apt-get install -y gnome-builder dconf-editor devhelp sysprof
    _success "Apps de Desarrollo instaladas."
fi

if [ "$INSTALL_GNOME_CIRCLE" = true ]; then
    _log "[GNOME CÍRCULO] Instalando aplicaciones del Círculo (Flatpak)..."
    # Autenticador (2FA), Dialect (Traducción), Fragments (Torrents), Flatseal (Permisos)
    sudo flatpak install -y --noninteractive flathub \
        com.belmoussaoui.Authenticator \
        app.drey.Dialect \
        de.haeckerfelix.Fragments \
        com.github.tchx84.Flatseal
    _success "Apps del Círculo instaladas."
fi

# ------------------------------------------------------------------------------
# 4. OH MY ZSH, GITOPS & DOTFILES
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
    git clone https://github.com/$USER/dotfiles.git "$HOME/.dotfiles"
    cd "$HOME/.dotfiles"
    stow configs fonts
fi
_success "Oh My Zsh y Dotfiles instalados y enlazados."

# ------------------------------------------------------------------------------
# 5. RUNTIMES LOCALES
# ------------------------------------------------------------------------------
_log "Instalando runtimes (uv, fnm, sdkman)..."
mkdir -p "$HOME/.local/bin"

env ZDOTDIR="/tmp" curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
curl -s "https://get.sdkman.io?rcupdate=false" | bash

_success "Runtimes listos."

# ------------------------------------------------------------------------------
# 6. CONFIGURACIÓN DE GNOME Y TIPOGRAFÍAS
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
