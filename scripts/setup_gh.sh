#!/usr/bin/env bash
# scripts/setup_gh.sh - Configuración SSH automática con GitHub CLI
set -euo pipefail

echo "================================================================="
echo "=== Iniciando configuración SSH Automatizada con GitHub ==="
echo "================================================================="

# 1. Validar y resolver la autenticación inline
if ! gh auth status &>/dev/null; then
    echo "No se detectó una sesión activa en GitHub CLI."
    echo "Iniciando inicio de sesión interactivo con los permisos requeridos..."
    gh auth login -h github.com -p ssh -w -s admin:public_key
else
    if ! gh auth status -v 2>&1 | grep -q "admin:public_key"; then
        echo "Sesión detectada, pero falta el permiso 'admin:public_key'."
        echo "Actualizando los permisos de tu sesión actual..."
        gh auth refresh -h github.com -s admin:public_key
    fi
fi

# 2. Autodetectar datos del desarrollador
echo "Detectando información de la cuenta de GitHub..."
GH_USER=$(gh api user --jq '.login')

USER_EMAIL=$(gh api user --jq '.email // empty')
if [ -z "$USER_EMAIL" ]; then
    USER_EMAIL="${GH_USER}@users.noreply.github.com"
fi

KEY_TITLE="${USER:-user}@$(hostname)"
KEY_PATH="$HOME/.ssh/id_ed25519"

# 3. Generar la clave SSH localmente (Idempotente)
if [ -f "$KEY_PATH" ]; then
    echo "✔ La clave SSH ya existe en $KEY_PATH. Omitiendo generación."
else
    echo "Generando clave SSH ed25519..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$KEY_PATH" -N "" >/dev/null
fi

# 4. Asegurar que la clave esté cargada localmente
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$KEY_PATH" 2>/dev/null || true

# 5. Verificar presencia en GitHub y subirla si falta
echo "Verificando llaves registradas en tu perfil de GitHub..."
PUB_BLOB=$(awk '{print $2}' "${KEY_PATH}.pub")

if gh ssh-key list 2>/dev/null | grep -F "$PUB_BLOB" >/dev/null; then
    echo "✔ Esta clave pública ya está registrada en GitHub."
else
    echo "Subiendo la clave pública a GitHub bajo el título '$KEY_TITLE'..."
    gh ssh-key add "${KEY_PATH}.pub" --title "$KEY_TITLE" --type authentication
    sleep 2
fi

# 6. Configurar usuario de git globalmente de forma automática
echo "Sincronizando configuración global de Git..."
git config --global user.email "$USER_EMAIL"
git config --global user.name "$GH_USER"

# 7. Probar la conexión SSH de forma robusta
echo "Probando conexión con GitHub..."
SSH_CHECK=$(ssh -T -i "$KEY_PATH" -o StrictHostKeyChecking=no git@github.com 2>&1 || true)

if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    echo "================================================================="
    echo "✔ ¡SSH y GitHub configurados con éxito para $GH_USER!"
    echo "================================================================="
else
    echo "⚠️ Advertencia: No se pudo validar la conexión SSH automáticamente."
    echo "Detalles:"
    echo "$SSH_CHECK"
fi
