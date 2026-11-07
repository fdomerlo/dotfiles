#!/usr/bin/env bash
# ==============================================================================
# Aplica el wallpaper: hyprpaper si existe la imagen; swaybg como fallback PikaOS.
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

pkill -x hyprpaper 2>/dev/null || true
pkill -x swaybg 2>/dev/null || true

if [ -n "$WALL" ] && [ -f "$WALL" ] && command -v hyprpaper >/dev/null 2>&1; then
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
    sleep 0.6
    if pgrep -x hyprpaper >/dev/null 2>&1; then
        # Best-effort: asegura la asignación en todos los monitores
        hyprctl hyprpaper wallpaper ",$WALL,cover" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# Fallback con el color base de PikaOS (Cyber-Teal / Deep Slate)
if command -v swaybg >/dev/null 2>&1; then
    swaybg -c '#0c1012' >/dev/null 2>&1 &
fi
