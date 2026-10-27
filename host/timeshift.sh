#!/usr/bin/env bash
# host/timeshift.sh - Instalación y configuración idempotente de Timeshift (opcional)
# Nota: Solo instala y deja lista la configuración en /etc/timeshift/timeshift.json.
# Los snapshots son gestionados manualmente o programados por el usuario.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecutar como root: sudo bash host/timeshift.sh"; exit 1; }

DISTRO_NAME=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || echo "debian")

echo "================================================================="
echo "==> [Debian ${DISTRO_NAME^}] Configurando Timeshift (Snapshots del Sistema)"
echo "================================================================="

# 1. Instalar Timeshift y daemon cron requerido por el planificador
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y timeshift cron

# 2. Detectar sistema de archivos y UUID de la partición raíz (/)
ROOT_FSTYPE=$(findmnt -n -o FSTYPE / || echo "ext4")
ROOT_UUID=$(findmnt -n -o UUID / || echo "")

if [ -z "$ROOT_UUID" ]; then
    echo "  ⚠️ No se pudo detectar el UUID de /. Omitiendo escritura de /etc/timeshift/timeshift.json."
    exit 0
fi

mkdir -p /etc/timeshift

if [[ "$ROOT_FSTYPE" == "btrfs" ]]; then
    echo "==> Detectado Btrfs en raíz (UUID: $ROOT_UUID). Configurando modo BTRFS..."
    cat <<EOF > /etc/timeshift/timeshift.json
{
  "backup_device_uuid" : "${ROOT_UUID}",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "true",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "true",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "true",
  "count_monthly" : "0",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "0",
  "count_boot" : "3",
  "snapshot_tags" : "",
  "exclude" : [],
  "exclude-apps" : []
}
EOF
else
    echo "==> Detectado ${ROOT_FSTYPE} en raíz (UUID: $ROOT_UUID). Configurando modo RSYNC..."
    cat <<EOF > /etc/timeshift/timeshift.json
{
  "backup_device_uuid" : "${ROOT_UUID}",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "0",
  "count_weekly" : "0",
  "count_daily" : "3",
  "count_hourly" : "0",
  "count_boot" : "0",
  "snapshot_tags" : "",
  "exclude" : [
    "+ /root/**",
    "- /home/**",
    "- /swapfile",
    "- /var/lib/docker/**",
    "- /var/lib/containers/**",
    "- /var/cache/**",
    "- /var/tmp/**",
    "- /var/log/**",
    "- /tmp/**"
  ],
  "exclude-apps" : []
}
EOF
fi

# 3. Habilitar el servicio cron para las tareas programadas de Timeshift
systemctl enable --now cron.service 2>/dev/null || true

echo "================================================================="
echo "✔ Timeshift instalado y configurado en /etc/timeshift/timeshift.json."
echo "  (Los snapshots quedan a cargo del usuario: 'sudo timeshift --create' o vía GUI)."
echo "================================================================="
