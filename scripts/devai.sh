#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSHRC_REPO="$REPO_DIR/shell/zshrc"

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:/usr/local/bin:$PATH"

echo "================================================================="
echo "==> Instalando herramientas de Inteligencia Artificial..."
echo "================================================================="

# Guarda para evitar que instaladores remotos ensucien shell/zshrc versionado
run_with_zshrc_guard() {
    local snapshot=""
    if [[ -f "$ZSHRC_REPO" ]]; then
        snapshot="$(mktemp)"
        cp "$ZSHRC_REPO" "$snapshot"
    fi

    "$@"

    if [[ -n "$snapshot" ]]; then
        if [[ -f "$ZSHRC_REPO" ]] && ! cmp -s "$snapshot" "$ZSHRC_REPO"; then
            cp "$snapshot" "$ZSHRC_REPO"
        fi
        rm -f "$snapshot"
    fi
}

install_opencode() {
    curl -fsSL https://opencode.ai/v2/install | bash
}

install_antigravity_cli() {
    curl -fsSL https://antigravity.google/cli/install.sh | bash
}

# 1. OpenCode CLI
if command -v opencode &>/dev/null || [[ -x "$HOME/.opencode/bin/opencode" ]] || [[ -x "$HOME/.local/bin/opencode" ]]; then
    echo "✔ OpenCode CLI ya está instalado."
else
    echo "Instalando OpenCode CLI..."
    run_with_zshrc_guard install_opencode
fi

# 2. Antigravity CLI (instalación autónoma sin requerir el paquete GUI)
mkdir -p "$HOME/.local/bin"
if [[ -x "$HOME/.local/bin/agy" ]] || command -v agy &>/dev/null; then
    echo "✔ Antigravity CLI ya está instalado."
else
    echo "Instalando Antigravity CLI..."
    run_with_zshrc_guard install_antigravity_cli
fi

# Enlaces simbólicos de conveniencia para CLI
if [ -f "$HOME/.local/bin/agy" ]; then
    ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity-cli"
fi

# Fallback: si no existe el Core/IDE (/usr/local/bin/antigravity), enlazar 'antigravity' al CLI
if ! command -v antigravity &>/dev/null && [ ! -f "/usr/local/bin/antigravity" ] && [ -f "$HOME/.local/bin/agy" ]; then
    ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity"
fi

# 3. Antigravity Desktop (componente opcional)
bash "$SCRIPT_DIR/setup_agy.sh"

# 4. Skills globales del repo para OpenCode y Antigravity.
#    Cada ai/skills/<id>/SKILL.md se enlaza con ruta absoluta (requisito de IDE/CLI).
link_skill_into_dir() {
    local skill_src="$1"
    local skill_name="$2"
    local target_dir="$3"
    local skill_dest="$target_dir/$skill_name"

    mkdir -p "$target_dir"
    if [ -L "$skill_dest" ] || [ ! -e "$skill_dest" ]; then
        ln -sfn "$skill_src" "$skill_dest"
        echo "✔ Skill '$skill_name' enlazada en $target_dir."
    else
        echo "  ⚠️ $skill_dest existe y no es un symlink; se deja intacta."
    fi
}

SKILL_TARGET_DIRS=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
    "$HOME/.gemini/config/skills"
)

if command -v agy &>/dev/null || [ -x "$HOME/.local/bin/agy" ] || [ -d "$HOME/.gemini/antigravity-cli" ]; then
    SKILL_TARGET_DIRS+=("$HOME/.gemini/antigravity-cli/skills")
fi

if [ -d "/opt/Antigravity-x64" ] || [ -d "$HOME/.gemini/antigravity" ]; then
    SKILL_TARGET_DIRS+=("$HOME/.gemini/antigravity/skills")
fi

shopt -s nullglob
for skill_md in "$REPO_DIR"/ai/skills/*/SKILL.md; do
    skill_src="$(cd "$(dirname "$skill_md")" && pwd)"
    skill_name="$(basename "$skill_src")"
    for target_dir in "${SKILL_TARGET_DIRS[@]}"; do
        link_skill_into_dir "$skill_src" "$skill_name" "$target_dir"
    done
done
shopt -u nullglob

echo "✔ Herramientas de IA configuradas."
