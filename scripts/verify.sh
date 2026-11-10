#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH"

echo "================================================================="
echo "       Debian Stable Workstation - Verificación de Estado          "
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

# 0. Validación de sintaxis de scripts del repositorio
echo -n "Sintaxis Bash de scripts del repositorio... "
syntax_fail=0
for s in "$REPO_DIR"/host/*.sh "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/shell/devctl; do
    if [ -f "$s" ] && ! bash -n "$s" &>/dev/null; then
        syntax_fail=1
        echo -e "\n  -> Error de sintaxis en: ${s#"$REPO_DIR/"}"
    fi
done
if [ $syntax_fail -eq 0 ]; then
    check_status 0 "Todos los scripts pasaron 'bash -n' correctamente"
else
    check_status 1 "Se detectaron errores de sintaxis en scripts"
fi

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
if command -v podman &>/dev/null && { [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ] || [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" ]; }; then
    check_status 0 "Podman Rootless activo y operativo"
else
    check_status 1 "Podman Rootless no disponible o sin modo rootless"
fi

# 6. Tipografías del Sistema
echo -n "Tipografías del sistema (JetBrains Mono / Fira Code / Noto Sans / Adwaita Sans)... "
fonts_ok=0
INSTALLED_FONTS=$(fc-list : family 2>/dev/null || true)
for f in "JetBrains Mono" "Fira Code" "Noto Sans" "Adwaita Sans"; do
    if ! echo "$INSTALLED_FONTS" | grep -qi "$f"; then
        fonts_ok=1
    fi
done
if [ $fonts_ok -eq 0 ]; then
    check_status 0 "Fuentes reconocidas por fontconfig"
else
    check_status 1 "Faltan fuentes esenciales en fontconfig"
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
for cmd in git gh uv fnm code zed opencode antigravity agy podman yazi mc; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null || [ -f "$HOME/.local/bin/$cmd" ]; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado en PATH"
    fi
done

echo "Herramientas de shell productiva:"
for cmd in zoxide atuin starship tmux; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado (ejecuta 'make host')"
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
if [ -e /etc/apt/keyrings/docker.asc ]; then
    if ! grep -rh 'docker\.asc' "$SOURCES_D" --include='*.list' --include='*.sources' 2>/dev/null | grep -qv '^[[:space:]]*\(#\|$\)'; then
        echo -e "\n  -> Keyring huérfano: /etc/apt/keyrings/docker.asc"
        apt_ok=1
    fi
fi
if [ $apt_ok -eq 0 ]; then
    check_status 0 "Fuentes limpias, podman-only, keyrings presentes"
else
    check_status 1 "Se detectaron residuos de Docker o duplicados (ejecuta 'sudo bash scripts/apt-maintenance.sh')"
fi

# 10. Autenticación con GitHub (solo lectura, sin mutar credenciales)
echo -n "Login GitHub (SSH)... "
KEY_ARGS=()
[ -f "$HOME/.ssh/id_ed25519" ] && KEY_ARGS=(-i "$HOME/.ssh/id_ed25519")
SSH_REPLY=$(ssh -T "${KEY_ARGS[@]}" -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)
if echo "$SSH_REPLY" | grep -q "successfully authenticated"; then
    SSH_USER=$(echo "$SSH_REPLY" | sed -n 's/^Hi \([^!]*\)!.*/\1/p')
    check_status 0 "SSH autenticado como ${SSH_USER:-usuario}"
else
    check_status 1 "SSH con GitHub no autenticado (revisa ~/.ssh/id_ed25519)"
fi

