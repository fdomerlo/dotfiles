#!/usr/bin/env bash
set -euo pipefail

echo "==> Desplegando tipografías de usuario (Google Sans, Google Sans Code, Space Grotesk)..."

TARGET_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
FONTS_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fonts/.local/share/fonts" && pwd)"

mkdir -p "$TARGET_DIR"

if [ -d "$FONTS_SRC_DIR" ]; then
    for font_dir in "$FONTS_SRC_DIR"/*; do
        if [ -d "$font_dir" ]; then
            font_name=$(basename "$font_dir")
            target_path="$TARGET_DIR/$font_name"
            ln -snf "$font_dir" "$target_path"
            echo "  ✔ Enlazada tipografía: $font_name"
        fi
    done
fi

echo "==> Actualizando caché de tipografías (fc-cache)..."
fc-cache -f

echo "✔ Tipografías listas."
