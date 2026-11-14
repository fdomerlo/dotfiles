#!/usr/bin/env bash
# scripts/update.sh - Actualización idempotente de la estación (sin reconfigurar SSH/identidad)
#
# Filosofía: NO rompe la idempotencia de install. Es seguro ejecutarlo N veces.
#   - `make install`  -> converge todo desde cero (re-ejecutable).
#   - `make update`   -> higiene APT (apt-maintenance.sh) + fast-forward:
#     APT only-upgrade (desde manifiestos en packages/) + self-updates user-space.
# No toca: claves SSH, `gh auth`, `/opt/Antigravity` (requiere tarball manual),
#   shell por defecto (chsh), linger, ni registros de Podman.
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSHRC_REPO="$REPO_DIR/shell/zshrc"

# shellcheck source=scripts/lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"

warn() { echo "  ⚠️ $1"; }
ok()   { echo "  ✔ $1"; }
step() { echo; echo "==> $1"; }

# Guarda para evitar que instaladores remotos ensucien shell/zshrc versionado
run_with_zshrc_guard() {
    local snapshot="" rc=0
    if [[ -f "$ZSHRC_REPO" ]]; then
        snapshot="$(mktemp)"
        cp "$ZSHRC_REPO" "$snapshot"
    fi

    "$@" || rc=$?

    if [[ -n "$snapshot" ]]; then
        if [[ -f "$ZSHRC_REPO" ]] && ! cmp -s "$snapshot" "$ZSHRC_REPO"; then
            cp "$snapshot" "$ZSHRC_REPO"
        fi
        rm -f "$snapshot"
    fi
    return "$rc"
}

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

    BASE_APT_PKGS=()
    OPT_APT_PKGS=()
    read_manifest "$REPO_DIR/packages/apt-base.txt" BASE_APT_PKGS
    read_manifest "$REPO_DIR/packages/apt-optional.txt" OPT_APT_PKGS

    # Paquetes del perfil opcional Hyprland: compartidos con scripts/hyprland.sh.
    # shellcheck source=scripts/hyprland-packages.sh
    source "$SCRIPT_DIR/hyprland-packages.sh"

    CANDIDATES=(
        "${BASE_APT_PKGS[@]}"
        "${OPT_APT_PKGS[@]}"
        "${HYPR_BACKPORTS_PKGS[@]}"
        "${HYPR_MAIN_PKGS[@]}"
    )

    # Deduplicar preservando el orden: hay paquetes compartidos entre manifiestos.
    mapfile -t CANDIDATES < <(printf '%s\n' "${CANDIDATES[@]}" | awk '!seen[$0]++')

    # Filtrar a paquetes realmente instalados (--only-upgrade no instala nuevos,
    # pero filtrar evita ruido y errores si el repo de un candidato falta).
    TO_UPGRADE=()
    for pkg in "${CANDIDATES[@]}"; do
        if [ "$pkg" = "code" ] && [ ! -f /etc/apt/sources.list.d/vscode.list ] && [ ! -f /etc/apt/sources.list.d/vscode.sources ]; then
            continue
        fi
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
# 2. Managers user-space: gh, uv, fnm, sdkman, yazi, lazydocker
# ------------------------------------------------------------------------------
step "Actualizando GitHub CLI (gh user-space)..."
if [ -x "$HOME/.local/bin/gh" ]; then
    DET_ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [ "$DET_ARCH" = "amd64" ] || [ "$DET_ARCH" = "x86_64" ]; then
        GH_ARCH="amd64"
    elif [ "$DET_ARCH" = "arm64" ] || [ "$DET_ARCH" = "aarch64" ]; then
        GH_ARCH="arm64"
    else
        GH_ARCH=""
    fi
    if [ -n "$GH_ARCH" ]; then
        GH_LATEST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest 2>/dev/null || echo "")
        GH_VERSION="${GH_LATEST_URL##*/}"
        GH_CUR_VER="$("$HOME/.local/bin/gh" --version 2>/dev/null | awk '/^gh version / {print $3; exit}' || true)"
        if [ -n "$GH_VERSION" ] && [ "$GH_VERSION" != "latest" ]; then
            if [ -n "$GH_CUR_VER" ] && [ "$GH_CUR_VER" = "${GH_VERSION#v}" ]; then
                ok "gh ya está al día ($GH_VERSION)."
            else
                TMP_DIR=$(mktemp -d)
                GH_VER_NUM="${GH_VERSION#v}"
                if curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VER_NUM}_linux_${GH_ARCH}.tar.gz" -o "$TMP_DIR/gh.tar.gz" 2>/dev/null \
                    && tar -xzf "$TMP_DIR/gh.tar.gz" -C "$TMP_DIR" --strip-components=1 2>/dev/null \
                    && [ -f "$TMP_DIR/bin/gh" ]; then
                    mv "$TMP_DIR/bin/gh" "$HOME/.local/bin/gh"
                    chmod +x "$HOME/.local/bin/gh"
                    ok "gh actualizado ($GH_VERSION)."
                else
                    warn "no se pudo descargar actualización de gh."
                fi
                rm -rf "$TMP_DIR"
            fi
        fi
    fi
