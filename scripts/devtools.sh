#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Instalando DevManagers (gh, uv, fnm, sdkman)..."
echo "================================================================="

if ! command -v gh &> /dev/null; then
    echo "Instalando GitHub CLI (gh vía binario oficial para Debian Testing)..."
    
    # 1. Crear directorio local de binarios si no existe
    mkdir -p "$HOME/.local/bin"
    
    # 2. Detectar arquitectura del procesador
    DET_ARCH=$(dpkg --print-architecture)
    if [ "$DET_ARCH" = "amd64" ]; then 
        ARCH="amd64"
    elif [ "$DET_ARCH" = "arm64" ]; then 
        ARCH="arm64"
    else
        ARCH="386"
    fi
    
    # 3. Obtener la última etiqueta de versión limpia (ej. v2.40.0) de la API de GitHub
    GH_VERSION=$(curl -sSL https://api.github.com/repos/cli/cli/releases/latest | jq -r .tag_name)
    # Quitarle la 'v' inicial para que coincida con el nombre de las carpetas internas
    VERSION_NUM="${GH_VERSION#v}"
    
    # 4. Descargar, extraer el binario usando llaves de protección y guardarlo
    TMP_DIR=$(mktemp -d)
    # Usamos la URL estructurada real que requiere la versión y la arquitectura explícitas
    curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${VERSION_NUM}_linux_${ARCH}.tar.gz" | tar -xz -C "$TMP_DIR" --strip-components=1
    
    mv "$TMP_DIR/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    rm -rf "$TMP_DIR"
    
    echo "✔ gh instalado correctamente en ~/.local/bin/gh"
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
