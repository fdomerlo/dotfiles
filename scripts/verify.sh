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

check_optional() {
    echo -e " [ \033[33mINFO\033[0m ] $1"
}

# 1. Controlador de Gráficos (AMD / Intel)
echo -n "Controlador de gráficos (DRM/GPU)... "
LOADED_GPU=$(lsmod | awk '/^(amdgpu|i915|xe)[[:space:]]/ {print $1}' | head -n1 || true)
if [ -n "$LOADED_GPU" ]; then
    check_status 0 "Módulo $LOADED_GPU cargado en el kernel"
else
    check_status 1 "Ningún módulo DRM acelerado (amdgpu/i915/xe) detectado"
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

# 4. Timeshift (Opcional)
echo -n "Timeshift (Snapshots - opcional)... "
if command -v timeshift &>/dev/null && [ -f /etc/timeshift/timeshift.json ]; then
    check_status 0 "Timeshift instalado y configurado (/etc/timeshift/timeshift.json)"
else
    check_optional "No instalado (opcional: ejecuta 'make timeshift' si lo requieres)"
fi

# 5. Podman Rootless
echo -n "Podman Rootless... "
if command -v podman &>/dev/null && [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ]; then
    check_status 0 "Podman Rootless activo y operativo"
else
    check_status 1 "Podman Rootless no disponible o sin modo rootless"
fi

# 6. Tipografías
echo -n "Tipografías del sistema (Google Sans / Fira)... "
if fc-list : family | grep -iE "Google Sans|Fira Code" >/dev/null 2>&1; then
    check_status 0 "Fuentes reconocidas por fontconfig"
else
    check_status 1 "No se encontraron Google Sans ni Fira Code"
fi

# 7. Enlaces simbólicos de dotfiles
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

# 8. Herramientas CLI críticas
echo "Disponibilidad de herramientas clave:"
for cmd in git gh uv fnm code zed antigravity podman; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null || [ -f "$HOME/.local/bin/$cmd" ]; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado en PATH"
    fi
done

# 9. Higiene APT (solo lectura: podman-only, sin duplicados, keyrings presentes)
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

# 10. Login en GitHub (solo lectura: SSH + gh CLI, sin prompts)
echo -n "Login GitHub (SSH)... "
SSH_KEY_ARGS=()
[ -f "$HOME/.ssh/id_ed25519" ] && SSH_KEY_ARGS=(-i "$HOME/.ssh/id_ed25519")
SSH_REPLY=$(ssh -T "${SSH_KEY_ARGS[@]}" -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)
if echo "$SSH_REPLY" | grep -q "successfully authenticated"; then
    SSH_USER=$(echo "$SSH_REPLY" | sed -n 's/^Hi \([^!]*\)!.*/\1/p')
    check_status 0 "SSH autenticado como ${SSH_USER:-usuario}"
else
    check_status 1 "SSH con GitHub no autenticado (ejecuta 'make devtools')"
fi
echo -n "Login GitHub (gh CLI)... "
# Ojo: `gh auth status` puede devolver 0 con un token muerto; la única prueba
# fiable es llamar a la API y validar forma de usuario GitHub.
GH_USER=""
if command -v gh &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
fi
if [[ "$GH_USER" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
    check_status 0 "gh autenticado como $GH_USER"
else
    check_status 1 "gh sin sesión válida (ejecuta 'gh auth login -h github.com -p ssh -w')"
fi

echo "================================================================="
echo "Verificación finalizada."
echo "================================================================="
