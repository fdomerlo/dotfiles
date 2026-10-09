#!/usr/bin/env bash
set -euo pipefail

echo "==> Configurando Timeshift para snapshots del sistema..."

if [[ $EUID -ne 0 ]]; then
    echo "Error: Este script debe ejecutarse con sudo." >&2
    exit 1
fi

# 1. Instalar Timeshift y herramientas complementarias
apt-get install -y timeshift

# 2. Detectar tipo de sistema de archivos en la raíz (/)
ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)
ROOT_UUID=$(findmnt -n -o UUID /)

mkdir -p /etc/timeshift

if [[ "$ROOT_FSTYPE" == "btrfs" ]]; then
    echo "==> Detectado Btrfs en raíz. Configurando modo BTRFS..."
    cat << EOF > /etc/timeshift/timeshift.json
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
  "schedule_boot" : "true",
  "count_monthly" : "0",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_boot" : "3",
  "snapshot_tags" : "",
  "exclude" : []
}
EOF
else
    echo "==> Detectado ${ROOT_FSTYPE} en raíz. Configurando modo RSYNC..."
    cat << EOF > /etc/timeshift/timeshift.json
{
  "backup_device_uuid" : "${ROOT_UUID}",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "true",
  "schedule_daily" : "true",
  "schedule_boot" : "false",
  "count_monthly" : "0",
  "count_weekly" : "2",
  "count_daily" : "3",
  "count_boot" : "0",
  "snapshot_tags" : "",
  "exclude" : [
    "+ /root/**",
    "- /home/**",
    "- /var/lib/docker/**",
    "- /var/lib/containers/**"
  ]
}
EOF
fi

# 3. Habilitar y arrancar el temporizador de systemd
systemctl enable --now cron.service || true

# 4. Generar el primer snapshot base inicial
echo "==> Creando primer snapshot base..."
timeshift --create --comments "Snapshot inicial post-install" --scripted || true

echo "==> Timeshift configurado y snapshot inicial generado."
