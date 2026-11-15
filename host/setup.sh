#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (e.g. sudo bash host/setup.sh)"; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"

echo "================================================================="
echo "==> [Debian Stable] Configuración de Sistema y Paquetes Base"
echo "================================================================="

echo "==> Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
bash "$REPO_DIR/scripts/apt-maintenance.sh"

# ------------------------------------------------------------------------------
# 1. Repositorios extendidos de Debian Stable (Backports)
# ------------------------------------------------------------------------------
echo "==> Configurando repositorios extendidos para Debian Stable (Backports)..."

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

# Debian Backports (formato canónico DEB822), solo si el sistema es Debian Stable.
# La coma final evita confundir 'stable' con 'stable-backports' en apt-cache policy.
# Fallback: en una instalación recién hecha puede no haber listas APT todavía;
# /etc/debian_version numérico (p. ej. 13.1) identifica una release estable.
IS_STABLE=false
if command -v apt-cache &>/dev/null && apt-cache policy 2>/dev/null | grep -q 'o=Debian,a=stable,'; then
    IS_STABLE=true
elif [ -r /etc/debian_version ] && grep -qE '^[0-9]+\.[0-9]+' /etc/debian_version; then
    IS_STABLE=true
fi

if [ "$IS_STABLE" = true ]; then
    BACKPORTS_FILE="/etc/apt/sources.list.d/debian-backports.sources"
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
    echo "  ⚠️ No se detectó Debian Stable; se omite Backports."
    echo "     Este repositorio solo soporta configuraciones para Debian Stable."
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

echo "================================================================="
echo "✔ Host setup completado (Debian Stable + Backports + Flatpak + AppImage + Podman Rootless + Energía)."
echo "================================================================="