echo -n "Login GitHub (gh CLI)... "
GH_USER=""
if command -v gh &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
fi
if [[ "$GH_USER" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
    check_status 0 "gh autenticado como $GH_USER"
else
    check_status 1 "gh CLI sin sesión activa (ejecuta 'gh auth login -h github.com -p ssh -w')"
fi

# 11. Personalizaciones de GNOME y Directorios de Trabajo
echo -n "Botones de control en ventanas (minimizar, maximizar, cerrar)... "
BTN_LAYOUT=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || echo "''")
if [[ "$BTN_LAYOUT" == *"minimize"* && "$BTN_LAYOUT" == *"maximize"* && "$BTN_LAYOUT" == *"close"* ]]; then
    check_status 0 "Configurados correctamente ($BTN_LAYOUT)"
else
    check_optional "Layout actual: $BTN_LAYOUT (ejecuta 'make desktop' para aplicar appmenu:minimize,maximize,close)"
fi

echo -n "Directorio dedicado de proyectos (XDG_PROJECTS_DIR)... "
PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
if [ -d "$PROJECTS_DIR" ]; then
    check_status 0 "Presente en $PROJECTS_DIR"
else
    check_status 1 "No encontrado en $PROJECTS_DIR"
fi

# 12. Ecosistema de Aplicaciones (Flatpak, AppImage y Repositorios Oficiales)
echo -n "Soporte Flatpak & Flathub... "
if command -v flatpak &>/dev/null; then
    if flatpak remotes 2>/dev/null | grep -q "flathub"; then
        check_status 0 "Flatpak instalado con repositorio Flathub activo"
    else
        check_optional "Flatpak presente pero Flathub no registrado (ejecuta 'make host')"
    fi
else
    check_status 1 "Flatpak no instalado"
fi

echo -n "Soporte AppImage (FUSE runtime)... "
if dpkg -s libfuse2t64 &>/dev/null || dpkg -s libfuse2 &>/dev/null || [ -e /usr/lib/x86_64-linux-gnu/libfuse.so.2 ]; then
    check_status 0 "Biblioteca FUSE 2 activa para AppImages"
else
    check_optional "libfuse2t64 / libfuse2 no detectado (opcional si no se usan AppImages FUSE 2)"
fi

echo -n "Directorio de aplicaciones portables/AppImages... "
APPIMAGE_DIR="${XDG_APPLICATIONS_DIR:-$HOME/Aplicaciones}"
if [ -d "$APPIMAGE_DIR" ]; then
    check_status 0 "Presente en $APPIMAGE_DIR"
else
    check_optional "No creado aún ($APPIMAGE_DIR)"
fi

echo -n "Repositorios oficiales de Debian Stable... "
EXT_REPOS=()
[ -f "/etc/apt/sources.list.d/debian-backports.sources" ] && EXT_REPOS+=("Backports")
if [ "${#EXT_REPOS[@]}" -gt 0 ]; then
    check_status 0 "Configurados: ${EXT_REPOS[*]}"
else
    check_optional "No configurados aún (se añaden en 'make host')"
fi

if [ -f "/etc/apt/sources.list.d/debian-fasttrack.sources" ]; then
    check_optional "FastTrack legacy detectado (se elimina con 'make host')"
fi

# 13. Perfil opcional Hyprland (no falla si no está instalado)
echo -n "Perfil Hyprland (opcional)... "
if ! command -v Hyprland &>/dev/null; then
    check_optional "No instalado (perfil opcional: ejecuta 'make hyprland')"
else
    check_status 0 "Instalado"

    echo -n "Componentes del escritorio Hyprland... "
    hypr_missing=()
    for cmd in Hyprland hyprctl waybar wofi mako hypridle hyprlock \
               swaync swaync-client swayosd-server swayosd-client \
               grim slurp wl-copy cliphist brightnessctl playerctl wpctl; do
        command -v "$cmd" &>/dev/null || hypr_missing+=("$cmd")
    done
    if command -v hyprpaper &>/dev/null || command -v swaybg &>/dev/null; then
        :
    else
        hypr_missing+=("hyprpaper|swaybg")
    fi
    if [ -x /usr/libexec/hyprpolkitagent ]; then
        :
    else
        hypr_missing+=("hyprpolkitagent")
    fi
    if [ "${#hypr_missing[@]}" -eq 0 ]; then
        check_status 0 "Binarios y agente polkit presentes"
    else
        check_status 1 "Faltan: ${hypr_missing[*]} (ejecuta 'make hyprland')"
    fi

    echo -n "Sesión de Hyprland en el display manager... "
    if [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
        check_status 0 "hyprland.desktop presente (GDM la detecta automáticamente)"
    else
        check_status 1 "No se encontró /usr/share/wayland-sessions/hyprland.desktop"
    fi

    echo -n "Portal de escritorio (screen sharing)... "
    if [ -f /usr/share/xdg-desktop-portal/portals/hyprland.portal ]; then
        if dpkg -s xdg-desktop-portal-gtk &>/dev/null; then
            check_status 0 "Portal Hyprland + fallback GTK presentes"
        else
            check_optional "Portal Hyprland presente (falta xdg-desktop-portal-gtk)"
        fi
    else
        check_status 1 "No se encontró hyprland.portal (ejecuta 'make hyprland')"
    fi

    echo -n "Configuración de Hyprland desplegada... "
    cfg_missing=()
    for f in "$HOME/.config/hypr/hyprland.conf" \
             "$HOME/.config/waybar/config.jsonc" \
             "$HOME/.config/wofi/config" \
             "$HOME/.config/mako/config" \
             "$HOME/.config/swaync/config.json"; do
        [ -e "$f" ] || cfg_missing+=("$f")
    done
    if [ "${#cfg_missing[@]}" -eq 0 ]; then
        check_status 0 "Symlinks de configuración presentes"
    else
        check_status 1 "Faltan: ${cfg_missing[*]} (ejecuta 'make hyprland')"
    fi

    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl &>/dev/null; then
        echo -n "Errores de configuración de Hyprland... "
        HYPR_ERRORS="$(hyprctl configerrors 2>/dev/null || true)"
        if [ -z "$HYPR_ERRORS" ] || echo "$HYPR_ERRORS" | grep -qiE '^no errors|config ok'; then
            check_status 0 "Sin errores de configuración"
        else
            check_status 1 "hyprctl reportó errores: $HYPR_ERRORS"
        fi
    fi
fi

echo "================================================================="
echo "Verificación finalizada."
echo "================================================================="
