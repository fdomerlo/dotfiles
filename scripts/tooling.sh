#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

echo "================================================================="
echo "==> Instalando navegadores y editores (VS Code, Chrome, Zed, Neovim)..."
echo "================================================================="

# 1. Visual Studio Code (APT Oficial en formato canónico DEB822 para Debian)
if [ ! -f "/etc/apt/sources.list.d/vscode.sources" ] && [ ! -f "/etc/apt/sources.list.d/vscode.list" ]; then
    echo "==> Configurando repositorio oficial de Microsoft VS Code (DEB822)..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg
    sudo chmod a+r /etc/apt/keyrings/packages.microsoft.gpg
    sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /etc/apt/keyrings/packages.microsoft.gpg
EOF
    sudo apt-get update -y
fi

if ! command -v code &> /dev/null; then
    echo "Instalando Visual Studio Code..."
    sudo apt-get install -y code
else
    echo "✔ Visual Studio Code ya está instalado"
fi

# 2. Google Chrome Stable
if ! command -v google-chrome &> /dev/null; then
    echo "==> Instalando Google Chrome Stable..."
    CHROME_DEB="/tmp/google-chrome-stable_current_amd64.deb"
    curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$CHROME_DEB"
    sudo apt-get install -y "$CHROME_DEB" || {
        echo "Corrigiendo dependencias para Chrome..."
        sudo apt-get install -f -y
    }
    rm -f "$CHROME_DEB"
    echo "✔ Google Chrome instalado"
else
    echo "✔ Google Chrome ya está instalado"
fi

# 3. Zed Editor (Instalación nativa oficial de usuario)
if ! command -v zed &> /dev/null && [ ! -f "$HOME/.local/bin/zed" ]; then
    echo "==> Instalando Zed Editor..."
    curl -f https://zed.dev/install.sh | sh
    echo "✔ Zed instalado en ~/.local/bin/zed"
else
    echo "✔ Zed ya está instalado"
fi

# 4. Neovim (Editor de terminal extensible en espacio de usuario / APT)
if ! command -v nvim &> /dev/null && [ ! -f "$HOME/.local/bin/nvim" ]; then
    echo "==> Instalando Neovim..."
    DET_ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [ "$DET_ARCH" = "amd64" ] || [ "$DET_ARCH" = "x86_64" ]; then
        NVIM_ARCH="x86_64"
    elif [ "$DET_ARCH" = "arm64" ] || [ "$DET_ARCH" = "aarch64" ]; then
        NVIM_ARCH="arm64"
    else
        NVIM_ARCH=""
    fi

    if [ -n "$NVIM_ARCH" ]; then
        mkdir -p "$HOME/.local/share" "$HOME/.local/bin"
        TMP_DIR=$(mktemp -d)
        curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" -o "$TMP_DIR/nvim.tar.gz"
        tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"
        rm -rf "$HOME/.local/share/neovim"
        mv "$TMP_DIR/nvim-linux-${NVIM_ARCH}" "$HOME/.local/share/neovim"
        ln -sf "$HOME/.local/share/neovim/bin/nvim" "$HOME/.local/bin/nvim"
        rm -rf "$TMP_DIR"
        echo "✔ Neovim instalado en ~/.local/bin/nvim"
    elif sudo -n true 2>/dev/null; then
        sudo apt-get install -y neovim
        echo "✔ Neovim instalado vía APT"
    else
        echo "⚠️ No se pudo determinar arquitectura compatible para Neovim"
    fi
else
    echo "✔ Neovim ya está instalado"
fi

# Integración del lanzador (.desktop e icono para Fuzzel / GNOME)
if [ -f "$HOME/.local/share/neovim/share/applications/nvim.desktop" ]; then
    mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/128x128/apps"
    [ -f "$HOME/.local/share/neovim/share/icons/hicolor/128x128/apps/nvim.png" ] && \
        ln -sf "$HOME/.local/share/neovim/share/icons/hicolor/128x128/apps/nvim.png" "$HOME/.local/share/icons/hicolor/128x128/apps/nvim.png"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# 5. Herramientas Sysadmin APT (Remmina RDP/VNC + Wireshark sin root)
SYSADMIN_APT=()
for spkg in remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret wireshark tshark; do
    if ! dpkg -s "$spkg" &>/dev/null; then
        SYSADMIN_APT+=("$spkg")
    fi
done
if [ "${#SYSADMIN_APT[@]}" -gt 0 ]; then
    if sudo -n true 2>/dev/null; then
        echo "==> Instalando herramientas Sysadmin vía APT: ${SYSADMIN_APT[*]}..."
        echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${SYSADMIN_APT[@]}"
        if getent group wireshark >/dev/null 2>&1; then
            sudo usermod -aG wireshark "$USER" || true
        fi
    else
        echo "  (Pendiente sudo apt install ${SYSADMIN_APT[*]} o ejecutar 'make host')"
    fi
else
    echo "✔ Remmina y Wireshark ya están instalados"
fi

# 6. Suite de Aplicaciones Flatpak (Firefox estándar, LibreOffice, DBeaver, Bruno, Obsidian, Super Productivity)
if command -v flatpak &> /dev/null; then
    FLATPAK_APPS=(
        org.mozilla.firefox
        org.libreoffice.LibreOffice
        io.dbeaver.DBeaverCommunity
        com.usebruno.Bruno
        md.obsidian.Obsidian
        com.super_productivity.SuperProductivity
    )
    for app_id in "${FLATPAK_APPS[@]}"; do
        if flatpak info "$app_id" &> /dev/null; then
            echo "✔ Flatpak ya instalado: $app_id"
        else
            echo "==> Instalando Flatpak: $app_id..."
            flatpak install -y --noninteractive flathub "$app_id" 2>/dev/null || \
                flatpak install --user -y --noninteractive flathub "$app_id" 2>/dev/null || \
                echo "  ⚠️ No se pudo instalar $app_id en modo no interactivo"
        fi
    done

    # Configurar Firefox (Flatpak) como navegador predeterminado del sistema
    if flatpak info org.mozilla.firefox &> /dev/null && command -v xdg-settings &> /dev/null; then
        xdg-settings set default-web-browser org.mozilla.firefox.desktop 2>/dev/null || true
        if command -v xdg-mime &> /dev/null; then
            xdg-mime default org.mozilla.firefox.desktop x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml 2>/dev/null || true
        fi
        echo "✔ Firefox (Flatpak) configurado como navegador predeterminado (Chrome disponible para pruebas)"
    fi
fi

echo "================================================================="
echo "✔ Tooling (Firefox, Chrome, LibreOffice, VS Code, Zed, Neovim, Sysadmin & Productividad) completado."
echo "================================================================="
