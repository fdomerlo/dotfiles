#!/bin/bash

# Terminar inmediatamente si ocurre un error
set -e

# --- CONFIGURACIÓN DE PAQUETES Y BINARIOS ---
DESCARGAS_DIR="$HOME/Descargas"

ARCHIVO_APP="$DESCARGAS_DIR/Antigravity.tar.gz"
ARCHIVO_IDE="$DESCARGAS_DIR/Antigravity IDE.tar.gz"

# Carpetas que se crean al descomprimir
SUBDIR_APP="Antigravity-x64"
SUBDIR_IDE="Antigravity IDE"

# Nombres exactos de los ejecutables internos
BIN_APP="antigravity"
BIN_IDE="antigravity-ide"
# --------------------------------------------

echo "=== Iniciando instalación de Antigravity (Estructura x64) ==="

# Validar que los archivos existan en el directorio actual
if [ ! -f "$ARCHIVO_APP" ] || [ ! -f "$ARCHIVO_IDE" ]; then
    echo "[-] Error: No se encontraron los archivos comprimidos en este directorio."
    echo "    Asegurate de ejecutar el script exista en $DESCARGAS_DIR"
    exit 1
fi

# 1. Extracción limpia en /opt/
echo "[1/4] Extrayendo estructuras en /opt/..."
# Eliminar instalaciones previas en /opt para evitar conflicto de permisos
if [ -d "/opt/$SUBDIR_APP" ]; then sudo rm -rf "/opt/$SUBDIR_APP"; fi
if [ -d "/opt/$SUBDIR_IDE" ]; then sudo rm -rf "/opt/$SUBDIR_IDE"; fi

sudo tar -xzf "$ARCHIVO_APP" -C /opt/
sudo tar -xzf "$ARCHIVO_IDE" -C /opt/

# 2. Enlaces simbólicos globales apuntando al binario correcto
echo "[2/4] Creando enlaces simbólicos en /usr/local/bin/..."
sudo ln -sf "/opt/$SUBDIR_APP/$BIN_APP" /usr/local/bin/antigravity
sudo ln -sf "/opt/$SUBDIR_IDE/$BIN_IDE" /usr/local/bin/antigravity-ide

# 3. Lanzadores para el Dash de Fedora (GNOME/KDE)
echo "[3/4] Generando archivos .desktop..."

# Servidor / Core 2.0
sudo bash -c "cat <<EOF > /usr/share/applications/antigravity.desktop
[Desktop Entry]
Name=Antigravity 2.0
Comment=Orquestación asíncrona de agentes autónomos
Exec=/usr/local/bin/antigravity
Icon=/opt/$SUBDIR_APP/antigravity
Type=Application
Terminal=false
Categories=Development;IDE;
EOF"

# IDE Integrado
sudo bash -c "cat <<EOF > /usr/share/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=Entorno de desarrollo tradicional
Exec=/usr/local/bin/antigravity-ide
Icon=/opt/$SUBDIR_IDE/resources/app/resources/linux/code.png
Type=Application
Terminal=false
Categories=Development;IDE;
EOF"

# 4. Actualizar caché de aplicaciones del entorno de escritorio
echo "[4/4] Actualizando base de datos de aplicaciones del sistema..."
sudo update-desktop-database /usr/share/applications/

echo "=== Instalación finalizada ==="
echo "Los binarios ya están disponibles globalmente y mapeados en el Dash."
