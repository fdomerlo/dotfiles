#!/usr/bin/env bash
# ==============================================================================
# Sincroniza ~/.config/hypr/conf/smart-gaps.conf según el modo de barra activo
# en Quickshell (`bar` | `notch` | `auto`):
#   - bar / auto : Smart Gaps activas (w[tv1] y f[1] sin gaps/bordes/redondeo)
#   - notch      : Smart Gaps desactivadas (ventanas únicas/maximizadas conservan
#                  gaps_out, bordes y redondeo acordes al notch superior)
#
# Uso:
#   smart-gaps-sync.sh [--no-reload] [bar|notch|islands|auto]
# ==============================================================================
set -euo pipefail

NO_RELOAD=0
MODE=""

for arg in "$@"; do
    case "$arg" in
        --no-reload) NO_RELOAD=1 ;;
        -h|--help)
            echo "Uso: $0 [--no-reload] [bar|notch|islands|auto]"
            exit 0
            ;;
        *)
            if [ -z "$MODE" ]; then
                MODE="$arg"
            else
                echo "Uso: $0 [--no-reload] [bar|notch|islands|auto]" >&2
                exit 2
            fi
            ;;
    esac
done

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_JSON="$CONFIG_HOME/quickshell/local.json"
SMART_GAPS_CONF="$CONFIG_HOME/hypr/conf/smart-gaps.conf"

if [ -z "$MODE" ] && [ -f "$LOCAL_JSON" ]; then
    if command -v jq >/dev/null 2>&1; then
        MODE="$(jq -r '.barStyle // empty' "$LOCAL_JSON" 2>/dev/null || true)"
    elif command -v python3 >/dev/null 2>&1; then
        MODE="$(python3 -c '
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        d = json.load(f)
    if isinstance(d, dict) and isinstance(d.get("barStyle"), str):
        print(d["barStyle"])
except Exception:
    pass
' "$LOCAL_JSON" 2>/dev/null || true)"
    fi
fi

MODE_NORM="$(printf '%s' "${MODE:-bar}" | tr '[:upper:]' '[:lower:]' | xargs)"

mkdir -p "$(dirname "$SMART_GAPS_CONF")"
TMP_FILE="$(mktemp "${SMART_GAPS_CONF}.tmp.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

case "$MODE_NORM" in
    notch|islands)
        cat >"$TMP_FILE" <<'EOF'
# Generado automáticamente por smart-gaps-sync.sh (modo: notch).
# Smart Gaps desactivadas: las ventanas únicas y maximizadas conservan
# gaps_out, borde y redondeo acordes al notch superior central.
EOF
        ;;
    *)
        cat >"$TMP_FILE" <<'EOF'
# Generado automáticamente por smart-gaps-sync.sh (modo: bar/auto).
# Smart Gaps ("no gaps when only"): cuando hay una sola ventana visible en
# tiling (w[tv1]) o maximizada (f[1]), elimina márgenes, bordes y redondeo.
workspace = w[tv1], gapsout:0, gapsin:0
workspace = f[1], gapsout:0, gapsin:0
windowrule = match:float false, match:workspace w[tv1], border_size 0
windowrule = match:float false, match:workspace w[tv1], rounding 0
windowrule = match:float false, match:workspace f[1], border_size 0
windowrule = match:float false, match:workspace f[1], rounding 0
EOF
        ;;
esac

CHANGED=0
if [ ! -f "$SMART_GAPS_CONF" ] || ! cmp -s "$TMP_FILE" "$SMART_GAPS_CONF"; then
    mv "$TMP_FILE" "$SMART_GAPS_CONF"
    CHANGED=1
fi

if [ "$CHANGED" = "1" ] && [ "$NO_RELOAD" = "0" ] && command -v hyprctl >/dev/null 2>&1; then
    if hyprctl version >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
fi
