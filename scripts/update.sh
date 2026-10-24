#!/usr/bin/env bash
# scripts/update.sh - Actualización idempotente de la estación (sin reconfigurar SSH/identidad)
#
# Filosofía: NO rompe la idempotencia de install. Es seguro ejecutarlo N veces.
#   - `make install`  -> converge todo desde cero (re-ejecutable).
#   - `make update`   -> higiene APT (apt-maintenance.sh) + fast-forward:
#     APT only-upgrade + self-updates user-space.
# No toca: claves SSH, `gh auth`, `/opt/Antigravity` (requiere tarball manual),
#   shell por defecto (chsh), linger, ni registros de Podman.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

warn() { echo "  ⚠️ $1"; }
ok()   { echo "  ✔ $1"; }
step() { echo; echo "==> $1"; }

# ------------------------------------------------------------------------------
# 0. Pre-vuelos (no fatal)
# ------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    echo "[-] Ejecuta sin sudo: bash scripts/update.sh (usará sudo solo para APT)."
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Higiene APT + only-upgrade de paquetes gestionados (no full-upgrade)
# ------------------------------------------------------------------------------
step "Higiene APT previa (fuentes Docker, duplicados, reparaciones)..."
sudo bash "$SCRIPT_DIR/apt-maintenance.sh" || warn "apt-maintenance falló, continúo."

step "Actualizando paquetes APT gestionados (--only-upgrade)..."
if command -v apt-get &>/dev/null; then
    sudo apt-get update -y || warn "apt-get update falló, continúo con caché local."

    # Candidatos gestionados por host/setup.sh, host/timeshift.sh, ohmyzsh.sh, devtools.sh y tooling.sh.
    CANDIDATES=(
        git curl wget jq unzip zip ca-certificates gnupg lsb-release
        build-essential
        ripgrep fd-find fzf bat btop direnv wl-clipboard
        fonts-firacode fonts-jetbrains-mono fonts-noto-core
        gnome-shell-extension-dashtodock
        flatpak gnome-software-plugin-flatpak xdg-desktop-portal-gnome
        libglib2.0-bin
        fuse3 libfuse2t64 libfuse2 fasttrack-archive-keyring
        uidmap dbus-user-session iptables
        podman crun buildah skopeo podman-compose passt slirp4netns catatonit
        timeshift cron
        zsh gh
    )
    # VS Code si su repo está configurado (legacy .list o DEB822 .sources);
    # Chrome solo si está instalado.
    if [ -f /etc/apt/sources.list.d/vscode.list ] || [ -f /etc/apt/sources.list.d/vscode.sources ]; then
        CANDIDATES+=(code)
    fi
    if dpkg -s google-chrome-stable &>/dev/null; then
        CANDIDATES+=(google-chrome-stable)
    fi

    # Filtrar a paquetes realmente instalados (--only-upgrade no instala nuevos,
    # pero filtrar evita ruido y errores si el repo de un candidato falta).
    TO_UPGRADE=()
    for pkg in "${CANDIDATES[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            TO_UPGRADE+=("$pkg")
        fi
    done

    if [ "${#TO_UPGRADE[@]}" -gt 0 ]; then
        sudo apt-get install --only-upgrade -y "${TO_UPGRADE[@]}" || warn "APT only-upgrade parcial, revisa con 'sudo apt-get upgrade'."
        ok "APT actualizado: ${TO_UPGRADE[*]}"
    else
        ok "APT: nada que actualizar (ningún gestionado instalado)."
    fi
else
    warn "apt-get no disponible, omitiendo."
fi

# ------------------------------------------------------------------------------
# 2. Managers user-space: uv, fnm, sdkman
# ------------------------------------------------------------------------------
step "Actualizando uv (Python)..."
if command -v uv &>/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
    (uv self update 2>/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh) || warn "no se pudo actualizar uv."
    ok "uv: $("$HOME/.local/bin/uv" --version 2>/dev/null || uv --version 2>/dev/null || echo presente)"
else
    warn "uv no instalado (ejecuta 'make devtools')."
fi

step "Actualizando fnm (Node)..."
if command -v fnm &>/dev/null || [ -d "$HOME/.local/share/fnm" ]; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell || warn "no se pudo actualizar fnm."
    ok "fnm actualizado."
else
    warn "fnm no instalado (ejecuta 'make devtools')."
fi

