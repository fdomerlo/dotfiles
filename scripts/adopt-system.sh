#!/usr/bin/env bash
# scripts/adopt-system.sh - Nivelación de estación Debian preexistente hacia el estándar preseed.cfg
# Configura zRAM, swapfile, microcode, sysctl, fstab, repositorios y llama a la configuración de host.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Este script debe ejecutarse como root (ej. sudo bash scripts/adopt-system.sh)"; exit 1; }

FORCE=0
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE=1
    fi
done

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================="
echo "==> Adopción y Nivelación de Estación de Trabajo ([Debian Testing])"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Verificación previa de Auditoría
# ------------------------------------------------------------------------------
echo "==> Verificando compatibilidad de la estación..."
set +e
bash "$REPO_DIR/scripts/audit-system.sh"
AUDIT_STATUS=$?
set -e

if [ "$AUDIT_STATUS" -eq 2 ] && [ "$FORCE" -eq 0 ]; then
    echo ""
    echo "❌ ERROR: La auditoría detectó discrepancias críticas de arquitectura."
    echo "Se recomienda fuertemente una reinstalación limpia mediante preseed.cfg."
    echo "Si deseas forzar la adopción bajo tu propio riesgo, ejecuta:"
    echo "  sudo bash scripts/adopt-system.sh --force"
    exit 1
fi

echo ""
echo "================================================================="
echo "==> 1. Configuración de Repositorios Oficiales y APT Pinning"
echo "================================================================="
# Higiene APT previa
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# 1. Neutralización de /etc/apt/sources.list legacy si contiene líneas activas
if [ -f /etc/apt/sources.list ] && grep -vE '^[[:space:]]*(#|$)' /etc/apt/sources.list >/dev/null 2>&1; then
    echo "  Neutralizando /etc/apt/sources.list legacy (backup en /etc/apt/sources.list.bak)..."
    cp -a /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "# Migrado a DEB822 en /etc/apt/sources.list.d/debian.sources" > /etc/apt/sources.list
fi

# 2. Eliminación defensiva de fuentes exclusivas de Stable
rm -f /etc/apt/sources.list.d/debian-fasttrack.sources \
      /etc/apt/sources.list.d/debian-backports.sources

# 3. Escritura canónica de /etc/apt/sources.list.d/debian.sources
mkdir -p /etc/apt/sources.list.d
cat > /etc/apt/sources.list.d/debian.sources << 'EOF'
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: testing testing-updates unstable
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: testing-security stable-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
echo "  ✔ /etc/apt/sources.list.d/debian.sources configurado (DEB822 Testing)."

# 4. Escritura de /etc/apt/preferences.d/00-testing-pinning.pref
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/00-testing-pinning.pref << 'EOF'
Package: *
Pin: release a=testing
Pin-Priority: 900

Package: *
Pin: release a=testing-security
Pin-Priority: 900

Package: *
Pin: release a=testing-updates
Pin-Priority: 900

Package: *
Pin: release a=stable-security
Pin-Priority: 500

Package: *
Pin: release a=unstable
Pin-Priority: 100
EOF
echo "  ✔ /etc/apt/preferences.d/00-testing-pinning.pref configurado."

echo "==> Actualizando índices APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# ------------------------------------------------------------------------------
# 2. Detección Temprana de Hardware, Microcode y Firmware (preseed.cfg)
# ------------------------------------------------------------------------------
echo "================================================================="
echo "==> 2. Nivelando Microcode de CPU y Firmware de Hardware"
echo "================================================================="

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}' || true)
HARDWARE_PKGS=(
    firmware-linux-nonfree
    firmware-misc-nonfree
    firmware-iwlwifi
    firmware-realtek
    firmware-atheros
    firmware-sof-signed
    libgl1-mesa-dri
    mesa-vulkan-drivers
)

