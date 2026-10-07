#!/usr/bin/env bash

set -euo pipefail

echo "==> Setting up fonts..."

TARGET_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
FONTS_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fonts/.local/share/fonts" && pwd)"

mkdir -p "$TARGET_DIR"

echo "==> Symlinking fonts from $FONTS_SRC_DIR to $TARGET_DIR..."

for font_dir in "$FONTS_SRC_DIR"/*; do
    if [ -d "$font_dir" ]; then
        font_name=$(basename "$font_dir")
        target_path="$TARGET_DIR/$font_name"

        ln -snf "$font_dir" "$target_path"
        echo "Symlinked $font_name"
    fi
done

echo "==> Refreshing font cache silently..."
fc-cache -f

echo "==> Fonts setup complete."
