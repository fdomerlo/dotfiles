#!/usr/bin/env bash
set -euo pipefail

OMZ_DIR="$HOME/.oh-my-zsh"
PLUGINS_DIR="$OMZ_DIR/custom/plugins"

if ! command -v zsh &>/dev/null; then
  sudo apt-get install -y zsh
fi

CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
ZSH_PATH=$(command -v zsh)

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
  sudo chsh -s "$ZSH_PATH" "$USER"
fi

if [ ! -d "$OMZ_DIR" ]; then
  echo "==> Instalando Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "==> Oh My Zsh ya está instalado"
fi

mkdir -p "$PLUGINS_DIR"

if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
  echo "==> Clonando zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
else
  echo "==> Actualizando zsh-autosuggestions..."
  git -C "$PLUGINS_DIR/zsh-autosuggestions" pull
fi

if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  echo "==> Clonando zsh-syntax-highlighting..."
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"
else
  echo "==> Actualizando zsh-syntax-highlighting..."
  git -C "$PLUGINS_DIR/zsh-syntax-highlighting" pull
fi

echo "✔ Zsh & Oh My Zsh configurados correctamente."
