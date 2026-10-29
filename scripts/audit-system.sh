#!/usr/bin/env bash
# scripts/audit-system.sh - Auditoría profunda y comparación vs preseed.cfg y make install
# Detecta si una estación Debian preexistente es apta para adopción in-place o requiere reinstalación.
set -euo pipefail

# Asegurar rutas de herramientas administrativas en PATH
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

# Códigos de salida:
# 0 = Sistema completamente alineado
# 1 = Apto para adopción in-place (faltan configuraciones remediables)
# 2 = Crítico: Se recomienda reinstalación completa

EXIT_CODE=0
HAS_CRITICAL=0
HAS_WARNING=0

# Colores y símbolos
CLR_RESET="\033[0m"
CLR_RED="\033[31m"
CLR_GREEN="\033[32m"
CLR_YELLOW="\033[33m"
CLR_BLUE="\033[34m"
CLR_BOLD="\033[1m"

log_section() {
    echo -e "\n${CLR_BOLD}${CLR_BLUE}=== $1 ===${CLR_RESET}"
}

report_ok() {
    echo -e " [ ${CLR_GREEN}OK${CLR_RESET} ] $1"
}

report_warn() {
    echo -e " [ ${CLR_YELLOW}ADVERTENCIA${CLR_RESET} ] $1"
    HAS_WARNING=1
    if [ "$EXIT_CODE" -eq 0 ]; then EXIT_CODE=1; fi
}

report_critical() {
    echo -e " [ ${CLR_RED}CRÍTICO${CLR_RESET} ] $1"
    HAS_CRITICAL=1
    EXIT_CODE=2
}

report_info() {
    echo -e " [ INFO ] $1"
}

echo "================================================================="
echo "   Auditoría de Estación de Trabajo - Detección y Compatibilidad"
echo "        Comparativa contra preseed.cfg y 'make install'"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. EVALUACIÓN DE SHOWSTOPPERS / CRITERIOS CRÍTICOS (REINSTALACIÓN)
# ------------------------------------------------------------------------------
log_section "1. Arquitectura y Criterios Críticos de Sistema (Showstoppers)"

# 1.1 Distribución
IS_DEBIAN=0
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [ "${ID:-}" = "debian" ] || [[ "${ID_LIKE:-}" == *"debian"* ]]; then
        IS_DEBIAN=1
        report_ok "Sistema Operativo: $PRETTY_NAME (Debian compatible)"
    fi
fi
if [ "$IS_DEBIAN" -eq 0 ]; then
    report_critical "El sistema actual no es Debian puro (${ID:-desconocido}). preseed.cfg y la pila de repositorios testing asumen Debian GNU/Linux."
fi

# 1.2 Modo de Booteo (UEFI vs BIOS Legacy)
if [ -d /sys/firmware/efi ]; then
    report_ok "Modo de arranque: UEFI activo (/sys/firmware/efi)"
else
    report_critical "Modo de arranque: BIOS Legacy detectado. preseed.cfg utiliza tabla GPT y partición EFI (1GB FAT32). Convertir BIOS a UEFI in-place conlleva alto riesgo de rotura."
fi

# 1.3 Tabla de Particiones y Particionamiento Raíz
ROOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null || df / | tail -n 1 | awk '{print $1}')
DISK_DEV=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null | head -n1 || true)
if [ -n "$DISK_DEV" ]; then
    PT_TYPE=$(lsblk -no PTTYPE "/dev/$DISK_DEV" 2>/dev/null | head -n1 || true)
    if [ "$PT_TYPE" = "gpt" ]; then
        report_ok "Tabla de particiones del disco raíz (/dev/$DISK_DEV): GPT"
    elif [ -n "$PT_TYPE" ]; then
        report_critical "Tabla de particiones del disco raíz (/dev/$DISK_DEV): $PT_TYPE (preseed requiere GPT para arranque EFI monolítico robusto)."
    fi
fi

