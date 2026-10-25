#!/usr/bin/env bash
# scripts/migrate-to-testing.sh - Migración segura de Debian Stable a Debian Testing
#
# Automatiza la transición de la estación de trabajo:
#   1. Reconfigura fuentes oficiales a formato DEB822 apuntando a 'testing'.
#   2. Remueve repositorios exclusivos de Stable (FastTrack / Backports) para evitar
#      incompatibilidades o errores 404.
#   3. Actualiza el índice APT y realiza el 'dist-upgrade' (full-upgrade).
#   4. Ejecuta la higiene y limpieza profunda post-migración (purga de paquetes 'rc' y huérfanos).
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[-] Ejecutar con permisos de superusuario: sudo bash scripts/migrate-to-testing.sh"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_D="/etc/apt/sources.list.d"
KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"

log()  { echo -e "\n==> $1"; }
ok()   { echo "  ✔ $1"; }
warn() { echo "  ⚠️ $1"; }

CURRENT_SUITE=$(bash "$SCRIPT_DIR/detect-suite.sh" 2>/dev/null || echo "stable")

if [ "$CURRENT_SUITE" = "testing" ]; then
    ok "El sistema ya se encuentra en Debian Testing."
    echo "Ejecutando comprobación de higiene y limpieza de paquetes..."
    bash "$SCRIPT_DIR/apt-maintenance.sh" || true
    bash "$SCRIPT_DIR/clean-system.sh" || true
    ok "Estación al día en Debian Testing."
    exit 0
fi

log "Iniciando migración de estación: Debian Stable -> Debian Testing..."

# 1. Respaldo de fuentes actuales
if [ -f "$SOURCES_D/debian.sources" ]; then
    cp -a "$SOURCES_D/debian.sources" "$SOURCES_D/debian.sources.pre-testing.bak"
    ok "Respaldo creado en $SOURCES_D/debian.sources.pre-testing.bak"
fi

# 2. Configuración canónica DEB822 para Debian Testing
log "Configurando repositorios canónicos para Testing (DEB822)..."
cat > "$SOURCES_D/debian.sources" << EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: testing testing-updates
Components: main contrib non-free non-free-firmware
Signed-By: $KEYRING

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: testing-security
Components: main contrib non-free non-free-firmware
Signed-By: $KEYRING
EOF
ok "Repositorios configurados para Debian Testing."

# 3. Remover fuentes exclusivas de Stable
log "Higienizando repositorios extendidos de Stable..."
if [ -f "$SOURCES_D/debian-fasttrack.sources" ]; then
    rm -f "$SOURCES_D/debian-fasttrack.sources"
    ok "debian-fasttrack.sources eliminado (exclusivo de Stable)."
fi
if [ -f "$SOURCES_D/debian-backports.sources" ]; then
    rm -f "$SOURCES_D/debian-backports.sources"
    ok "debian-backports.sources removido (en Testing los paquetes provienen directamente de upstream)."
fi

# 4. Actualización del árbol de paquetes
log "Actualizando índices APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

log "Ejecutando actualización del sistema a Debian Testing (dist-upgrade)..."
apt-get dist-upgrade -y

# 5. Higiene y limpieza profunda post-migración
log "Ejecutando higiene APT y purga post-migración..."
bash "$SCRIPT_DIR/apt-maintenance.sh"
bash "$SCRIPT_DIR/clean-system.sh"

log "================================================================="
echo "✔ Migración a Debian Testing completada con éxito."
echo "  Ejecuta 'devctl doctor' o 'make verify' para validar el nuevo estado."
log "================================================================="
