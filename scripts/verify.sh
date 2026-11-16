#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH"

# shellcheck source=scripts/lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"

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

# 0. Validación de sintaxis de scripts del repositorio y manifiestos
echo -n "Sintaxis Bash de scripts del repositorio... "
syntax_fail=0
for s in "$REPO_DIR"/host/*.sh "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/scripts/lib/*.sh "$REPO_DIR"/hypr/scripts/*.sh "$REPO_DIR"/shell/devctl; do
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

echo -n "Manifiestos de paquetes (packages/)... "
manifest_fail=0
for m in apt-base.txt apt-optional.txt apt-backports.txt apt-hyprland.txt flatpak.txt external.txt; do
    mpath="$REPO_DIR/packages/$m"
    _tmp_items=()
    if ! read_manifest "$mpath" _tmp_items 2>/dev/null || [ "${#_tmp_items[@]}" -eq 0 ]; then
        manifest_fail=1
        echo -e "\n  -> Inválido o vacío: packages/$m"
    fi
done
if [ $manifest_fail -eq 0 ]; then
    check_status 0 "6 manifiestos válidos en packages/"
else
    check_status 1 "Faltan o fallaron manifiestos en packages/"
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
echo -n "Swapfile de respaldo (>= RAM)... "
if grep -q "swapfile" /proc/swaps && [ -f /swapfile ]; then
    ram_kib=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    ram_gib=$(( (ram_kib + 1048575) / 1048576 ))
    [ "$ram_gib" -lt 4 ] && ram_gib=4
    swap_bytes=$(stat -c%s /swapfile 2>/dev/null || echo 0)
    target_bytes=$(( ram_gib * 1024 * 1024 * 1024 ))
    if [ "$swap_bytes" -ge "$target_bytes" ]; then
        check_status 0 "Swapfile activo ($(( swap_bytes / 1024 / 1024 / 1024 )) GiB >= ${ram_gib} GiB RAM)"
    else
        check_optional "Swapfile activo ($(( swap_bytes / 1024 / 1024 )) MiB < ${ram_gib} GiB RAM; ejecutá 'make host' para redimensionar)"
    fi
else
    check_status 1 "Swapfile secundario no activo"
fi

# 3b. Hibernación y energía (suspend-then-hibernate)
echo -n "Energía e hibernación (suspend-then-hibernate)... "
if [ -f /etc/systemd/sleep.conf.d/10-workstation-power.conf ] && \
   [ -f /etc/systemd/logind.conf.d/10-workstation-power.conf ] && \
   [ -x /usr/local/libexec/workstation-hibernate-delay ] && \
   [ -f /etc/default/grub.d/99-hibernate.cfg ]; then
    can_sth=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspendThenHibernate 2>/dev/null | awk -F'"' '{print $2}' || true)
    if [ "$can_sth" = "yes" ]; then
        if grep -q 'resume=' /proc/cmdline; then
            check_status 0 "Hibernación y suspend-then-hibernate operativos"
        else
            check_optional "Configurado en disco; reiniciá para activar resume= en el kernel"
        fi
    elif [ -r /sys/power/disk ] && grep -q '\[disabled\]' /sys/power/disk 2>/dev/null; then
        check_optional "Secure Boot activo (kernel lockdown bloquea hibernación; desactivalo en UEFI/BIOS para habilitar 30/40 min)"
    else
        check_optional "Configurado, pero CanSuspendThenHibernate='${can_sth:-desconocido}' (revisá reboot o tamaño de swapfile)"
    fi
else
    check_optional "Falta política de energía del sistema (ejecutá 'make host')"
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

# 6. Tipografías Base (paquetes Debian)
echo -n "Tipografías base (JetBrains Mono / Noto Sans)... "
fonts_ok=0
INSTALLED_FONTS=$(fc-list : family 2>/dev/null || true)
for f in "JetBrains Mono" "Noto Sans"; do
    if ! grep -iq "$f" <<<"$INSTALLED_FONTS"; then
        fonts_ok=1
    fi
done
if [ $fonts_ok -eq 0 ]; then
    check_status 0 "Fuentes base reconocidas por fontconfig"
else
    check_status 1 "Faltan fuentes base en fontconfig (ejecuta 'make host')"
fi

# 7. Enlaces simbólicos de dotfiles e identidad Git local
echo -n "Integridad de dotfiles... "
missing=0
for f in "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.local/bin/devctl" \
         "$HOME/.config/nvim/init.lua" "$HOME/.config/zathura/zathurarc" \
         "$HOME/.config/lazydocker/config.yml"; do
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

echo -n "Identidad Git local (user.name / user.email)... "
GIT_NAME=$(git config --includes --global --get user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --includes --global --get user.email 2>/dev/null || true)
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    check_status 0 "$GIT_NAME <$GIT_EMAIL>"
else
    check_status 1 "Falta user.name o user.email (ejecuta 'make gitconfig')"
fi

# 8. Herramientas CLI críticas
echo "Disponibilidad de herramientas clave:"
for cmd in git gh uv fnm code zed nvim opencode antigravity agy podman yazi mc lazydocker; do
    echo -n "  -> $cmd: "
    if command -v "$cmd" &>/dev/null || [ -f "$HOME/.local/bin/$cmd" ]; then
        check_status 0 "Presente"
    else
        check_status 1 "No encontrado en PATH"
    fi
done

# 8b. IA integrada (OpenCode + skill) y virtualización opcional
echo -n "Skills del repo para OpenCode: "
skills_total=0
skills_missing=0
shopt -s nullglob
for skill_md in "$REPO_DIR"/ai/skills/*/SKILL.md; do
    skills_total=$((skills_total + 1))
    skill_name="$(basename "$(dirname "$skill_md")")"
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/$skill_name/SKILL.md" ] || skills_missing=$((skills_missing + 1))
done
shopt -u nullglob
if [ "$skills_total" -eq 0 ]; then
    check_optional "No hay skills versionadas en ai/skills/"
