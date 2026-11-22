#!/usr/bin/env bash
# host/setup.sh - Configuración base del sistema Debian Forky (root).
#
# Uso:
#   sudo bash host/setup.sh [--prune-unused-hw] [--prune-only]
#
# Opciones:
#   --prune-unused-hw  Tras configurar el host, purga microcódigo CPU y firmware/VA-API
#                      GPU de silicio fijo ausente en esta máquina (conserva red/audio/misc).
#   --prune-only       Ejecuta únicamente la purga de hardware no presente (implica --prune-unused-hw).
#   -h, --help         Muestra esta ayuda y sale.
set -euo pipefail

PRUNE_UNUSED_HW=false
PRUNE_ONLY=false

usage() {
    cat <<'EOF'
Uso: sudo bash host/setup.sh [OPCIÓN...]

Opciones:
  --prune-unused-hw  Tras configurar el host, purga microcódigo CPU y firmware/VA-API
                     GPU de silicio fijo ausente en esta máquina (conserva red/audio/misc).
  --prune-only       Ejecuta únicamente la purga de hardware no presente (implica --prune-unused-hw).
  -h, --help         Muestra esta ayuda y sale.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prune-unused-hw)
            PRUNE_UNUSED_HW=true
            ;;
        --prune-only)
            PRUNE_UNUSED_HW=true
            PRUNE_ONLY=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"

is_pkg_installed() {
    dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -qx 'install ok installed'
}

