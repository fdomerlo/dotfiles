#!/usr/bin/env bash
# Aplica el wallpaper: hyprpaper si existe la imagen; swaybg como fallback.
set -euo pipefail

WALL="${HYPR_WALLPAPER:-$HOME/.config/hypr/wallpapers/default.png}"

pkill -x hyprpaper 2>/dev/null || true
pkill -x swaybg 2>/dev/null || true

if [ -f "$WALL" ] && command -v hyprpaper >/dev/null 2>&1; then
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
        # Best-effort: asegura el fallback en todos los monitores.
        hyprctl hyprpaper wallpaper ",$WALL,cover" >/dev/null 2>&1 || true
        exit 0
    fi
fi

if command -v swaybg >/dev/null 2>&1; then
    swaybg -c '#1e1e2e' >/dev/null 2>&1 &
fi
