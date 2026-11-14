#!/usr/bin/env bash
# scripts/setup_git.sh - Configura la identidad global de Git (user.name / user.email)
# en ~/.config/git/local.gitconfig de forma idempotente, sin ensuciar shell/gitconfig.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

if ! command -v git &>/dev/null; then
  echo "ERROR: git no está instalado. Ejecutá 'make host' primero." >&2
  exit 1
fi

LOCAL_GITCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/local.gitconfig"
mkdir -p "$(dirname "$LOCAL_GITCONFIG")"

# Migración automática desde ~/.gitconfig.pre-dotfiles o ~/.gitconfig regular si existiera
migrate_legacy_key() {
  local key="$1" legacy_file val=""
  if [[ -n "$(git config --file "$LOCAL_GITCONFIG" --get "$key" 2>/dev/null || true)" ]]; then
    return 0
  fi
  for legacy_file in "$HOME/.gitconfig.pre-dotfiles" "$HOME/.gitconfig"; do
    if [[ -f "$legacy_file" && ! -L "$legacy_file" ]]; then
      val="$(git config --file "$legacy_file" --get "$key" 2>/dev/null || true)"
      if [[ -n "$val" ]]; then
        git config --file "$LOCAL_GITCONFIG" "$key" "$val"
        echo "==> Migrado git $key desde $legacy_file a $LOCAL_GITCONFIG"
        return 0
      fi
    fi
  done
}

configure_key() {
  local key="$1" env_value="$2" prompt="$3"
  local current value=""

  migrate_legacy_key "$key"

  current="$(git config --file "$LOCAL_GITCONFIG" --get "$key" 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    current="$(git config --includes --global --get "$key" 2>/dev/null || true)"
    if [[ -n "$current" ]]; then
      git config --file "$LOCAL_GITCONFIG" "$key" "$current"
    fi
  fi

  if [[ -n "$current" ]]; then
    echo "==> git $key ya configurado: $current"
    return 0
  fi

  if [[ -n "$env_value" ]]; then
    value="$env_value"
  elif [[ -t 0 ]]; then
    read -r -p "    $prompt: " value
  fi

  if [[ -n "$value" ]]; then
    git config --file "$LOCAL_GITCONFIG" "$key" "$value"
    echo "==> git $key configurado en $LOCAL_GITCONFIG: $value"
  else
    echo "ADVERTENCIA: git $key sin configurar. Definí GIT_USER_NAME/GIT_USER_EMAIL y ejecutá 'make gitconfig'." >&2
  fi
}

echo "==> Verificando identidad local de Git ($LOCAL_GITCONFIG)..."
configure_key user.name "${GIT_USER_NAME:-}" "Nombre para los commits (user.name)"
configure_key user.email "${GIT_USER_EMAIL:-}" "Email para los commits (user.email)"

# Valores predeterminados no personales, solo si no existen en global (incluye shell/gitconfig)
if [[ -z "$(git config --includes --global --get init.defaultBranch 2>/dev/null || true)" ]]; then
  git config --file "$LOCAL_GITCONFIG" init.defaultBranch main
  echo "==> git init.defaultBranch configurado: main"
fi
