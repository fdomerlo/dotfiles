#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "[-] Error: Este script debe ejecutarse como usuario normal (SIN sudo)."
    exit 1
fi

echo "================================================================="
echo "==> Configurando Docker en modo Rootless para el usuario: $USER"
echo "================================================================="

if ! command -v dockerd-rootless-setuptool.sh &> /dev/null; then
    echo "[-] Error: No se encontró dockerd-rootless-setuptool.sh."
    echo "    Asegúrate de ejecutar 'sudo bash host/setup.sh' primero."
    exit 1
fi

echo "==> Ejecutando instalación Rootless..."
dockerd-rootless-setuptool.sh install

echo "==> Habilitando e iniciando servicio de usuario systemd docker.service..."
systemctl --user daemon-reload
systemctl --user enable --now docker.service

export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"

echo "==> Verificando estado del demonio Docker Rootless..."
if docker info &> /dev/null; then
    echo "✔ Docker Rootless está activo y respondiendo correctamente."
    echo "  Socket: $DOCKER_HOST"
else
    echo "⚠️ Advertencia: docker info no respondió de inmediato. Revisa 'systemctl --user status docker.service'."
fi

echo "================================================================="
echo "✔ Configuración de Docker Rootless completada."
echo "================================================================="
