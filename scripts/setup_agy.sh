#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURACIÓN ---
DIR_DESCARGAS="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
if [[ -z "$DIR_DESCARGAS" ]] || [[ ! -d "$DIR_DESCARGAS" ]]; then
    if [[ -d "$HOME/Descargas" ]]; then
        DIR_DESCARGAS="$HOME/Descargas"
    else
        DIR_DESCARGAS="$HOME/Downloads"
    fi
fi
ARCHIVO_APP="$DIR_DESCARGAS/Antigravity.tar.gz"

SUBDIR_APP="Antigravity-x64"
BIN_APP="antigravity"

USUARIO_ACTUAL=$(whoami)
GRUPO_ACTUAL=$(id -g -n)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_PATH="$SCRIPT_DIR/antigravity.png"
# --------------------------------------------

echo "================================================================="
echo "=== Despliegue local de Antigravity Core / IDE ==="
echo "================================================================="

if [[ ! -f "$ARCHIVO_APP" ]]; then
    echo "[-] Aviso: No se encontró $ARCHIVO_APP."
    echo "    Si dispones del tarball de Antigravity, colócalo en $DIR_DESCARGAS/ y vuelve a ejecutar este script."
    echo "    Procediendo con la verificación del CLI únicamente..."
else
    ACTUALIZAR_APP=false
    if [[ ! -d "/opt/$SUBDIR_APP" ]] || [[ "$ARCHIVO_APP" -nt "/opt/$SUBDIR_APP" ]]; then
        ACTUALIZAR_APP=true
    fi

    if [[ "$ACTUALIZAR_APP" == true ]]; then
        echo "[1/4] Extrayendo y corrigiendo permisos en /opt/..."
        sudo rm -rf "/opt/$SUBDIR_APP"
        sudo tar -xzf "$ARCHIVO_APP" -C /opt/
        sudo chown -R "$USUARIO_ACTUAL:$GRUPO_ACTUAL" "/opt/$SUBDIR_APP"
        sudo touch "/opt/$SUBDIR_APP"
    else
        echo "[1/4] ✔ La versión en /opt/ ya está actualizada. Omitiendo extracción."
    fi

    if [ -L "/usr/local/bin/antigravity" ] && [ "$(readlink "/usr/local/bin/antigravity")" = "/opt/$SUBDIR_APP/$BIN_APP" ]; then
        echo "[2/4] ✔ Enlace simbólico en /usr/local/bin/antigravity ya configurado."
    else
        echo "[2/4] Configurando enlace simbólico en /usr/local/bin/..."
        sudo ln -sf "/opt/$SUBDIR_APP/$BIN_APP" /usr/local/bin/antigravity
    fi

    if [ -f "/usr/share/applications/antigravity.desktop" ]; then
        echo "[3/4] ✔ Lanzador antigravity.desktop ya existe."
    else
        echo "[3/4] Creando lanzador .desktop..."
        sudo bash -c "cat <<EOF > /usr/share/applications/antigravity.desktop
[Desktop Entry]
Name=Antigravity 2.0
Comment=Orquestación asíncrona de agentes autónomos
Exec=/usr/local/bin/antigravity
Icon=$ICON_PATH
Type=Application
Terminal=false
Categories=Development;
EOF"
        sudo update-desktop-database /usr/share/applications/
    fi
fi

echo "[4/4] Verificando Antigravity CLI..."
mkdir -p "$HOME/.local/bin"
if ! command -v agy &>/dev/null && [ ! -f "$HOME/.local/bin/agy" ]; then
    echo "Instalando Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
else
    echo "✔ Antigravity CLI ya está instalado."
fi

# Enlace de compatibilidad y conveniencia para 'antigravity-cli' -> 'agy'
if [ -f "$HOME/.local/bin/agy" ]; then
    ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity-cli"
fi

# Fallback: si no existe el Core/IDE (/usr/local/bin/antigravity), enlazar 'antigravity' al CLI
if ! command -v antigravity &>/dev/null && [ ! -f "$HOME/.local/bin/antigravity" ] && [ ! -f "/usr/local/bin/antigravity" ] && [ -f "$HOME/.local/bin/agy" ]; then
    ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity"
fi

echo "✔ Despliegue de Antigravity finalizado."
