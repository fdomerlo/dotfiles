#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "[-] Error: Este script debe ejecutarse como usuario normal (SIN sudo)."
    exit 1
fi

echo "================================================================="
echo "==> Configurando Podman en modo Rootless para el usuario: $USER"
echo "================================================================="

if ! command -v podman &> /dev/null; then
    echo "[-] Error: No se encontró podman en el sistema."
    echo "    Asegúrate de ejecutar 'sudo bash host/setup.sh' primero."
    exit 1
fi

echo "==> Deshabilitando servicios previos de Docker Rootless si existen..."
systemctl --user disable --now docker.service docker.socket 2>/dev/null || true

echo "==> Migrando namespaces, almacenamiento y runtime OCI (crun) de Podman..."
if command -v crun &> /dev/null; then
    podman system migrate --new-runtime crun
else
    podman system migrate
fi

echo "==> Configurando registros de contenedores (Docker Hub, Quay, GHCR)..."
mkdir -p "$HOME/.config/containers"
if [ ! -f "$HOME/.config/containers/registries.conf" ]; then
    cat <<'EOF' > "$HOME/.config/containers/registries.conf"
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]
EOF
fi

echo "==> Habilitando e iniciando servicio de usuario systemd podman.socket..."
systemctl --user daemon-reload
systemctl --user enable --now podman.socket

echo "==> Verificando estado de Podman Rootless..."
if [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ]; then
    echo "✔ Podman Rootless está activo y respondiendo correctamente."
    echo "  Versión: $(podman --version)"
    echo "  Runtime: $(podman info --format '{{.Host.OCIRuntime.Name}}' 2>/dev/null || echo 'crun')"
    echo "  Socket:  ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
else
    echo "⚠️ Advertencia: Podman info no reporta modo Rootless activo."
fi

echo "================================================================="
echo "✔ Configuración de Podman Rootless completada."
echo "================================================================="
