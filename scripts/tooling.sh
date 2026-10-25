#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Instalando navegadores y editores (VS Code, Chrome, Zed)..."
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

echo "================================================================="
echo "✔ Tooling (VS Code, Chrome, Zed) completado."
echo "================================================================="
