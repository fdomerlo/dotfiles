#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"

echo "================================================================="
echo "==> Instalando DevManagers (gh, uv, fnm, sdkman, yazi, mc, lazydocker)..."
echo "================================================================="

if ! command -v gh &> /dev/null; then
    echo "Instalando GitHub CLI (gh vía binario oficial)..."
    
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
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
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
    curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash
else
    echo "✔ sdkman ya está instalado"
fi

if ! command -v yazi &> /dev/null && [ ! -f "$HOME/.local/bin/yazi" ]; then
    echo "Instalando Yazi (Terminal File Manager)..."
    mkdir -p "$HOME/.local/bin"
    DET_ARCH=$(dpkg --print-architecture)
    if [ "$DET_ARCH" = "amd64" ]; then
        YAZI_TARGET="x86_64-unknown-linux-gnu"
    elif [ "$DET_ARCH" = "arm64" ]; then
        YAZI_TARGET="aarch64-unknown-linux-gnu"
    else
        YAZI_TARGET=""
    fi

    if [ -n "$YAZI_TARGET" ]; then
        YAZI_VERSION=$(curl -sSL https://api.github.com/repos/sxyazi/yazi/releases/latest | jq -r .tag_name)
        TMP_DIR=$(mktemp -d)
        curl -fsSL -o "$TMP_DIR/yazi.zip" "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_TARGET}.zip"
        unzip -q "$TMP_DIR/yazi.zip" -d "$TMP_DIR"
        mv "$TMP_DIR/yazi-${YAZI_TARGET}/yazi" "$HOME/.local/bin/yazi"
        if [ -f "$TMP_DIR/yazi-${YAZI_TARGET}/ya" ]; then
            mv "$TMP_DIR/yazi-${YAZI_TARGET}/ya" "$HOME/.local/bin/ya"
            chmod +x "$HOME/.local/bin/ya"
        fi
        chmod +x "$HOME/.local/bin/yazi"
        rm -rf "$TMP_DIR"
        echo "✔ yazi instalado correctamente en ~/.local/bin/yazi"
    else
        echo "⚠️ Arquitectura $DET_ARCH no soportada para binario precompilado de Yazi"
    fi
else
    echo "✔ yazi ya está instalado"
fi

# Yazi busca `fd` (Debian lo instala como `fdfind`).
if ! command -v fd &> /dev/null && [ -x /usr/bin/fdfind ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"
    echo "✔ fd enlazado a /usr/bin/fdfind"
fi

# Dependencias de previews de Yazi: video (ffmpeg), comprimidos (7zip) e imágenes Sixel en Foot (chafa).
YAZI_DEPS=()
command -v ffmpeg &> /dev/null || YAZI_DEPS+=(ffmpeg)
command -v chafa &> /dev/null || YAZI_DEPS+=(chafa)
if ! command -v 7z &> /dev/null && ! command -v 7zz &> /dev/null; then
    YAZI_DEPS+=(7zip)
fi
if [ ${#YAZI_DEPS[@]} -gt 0 ]; then
    if sudo -n true 2>/dev/null; then
        echo "Instalando dependencias de Yazi: ${YAZI_DEPS[*]}..."
        sudo apt-get install -y "${YAZI_DEPS[@]}"
    else
        echo "  (Pendiente sudo apt install ${YAZI_DEPS[*]} para previews extendidos de Yazi)"
    fi
else
    echo "✔ dependencias de previews de Yazi ya están instaladas"
fi

# Midnight Commander: alternativa TUI a Yazi, con skin Nord propio.
if ! command -v mc &> /dev/null; then
    if sudo -n true 2>/dev/null; then
        echo "Instalando Midnight Commander (mc)..."
        sudo apt-get install -y mc
    fi
else
    echo "✔ mc ya está instalado"
fi

# Lazydocker: TUI para gestión de contenedores Podman/Docker.
if ! command -v lazydocker &> /dev/null && [ ! -f "$HOME/.local/bin/lazydocker" ]; then
    echo "Instalando Lazydocker (TUI para Podman/Docker)..."
    mkdir -p "$HOME/.local/bin"
    DET_ARCH=$(dpkg --print-architecture)
    if [ "$DET_ARCH" = "amd64" ]; then
        LZD_ARCH="x86_64"
    elif [ "$DET_ARCH" = "arm64" ]; then
        LZD_ARCH="arm64"
    else
        LZD_ARCH=""
    fi

    if [ -n "$LZD_ARCH" ]; then
        LZD_LATEST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazydocker/releases/latest)
        LZD_VERSION="${LZD_LATEST_URL##*/}"
        LZD_VER_NUM="${LZD_VERSION#v}"
        TMP_DIR=$(mktemp -d)
        curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/${LZD_VERSION}/lazydocker_${LZD_VER_NUM}_Linux_${LZD_ARCH}.tar.gz" | tar -xz -C "$TMP_DIR"
        mv "$TMP_DIR/lazydocker" "$HOME/.local/bin/lazydocker"
        chmod +x "$HOME/.local/bin/lazydocker"
        rm -rf "$TMP_DIR"
        echo "✔ lazydocker ($LZD_VERSION) instalado correctamente en ~/.local/bin/lazydocker"
    else
        echo "⚠️ Arquitectura $DET_ARCH no soportada para binario de Lazydocker"
    fi
else
    echo "✔ lazydocker ya está instalado"
fi

# Enlazar wrapper de imv si el paquete de Debian está instalado
if [ -x /usr/libexec/imv/imv ] && [ ! -e "$HOME/.local/bin/imv" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/libexec/imv/imv "$HOME/.local/bin/imv"
    echo "✔ imv enlazado a /usr/libexec/imv/imv"
fi

echo "✔ DevManagers listos."