prune_unused_hw() {
    echo "==> Analizando hardware fijo presente para purgar paquetes CPU/GPU no usados..."
    export DEBIAN_FRONTEND=noninteractive

    local -a prune_pkgs=()
    local -a reasons=()

    # 1. Microcódigo CPU según vendor_id en /proc/cpuinfo
    local cpu_vendors=""
    if [ -r /proc/cpuinfo ]; then
        cpu_vendors=$(awk -F: '/^vendor_id[[:space:]]*:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2 }' /proc/cpuinfo 2>/dev/null | sort -u || true)
    fi

    local has_intel_cpu=false has_amd_cpu=false
    grep -qx 'GenuineIntel' <<<"$cpu_vendors" && has_intel_cpu=true
    grep -qx 'AuthenticAMD' <<<"$cpu_vendors" && has_amd_cpu=true

    if [ "$has_intel_cpu" = true ] && [ "$has_amd_cpu" = false ]; then
        if is_pkg_installed amd64-microcode; then
            prune_pkgs+=(amd64-microcode)
            reasons+=("CPU Intel detectada -> purgar amd64-microcode")
        fi
    elif [ "$has_amd_cpu" = true ] && [ "$has_intel_cpu" = false ]; then
        if is_pkg_installed intel-microcode; then
            prune_pkgs+=(intel-microcode)
            reasons+=("CPU AMD detectada -> purgar intel-microcode")
        fi
    else
        echo "  ⚠️ No se identificó un único vendor de CPU (GenuineIntel/AuthenticAMD); se conserva microcódigo."
    fi

    # 2. Firmware y VA-API GPU según controladores PCI de pantalla (clase 0x03*)
    local gpu_vendors=()
    local dev class_hex vendor_hex
    for dev in /sys/bus/pci/devices/*; do
        [ -r "$dev/class" ] && [ -r "$dev/vendor" ] || continue
        class_hex=$(<"$dev/class")
        case "$class_hex" in
            0x03*)
                vendor_hex=$(<"$dev/vendor")
                gpu_vendors+=("$vendor_hex")
                ;;
        esac
    done

    if [ "${#gpu_vendors[@]}" -eq 0 ]; then
        echo "  ⚠️ No se detectaron controladores PCI de pantalla (clase 0x03*); se conserva firmware GPU."
    else
        local has_intel_gpu=false has_amd_gpu=false v pkg
        for v in "${gpu_vendors[@]}"; do
            case "$v" in
                0x8086) has_intel_gpu=true ;;
                0x1002) has_amd_gpu=true ;;
            esac
        done

        if [ "$has_intel_gpu" = false ]; then
            for pkg in firmware-intel-graphics intel-media-va-driver; do
                if is_pkg_installed "$pkg"; then
                    prune_pkgs+=("$pkg")
                    reasons+=("Sin GPU Intel (0x8086) -> purgar $pkg")
                fi
            done
        fi

        if [ "$has_amd_gpu" = false ]; then
            if is_pkg_installed firmware-amd-graphics; then
                # Evita que firmware-misc-nonfree quede huérfano si firmware-linux-nonfree lo trajo como dependencia.
                if is_pkg_installed firmware-misc-nonfree; then
                    apt-mark manual firmware-misc-nonfree >/dev/null 2>&1 || true
                fi
                if is_pkg_installed firmware-linux-nonfree; then
                    prune_pkgs+=(firmware-linux-nonfree)
                    reasons+=("Sin GPU AMD (0x1002) -> purgar metapaquete firmware-linux-nonfree (conservando firmware-misc-nonfree)")
                fi
                prune_pkgs+=(firmware-amd-graphics)
                reasons+=("Sin GPU AMD (0x1002) -> purgar firmware-amd-graphics")
            fi
        fi
    fi

    if [ "${#prune_pkgs[@]}" -eq 0 ]; then
        echo "  ✔ No hay paquetes de microcódigo o GPU sin uso para purgar."
        return 0
    fi

    local r
    for r in "${reasons[@]}"; do
        echo "  -> $r"
    done

    apt-get purge -y "${prune_pkgs[@]}"
    apt-get autoremove --purge -y
    echo "  ✔ Purga de hardware no presente completada (firmwares de red/audio/misc intactos)."
}

if [ "$PRUNE_ONLY" = true ]; then
    echo "================================================================="
    echo "==> [Debian Forky] Purga de Hardware No Presente"
    echo "================================================================="
    prune_unused_hw
    echo "================================================================="
    echo "✔ Purga selectiva de hardware completada."
    echo "================================================================="
    exit 0
fi

echo "================================================================="
echo "==> [Debian Forky] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# ------------------------------------------------------------------------------
# 1. Verificación de suite Debian (Forky/testing vs Stable)
# ------------------------------------------------------------------------------
echo "==> Verificando suite de repositorios Debian..."

# Escribe $file solo si su contenido difiere de $content (convergencia idempotente).
write_if_changed() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
        printf '%s\n' "$content" > "$file"
        return 0
    fi
    return 1
}

IS_TESTING=false
IS_STABLE=false
APT_POLICY="$(apt-cache policy 2>/dev/null || true)"
if grep -qE 'o=Debian,a=testing,|o=Debian,.*,n=forky,' <<<"$APT_POLICY"; then
    IS_TESTING=true
elif [ -r /etc/os-release ] && grep -qE '^VERSION_CODENAME=forky$' /etc/os-release; then
    IS_TESTING=true
elif grep -q 'o=Debian,a=stable,' <<<"$APT_POLICY"; then
    IS_STABLE=true
elif [ -r /etc/debian_version ] && grep -qE '^[0-9]+\.[0-9]+' /etc/debian_version; then
    IS_STABLE=true
fi

BACKPORTS_FILE="/etc/apt/sources.list.d/debian-backports.sources"
if [ "$IS_TESTING" = true ]; then
    echo "  ✔ Debian Testing (forky) detectado: todo el stack vive en main (sin backports)."
    if [ -f "$BACKPORTS_FILE" ]; then
        echo "  -> Eliminando $BACKPORTS_FILE heredado de Stable para no mezclar suites..."
        rm -f "$BACKPORTS_FILE"
    fi
elif [ "$IS_STABLE" = true ]; then
    DEB_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
    BACKPORTS_CONTENT=$(cat << EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: stable-backports
Components: main contrib non-free non-free-firmware
Signed-By: $DEB_KEYRING
EOF
)
    if write_if_changed "$BACKPORTS_FILE" "$BACKPORTS_CONTENT"; then
        echo "  ✔ Debian Backports configurado (stable-backports)."
    else
        echo "  ✔ Debian Backports ya actualizado (stable-backports)."
    fi
else
    echo "  ⚠️ No se detectó Debian Forky (testing) ni Stable; revisá tus fuentes APT."
fi

echo "==> Actualizando repositorios APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ------------------------------------------------------------------------------
# 2. Soporte para AppImage (FUSE 2 nativo / Fallback Auto-extraíble)
# ------------------------------------------------------------------------------
APPIMAGE_FUSE_PKGS=()
FUSE2_DISPONIBLE=false

# Devuelve 0 si el paquete tiene un candidato de instalación real.
has_apt_candidate() {
    local candidate
    candidate=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidato:|Candidate:/ {print; exit}')
    [ -n "$candidate" ] && ! printf '%s\n' "$candidate" | grep -qE '\(ninguno|\(none'
}

# 1. Comprobar si existe un candidato de instalación real para FUSE 2
for fpkg in libfuse2t64 libfuse2; do
    if has_apt_candidate "$fpkg"; then
        APPIMAGE_FUSE_PKGS+=("$fpkg")
        FUSE2_DISPONIBLE=true
        break
    fi
done

# 2. Si no hay FUSE 2, dependemos de fuse3 y del fallback de extracción
if [ "$FUSE2_DISPONIBLE" = false ]; then
    if has_apt_candidate "fuse3"; then
        APPIMAGE_FUSE_PKGS+=("fuse3")
    fi

    # Configurar el fallback global para AppImages en sistemas sin FUSE 2
    if ! grep -q "APPIMAGE_EXTRACT_AND_RUN" /etc/environment 2>/dev/null; then
        echo "Configurando fallback de extracción para AppImages..."
        echo "APPIMAGE_EXTRACT_AND_RUN=1" | tee -a /etc/environment > /dev/null
    fi
fi

echo "==> Preconfigurando Wireshark para captura de paquetes sin root..."
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

BASE_APT_PKGS=()
read_manifest "$REPO_DIR/packages/apt-base.txt" BASE_APT_PKGS

echo "==> Instalando paquetes base, CLI moderna, sysadmin, Flatpak, AppImage y Podman..."
apt-get install -y "${BASE_APT_PKGS[@]}" "${APPIMAGE_FUSE_PKGS[@]}"

if getent group wireshark >/dev/null 2>&1; then
    usermod -aG wireshark "$TARGET_USER" || true
fi

# ------------------------------------------------------------------------------
# 3. Configuración de Flathub para Aplicaciones de Escritorio
# ------------------------------------------------------------------------------
echo "==> Configurando repositorio Flathub (aplicaciones de escritorio)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || \
  echo "  ⚠️ No se pudo registrar Flathub en este momento (verifica conexión de red)."

# ------------------------------------------------------------------------------
# 4. Directorio Dedicado para AppImages y Herramientas Portables
# ------------------------------------------------------------------------------
APPIMAGE_DIR="$USER_HOME/Aplicaciones"
mkdir -p "$APPIMAGE_DIR"
chown "$TARGET_USER:$TARGET_USER" "$APPIMAGE_DIR"
chmod 755 "$APPIMAGE_DIR"

# ------------------------------------------------------------------------------
# 5. Podman Rootless: rangos subuid/subgid y systemd linger
# ------------------------------------------------------------------------------
echo "==> Verificando rangos subuid y subgid para $TARGET_USER..."
if ! grep -q "^${TARGET_USER}:" /etc/subuid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${TARGET_USER}:" /etc/subgid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subgid
fi

echo "==> Habilitando systemd linger para $TARGET_USER..."
loginctl enable-linger "$TARGET_USER"

# ------------------------------------------------------------------------------
# 6. Gestión de energía e hibernación (swapfile >= RAM, resume, logind, sleep)
# ------------------------------------------------------------------------------
echo "==> Configurando energía e hibernación automática (suspend-then-hibernate)..."

# 6a. Asegurar /swapfile >= RAM (zram vive en RAM y no sirve para hibernar).
RAM_KIB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
RAM_GIB=$(( (RAM_KIB + 1048575) / 1048576 ))
[ "$RAM_GIB" -lt 4 ] && RAM_GIB=4
TARGET_SWAP_BYTES=$(( RAM_GIB * 1024 * 1024 * 1024 ))
ROOT_FSTYPE=$(findmnt -no FSTYPE / 2>/dev/null || echo "")

if [ "$ROOT_FSTYPE" = "ext4" ] || [ "$ROOT_FSTYPE" = "xfs" ]; then
    CUR_SWAP_BYTES=0
    [ -f /swapfile ] && CUR_SWAP_BYTES=$(stat -c%s /swapfile 2>/dev/null || echo 0)

    if [ "$CUR_SWAP_BYTES" -lt "$TARGET_SWAP_BYTES" ]; then
        AVAIL_BYTES=$(df -B1 --output=avail / | tail -n1 | tr -d ' ')
        NEEDED_BYTES=$(( TARGET_SWAP_BYTES - CUR_SWAP_BYTES ))
        MARGIN_BYTES=$(( 5 * 1024 * 1024 * 1024 ))

        if [ "$AVAIL_BYTES" -ge $(( NEEDED_BYTES + MARGIN_BYTES )) ]; then
            echo "  -> Ajustando /swapfile a ${RAM_GIB}G (RAM detectada: ${RAM_GIB} GiB)..."
            swapoff /swapfile 2>/dev/null || true
            rm -f /swapfile
            fallocate -l "${RAM_GIB}G" /swapfile
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null
            swapon --priority 10 /swapfile
        else
            echo "  ⚠️ Espacio libre insuficiente en / para ajustar /swapfile a ${RAM_GIB}G."
        fi
    else
        echo "  ✔ /swapfile ya tiene tamaño suficiente (>= ${RAM_GIB} GiB)."
    fi

    if [ -f /swapfile ]; then
        if ! grep -qE '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab; then
            echo '/swapfile none swap defaults,pri=10 0 0' >> /etc/fstab
        fi
        if ! grep -qE '^[[:space:]]*/swapfile[[:space:]]' /proc/swaps; then
            swapon --priority 10 /swapfile || true
        fi
    fi
else
    echo "  ⚠️ Raíz en '$ROOT_FSTYPE'; omitiendo ajuste automático de /swapfile."
fi

# 6b. Parámetros de reanudación (resume= / resume_offset=) en GRUB para /swapfile.
if [ -f /swapfile ] && command -v filefrag >/dev/null 2>&1 && [ -d /etc/default/grub.d ]; then
    ROOT_UUID=$(findmnt -no UUID / 2>/dev/null || true)
    SWAP_OFFSET=$(filefrag -v /swapfile 2>/dev/null | awk -F: '$1 ~ /^[[:space:]]*0$/ { sub(/\.\..*/, "", $3); gsub(/[[:space:]]/, "", $3); print $3; exit }' || true)

    if [ -n "$ROOT_UUID" ] && [[ "$SWAP_OFFSET" =~ ^[0-9]+$ ]] && [ "$SWAP_OFFSET" -gt 0 ]; then
        GRUB_HIBERNATE_CFG="/etc/default/grub.d/99-hibernate.cfg"
        GRUB_HIBERNATE_CONTENT=$(cat <<EOF
# Configurado por dotfiles (host/setup.sh) para reanudar desde /swapfile
case " \${GRUB_CMDLINE_LINUX_DEFAULT:-} " in
    *" resume="*) ;;
    *) GRUB_CMDLINE_LINUX_DEFAULT="\${GRUB_CMDLINE_LINUX_DEFAULT:+\$GRUB_CMDLINE_LINUX_DEFAULT }resume=UUID=${ROOT_UUID} resume_offset=${SWAP_OFFSET}" ;;
