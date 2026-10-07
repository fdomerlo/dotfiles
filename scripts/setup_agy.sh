#!/bin/bash
set -euo pipefail

# --- CONFIGURACIÓN ---
DIR_DESCARGAS="$HOME/Descargas"
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
    echo "[-] Aviso: No se encontró $ARCHIVO_APP en $DIR_DESCARGAS."
    echo "    Si dispones del tarball de Antigravity, colócalo en ~/Descargas/ y vuelve a ejecutar este script."
    echo "    Procediendo con la instalación del CLI únicamente..."
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
        echo "[1/4] La versión en /opt/ ya está actualizada. Omitiendo extracción."
    fi

    echo "[2/4] Verificando enlaces simbólicos en /usr/local/bin/..."
    sudo ln -sf "/opt/$SUBDIR_APP/$BIN_APP" /usr/local/bin/antigravity

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

echo "[4/4] Instalando / Actualizando Antigravity CLI..."
curl -fsSL https://antigravity.google/cli/install.sh | bash

echo "✔ Despliegue de Antigravity finalizado."
