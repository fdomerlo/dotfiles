#!/usr/bin/env bash

set -euo pipefail

echo "==> Setting up dotfiles..."

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
else
    echo "Oh My Zsh is already installed."
fi

# Install Oh My Zsh plugins
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

DOTFILES_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

FILES_TO_LINK=(
    ".functions.sh"
    ".gitconfig"
    ".zshrc"
)

for file in "${FILES_TO_LINK[@]}"; do
    target="$HOME/$file"
    source_file="$DOTFILES_SRC_DIR/$file"

    if [ -f "$target" ] || [ -L "$target" ]; then
        # Check if it's already a symlink pointing to our repo
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source_file" ]; then
            echo "Symlink for $file already correct, skipping backup."
        else
            echo "Backing up existing $file to $BACKUP_DIR/"
            mkdir -p "$BACKUP_DIR"
            mv "$target" "$BACKUP_DIR/"
        fi
    fi

    echo "Creating symlink for $file..."
    ln -sf "$source_file" "$target"
done

echo "==> Validating default shell..."
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
ZSH_PATH=$(command -v zsh || echo "/usr/bin/zsh")

if [ "$(readlink -f "$CURRENT_SHELL")" != "$(readlink -f "$ZSH_PATH")" ]; then
    echo "Changing default shell to zsh ($ZSH_PATH)..."
    # Try using sudo if chsh requires it (often does for changing shell)
    if command -v sudo >/dev/null 2>&1; then
        sudo chsh -s "$ZSH_PATH" "$USER"
    else
        chsh -s "$ZSH_PATH"
    fi
    echo "Default shell changed. You may need to log out and log back in for this to take effect."
else
    echo "Default shell is already zsh."
fi

echo "==> Dotfiles setup complete."