esac
EOF
)
        if write_if_changed "$GRUB_HIBERNATE_CFG" "$GRUB_HIBERNATE_CONTENT"; then
            if command -v update-grub >/dev/null 2>&1; then
                echo "  -> Actualizando GRUB con resume=UUID=${ROOT_UUID} resume_offset=${SWAP_OFFSET}..."
                update-grub
            fi
        else
            echo "  ✔ GRUB resume= ya configurado."
        fi
    fi
fi

# 6c. systemd-sleep: habilitar hibernación + retardo dinámico (15m batería / 20m AC).
SLEEP_CONF="/etc/systemd/sleep.conf.d/10-workstation-power.conf"
SLEEP_CONTENT=$(cat <<'EOF'
[Sleep]
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateOnACPower=yes
HibernateDelaySec=20min
EOF
)
if write_if_changed "$SLEEP_CONF" "$SLEEP_CONTENT"; then
    echo "  ✔ Política de sleep/hibernación escrita en $SLEEP_CONF."
fi

DELAY_BIN="/usr/local/libexec/workstation-hibernate-delay"
mkdir -p "$(dirname "$DELAY_BIN")"
if [ ! -f "$DELAY_BIN" ] || ! cmp -s "$REPO_DIR/host/hibernate-delay.sh" "$DELAY_BIN"; then
    install -m 0755 "$REPO_DIR/host/hibernate-delay.sh" "$DELAY_BIN"
    echo "  ✔ Helper de retardo AC/batería instalado en $DELAY_BIN."