# 1.4 Espacio Disponible en Raíz (/)
ROOT_FREE_KB=$(df -P / | awk 'NR==2 {print $4}')
ROOT_FREE_GB=$(( ROOT_FREE_KB / 1024 / 1024 ))
if [ "$ROOT_FREE_GB" -ge 20 ]; then
    report_ok "Espacio libre en partición raíz (/): ${ROOT_FREE_GB} GB disponibles (adecuado)"
elif [ "$ROOT_FREE_GB" -ge 12 ]; then
    report_warn "Espacio libre en partición raíz (/): ${ROOT_FREE_GB} GB (mínimo justo; se recomiendan al menos 20 GB para Podman, Tooling y SDKs)"
else
    report_critical "Espacio libre en partición raíz (/): ${ROOT_FREE_GB} GB (insuficiente para el stack completo de ingeniería, riesgo de partición saturada)"
fi

# 1.5 Suite de Debian
if [ -f /etc/debian_version ]; then
    DEB_VER=$(cat /etc/debian_version)
    if [[ "$DEB_VER" =~ ^(testing|forky|trixie|unstable|sid) ]] || [[ "${VERSION_CODENAME:-}" =~ ^(testing|forky|trixie|sid) ]]; then
        report_ok "Suite de Debian: $DEB_VER (Testing / Sid compatible)"
    elif [[ "$DEB_VER" =~ ^12(\..*)? ]] || [ "${VERSION_CODENAME:-}" = "bookworm" ]; then
        report_warn "Suite de Debian: Debian 12 (Bookworm - Stable). Requiere actualización a Debian Testing como propone preseed.cfg."
    else
        report_critical "Suite de Debian: $DEB_VER (Antigua). Actualizar directamente a Testing desde Debian 11 o inferior no es seguro in-place."
    fi
fi

# ------------------------------------------------------------------------------
# 2. COMPARATIVA DE CONFIGURACIONES BASE DE PRESEED.CFG
# ------------------------------------------------------------------------------
log_section "2. Base de preseed.cfg (Hardware, Firmware, Memoria y Kernel)"