step "Actualizando sdkman (JVM)..."
if [ -d "$HOME/.sdkman" ]; then
    # shellcheck disable=SC1091
    (source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk selfupdate) || warn "no se pudo auto-actualizar sdkman."
    ok "sdkman actualizado (candidatos java/node no se tocan)."
else
    warn "sdkman no instalado (ejecuta 'make devtools')."
fi

# ------------------------------------------------------------------------------
# 3. Editores/navegadores nativos (APT ya cubrió code/chrome; aquí Zed)
# ------------------------------------------------------------------------------
step "Actualizando Zed editor..."
if command -v zed &>/dev/null || [ -f "$HOME/.local/bin/zed" ]; then
    curl -f https://zed.dev/install.sh | sh || warn "no se pudo actualizar Zed."
    ok "Zed actualizado."
else
    warn "Zed no instalado (ejecuta 'make tooling')."
fi

# ------------------------------------------------------------------------------
# 4. IA: OpenCode CLI + Antigravity CLI (+ convergencia /opt sin re-extraer)
# ------------------------------------------------------------------------------
step "Actualizando OpenCode CLI..."
if command -v opencode &>/dev/null; then
    curl -fsSL https://opencode.ai/v2/install | bash || warn "no se pudo actualizar OpenCode."
    ok "OpenCode actualizado."
else
    warn "opencode no instalado (ejecuta 'make devai')."
fi

step "Convergencia Antigravity (/opt + CLI)..."
# setup_agy.sh es idempotente: si el tarball de Descargas es más nuevo que
# /opt re-extrae; si no, solo verifica symlink/.desktop/CLI. Barato y seguro.
bash "$SCRIPT_DIR/setup_agy.sh" || warn "setup_agy.sh falló."
# Forzar CLI a última versión aunque ya existiera (setup_agy solo instala si falta).
if command -v antigravity &>/dev/null || [ -f "$HOME/.local/bin/antigravity" ] || [ -f /usr/local/bin/antigravity ]; then
    curl -fsSL https://antigravity.google/cli/install.sh | bash || warn "no se pudo actualizar Antigravity CLI."
    ok "Antigravity CLI actualizado."
fi

# ------------------------------------------------------------------------------
# 5. Oh My Zsh + plugins (git fast-forward, no reinstala, no chsh)
# ------------------------------------------------------------------------------
step "Actualizando Oh My Zsh y plugins..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    git -C "$HOME/.oh-my-zsh" pull --ff-only -q || warn "OMZ core no avanzó (divergió o sin red)."
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        PLUGIN_DIR="$HOME/.oh-my-zsh/custom/plugins/$plugin"
        if [ -d "$PLUGIN_DIR" ]; then
            git -C "$PLUGIN_DIR" pull -q --ff-only || warn "$plugin no avanzó."
        fi
    done
    ok "Oh My Zsh y plugins al día."
else
    warn "Oh My Zsh no instalado (ejecuta 'make shell')."
fi

# ------------------------------------------------------------------------------
# 6. Podman Rootless: reiniciar socket + verificar (sin migrate disruptivo)
# ------------------------------------------------------------------------------
step "Verificando Podman Rootless..."
if command -v podman &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user restart podman.socket 2>/dev/null || systemctl --user start podman.socket 2>/dev/null || warn "no se pudo (re)iniciar podman.socket."
    if [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = "true" ] || [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" ]; then
        ok "Podman Rootless operativo ($(podman --version))."
    else
        warn "Podman no reporta modo Rootless (ejecuta 'make podman')."
    fi
else
    warn "podman no instalado (ejecuta 'make host')."
fi

# ------------------------------------------------------------------------------
# 7. Tipografías: refrescar caché (fc-cache)
# ------------------------------------------------------------------------------
step "Refrescando caché de tipografías (fc-cache)..."
fc-cache -f 2>/dev/null || true
ok "Caché de tipografías al día."

# ------------------------------------------------------------------------------
# 8. Flatpak: actualizar aplicaciones de escritorio de usuario
# ------------------------------------------------------------------------------
if command -v flatpak &>/dev/null; then
    step "Actualizando aplicaciones Flatpak..."
    flatpak update -y 2>/dev/null || warn "flatpak update devolvió advertencias."
    ok "Aplicaciones Flatpak al día."
fi

echo
echo "================================================================="
echo "✔ Update completado (idempotente). Valida con: make verify"
echo "  Nota: no se tocó SSH/gh auth, /opt (sin tarball nuevo), ni chsh."
echo "================================================================="