elif command -v gh &>/dev/null; then
    ok "gh gestionado fuera de ~/.local/bin."
else
    warn "gh no instalado (ejecuta 'make devtools')."
fi

step "Actualizando uv (Python)..."
if command -v uv &>/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
    (uv self update 2>/dev/null || curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh) || warn "no se pudo actualizar uv."
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

step "Actualizando Yazi (Terminal File Manager)..."
if command -v yazi &>/dev/null || [ -f "$HOME/.local/bin/yazi" ]; then
    DET_ARCH=$(dpkg --print-architecture)
    if [ "$DET_ARCH" = "amd64" ]; then
        YAZI_TARGET="x86_64-unknown-linux-gnu"
    elif [ "$DET_ARCH" = "arm64" ]; then
        YAZI_TARGET="aarch64-unknown-linux-gnu"
    else
        YAZI_TARGET=""
    fi
    if [ -n "$YAZI_TARGET" ]; then
        YAZI_LATEST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/sxyazi/yazi/releases/latest 2>/dev/null || echo "")
        YAZI_VERSION="${YAZI_LATEST_URL##*/}"
        YAZI_CUR_VER="$(yazi --version 2>/dev/null | awk '/Version:/ {print $2; exit} /^Yazi [0-9]/ {print $2; exit}' || true)"
        if [ -n "$YAZI_VERSION" ] && [ "$YAZI_VERSION" != "latest" ]; then
            if [ -n "$YAZI_CUR_VER" ] && [ "$YAZI_CUR_VER" = "${YAZI_VERSION#v}" ]; then
                ok "Yazi ya está al día ($YAZI_VERSION)."
            else
                TMP_DIR=$(mktemp -d)
                if curl -fsSL -o "$TMP_DIR/yazi.zip" "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_TARGET}.zip" 2>/dev/null \
                    && unzip -tq "$TMP_DIR/yazi.zip" >/dev/null 2>&1; then
                    unzip -q "$TMP_DIR/yazi.zip" -d "$TMP_DIR"
                    mv "$TMP_DIR/yazi-${YAZI_TARGET}/yazi" "$HOME/.local/bin/yazi"
                    [ -f "$TMP_DIR/yazi-${YAZI_TARGET}/ya" ] && mv "$TMP_DIR/yazi-${YAZI_TARGET}/ya" "$HOME/.local/bin/ya" && chmod +x "$HOME/.local/bin/ya"
                    chmod +x "$HOME/.local/bin/yazi"
                    ok "Yazi actualizado ($YAZI_VERSION)."
                else
                    warn "no se pudo descargar actualización de Yazi."
                fi
                rm -rf "$TMP_DIR"
            fi
        fi
    fi
else
    warn "yazi no instalado (ejecuta 'make devtools')."
fi

