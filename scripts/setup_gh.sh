#!/usr/bin/env bash
# scripts/setup_gh.sh - Configuración SSH automática con GitHub CLI
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

MODE="${1:-default}"

echo "================================================================="
echo "=== Iniciando configuración SSH Automatizada con GitHub ==="
echo "================================================================="

KEY_PATH="$HOME/.ssh/id_ed25519"
KEY_TITLE="${USER:-user}@$(hostname)"

# 1. Generar la clave SSH localmente (Idempotente)
if [ -f "$KEY_PATH" ]; then
    echo "✔ La clave SSH ya existe en $KEY_PATH. Omitiendo generación."
else
    echo "Generando clave SSH ed25519..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    USER_EMAIL=$(git config --includes --global --get user.email 2>/dev/null || true)
    if [ -z "$USER_EMAIL" ] && command -v gh &>/dev/null && gh auth status &>/dev/null; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
        USER_EMAIL=$(gh api user --jq '.email // empty' 2>/dev/null || true)
        if [ -z "$USER_EMAIL" ] && [ -n "$GH_USER" ]; then
            USER_EMAIL="${GH_USER}@users.noreply.github.com"
        fi
    fi
    if [ -z "$USER_EMAIL" ]; then
        USER_EMAIL="${USER:-user}@$(hostname)"
    fi
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$KEY_PATH" -N "" >/dev/null
fi

# 2. Asegurar que la clave esté cargada en el agente SSH de sesión (systemd o fallback)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user start ssh-agent.socket >/dev/null 2>&1 || true
    fi
    if [ -S "$RUNTIME_DIR/openssh_agent" ]; then
        export SSH_AUTH_SOCK="$RUNTIME_DIR/openssh_agent"
    elif [ -S "$RUNTIME_DIR/gcr/ssh" ]; then
        export SSH_AUTH_SOCK="$RUNTIME_DIR/gcr/ssh"
    elif ! pgrep -u "$USER" ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)" >/dev/null
    fi
fi
ssh-add "$KEY_PATH" 2>/dev/null || true

# Función auxiliar: sincroniza user.name y user.email en ~/.config/git/local.gitconfig
ensure_git_identity() {
    local gh_user="${1:-}"
    local gh_email="${2:-}"
    local local_gitconfig="${XDG_CONFIG_HOME:-$HOME/.config}/git/local.gitconfig"
    local current_name current_email

    mkdir -p "$(dirname "$local_gitconfig")"
    current_name=$(git config --includes --global --get user.name 2>/dev/null || true)
    current_email=$(git config --includes --global --get user.email 2>/dev/null || true)

    if [ -z "$current_name" ] && [ -n "$gh_user" ]; then
        git config --file "$local_gitconfig" user.name "$gh_user"
    fi
    if [ -z "$current_email" ] && [ -n "$gh_email" ]; then
        git config --file "$local_gitconfig" user.email "$gh_email"
    fi
}

# 3. Comprobar si la autenticación SSH con GitHub ya está activa y funcionando
echo "Verificando conexión SSH existente con GitHub..."
SSH_CHECK=$(ssh -T -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)

if [[ "$MODE" != "--auth" && "$MODE" != "auth" ]] && echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "✔ Conexión SSH con GitHub ya autenticada y operativa."
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
        USER_EMAIL=$(gh api user --jq '.email // empty' 2>/dev/null || true)
        [ -z "$USER_EMAIL" ] && [ -n "$GH_USER" ] && USER_EMAIL="${GH_USER}@users.noreply.github.com"
        ensure_git_identity "$GH_USER" "$USER_EMAIL"
    fi
    echo "================================================================="
    echo "✔ SSH y GitHub validados correctamente (sin acciones pendientes)."
    echo "================================================================="
    exit 0
fi

# 4. Si SSH no funciona o se fuerza --auth, resolver con GitHub CLI
echo "Verificando GitHub CLI..."

if ! command -v gh &>/dev/null; then
    if [ -x "$HOME/.local/bin/gh" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo "[-] Error: gh CLI no está instalado en PATH ni en ~/.local/bin/gh."
        exit 1
    fi
fi

# Configurar protocolo git en gh como SSH de forma idempotente
CURRENT_PROTO="$(gh config get git_protocol 2>/dev/null || true)"
if [[ "$CURRENT_PROTO" != "ssh" ]]; then
    gh config set git_protocol ssh 2>/dev/null || true
fi

if ! gh auth status &>/dev/null || [[ "$MODE" == "--auth" || "$MODE" == "auth" ]]; then
    if [[ -t 0 || "$MODE" == "--auth" || "$MODE" == "auth" ]]; then
        echo "No se detectó una sesión activa en GitHub CLI."
        echo "Iniciando inicio de sesión interactivo con los permisos requeridos..."
        gh auth login -h github.com -p ssh -w -s admin:public_key
    else
        echo "⚠️ Aviso: GitHub CLI no está autenticado y no hay una TTY interactiva disponible."
        echo "   Para iniciar sesión y subir tu clave SSH ejecuta: make github-auth"
        exit 0
    fi
fi

# 5. Autodetectar datos del desarrollador vía gh
echo "Detectando información de la cuenta de GitHub..."
GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
USER_EMAIL=$(gh api user --jq '.email // empty' 2>/dev/null || true)
if [ -z "$USER_EMAIL" ] && [ -n "$GH_USER" ]; then
    USER_EMAIL="${GH_USER}@users.noreply.github.com"
fi

# 6. Verificar presencia de la clave en GitHub y subirla si falta
echo "Verificando llaves registradas en tu perfil de GitHub..."
if [ -f "${KEY_PATH}.pub" ]; then
    PUB_BLOB=$(awk '{print $2}' "${KEY_PATH}.pub")
    if gh ssh-key list 2>/dev/null | grep -F "$PUB_BLOB" >/dev/null; then
        echo "✔ Esta clave pública ya está registrada en GitHub."
    else
        if ! gh auth status 2>&1 | grep -q "admin:public_key"; then
            echo "La clave SSH no está en GitHub y la sesión actual no tiene permiso 'admin:public_key'."
            echo "Actualizando permisos de tu sesión de GitHub CLI..."
            gh auth refresh -h github.com -s admin:public_key
        fi
        echo "Subiendo la clave pública a GitHub bajo el título '$KEY_TITLE'..."
        gh ssh-key add "${KEY_PATH}.pub" --title "$KEY_TITLE" --type authentication
        sleep 2
    fi
fi

# 7. Asegurar identidad global de Git
if [ -n "$GH_USER" ]; then
    echo "Verificando identidad global de Git..."
    ensure_git_identity "$GH_USER" "$USER_EMAIL"
fi

# 8. Probar la conexión SSH de forma robusta
echo "Probando conexión con GitHub..."
SSH_CHECK=$(ssh -T -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)

if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "================================================================="
    echo "✔ ¡SSH y GitHub configurados con éxito${GH_USER:+ para $GH_USER}!"
    echo "================================================================="
else
    echo "⚠️ Advertencia: No se pudo validar la conexión SSH automáticamente."
    echo "Detalles:"
    echo "$SSH_CHECK"
fi
