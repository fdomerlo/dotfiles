#!/usr/bin/env bash

set -euo pipefail

echo "==> Setting up developer toolchains via mise..."

MISE_BIN="$HOME/.local/bin/mise"

if [ ! -f "$MISE_BIN" ]; then
    echo "Installing mise..."
    curl https://mise.run | sh
else
    echo "mise is already installed."
fi

# Ensure mise is available in current session for installation
export PATH="$HOME/.local/bin:$PATH"

echo "==> Installing developer runtimes via mise..."
mise use --global node@lts
mise use --global python@latest
mise use --global go@latest

# Add mise hook to .zshrc if not present
ZSHRC_PATH="$HOME/.zshrc"
# It might be a symlink to our configs/.zshrc, we'll append to the symlink source if needed,
# or we'll let the user add it. Actually, modifying the repo file directly might be better,
# or we can assume it's in the repo file already.
# We will check the target of the symlink.
if [ -L "$ZSHRC_PATH" ]; then
    ZSHRC_REAL=$(readlink "$ZSHRC_PATH")
else
    ZSHRC_REAL="$ZSHRC_PATH"
fi

if ! grep -q 'eval "$(mise activate zsh)"' "$ZSHRC_REAL" 2>/dev/null; then
    echo 'eval "$(mise activate zsh)"' >> "$ZSHRC_REAL"
    echo "Added mise activation hook to .zshrc."
fi

echo "==> Toolchains setup complete."