step "Actualizando Lazydocker (TUI Contenedores)..."
if command -v lazydocker &>/dev/null || [ -f "$HOME/.local/bin/lazydocker" ]; then
    DET_ARCH=$(dpkg --print-architecture)
    if [ "$DET_ARCH" = "amd64" ]; then
        LZD_ARCH="x86_64"
    elif [ "$DET_ARCH" = "arm64" ]; then
        LZD_ARCH="arm64"
    else
        LZD_ARCH=""
    fi
    if [ -n "$LZD_ARCH" ]; then
        LZD_LATEST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazydocker/releases/latest 2>/dev/null || echo "")
        LZD_VERSION="${LZD_LATEST_URL##*/}"
        LZD_CUR_VER="$(lazydocker --version 2>/dev/null | awk -F': ' '/^Version:/ {print $2; exit}' || true)"
        if [ -n "$LZD_VERSION" ] && [ "$LZD_VERSION" != "latest" ]; then
            if [ -n "$LZD_CUR_VER" ] && [ "$LZD_CUR_VER" = "${LZD_VERSION#v}" ]; then
                ok "Lazydocker ya está al día ($LZD_VERSION)."
            else
                LZD_VER_NUM="${LZD_VERSION#v}"
                TMP_DIR=$(mktemp -d)
                if curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/${LZD_VERSION}/lazydocker_${LZD_VER_NUM}_Linux_${LZD_ARCH}.tar.gz" | tar -xz -C "$TMP_DIR" 2>/dev/null; then
                    mv "$TMP_DIR/lazydocker" "$HOME/.local/bin/lazydocker"
                    chmod +x "$HOME/.local/bin/lazydocker"
                    ok "Lazydocker actualizado ($LZD_VERSION)."
                else
                    warn "no se pudo descargar actualización de Lazydocker."
                fi
                rm -rf "$TMP_DIR"
            fi
        fi
    fi
else
    warn "lazydocker no instalado (ejecuta 'make devtools')."
fi

# ------------------------------------------------------------------------------
# 3. Editores/navegadores nativos (APT ya cubrió code/chrome/nvim; aquí Zed y user-space nvim)
# ------------------------------------------------------------------------------
step "Actualizando Zed editor..."
if command -v zed &>/dev/null || [ -f "$HOME/.local/bin/zed" ]; then
    curl -fsSL https://zed.dev/install.sh | sh || warn "no se pudo actualizar Zed."
    ok "Zed actualizado."
else
    warn "Zed no instalado (ejecuta 'make tooling')."
fi

step "Actualizando Neovim..."
if [ -d "$HOME/.local/share/neovim" ]; then
    DET_ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [ "$DET_ARCH" = "amd64" ] || [ "$DET_ARCH" = "x86_64" ]; then
        NVIM_ARCH="x86_64"
    elif [ "$DET_ARCH" = "arm64" ] || [ "$DET_ARCH" = "aarch64" ]; then
        NVIM_ARCH="arm64"
    else
        NVIM_ARCH=""
    fi
    if [ -n "$NVIM_ARCH" ]; then
        NVIM_LATEST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/neovim/neovim/releases/latest 2>/dev/null || echo "")
        NVIM_VERSION="${NVIM_LATEST_URL##*/}"
        NVIM_CUR_VER="$("$HOME/.local/bin/nvim" --version 2>/dev/null | awk 'NR==1 {print $2}' || true)"
        if [ -n "$NVIM_VERSION" ] && [ "$NVIM_VERSION" != "latest" ] && [ -n "$NVIM_CUR_VER" ] && [ "$NVIM_CUR_VER" = "$NVIM_VERSION" ]; then
            ok "Neovim ya está al día ($NVIM_VERSION)."
        else
            TMP_DIR=$(mktemp -d)
            if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" -o "$TMP_DIR/nvim.tar.gz" 2>/dev/null \
                && tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR" 2>/dev/null \
                && [ -d "$TMP_DIR/nvim-linux-${NVIM_ARCH}" ]; then
                rm -rf "$HOME/.local/share/neovim"
                mv "$TMP_DIR/nvim-linux-${NVIM_ARCH}" "$HOME/.local/share/neovim"
                ln -sf "$HOME/.local/share/neovim/bin/nvim" "$HOME/.local/bin/nvim"
                ok "Neovim actualizado en ~/.local/bin/nvim (${NVIM_VERSION:-latest})."
            else
                warn "no se pudo descargar la última versión de Neovim."
            fi
            rm -rf "$TMP_DIR"
        fi
    fi