if [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    echo "  -> CPU AMD detectada: agregando amd64-microcode y firmware-amd-graphics..."
    HARDWARE_PKGS+=(amd64-microcode firmware-amd-graphics)
elif [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    echo "  -> CPU Intel detectada: agregando intel-microcode e intel-media-va-driver..."
    HARDWARE_PKGS+=(intel-microcode intel-media-va-driver)
fi

echo "  Instalando paquetes de hardware y firmware..."
apt-get install -y "${HARDWARE_PKGS[@]}" || {
    echo "  ⚠️ Algunos paquetes de firmware específicos no pudieron instalarse (continuando)..."
}

# ------------------------------------------------------------------------------
# 3. Configuración de zRAM y Memoria de Intercambio (preseed Late Command)
# ------------------------------------------------------------------------------
echo "================================================================="
echo "==> 3. Configurando Arquitectura de Memoria (zRAM + Swapfile)"
echo "================================================================="

apt-get install -y systemd-zram-generator

# 3.1 Generador zRAM
mkdir -p /etc/systemd
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
echo "  ✔ /etc/systemd/zram-generator.conf configurado."

# 3.2 Optimización Sysctl para zRAM
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-zram.conf << 'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
echo "  ✔ /etc/sysctl.d/99-zram.conf configurado."
sysctl --system || true

# 3.3 Swapfile secundario de 4GB si no existe
if [ ! -f /swapfile ]; then
    echo "  -> Creando swapfile secundario de 4GB en /swapfile..."
    if ! fallocate -l 4G /swapfile 2>/dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none
    fi
    chmod 600 /swapfile
    mkswap /swapfile
    echo "  ✔ Swapfile creado exitosamente."
else
    echo "  ✔ Swapfile ya existente en /swapfile."
fi

# Asegurar activación en fstab
if ! grep -q "/swapfile" /etc/fstab 2>/dev/null; then
    echo "  -> Agregando /swapfile a /etc/fstab (prioridad 10)..."
    echo '/swapfile none swap defaults,pri=10 0 0' >> /etc/fstab
fi

# Activar swaps ahora
swapon --priority 10 /swapfile 2>/dev/null || true
systemctl daemon-reload
systemctl restart /dev/zram0 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Optimizaciones de Almacenamiento y Servicios de Sistema
# ------------------------------------------------------------------------------
echo "================================================================="
echo "==> 4. Optimizaciones de Sistema de Archivos y Servicios"
echo "================================================================="

# 4.1 Opciones de montaje en /etc/fstab para raíz EXT4
if grep -E '^[[:space:]]*[^#]+[[:space:]]+/[[:space:]]+ext4' /etc/fstab 2>/dev/null | grep -qv "noatime"; then
    echo "  -> Aplicando noatime,commit=60 en /etc/fstab para partición raíz..."
    cp -a /etc/fstab /etc/fstab.bak
    if grep -q "errors=remount-ro" /etc/fstab; then
        sed -i 's/errors=remount-ro/noatime,commit=60,errors=remount-ro/' /etc/fstab
    fi
    echo "  ✔ /etc/fstab optimizado."
else
    echo "  ✔ Partición raíz ya cuenta con opciones noatime en fstab."
fi

# 4.2 Habilitar fstrim.timer
systemctl enable --now fstrim.timer 2>/dev/null || true
echo "  ✔ fstrim.timer habilitado."

# 4.3 Locale es_AR.UTF-8 si no está generado
if ! locale -a 2>/dev/null | grep -qiE 'es_AR\.utf-?8'; then
    echo "  -> Generando locale es_AR.UTF-8..."
    if [ -f /etc/locale.gen ]; then
        sed -i 's/^# *\(es_AR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        locale-gen es_AR.UTF-8 || true
    fi
fi

# ------------------------------------------------------------------------------
# 5. Ejecución del Aprovisionamiento Base de Host (setup.sh)
# ------------------------------------------------------------------------------
echo "================================================================="
echo "==> 5. Ejecutando Aprovisionamiento de Host y Podman (setup.sh)"
echo "================================================================="

bash "$REPO_DIR/host/setup.sh"

echo ""
echo "================================================================="
echo "✔ Nivelación de la estación completada exitosamente."
echo "La base de preseed.cfg ha sido asimilada."
echo "================================================================="