elif [ "$skills_missing" -eq 0 ]; then
    check_status 0 "$skills_total enlazada(s)"
else
    check_optional "$skills_missing de $skills_total sin enlazar (ejecuta 'make devai')"
fi

echo -n "Acciones IA de Hyprland (ai.sh): "
if [ -x "$HOME/.config/hypr/scripts/ai.sh" ]; then
    check_status 0 "Presente"
else
    check_optional "No instalada (ejecuta 'make hyprland' o 'make refresh')"
fi

echo -n "Virtualización (Quickemu + /dev/kvm): "
if command -v quickemu &>/dev/null && [ -c /dev/kvm ]; then
    check_status 0 "Disponible"
elif command -v quickemu &>/dev/null; then
    check_optional "Quickemu instalado, pero /dev/kvm ausente (revisa BIOS/grupo kvm)"
else
    check_optional "No instalada (opcional: 'make virt')"
fi

echo -n "  -> firefox (navegador default): "
if (command -v flatpak &>/dev/null && flatpak info org.mozilla.firefox &>/dev/null) || command -v firefox &>/dev/null || command -v firefox-esr &>/dev/null; then
    DEF_BROWSER="$(xdg-settings get default-web-browser 2>/dev/null || true)"
    if [[ "$DEF_BROWSER" == *firefox* ]]; then
        check_status 0 "Presente y predeterminado ($DEF_BROWSER)"
    else
        check_optional "Presente, pero default actual es '${DEF_BROWSER:-ninguno}' (ejecuta 'make tooling')"
    fi
else
    check_optional "No instalado aún (ejecuta 'make tooling' para instalar Firefox)"
fi

echo -n "  -> google-chrome (soporte PWAs): "
if command -v google-chrome &>/dev/null; then
    check_status 0 "Presente"
else
    check_optional "No instalado aún (ejecuta 'make tooling' para habilitar PWAs con Chrome)"
fi

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
if [ -f "$SOURCES_D/google-chrome.list" ] && [ -f "$SOURCES_D/google-chrome.sources" ]; then
    echo -e "\n  -> Google Chrome duplicado (google-chrome.list + google-chrome.sources)"
    apt_ok=1
fi
for pkg in docker-ce docker-ce-cli containerd.io docker.io; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo -e "\n  -> Paquete Docker instalado: $pkg"
        apt_ok=1
    fi
done
if [ -e /etc/apt/keyrings/docker.asc ]; then
    if ! grep -rh 'docker\.asc' "$SOURCES_D" --include='*.list' --include='*.sources' 2>/dev/null | grep -v '^[[:space:]]*\(#\|$\)' >/dev/null; then
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
if grep -q "successfully authenticated" <<<"$SSH_REPLY"; then
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

# 11. Directorios de Trabajo y GNOME Fallback estándar
echo -n "Directorio dedicado de proyectos (XDG_PROJECTS_DIR)... "
PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
if [ -d "$PROJECTS_DIR" ]; then
    check_status 0 "Presente en $PROJECTS_DIR"
else
    check_status 1 "No encontrado en $PROJECTS_DIR"
fi

if dpkg -s gnome-shell-extension-dashtodock &>/dev/null; then
    echo -n "GNOME estándar (fallback limpio)... "
    check_optional "Paquete residual gnome-shell-extension-dashtodock instalado (purgar con: sudo apt-get purge -y gnome-shell-extension-dashtodock)"
fi