elif command -v nvim &>/dev/null; then
    ok "Neovim gestionado por APT."
else
    warn "Neovim no instalado (ejecuta 'make tooling')."
fi

step "Sincronizando plugins de Neovim (lazy.nvim)..."
if command -v nvim &>/dev/null && [ -d "$HOME/.local/share/nvim/lazy" ]; then
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "no se pudieron actualizar los plugins de Neovim en modo headless."
    ok "Plugins de Neovim sincronizados."
else
    ok "Neovim: plugins gestionados por lazy.nvim al iniciar."
fi

# ------------------------------------------------------------------------------
# 4. IA: OpenCode CLI + Antigravity CLI (+ convergencia /opt sin re-extraer)
# ------------------------------------------------------------------------------
install_opencode() {
    curl -fsSL https://opencode.ai/v2/install | bash
}

install_antigravity_cli() {
    curl -fsSL https://antigravity.google/cli/install.sh | bash
}

step "Actualizando OpenCode CLI..."
if command -v opencode &>/dev/null || [ -x "$HOME/.opencode/bin/opencode" ]; then
    run_with_zshrc_guard install_opencode || warn "no se pudo actualizar OpenCode."
    ok "OpenCode actualizado."
else
    warn "opencode no instalado (ejecuta 'make devai')."
fi

step "Convergencia Antigravity (/opt + CLI)..."
# setup_agy.sh es idempotente: si el tarball de Descargas es más nuevo que
# /opt re-extrae; si no, solo verifica symlink/.desktop/CLI. Barato y seguro.
bash "$SCRIPT_DIR/setup_agy.sh" || warn "setup_agy.sh falló."
# Forzar CLI a última versión aunque ya existiera (setup_agy solo instala si falta).
if command -v agy &>/dev/null || [ -f "$HOME/.local/bin/agy" ]; then
    run_with_zshrc_guard install_antigravity_cli || warn "no se pudo actualizar Antigravity CLI."
    [ -f "$HOME/.local/bin/agy" ] && ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity-cli"
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
        if [ -d "$PLUGIN_DIR/.git" ]; then
            git -C "$PLUGIN_DIR" pull --ff-only -q || warn "$plugin no avanzó (divergió o sin red)."
        fi
    done
    ok "Oh My Zsh y plugins al día."
else
    warn "Oh My Zsh no instalado (ejecuta 'make shell')."
fi

# ------------------------------------------------------------------------------
# 6. Podman: verificar socket de usuario
# ------------------------------------------------------------------------------
step "Verificando servicio Podman rootless (systemd --user)..."
if command -v podman &>/dev/null; then
    if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi "true"; then
        systemctl --user is-active --quiet podman.socket || systemctl --user start podman.socket 2>/dev/null || true
        ok "Podman rootless operativo (socket activo)."
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
    flatpak update -y --noninteractive 2>/dev/null || flatpak update -y 2>/dev/null || warn "flatpak update devolvió advertencias."
    FLATPAK_APPS=()
    read_manifest "$REPO_DIR/packages/flatpak.txt" FLATPAK_APPS
    missing_flatpaks=()
    for app_id in "${FLATPAK_APPS[@]}"; do
        flatpak info "$app_id" &>/dev/null || missing_flatpaks+=("$app_id")
    done
    if [ "${#missing_flatpaks[@]}" -gt 0 ]; then
        warn "Flatpaks del manifiesto ausentes (${missing_flatpaks[*]}). Ejecuta 'make tooling' si deseas instalarlos."
    fi
    ok "Aplicaciones Flatpak al día."
fi

echo
echo "================================================================="
echo "✔ Update completado (idempotente). Valida con: make verify"
echo "  Nota: no se tocó SSH/gh auth, /opt (sin tarball nuevo), ni chsh."
echo "  Si cambiaste configs/scripts de Hyprland en el repo: git pull && make refresh"
echo "================================================================="
