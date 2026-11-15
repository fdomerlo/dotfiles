#!/usr/bin/env bash
# ==============================================================================
# Ajusta HibernateDelaySec dinámicamente antes de suspend-then-hibernate:
#   - Sin corriente (batería): 15 min en suspensión -> hiberna a los 30 min totales
#   - Con corriente (AC / desktop): 20 min en suspensión -> hiberna a los 40 min totales
#
# Instalado en /usr/local/libexec/workstation-hibernate-delay por host/setup.sh
# y ejecutado como ExecStartPre por systemd-suspend-then-hibernate.service.
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

delay="20min"
if is_on_battery; then
    delay="15min"
fi

mkdir -p /run/systemd/sleep.conf.d
cat > /run/systemd/sleep.conf.d/50-hibernate-delay.conf <<EOF
[Sleep]
HibernateDelaySec=$delay
EOF
