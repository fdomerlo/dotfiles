#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Instalando DevManagers (gh, uv, fnm, sdkman)..."
echo "================================================================="

if ! command -v gh &> /dev/null; then
    echo "Instalando GitHub CLI (gh vía repositorios oficiales)..."
    
    # 1. Asegurar herramientas iniciales para manejar llaves
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg
    
    # 2. Descargar la clave GPG oficial de GitHub CLI de forma segura
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://github.com | \
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    
    # 3. Registrar el repositorio oficial usando el dominio ://github.com
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://://github.com stable main" | \
      sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    
    # 4. Actualizar e instalar el paquete fresco
    sudo apt-get update -y
    sudo apt-get install -y gh
else
    echo "✔ gh ya está instalado"
fi

if ! command -v uv &> /dev/null && [ ! -f "$HOME/.local/bin/uv" ]; then
    echo "Instalando uv (Astral Python Package Manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "✔ uv ya está instalado"
fi

if ! command -v fnm &> /dev/null && [ ! -d "$HOME/.local/share/fnm" ]; then
    echo "Instalando fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
    echo "✔ fnm ya está instalado"
fi

if [ ! -d "$HOME/.sdkman" ]; then
    echo "Instalando sdkman..."
    if ! command -v unzip &> /dev/null || ! command -v zip &> /dev/null; then
        sudo apt-get install -y zip unzip
    fi
    export SDKMAN_DIR="$HOME/.sdkman"
    curl -s "https://get.sdkman.io" | bash
else
    echo "✔ sdkman ya está instalado"
fi

echo "✔ DevManagers listos."
