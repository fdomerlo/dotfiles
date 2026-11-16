#!/usr/bin/env bash
# ==============================================================================
# scripts/virt.sh - Virtualización opcional con Quickemu + QEMU/KVM.
#
# Filosofía:
#   - Sin libvirtd, sin daemons permanentes y sin privilegios para usar las VMs.
#   - Cada VM es un proceso QEMU del usuario que termina al apagarla.
#   - Pensado para pruebas esporádicas de software, drivers y paridad con
#     estaciones Windows/Ubuntu/Zorin/Fedora administradas.
#
# Uso:
#   make virt
#   bash scripts/virt.sh [--check]
# ==============================================================================
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"

VMS_DIR="${VMS_DIR:-$HOME/VMs}"
CHECK_ONLY=0
case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    "") ;;
    *) echo "Uso: $0 [--check]" >&2; exit 2 ;;
esac

ok()   { echo "  ✔ $1"; }
warn() { echo "  ⚠️ $1"; }
step() { echo; echo "==> $1"; }

# Paquetes APT: quickemu arrastra QEMU, SPICE y swtpm; el resto se declara
# explícito para dejar clara la dependencia (OVMF, ISOs y passthrough USB).
VIRT_PKGS=(quickemu qemu-system-x86 qemu-utils ovmf swtpm genisoimage usbutils)

echo "================================================================="
echo "==> Virtualización opcional (Quickemu + QEMU/KVM, sin daemon)"
echo "================================================================="

step "Comprobando soporte de virtualización"
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then
    ok "Arquitectura x86_64"
else
    warn "Arquitectura detectada: $ARCH (el perfil asume x86_64)"
fi

CPU_FLAGS="$(awk -F: '/^flags/{print $2; exit}' /proc/cpuinfo 2>/dev/null | tr ' ' '\n')"
if grep -qxE 'svm|vmx' <<<"$CPU_FLAGS"; then
    ok "CPU con extensiones de virtualización (AMD-V/Intel VT-x)"
elif grep -qxE 'npt|svm_lock' <<<"$CPU_FLAGS"; then
    warn "CPU AMD con SVM deshabilitado en el firmware: habilitá 'SVM Mode' en BIOS/UEFI"
else
    warn "No se detectaron extensiones de virtualización; revisá el BIOS/UEFI"
fi

step "Paquetes de virtualización"
MISSING=()
for pkg in "${VIRT_PKGS[@]}"; do
    dpkg -s "$pkg" &>/dev/null || MISSING+=("$pkg")
done

if [ "${#MISSING[@]}" -eq 0 ]; then
    ok "Paquetes ya instalados: ${VIRT_PKGS[*]}"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "Faltan: ${MISSING[*]} (ejecutá 'make virt')"
else
    if sudo -n true 2>/dev/null; then
        echo "==> Instalando: ${MISSING[*]}..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING[@]}"
        ok "Paquetes instalados"
    else
        warn "Faltan: ${MISSING[*]}"
        warn "Instalalos con: sudo apt install ${MISSING[*]}"
        exit 0
    fi
fi

if ! command -v quickemu &>/dev/null || ! command -v quickget &>/dev/null; then
    warn "quickemu/quickget no están disponibles todavía (¿reiniciar la sesión?)"
    exit 0
fi
ok "quickemu y quickget disponibles"

step "Aceleración por hardware"
if [ -c /dev/kvm ]; then
    ok "/dev/kvm disponible"
else
    warn "/dev/kvm ausente: las VMs funcionarán por emulación (muy lentas)"
    warn "Reiniciá la sesión o habilitá AMD-V/Intel VT-x en el firmware"
fi

if getent group kvm >/dev/null 2>&1; then
    if id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx kvm; then
        ok "Usuario '$USER' en el grupo kvm"
    elif [ -c /dev/kvm ] && [ "$(stat -c '%a' /dev/kvm 2>/dev/null || echo 000)" = "666" ]; then
        ok "/dev/kvm es accesible sin grupo kvm"
    elif sudo -n true 2>/dev/null; then
        sudo usermod -aG kvm "$USER"
        warn "Agregado '$USER' al grupo kvm: cerrá sesión y volvé a entrar"
    else
        warn "Falta el grupo kvm: sudo usermod -aG kvm $USER (y reiniciar sesión)"
    fi
fi

step "Directorio de máquinas virtuales"
if [ -d "$VMS_DIR" ]; then
    ok "$VMS_DIR ya existe"
else
    mkdir -p "$VMS_DIR"
    ok "Creado $VMS_DIR"
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    step "Estado"
    ok "Verificación de virtualización finalizada"
    exit 0
fi

cat <<EOF

=================================================================
 Virtualización lista (sin daemons ni autostart)
=================================================================
 Directorio de VMs: $VMS_DIR

 Descargar y crear una VM:
   quickget windows 10                 # Windows 10 (ISO oficial de Microsoft)
   quickget ubuntu 24.04               # Ubuntu LTS
   quickget zorin 17                   # Zorin OS
   quickget fedora <release>           # Fedora (usar 'quickget --list')

 Arrancar una VM (proceso QEMU del usuario):
   quickemu --vm $VMS_DIR/<os>-<release>.conf

 Snapshots:
   quickemu --vm <conf> --snapshot create base
   quickemu --vm <conf> --snapshot apply base

 Notas:
   - Windows requiere el ISO virtio-win (Quickemu lo descarga solo).
   - Para passthrough USB, editá 'usb_devices' en el .conf (usá 'lsusb').
   - Si Microsoft bloquea la descarga automática de Windows, descargá el ISO
     desde el navegador y guardalo en $VMS_DIR.
   - Aceleración: si no aparece /dev/kvm, habilitá SVM/AMD-V (o VT-x) en el
     firmware y reiniciá la sesión.
   - No hay libvirtd, red NAT administrada ni autostart: al apagar la VM,
     no queda ningún proceso corriendo.
=================================================================
EOF