# 2.1 Microcode de CPU
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}' || true)
if [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    if dpkg -s amd64-microcode &>/dev/null; then
        report_ok "CPU AMD detectada: amd64-microcode instalado"
    else
        report_warn "CPU AMD detectada: amd64-microcode NO instalado (propuesto en preseed.cfg)"
    fi
elif [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    if dpkg -s intel-microcode &>/dev/null; then
        report_ok "CPU Intel detectada: intel-microcode instalado"
    else
        report_warn "CPU Intel detectada: intel-microcode NO instalado (propuesto en preseed.cfg)"
    fi
else
    report_info "Fabricante de CPU: $CPU_VENDOR (no requiere microcode específico AMD/Intel)"
fi

# 2.2 Paquetes de Firmware y Gráficos
for pkg in firmware-linux-nonfree firmware-misc-nonfree mesa-vulkan-drivers libgl1-mesa-dri; do
    if dpkg -s "$pkg" &>/dev/null; then
        report_ok "Paquete esencial de hardware: $pkg instalado"
    else
        report_warn "Paquete esencial de hardware: $pkg ausente"
    fi
done

# 2.3 Memoria Swap y zRAM (preseed Late Command)
if dpkg -s systemd-zram-generator &>/dev/null && [ -f /etc/systemd/zram-generator.conf ]; then
    report_ok "zRAM generator: instalado y configurado en /etc/systemd/zram-generator.conf"
else
    report_warn "zRAM generator: falta instalar o configurar /etc/systemd/zram-generator.conf"
fi

if grep -q "zram" /proc/swaps 2>/dev/null; then
    report_ok "Dispositivo zRAM activo en /proc/swaps"
else
    report_warn "Dispositivo zRAM NO activo como swap principal"
fi

# 2.4 Swapfile secundario de 4GB (preseed Late Command)
if [ -f /swapfile ] && grep -q "/swapfile" /proc/swaps 2>/dev/null; then
    report_ok "Swapfile de respaldo (/swapfile) activo en /proc/swaps"
elif [ -f /swapfile ]; then
    report_warn "Swapfile (/swapfile) existe pero no está activo en /proc/swaps"
else
    report_warn "Swapfile (/swapfile de 4GB) no existe en el sistema"
fi

# 2.5 Sysctl de Kernel para zRAM (/etc/sysctl.d/99-zram.conf)
if [ -f /etc/sysctl.d/99-zram.conf ] && grep -q "vm.swappiness = 180" /etc/sysctl.d/99-zram.conf 2>/dev/null; then
    report_ok "Parámetros sysctl zRAM: configurados en /etc/sysctl.d/99-zram.conf"
else
    report_warn "Parámetros sysctl zRAM: ausentes o incompletos en /etc/sysctl.d/99-zram.conf"
fi

# 2.6 Opciones de montaje en /etc/fstab (noatime,commit=60)
if grep -E '^[[:space:]]*[^#]+[[:space:]]+/[[:space:]]+ext4' /etc/fstab 2>/dev/null | grep -q "noatime"; then
    report_ok "Opciones de fstab para /: optimizado con noatime"
else
    report_warn "Opciones de fstab para /: falta 'noatime,commit=60' (propuesto en preseed late_command)"
fi

# 2.7 Servicio fstrim.timer
if systemctl is-enabled fstrim.timer &>/dev/null; then
    report_ok "fstrim.timer: habilitado en systemd"
else
    report_warn "fstrim.timer: deshabilitado o inactivo"
fi

# 2.8 Localización
CURRENT_LANG=$(locale -a 2>/dev/null | grep -iE 'es_AR\.utf-?8' | head -n1 || true)
if [ -n "$CURRENT_LANG" ]; then
    report_ok "Locale es_AR.UTF-8 disponible en el sistema ($CURRENT_LANG)"
else
    report_warn "Locale es_AR.UTF-8 no generado en /etc/locale.gen"
fi

# ------------------------------------------------------------------------------
# 3. COMPARATIVA DE REPOSITORIOS APT (DEB822 + PINNING)
# ------------------------------------------------------------------------------
log_section "3. Repositorios APT y APT Pinning"

if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    report_ok "Repositorio debian.sources en formato estándar DEB822 presente"
else
    report_warn "debian.sources (DEB822) no encontrado en /etc/apt/sources.list.d/"
fi

if [ -f /etc/apt/preferences.d/00-testing-pinning.pref ]; then
    report_ok "APT Pinning híbrido de Debian Testing configurado (/etc/apt/preferences.d/00-testing-pinning.pref)"
else
    report_warn "APT Pinning no configurado (pendiente para Testing)"
fi

# ------------------------------------------------------------------------------
# 4. CAPA DE APROVISIONAMIENTO MAKE INSTALL
# ------------------------------------------------------------------------------
log_section "4. Ecosistema de Desarrollo (make install)"

# 4.1 Paquetes CLI base y guardarraíles Sieve
CLI_MISSING=()
for pkg in sudo curl git zsh make build-essential ripgrep fd-find fzf bat btop direnv wl-clipboard flatpak fuse3 uidmap; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        CLI_MISSING+=("$pkg")
    fi
done
if [ ${#CLI_MISSING[@]} -eq 0 ]; then
    report_ok "Paquetes base CLI y guardarraíles Sieve instalados"
else
    report_warn "Faltan paquetes base: ${CLI_MISSING[*]}"
fi

# 4.2 Podman Rootless
if command -v podman &>/dev/null && [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ]; then
    report_ok "Podman Rootless activo y operativo"
else
    report_warn "Podman Rootless no disponible o no configurado en modo rootless"
fi

# 4.3 Dotfiles y devctl
DOTFILES_MISSING=0
for f in "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.local/bin/devctl"; do
    if [ ! -e "$f" ]; then
        DOTFILES_MISSING=1
    fi
done
if [ $DOTFILES_MISSING -eq 0 ]; then
    report_ok "Dotfiles y CLI devctl enlazados"
else
    report_warn "Dotfiles o devctl faltantes en el perfil de usuario"
fi

# 4.4 Toolchains y DevManagers
DEVMGR_MISSING=()
for mgr in gh uv fnm; do
    if ! command -v "$mgr" &>/dev/null && [ ! -f "$HOME/.local/bin/$mgr" ]; then
        DEVMGR_MISSING+=("$mgr")
    fi
done
if [ -d "$HOME/.sdkman" ]; then
    report_ok "sdkman instalado en ~/.sdkman"
else
    DEVMGR_MISSING+=("sdkman")
fi
if [ ${#DEVMGR_MISSING[@]} -eq 0 ]; then
    report_ok "Manejadores de runtime (gh, uv, fnm, sdkman) presentes"
else
    report_warn "Manejadores ausentes: ${DEVMGR_MISSING[*]}"
fi

# 4.5 Tooling de escritorio y DevAI
APP_MISSING=()
for app in code google-chrome-stable zed antigravity opencode; do
    if ! command -v "$app" &>/dev/null && [ ! -f "$HOME/.local/bin/$app" ] && [ ! -f "/opt/Antigravity/antigravity" ]; then
        APP_MISSING+=("$app")
    fi
done
if [ ${#APP_MISSING[@]} -eq 0 ]; then
    report_ok "Tooling de escritorio y DevAI presentes"
else
    report_warn "Aplicaciones ausentes: ${APP_MISSING[*]}"
fi

# ------------------------------------------------------------------------------
# 5. DICTAMEN FINAL Y RECOMENDACIÓN
# ------------------------------------------------------------------------------
echo ""
echo "================================================================="
echo "                       DICTAMEN FINAL"
echo "================================================================="

if [ "$HAS_CRITICAL" -gt 0 ]; then
    echo -e "${CLR_BOLD}${CLR_RED}❌ ESTADO: SE RECOMIENDA REINSTALACIÓN COMPLETA LIMPIA${CLR_RESET}"
    echo ""
    echo "Motivos técnicos insalvables detectados:"
    echo "  - La estación no cumple con los requisitos arquitectónicos de preseed.cfg"
    echo "    (ej. BIOS Legacy en vez de UEFI/GPT, espacio crítico insuficiente, distro no compatible o Debian obsoleto)."
    echo ""
    echo "Pasos recomendados:"
    echo "  1. Realiza una copia de seguridad de tus datos personales (/home)."
    echo "  2. Prepara un medio USB de instalación con preseed.cfg (o Ventoy con preseed.cfg inyectado)."
    echo "  3. Realiza una instalación desatendida limpia para garantizar la partición EFI de 1GB,"
    echo "     zRAM nativo y la raíz EXT4 monolítica."
    echo "  4. Una vez reiniciado el equipo, ejecuta: make install"
    exit 2
elif [ "$HAS_WARNING" -gt 0 ]; then
    echo -e "${CLR_BOLD}${CLR_YELLOW}⚠️ ESTADO: ESTACIÓN APTA PARA ADOPCIÓN IN-PLACE${CLR_RESET}"
    echo ""
    echo "La estación cuenta con la arquitectura adecuada (Debian compatible, UEFI y espacio suficiente),"
    echo "pero presenta diferencias de configuración respecto a preseed.cfg y make install."
    echo ""
    echo "Acción recomendada:"
    echo "  Ejecuta el proceso de adopción y nivelación automática ejecutando:"
    echo -e "    ${CLR_BOLD}make adopt${CLR_RESET}   (o 'devctl adopt')"
    echo ""
    echo "Esto nivelará zRAM, swapfile, microcode/firmware, sysctl, fstab y ejecutará 'make install'."
    exit 1
else
    echo -e "${CLR_BOLD}${CLR_GREEN}✅ ESTADO: ESTACIÓN COMPLETAMENTE HOMOLOGADA${CLR_RESET}"
    echo "La estación de trabajo coincide plenamente con preseed.cfg y el perfil de ingeniería de make install."
    exit 0
fi
