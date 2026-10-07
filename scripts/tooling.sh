#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Instalando navegadores y editores (VS Code, Chrome, Zed)..."
echo "================================================================="

# 1. Visual Studio Code (APT Oficial)
if [ ! -f "/etc/apt/sources.list.d/vscode.list" ]; then
    echo "==> Configurando repositorio oficial de Microsoft VS Code..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg
    sudo chmod a+r /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -y
fi

if ! command -v code &> /dev/null; then
    echo "Instalando VS Code..."
    sudo apt-get install -y code
else
    echo "✔ VS Code ya está instalado"
fi

# 2. Zed Editor
if ! command -v zed &> /dev/null && [ ! -f "$HOME/.local/bin/zed" ]; then
    echo "==> Instalando Zed editor..."
    curl -f https://zed.dev/install.sh | sh
else
    echo "✔ Zed ya está instalado"
fi

# 3. Google Chrome (deb oficial)
if ! command -v google-chrome-stable &> /dev/null; then
    echo "==> Instalando Google Chrome oficial..."
    TMP_DEB=$(mktemp /tmp/google-chrome-XXXXXX.deb)
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$TMP_DEB"
    sudo apt-get install -y "$TMP_DEB"
    rm -f "$TMP_DEB"
else
    echo "✔ Google Chrome ya está instalado"
fi

echo "✔ Tooling listo."
