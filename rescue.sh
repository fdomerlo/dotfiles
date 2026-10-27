#!/usr/bin/env bash
# rescue.sh - Automatización de montaje y chroot para estaciones Debian (Ext4 + EFI)
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[-] Ejecutar como root: sudo bash rescue.sh"; exit 1; }

# 1. Detectar el disco primario igual que en preseed.cfg (excluyendo el USB actual)
USB_DISK=$(findmnt -n -o SOURCE /run/live/medium 2>/dev/null | sed 's/[0-9]*$//' || true)
TARGET_DISK=""

for candidate in /dev/nvme[0-9]*n1 /dev/vda /dev/sda /dev/mmcblk0; do
    if [ -b "$candidate" ] && [ "$candidate" != "$USB_DISK" ]; then
        TARGET_DISK="$candidate"
        break
    fi
done

if [ -z "$TARGET_DISK" ]; then
    echo "[-] No se pudo detectar automáticamente el disco del sistema."
    lsblk -f
    exit 1
fi

# Determinar sufijo de partición ('p1'/'p2' en NVMe/eMMC vs '1'/'2' en SATA/VirtIO)
if [[ "$TARGET_DISK" =~ "nvme" ]] || [[ "$TARGET_DISK" =~ "mmcblk" ]]; then
    EFI_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

echo "==> Disco detectado: $TARGET_DISK"
echo "    Raíz (ext4) : $ROOT_PART"
echo "    EFI (fat32) : $EFI_PART"

# 2. Montar sistema de archivos y enlaces virtuales
mkdir -p /mnt/rescue
mount "$ROOT_PART" /mnt/rescue
mount "$EFI_PART" /mnt/rescue/boot/efi

for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "/mnt/rescue$dir"
done

# Enlazar variables UEFI si el host arrancó en modo UEFI (vital para grub-install)
if [ -d /sys/firmware/efi/efivars ]; then
    mount --bind /sys/firmware/efi/efivars /mnt/rescue/sys/firmware/efi/efivars 2>/dev/null || true
fi

# Asegurar salida a internet dentro del chroot
cp -L /etc/resolv.conf /mnt/rescue/etc/resolv.conf 2>/dev/null || true

# Función de limpieza garantizada al salir del chroot
cleanup() {
    echo -e "\n==> Desmontando entorno de rescate de forma segura..."
    umount -R /mnt/rescue 2>/dev/null || umount -l /mnt/rescue
    sync
    echo "✔ Listo. Ya podés reiniciar el equipo con 'reboot'."
}
trap cleanup EXIT

echo "================================================================="
echo "✔ Entrando al sistema instalado (chroot)."
echo "  - Para restaurar un snapshot : timeshift --restore"
echo "  - Para reparar paquetes APT  : dpkg --configure -a && apt-get install -f"
echo "  - Para reparar el arranque   : grub-install / update-initramfs -u -k all"
echo "  - Para salir y desmontar     : exit"
echo "================================================================="

chroot /mnt/rescue /bin/bash
