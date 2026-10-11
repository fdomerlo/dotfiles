#!/usr/bin/env bash
# scripts/setup_gh.sh - Configuración SSH automática con GitHub CLI
set -euo pipefail

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

    USER_EMAIL=""
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
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

# 2. Asegurar que la clave esté cargada localmente en ssh-agent
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$KEY_PATH" 2>/dev/null || true

# 3. Comprobar si la autenticación SSH con GitHub ya está activa y funcionando
echo "Verificando conexión SSH existente con GitHub..."
SSH_CHECK=$(ssh -T -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)

if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "✔ Conexión SSH con GitHub ya autenticada y operativa."
    # Asegurar git config user.name y user.email si no están establecidos
    CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || true)
    CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
    if [ -z "$CURRENT_GIT_NAME" ] || [ -z "$CURRENT_GIT_EMAIL" ]; then
        if command -v gh &>/dev/null && gh auth status &>/dev/null; then
            GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
            USER_EMAIL=$(gh api user --jq '.email // empty' 2>/dev/null || true)
            [ -z "$USER_EMAIL" ] && [ -n "$GH_USER" ] && USER_EMAIL="${GH_USER}@users.noreply.github.com"
            [ -z "$CURRENT_GIT_NAME" ] && [ -n "$GH_USER" ] && git config --global user.name "$GH_USER"
            [ -z "$CURRENT_GIT_EMAIL" ] && [ -n "$USER_EMAIL" ] && git config --global user.email "$USER_EMAIL"
            echo "✔ Git config sincronizado con perfil de GitHub ($GH_USER)."
        fi
    fi
    echo "================================================================="
    echo "✔ SSH y GitHub validados correctamente (sin acciones pendientes)."
    echo "================================================================="
    exit 0
fi

# 4. Si SSH no funciona, resolver autenticación con GitHub CLI
echo "La conexión SSH requiere configuración. Verificando GitHub CLI..."

if ! command -v gh &>/dev/null; then
    echo "[-] Error: gh CLI no está instalado."
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "No se detectó una sesión activa en GitHub CLI."
    echo "Iniciando inicio de sesión interactivo con los permisos requeridos..."
    gh auth login -h github.com -p ssh -w -s admin:public_key
fi

# 5. Autodetectar datos del desarrollador vía gh
echo "Detectando información de la cuenta de GitHub..."
GH_USER=$(gh api user --jq '.login')
USER_EMAIL=$(gh api user --jq '.email // empty')
if [ -z "$USER_EMAIL" ]; then
    USER_EMAIL="${GH_USER}@users.noreply.github.com"
fi

# 6. Verificar presencia de la clave en GitHub y subirla si falta
echo "Verificando llaves registradas en tu perfil de GitHub..."
PUB_BLOB=$(awk '{print $2}' "${KEY_PATH}.pub")

if gh ssh-key list 2>/dev/null | grep -F "$PUB_BLOB" >/dev/null; then
    echo "✔ Esta clave pública ya está registrada en GitHub."
else
    # Validar scope admin:public_key antes de intentar añadirla
    if ! gh auth status 2>&1 | grep -q "admin:public_key"; then
        echo "La clave SSH no está en GitHub y la sesión actual no tiene permiso 'admin:public_key'."
        echo "Actualizando permisos de tu sesión de GitHub CLI..."
        gh auth refresh -h github.com -s admin:public_key
    fi
    echo "Subiendo la clave pública a GitHub bajo el título '$KEY_TITLE'..."
    gh ssh-key add "${KEY_PATH}.pub" --title "$KEY_TITLE" --type authentication
    sleep 2
fi

# 7. Configurar usuario de git globalmente de forma automática
echo "Sincronizando configuración global de Git..."
git config --global user.email "$USER_EMAIL"
git config --global user.name "$GH_USER"

# 8. Probar la conexión SSH de forma robusta
echo "Probando conexión con GitHub..."
SSH_CHECK=$(ssh -T -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 git@github.com 2>&1 || true)

if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "================================================================="
    echo "✔ ¡SSH y GitHub configurados con éxito para $GH_USER!"
    echo "================================================================="
else
    echo "⚠️ Advertencia: No se pudo validar la conexión SSH automáticamente."
    echo "Detalles:"
    echo "$SSH_CHECK"
fi