fi

STH_DROPIN="/etc/systemd/system/systemd-suspend-then-hibernate.service.d/10-hibernate-delay.conf"
STH_CONTENT=$(cat <<EOF
[Service]
ExecStartPre=${DELAY_BIN}
EOF
)
if write_if_changed "$STH_DROPIN" "$STH_CONTENT"; then
    systemctl daemon-reload
    echo "  ✔ Drop-in de systemd-suspend-then-hibernate actualizado."
fi

# 6d. systemd-logind: cierre de tapa en laptop -> suspend-then-hibernate.
LOGIND_CONF="/etc/systemd/logind.conf.d/10-workstation-power.conf"
LOGIND_CONTENT=$(cat <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
HandleLidSwitchDocked=ignore
EOF
)
if write_if_changed "$LOGIND_CONF" "$LOGIND_CONTENT"; then
    systemctl reload systemd-logind.service 2>/dev/null || true
    echo "  ✔ Política de tapa (laptop) aplicada en $LOGIND_CONF."
fi

# 6e. Advertencia explícita si Secure Boot (lockdown) bloquea la hibernación.
if [ -r /sys/power/disk ] && grep -q '\[disabled\]' /sys/power/disk 2>/dev/null; then
    echo "  ⚠️ ATENCIÓN: el kernel reporta /sys/power/disk = [disabled] (lockdown/Secure Boot)."
    echo "     En Debian con Secure Boot activo, el kernel bloquea la hibernación."
    echo "     Desactivá Secure Boot en UEFI/BIOS para habilitar hibernación (30/40 min)."
fi

# ------------------------------------------------------------------------------
# 7. Purga opcional de paquetes CPU/GPU de hardware fijo no presente
# ------------------------------------------------------------------------------
if [ "$PRUNE_UNUSED_HW" = true ]; then
    prune_unused_hw
fi

echo "================================================================="
echo "✔ Host setup completado (Debian Forky + Flatpak + AppImage + Podman Rootless + Energía)."
echo "================================================================="
