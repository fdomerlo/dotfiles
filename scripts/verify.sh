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
if lsmod | grep "^amdgpu" >/dev/null 2>&1; then
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

# 4. Podman Rootless
echo -n "Podman Rootless... "
if command -v podman &>/dev/null && [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ]; then
    check_status 0 "Podman Rootless activo y operativo"
else
    check_status 1 "Podman Rootless no disponible o sin modo rootless"
fi

# 5. Tipografías
echo -n "Tipografías del sistema (Google Sans / Fira)... "
if fc-list : family | grep -iE "Google Sans|Fira Code" >/dev/null 2>&1; then
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
for cmd in git gh uv fnm code antigravity podman; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null || [ -f "$HOME/.local/bin/$cmd" ]; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado en PATH"
    fi
done

# 8. Higiene APT (solo lectura: podman-only, sin duplicados, keyrings presentes)
echo -n "Higiene APT (podman-only, sin duplicados)... "
apt_ok=0
SOURCES_D="/etc/apt/sources.list.d"
[ -e "$SOURCES_D/docker.list" ] && { echo -e "\n  -> Persiste fuente activa: docker.list"; apt_ok=1; }
[ -e "$SOURCES_D/docker.sources" ] && { echo -e "\n  -> Persiste fuente activa: docker.sources"; apt_ok=1; }
if [ -f "$SOURCES_D/vscode.list" ] && [ -f "$SOURCES_D/vscode.sources" ]; then
    echo -e "\n  -> VS Code duplicado (vscode.list + vscode.sources)"
    apt_ok=1
fi
for pkg in docker-ce docker-ce-cli containerd.io docker.io; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "\n  -> Paquete Docker instalado: $pkg"
        apt_ok=1
    fi
done
while IFS= read -r key; do
    if [ -n "$key" ] && [ ! -e "$key" ]; then
        echo -e "\n  -> Keyring referenciado inexistente: $key"
        apt_ok=1
    fi
done < <( { sed -n 's/.*signed-by=\([^]]*\).*/\1/p' "$SOURCES_D"/*.list 2>/dev/null; \
            sed -n 's/^Signed-By:[[:space:]]*//p' "$SOURCES_D"/*.sources 2>/dev/null; } | sort -u )
if [ $apt_ok -eq 0 ]; then
    check_status 0 "Fuentes limpias, podman-only, keyrings presentes"
else
    check_status 1 "Hay higiene APT pendiente (ejecuta 'make update')"
fi

echo "================================================================="
echo "Verificación finalizada."
echo "================================================================="
