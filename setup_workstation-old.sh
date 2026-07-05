#!/bin/bash
# ==============================================================================
# setup_workstation.sh
# Propósito: Aprovisionamiento de nodo efímero (Debian 12 Stable).
# Stack: zRam, Docker, Python (uv), Node (fnm), GNOME UI, GitOps (Dotfiles).
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
_log() { echo -e "\n${BLUE}==> $1${NC}"; }
_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Variables de entorno
TARGET_USER="fdomerlo" # Debe coincidir con el usuario del Preseed
USER_HOME="/home/$TARGET_USER"
ARCH=$(dpkg --print-architecture)

_log "Iniciando aprovisionamiento del nodo de trabajo..."

# 1. OPTIMIZACIÓN DE MEMORIA (zRam + Swapfile)
_log "Configurando zRam y Swapfile fallback..."
apt-get install -y zram-tools
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl restart zramswap.service

if [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw,pri=10 0 0" >> /etc/fstab
fi
_success "Memoria virtual optimizada."

# 2. REPOSITORIOS DE TERCEROS (DEB822)
_log "Configurando repositorios (VS Code, Docker, GitHub CLI, Antigravity)..."
install -m 0755 -d /etc/apt/keyrings

# Docker (Apuntando a Trixie / Stable)
if [ ! -f /etc/apt/sources.list.d/docker.sources ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    cat <<EOF > /etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: stable
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.gpg
EOF
    _success "Repo: Docker configurado."
fi

# Visual Studio Code
if [ ! -f /etc/apt/sources.list.d/vscode.sources ]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg
    cat <<EOF > /etc/apt/sources.list.d/vscode.sources
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
    _success "Repo: VS Code configurado."
fi

# GitHub CLI
if [ ! -f /etc/apt/sources.list.d/github-cli.sources ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --yes --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
    cat <<EOF > /etc/apt/sources.list.d/github-cli.sources
Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg
EOF
    _success "Repo: GitHub CLI configurado."
fi

# DBeaver
if [ ! -f /etc/apt/sources.list.d/dbeaver.sources ]; then
    curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | gpg --yes --dearmor -o /etc/apt/keyrings/dbeaver.gpg
    cat <<EOF > /etc/apt/sources.list.d/dbeaver.sources
Types: deb
URIs: https://dbeaver.io/debs/dbeaver-ce
Suites: /
Signed-By: /etc/apt/keyrings/dbeaver.gpg
EOF
    _success "Repo: DBeaver configurado."
fi

# Google Chrome
if [ ! -f /etc/apt/sources.list.d/google-chrome.sources ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    cat <<EOF > /etc/apt/sources.list.d/google-chrome.sources
Types: deb
URIs: http://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.gpg
EOF
    _success "Repo: Google Chrome configurado."
fi

# Firefox Developer Edition
if [ ! -f /etc/apt/sources.list.d/mozilla.sources ]; then
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
    cat <<EOF | sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
    _success "Repo: Firefox configurado."
fi

_success "Repositorios configurados."

# 3. INSTALACIÓN DE HERRAMIENTAS CORE
_log "Instalando stack de ingeniería (Agnóstico de DB local)..."
apt-get update -qq
DEV_PKGS=(
    git curl wget unzip zip htop stow
    code gh antigravity google-chrome-stable firefox-devedition firefox-devedition-l10n-es-ar
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    gnome-shell-extension-manager gnome-shell-extension-dashtodock flatpak
)
apt-get install -y "${DEV_PKGS[@]}"

# Flatpaks
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
_success "Herramientas del sistema instaladas."

# 4. RUNTIMES Y PERMISOS DEL USUARIO
_log "Configurando entornos de desarrollo para $TARGET_USER..."

# Docker sin sudo
usermod -aG docker "$TARGET_USER"

# Instalar uv (Python)
_log "Verificando uv (Python)..."
if ! sudo -u "$TARGET_USER" env HOME="$USER_HOME" sh -c "command -v uv" &> /dev/null; then
    sudo -u "$TARGET_USER" env HOME="$USER_HOME" sh -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
    _success "uv instalado."
else
    _success "uv ya estaba instalado. Omitiendo red."
fi

# Instalar fnm (Node.js)
_log "Verificando fnm (Node.js)..."
if ! sudo -u "$TARGET_USER" env HOME="$USER_HOME" sh -c "command -v fnm" &> /dev/null; then
    sudo -u "$TARGET_USER" env HOME="$USER_HOME" sh -c "curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir \"$USER_HOME/.local/bin\" --skip-shell"
    _success "fnm instalado."
else
    _success "fnm ya estaba instalado. Omitiendo red."
fi

# SDKMAN (Java/Scala/Kotlin)
# Nota Sysadmin: SDKMAN requiere explícitamente 'bash', no 'sh'
if [ ! -d "$USER_HOME/.sdkman" ]; then
    sudo -u "$TARGET_USER" env HOME="$USER_HOME" bash -c "curl -s \"https://get.sdkman.io\" | bash"
fi

_success "Runtimes (uv, fnm, sdkman) instalados correctamente."

# 5. GITOPS: RECUPERACIÓN DEL ENTORNO (El reemplazo del /home persistente)
_log "Desplegando Dotfiles del usuario..."
chsh -s "$(which zsh)" "$TARGET_USER"

# Clonar repositorio de configuraciones
if [ ! -d "$USER_HOME/.dotfiles" ]; then
    sudo -u "$TARGET_USER" env HOME="$USER_HOME" git clone https://github.com/$TARGET_USER/dotfiles.git "$USER_HOME/.dotfiles"
    
    # Usar GNU Stow para enlazar limpiamente zsh, tmux, etc.
    sudo -u "$TARGET_USER" env HOME="$USER_HOME" sh -c "cd $USER_HOME/.dotfiles && stow zsh tmux git"
fi
_success "Entorno personal restaurado vía GitOps."

_log "Actualizando caché de tipografías..."
sudo -u "$TARGET_USER" fc-cache -f -v > /dev/null
_success "Caché de fuentes actualizada."

# 6. GNOME UI (Dash to Dock)
_log "Configurando estética de GNOME..."
sudo -u "$TARGET_USER" dbus-launch gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Mono 11'
sudo -u "$TARGET_USER" dbus-launch gnome-extensions enable dash-to-dock@micxgx.gmail.com || true
sudo -u "$TARGET_USER" dbus-launch gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' || true
sudo -u "$TARGET_USER" dbus-launch gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false || true
_success "GNOME configurado."

_success "NODO DE INGENIERÍA APROVISIONADO. Listo para reboot."
