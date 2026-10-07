#!/usr/bin/env bash

set -euo pipefail

echo "==> Setting up dotfiles..."

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
ZSH_PATH=$(which zsh || echo "/usr/bin/zsh")

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
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
