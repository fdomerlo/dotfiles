#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "       Debian Trixie Workstation - Verificación de Estado        "
echo "================================================================="

check_status() {
    if [ "$1" -eq 0 ]; then
        echo -e " [ \033[32mOK\033[0m ] $2"
    else
        echo -e " [ \033[31mFAIL\033[0m ] $2"
    fi
}

# 1. Controlador AMDGPU
echo -n "Controlador de gráficos (amdgpu)... "
if lsmod | grep -q "^amdgpu"; then
    check_status 0 "Módulo amdgpu cargado en el kernel"
else
    check_status 1 "amdgpu NO está cargado"
fi

# 2. zRAM
echo -n "Dispositivo zRAM... "
if grep -q "zram" /proc/swaps; then
    check_status 0 "zRAM activo como swap principal"
else
    check_status 1 "zRAM no detectado en /proc/swaps"
fi

# 3. Swapfile en disco
echo -n "Swapfile de respaldo... "
if grep -q "swapfile" /proc/swaps; then
    check_status 0 "Swapfile secundario activo"
else
    check_status 1 "Swapfile secundario no activo"
fi

# 4. Docker Rootless
echo -n "Docker Rootless... "
SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"
if [ -S "$SOCK" ] && DOCKER_HOST="unix://$SOCK" docker info &>/dev/null; then
    check_status 0 "Docker Rootless activo y respondiendo"
else
    check_status 1 "Docker Rootless no responde en $SOCK"
fi

# 5. Tipografías
echo -n "Tipografías del sistema (Google Sans / Fira)... "
if fc-list : family | grep -iq "Google Sans\|Fira Code"; then
    check_status 0 "Fuentes reconocidas por fontconfig"
else
    check_status 1 "No se encontraron Google Sans ni Fira Code"
fi

# 6. Enlaces simbólicos de dotfiles
echo -n "Integridad de dotfiles... "
missing=0
for f in "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.local/bin/devctl"; do
    if [ ! -e "$f" ]; then
        missing=1
        echo -e "\n  -> Falta: $f"
    fi
done
if [ $missing -eq 0 ]; then
    check_status 0 "Dotfiles principales enlazados correctamente"
else
    check_status 1 "Faltan dotfiles requeridos"
fi

# 7. Herramientas CLI críticas
echo "Disponibilidad de herramientas clave:"
for cmd in git gh uv fnm code antigravity; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null || [ -f "$HOME/.local/bin/$cmd" ]; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado en PATH"
    fi
done

echo "================================================================="
echo "Verificación finalizada."
echo "================================================================="
