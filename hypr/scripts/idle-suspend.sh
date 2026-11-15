#!/usr/bin/env bash
# ==============================================================================
# Suspensión automática con escalado a hibernación (systemd suspend-then-hibernate).
#
# Uso:
#   idle-suspend.sh                # Suspende siempre (corriente o batería)
#   idle-suspend.sh --battery-only # Solo suspende si está funcionando con batería
#
# Si el kernel aún no permite hibernar (p. ej. Secure Boot activo con lockdown
# o swap/resume sin configurar), cae de forma segura a `systemctl suspend`
# para no dejar el equipo encendido indefinidamente.
# ==============================================================================
set -euo pipefail

is_on_battery() {
    local has_battery=false
    local ps ptype online status

    for ps in /sys/class/power_supply/BAT*; do
        [ -e "$ps" ] || continue
        has_battery=true
        break
    done
    [ "$has_battery" = true ] || return 1

    # Si alguna fuente Mains o USB PD está conectada, se considera con corriente.
    for ps in /sys/class/power_supply/*; do
        [ -d "$ps" ] || continue
        ptype=$(cat "$ps/type" 2>/dev/null || true)
        case "$ptype" in
            Mains|USB)
                online=$(cat "$ps/online" 2>/dev/null || echo 0)
                if [ "$online" = "1" ]; then
                    return 1
                fi
                ;;
        esac
    done

    for ps in /sys/class/power_supply/BAT*; do
        [ -d "$ps" ] || continue
        status=$(cat "$ps/status" 2>/dev/null || true)
        if [ "$status" = "Discharging" ]; then
            return 0
        fi
    done

    return 1
}

if [ "${1:-}" = "--battery-only" ]; then
    if ! is_on_battery; then
        exit 0
    fi
fi

can_sth=""
if command -v busctl >/dev/null 2>&1; then
    can_sth=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager CanSuspendThenHibernate 2>/dev/null \
        | awk -F'"' '{print $2}' || true)
fi

if [ "$can_sth" = "yes" ]; then
    exec systemctl suspend-then-hibernate
fi

exec systemctl suspend
