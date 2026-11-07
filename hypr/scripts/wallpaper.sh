#!/usr/bin/env bash
# ==============================================================================
# Aplica el wallpaper: swaybg preferido por compatibilidad universal Wayland;
# fallback a hyprpaper si swaybg no está disponible.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_WALL="$(cd "$SCRIPT_DIR/.." && pwd)/wallpapers/default.png"
USER_WALL="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpapers/default.png"

WALL="${HYPR_WALLPAPER:-}"
if [ -z "$WALL" ]; then
    if [ -f "$USER_WALL" ]; then
        WALL="$USER_WALL"
    elif [ -f "$REPO_WALL" ]; then
        WALL="$REPO_WALL"
    fi
fi

pkill -x swaybg 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true

if [ -n "$WALL" ] && [ -f "$WALL" ]; then
    if command -v swaybg >/dev/null 2>&1; then
        swaybg -i "$WALL" -m fill -c '#0c1012' >/dev/null 2>&1 &
        exit 0
    elif command -v hyprpaper >/dev/null 2>&1; then
        CONF_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}"
        mkdir -p "$CONF_DIR"
        CONF="$CONF_DIR/hyprpaper-runtime.conf"
        cat > "$CONF" <<EOF
splash = false
wallpaper {
    monitor =
    path = $WALL
    fit_mode = cover
}
EOF
        hyprpaper -c "$CONF" >/dev/null 2>&1 &
        exit 0
    fi
fi

# Fallback si no hay imagen: color sólido base de PikaOS
if command -v swaybg >/dev/null 2>&1; then
    swaybg -c '#0c1012' >/dev/null 2>&1 &
fi