# 12. Ecosistema de Aplicaciones (Flatpak, AppImage y Repositorios Oficiales)
echo -n "Soporte Flatpak & Flathub... "
if command -v flatpak &>/dev/null; then
    if flatpak remotes 2>/dev/null | grep -q "flathub"; then
        check_status 0 "Flatpak instalado con repositorio Flathub activo"
    else
        check_optional "Flatpak presente pero Flathub no registrado (ejecuta 'make host')"
    fi
    echo -n "Aplicaciones Flatpak (packages/flatpak.txt)... "
    FLATPAK_APPS=()
    read_manifest "$REPO_DIR/packages/flatpak.txt" FLATPAK_APPS
    fp_installed=0
    fp_missing=()
    for app_id in "${FLATPAK_APPS[@]}"; do
        if flatpak info "$app_id" &>/dev/null; then
            fp_installed=$((fp_installed + 1))
        else
            fp_missing+=("$app_id")
        fi
    done
    if [ "${#fp_missing[@]}" -eq 0 ]; then
        check_status 0 "${fp_installed}/${#FLATPAK_APPS[@]} instaladas"
    else
        check_optional "${fp_installed}/${#FLATPAK_APPS[@]} instaladas (ausentes: ${fp_missing[*]})"
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

# 13. Escritorio Hyprland (GNOME estándar queda como fallback)
echo -n "Escritorio Hyprland... "
if ! command -v Hyprland &>/dev/null; then
    check_optional "No instalado (instalación base; agrega Hyprland con 'make hyprland')"
else
    check_status 0 "Instalado"

    echo -n "Componentes del escritorio Hyprland... "
    # shellcheck source=scripts/hyprland-packages.sh
    source "$REPO_DIR/scripts/hyprland-packages.sh"
    hypr_missing=()
    for cmd in "${HYPR_REQUIRED_BINS[@]}"; do
        command -v "$cmd" &>/dev/null || hypr_missing+=("$cmd")
    done
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

    echo -n "Tipografías Debian para Hyprland (Inter / Atkinson Hyperlegible / JetBrains Mono)... "
    hypr_fonts_missing=()
    for f in "Inter" "Atkinson Hyperlegible" "JetBrains Mono"; do
        if ! grep -iqE "(^|,)${f}(,|$)" <<<"$INSTALLED_FONTS"; then
            hypr_fonts_missing+=("$f")
        fi
    done
    if [ "${#hypr_fonts_missing[@]}" -eq 0 ]; then
        check_status 0 "Presentes en fontconfig"
    else
        check_optional "Faltan: ${hypr_fonts_missing[*]} (ejecuta 'make hyprland' o 'sudo apt-get install -y fonts-inter fonts-atkinson-hyperlegible fonts-jetbrains-mono')"
    fi

    echo -n "Cursor Bibata para Hyprland (bibata-cursor-theme)... "
    if [ -d /usr/share/icons/Bibata-Modern-Classic ] || [ -d "$HOME/.local/share/icons/Bibata-Modern-Classic" ]; then
        check_status 0 "Bibata-Modern-Classic presente"
    else
        check_optional "Bibata-Modern-Classic no encontrado (ejecuta 'make hyprland' o 'sudo apt-get install -y bibata-cursor-theme')"
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
             "$HOME/.config/hypr/hypridle.conf" \
             "$HOME/.config/hypr/scripts/idle-suspend.sh" \
             "$HOME/.config/hypr/conf/plugins.conf" \
             "$HOME/.config/hypr/conf/local.conf" \
             "$HOME/.config/hypr/conf/webapps.conf" \
             "$HOME/.config/fontconfig/conf.d/10-hyprland-fonts.conf" \
             "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" \
             "$HOME/.config/waybar/config.jsonc" \
             "$HOME/.config/waybar/local.jsonc" \
             "$HOME/.config/fuzzel/fuzzel.ini" \
             "$HOME/.config/foot/foot.ini" \
             "$HOME/.config/swappy/config" \
             "$HOME/.config/swaync/config.json" \
             "$HOME/.config/quickshell/shell.qml" \
             "$HOME/.config/quickshell/WallpaperBadge.qml"; do
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
        if [ -z "$HYPR_ERRORS" ] || grep -iqE '^no errors|config ok' <<<"$HYPR_ERRORS"; then
            check_status 0 "Sin errores de configuración"
        else
            check_status 1 "hyprctl reportó errores: $HYPR_ERRORS"
        fi

        echo -n "Agente SSH y Keyring en sesión... "
        KEYRING_COUNT=$(pgrep -u "$USER" -f '(^|/)gnome-keyring-daemon([[:space:]]|$)' 2>/dev/null | wc -l || echo 0)
        if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ] && [ "$KEYRING_COUNT" -le 1 ]; then
            check_status 0 "SSH_AUTH_SOCK activo (${SSH_AUTH_SOCK}), keyring=${KEYRING_COUNT}"
        elif [ "$KEYRING_COUNT" -gt 1 ]; then
            check_optional "Instancias duplicadas de gnome-keyring-daemon ($KEYRING_COUNT); se normalizará al reiniciar sesión"
        else
            check_optional "SSH_AUTH_SOCK no apunta a un socket activo (${SSH_AUTH_SOCK:-unset})"
        fi
    fi
fi

echo "================================================================="
echo "Verificación finalizada."
echo "================================================================="
