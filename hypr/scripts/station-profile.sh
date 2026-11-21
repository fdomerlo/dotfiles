#!/usr/bin/env bash
# ==============================================================================
# Gestión del perfil local de estación (desktop / laptop) para Hyprland.
#
# Escribe ~/.config/hypr/conf/local.lua a partir de hypr/conf/profiles/*.lua
# sin tocar los archivos versionados del repositorio ni pisar overrides locales
# existentes (salvo con --force, creando respaldo previo).
#
# Uso:
#   station-profile.sh detect
#   station-profile.sh apply [auto|desktop|laptop] [--force]
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILES_DIR="$HYPR_DIR/conf/profiles"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_LUA="$CONFIG_HOME/hypr/conf/local.lua"

detect_station() {
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
        printf 'laptop\n'
        return 0
    fi
    if [ -r /sys/class/dmi/id/chassis_type ]; then
        case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)" in
            8|9|10|11|14|30|31|32)
                printf 'laptop\n'
                return 0
                ;;
        esac
    fi
    printf 'desktop\n'
}

apply_profile() {
    local requested="${1:-auto}"
    local force="${2:-}"
    local profile template stamp

    if [ "$requested" = "auto" ]; then
        profile="$(detect_station)"
    else
        profile="$requested"
    fi

    template="$PROFILES_DIR/${profile}.lua"
    if [ ! -f "$template" ]; then
        echo "ERROR: No existe la plantilla de perfil '$profile' ($template)." >&2
        return 1
    fi

    if [ -e "$LOCAL_LUA" ] || [ -L "$LOCAL_LUA" ]; then
        if [ "$force" != "--force" ]; then
            echo "✔ $LOCAL_LUA ya existe (se conserva sin cambios)."
            return 0
        fi
        stamp="$(date +%Y%m%d%H%M%S)"
        mv "$LOCAL_LUA" "${LOCAL_LUA}.bak.${stamp}"
        echo "  ⚠ Backup de local.lua anterior: ${LOCAL_LUA}.bak.${stamp}"
    fi

    mkdir -p "$(dirname "$LOCAL_LUA")"
    cp "$template" "$LOCAL_LUA"
    echo "✔ Perfil '$profile' aplicado en $LOCAL_LUA"

    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

case "${1:-detect}" in
    detect)
        detect_station
        ;;
    apply)
        apply_profile "${2:-auto}" "${3:-}"
        ;;
    -h|--help)
        sed -n '2,14p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "Uso: $0 {detect|apply [auto|desktop|laptop] [--force]}" >&2
        exit 2
        ;;
esac
