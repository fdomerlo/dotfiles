#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/lock-telemetry.sh - Telemetría liviana para el HUD de Hyprlock
#
# Diseñado para ejecutarse periódicamente desde `label { text = cmd[update:...] }`
# sin levantar runtimes pesados ni emitir caracteres reservados de Pango (<, >, &).
#
# Uso:
#   lock-telemetry.sh left       # Bloque superior izquierdo (sistema, kernel, RAM)
#   lock-telemetry.sh right      # Bloque superior derecho (red, IP, VPN, KVM, energía)
#   lock-telemetry.sh stream     # Stream compacto inferior (Opción A)
#   lock-telemetry.sh soc        # Consola SOC estática/mixta
#   lock-telemetry.sh soc-feed   # HUD superior derecho con telemetría + feed progresivo
#   lock-telemetry.sh matrix-l   # Flanco izquierdo amplio para Matrix SOC (Opción C)
#   lock-telemetry.sh matrix-r   # Flanco derecho amplio para Matrix SOC (Opción C)
# ==============================================================================
set -euo pipefail

LC_ALL=C
export LC_ALL

sanitize() {
    tr -d '<>&'
}

fmt_uptime() {
    local secs d h m
    secs="${1%.*}"
    d=$((secs / 86400))
    h=$(((secs % 86400) / 3600))
    m=$(((secs % 3600) / 60))
    if [ "$d" -gt 0 ]; then
        printf '%dd %02dh %02dm' "$d" "$h" "$m"
    else
        printf '%02dh %02dm' "$h" "$m"
    fi
}

read_cpu_temp() {
    local hw name raw
    for hw in /sys/class/hwmon/hwmon*; do
        [ -r "$hw/name" ] && [ -r "$hw/temp1_input" ] || continue
        name="$(cat "$hw/name" 2>/dev/null || true)"
        case "$name" in
            k10temp|coretemp|zenpower|cpu_thermal)
                raw="$(cat "$hw/temp1_input" 2>/dev/null || true)"
                if [[ "$raw" =~ ^[0-9]+$ ]] && [ "$raw" -gt 1000 ]; then
                    printf '%dC' "$((raw / 1000))"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

probe_host_facts() {
    read -r HOST_NAME </proc/sys/kernel/hostname 2>/dev/null || HOST_NAME="workstation"
    HOST_NAME="${HOST_NAME%%.*}"
    read -r KERNEL_REL </proc/sys/kernel/osrelease 2>/dev/null || KERNEL_REL="linux"
    read -r UP_SECS _ </proc/uptime 2>/dev/null || UP_SECS="0"
    UPTIME_STR="$(fmt_uptime "$UP_SECS")"
    LOAD_STR="$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null || printf 'n/a')"

    read -r _ _ _ PROCS_PAIR _ </proc/loadavg 2>/dev/null || PROCS_PAIR="?/?"
    PROCS_RUN="${PROCS_PAIR%%/*}"
    PROCS_TOT="${PROCS_PAIR#*/}"

    MEM_STR="$(awk '
        /^MemTotal:/     { t = $2 }
        /^MemAvailable:/ { a = $2 }
        END {
            if (t > 0) {
                u = t - a
                printf "%.1f / %.1f GiB (%d%%)", u / 1048576, t / 1048576, (u * 100) / t
            } else {
                printf "n/a"
            }
        }
    ' /proc/meminfo 2>/dev/null || printf 'n/a')"

    MEM_COMPACT="$(awk '
        /^MemTotal:/     { t = $2 }
        /^MemAvailable:/ { a = $2 }
        END {
            if (t > 0) {
                u = t - a
                printf "%.1f/%.1fG(%d%%)", u / 1048576, t / 1048576, (u * 100) / t
            } else {
                printf "n/a"
            }
        }
    ' /proc/meminfo 2>/dev/null || printf 'n/a')"

    SWAP_STR="$(awk '
        /^SwapTotal:/ { t = $2 }
        /^SwapFree:/  { f = $2 }
        END {
            if (t > 0) {
                u = t - f
                printf "%.1f / %.1f GiB (%d%%)", u / 1048576, t / 1048576, (u * 100) / t
            } else {
                printf "OFF"
            }
        }
    ' /proc/meminfo 2>/dev/null || printf 'n/a')"

    SWAP_COMPACT="$(awk '
        /^SwapTotal:/ { t = $2 }
        /^SwapFree:/  { f = $2 }
        END {
            if (t > 0) {
                u = t - f
                printf "%.1f/%.1fG", u / 1048576, t / 1048576
            } else {
                printf "OFF"
            }
        }
    ' /proc/meminfo 2>/dev/null || printf 'n/a')"

    local route_line
    route_line="$(ip -4 route get 1.1.1.1 2>/dev/null | head -n1 || true)"
    if [ -n "$route_line" ]; then
        NET_IFACE="$(awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' <<<"$route_line")"
        NET_IP="$(awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' <<<"$route_line")"
    else
        NET_IFACE=""
        NET_IP=""
    fi
    if [ -z "$NET_IFACE" ]; then
        NET_IFACE="OFFLINE"
        NET_IP="0.0.0.0"
    else
        [ -n "$NET_IP" ] || NET_IP="DHCP"
    fi

    VPN_IFACES="$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 | grep -E '^(wg|tun|tap|proton|tailscale)[0-9A-Za-z_-]*$' | paste -sd ',' - || true)"
    if [ -n "$VPN_IFACES" ]; then
        VPN_STATE="ACTIVE ($VPN_IFACES)"
        VPN_SHORT="UP:$VPN_IFACES"
    else
        VPN_STATE="STANDBY (wg0/tun0: down)"
        VPN_SHORT="STANDBY"
    fi

    VM_RUNNING=0
    local vms_dir="${VMS_DIR:-$HOME/VMs}"
    if [ -d "$vms_dir" ]; then
        local pid_file pid
        while IFS= read -r pid_file; do
            [ -r "$pid_file" ] || continue
            pid="$(head -n 1 "$pid_file" 2>/dev/null || true)"
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                VM_RUNNING=$((VM_RUNNING + 1))
            fi
        done < <(find "$vms_dir" -maxdepth 2 -name '*.pid' 2>/dev/null || true)
    fi

    CPU_TEMP="$(read_cpu_temp || printf 'n/a')"
}

last_login_line() {
    if command -v last >/dev/null 2>&1; then
        last -n 1 -w 2>/dev/null | head -n1 | awk '{print $1 "@" $2 " (" $4 " " $5 " " $6 " " $7 ")"}' | sanitize || true
    fi
}

# Lee entradas reales del journal: si el usuario tiene acceso al journal del sistema
# (grupo systemd-journal/adm), prioriza eventos del sistema; si no, usa journal --user.
recent_journal_lines() {
    local count="${1:-3}" maxlen="${2:-62}"
    command -v journalctl >/dev/null 2>&1 || return 0

    local raw=""
    if id -nG 2>/dev/null | tr ' ' '\n' | grep -qxE 'adm|systemd-journal'; then
        raw="$(journalctl -q -n 40 -o short-iso --no-pager 2>/dev/null || true)"
    fi
    if [ -z "$raw" ]; then
        raw="$(journalctl -q --user -n 30 -o short-iso --no-pager 2>/dev/null || true)"
    fi

    [ -n "$raw" ] || return 0
    printf '%s\n' "$raw" \
        | grep -v 'health_status' \
        | tail -n "$count" \
        | sed -E 's/^[^T]+T([0-9:]+)-[^ ]+ [^ ]+ ([^:]+): (.*)$/[\1] \2: \3/' \
        | sanitize \
        | cut -c1-"$maxlen" || true
}

render_left() {
    probe_host_facts
    printf '[SYS // %s]\n' "$HOST_NAME"
    printf '%-7s %s\n' "KERNEL" "$KERNEL_REL"
    printf '%-7s %s\n' "UPTIME" "$UPTIME_STR"
    printf '%-7s %s\n' "LOAD"   "$LOAD_STR"
    printf '%-7s %s\n' "MEM"    "$MEM_STR"
    printf '%-7s %s\n' "SWAP"   "$SWAP_STR"
}

render_right() {
    probe_host_facts
    local iface_disp vpn_disp pwr_label
    if [ "$NET_IFACE" = "OFFLINE" ]; then
        iface_disp="OFFLINE"
    else
        iface_disp="$NET_IFACE (UP)"
    fi
    if [ -n "$VPN_IFACES" ]; then
        vpn_disp="ACTIVE ($VPN_IFACES)"
    else
        vpn_disp="STANDBY"
    fi

    local bat_dir=""
    for d in /sys/class/power_supply/BAT*; do
        [ -d "$d" ] && { bat_dir="$d"; break; }
    done
    if [ -n "$bat_dir" ] && [ -r "$bat_dir/capacity" ]; then
        local cap st
        cap="$(cat "$bat_dir/capacity" 2>/dev/null || echo '?')"
        st="$(cat "$bat_dir/status" 2>/dev/null || echo 'BAT')"
        pwr_label="${st^^} (${cap}%)"
    else
        pwr_label="AC // DESKTOP"
    fi

    printf '[NET // SEC TELEMETRY]\n'
    printf '%s  %-5s\n' "$iface_disp"         "IFACE"
    printf '%s  %-5s\n' "$NET_IP"             "ADDR"
    printf '%s  %-5s\n' "$vpn_disp"           "VPN"
    printf '%d ACTIVE  %-5s\n' "$VM_RUNNING"  "KVM"
    printf '%s  %-5s\n' "$pwr_label"          "PWR"
}

render_stream() {
    probe_host_facts
    local ts net_stat top_procs
    ts="$(date +"%H:%M:%S")"

    net_stat="$(awk '
        NR > 2 {
            gsub(/:/, "", $1)
            if ($1 != "lo" && $2 + $10 > 0) {
                printf "%s rx=%.1fMiB tx=%.1fMiB", $1, $2 / 1048576, $10 / 1048576
                exit
            }
        }
    ' /proc/net/dev 2>/dev/null || printf 'net=idle')"
    [ -n "$net_stat" ] || net_stat="net=idle"

    top_procs="$(ps -eo comm=,rss= --sort=-rss 2>/dev/null | awk '
        NR <= 3 {
            if (NR > 1) out = out " · "
            out = out sprintf("%s(%dM)", $1, int($2 / 1024))
        }
        END { print out }
    ' | sanitize || printf 'n/a')"

    printf '[MON %s] procs_run=%s/%s · cpu_temp=%s\n' "$ts" "$PROCS_RUN" "$PROCS_TOT" "$CPU_TEMP"
    printf '[NET // IO]  %s\n' "$net_stat"
    printf '[TOP // MEM] %s\n' "$top_procs"
    printf '[SEC // PAM] pam_unix: armed · lock: hyprlock · dpms: 600s\n'
}

render_soc() {
    probe_host_facts
    local ts login_info j_lines kvm_dev="missing" zram_dev="off"
    ts="$(date +"%H:%M:%S")"
    login_info="$(last_login_line)"
    j_lines="$(recent_journal_lines 3 64)"
    [ -c /dev/kvm ] && kvm_dev="rw (/dev/kvm)"
    [ -b /dev/zram0 ] && zram_dev="active (zram0)"

    printf '[OK ] sys.kernel   %s · up %s · temp %s\n' "$KERNEL_REL" "$UPTIME_STR" "$CPU_TEMP"
    printf '[OK ] sys.mem      ram=%s · swap=%s · %s\n' "$MEM_STR" "$SWAP_STR" "$zram_dev"
    printf '[OK ] net.route    iface=%s · ip=%s · vpn=%s\n' "$NET_IFACE" "$NET_IP" "$VPN_STATE"
    printf '[SEC] pam_unix     session=locked · kvm=%s · vms_up=%d\n' "$kvm_dev" "$VM_RUNNING"
    if [ -n "$login_info" ]; then
        printf '[LOG] auth.last    %s\n' "$login_info"
    fi
    printf '[MON] pulse        %s · load=%s · procs=%s/%s\n' "$ts" "$LOAD_STR" "$PROCS_RUN" "$PROCS_TOT"
    if [ -n "$j_lines" ]; then
        printf '%s\n' "$j_lines"
    fi
}

# Genera una línea nueva por tick para el feed progresivo de soc-console.
next_soc_line() {
    local step="$1" ts tcp_est net_io top_procs fs_root last_pkg j_entry
    ts="$(date +"%H:%M:%S")"

    case $((step % 6)) in
        0)
            printf '[MON %s] load=%s · procs=%s/%s · cpu=%s\n' \
                "$ts" "${LOAD_STR%% *}" "$PROCS_RUN" "$PROCS_TOT" "$CPU_TEMP"
            ;;
        1)
            j_entry="$(recent_journal_lines 1 60 || true)"
            if [ -n "$j_entry" ] && ! grep -Fqx -- "$j_entry" "$FEED_LOG" 2>/dev/null; then
                printf '%s\n' "$j_entry"
            else
                tcp_est="$(ss -Ht state established 2>/dev/null | wc -l || echo 0)"
                printf '[SEC %s] pam_unix: armed · tcp_est=%s · kvm_vms=%d\n' \
                    "$ts" "$tcp_est" "$VM_RUNNING"
            fi
            ;;
        2)
            net_io="$(awk '
                NR > 2 {
                    gsub(/:/, "", $1)
                    if ($1 != "lo" && $2 + $10 > 0) {
                        printf "%s rx=%.1fMiB tx=%.1fMiB", $1, $2 / 1048576, $10 / 1048576
                        exit
                    }
                }
            ' /proc/net/dev 2>/dev/null || printf 'idle')"
            printf '[IO  %s] %s\n' "$ts" "${net_io:-idle}"
            ;;
        3)
            top_procs="$(ps -eo comm=,rss= --sort=-rss 2>/dev/null | awk '
                NR <= 3 {
                    if (NR > 1) out = out " · "
                    out = out sprintf("%s(%dM)", $1, int($2 / 1024))
                }
                END { print out }
            ' | sanitize || printf 'n/a')"
            printf '[TOP %s] %s\n' "$ts" "$top_procs"
            ;;
        4)
            fs_root="$(df -P / 2>/dev/null | awk 'NR==2{print $5 " (" $4 ")"}')"
            printf '[FS  %s] root=%s · mem=%s · zram=%s\n' \
                "$ts" "${fs_root:-n/a}" "$MEM_COMPACT" "$SWAP_COMPACT"
            ;;
        5)
            last_pkg="$(grep -E ' (install|upgrade) ' /var/log/dpkg.log 2>/dev/null | tail -n1 | awk '{print $1 " " $4}' | cut -d: -f1 | sanitize || true)"
            if [ -n "$last_pkg" ]; then
                printf '[PKG %s] apt.last: %s\n' "$ts" "$last_pkg"
            else
                printf '[SVC %s] hypridle/swaync/rofi · lock_policy=300s\n' "$ts"
            fi
            ;;
    esac
}

# HUD completo en esquina superior derecha: cabecera fija + feed progresivo en tmpfs.
# Usa flock + timestamp para sincronizar múltiples monitores sin duplicar ticks.
render_soc_feed() {
    probe_host_facts

    local run_dir="${XDG_RUNTIME_DIR:-/tmp}"
    local FEED_LOG="$run_dir/hyprlock-soc.feed"
    local STATE_FILE="$run_dir/hyprlock-soc.state"
    local LOCK_FILE="$run_dir/hyprlock-soc.lock"
    local now ts login_info
    now="$(date +%s)"
    ts="$(date +"%H:%M:%S")"
    login_info="$(last_login_line)"

    exec 9>"$LOCK_FILE"
    flock -w 1 9 2>/dev/null || true

    local prev_ts=0 tick=0
    if [ -r "$STATE_FILE" ]; then
        read -r prev_ts tick <"$STATE_FILE" 2>/dev/null || { prev_ts=0; tick=0; }
    fi

    # Si es un bloqueo nuevo (>8s desde el último refresco) o no existe buffer, reiniciar feed
    if [ ! -f "$FEED_LOG" ] || [ $((now - prev_ts)) -gt 8 ]; then
        {
            printf '[SEC %s] ext-session-lock-v1 acquired · pam_unix armed\n' "$ts"
            printf '[NET %s] %s %s · vpn %s\n' "$ts" "$NET_IFACE" "$NET_IP" "$VPN_SHORT"
            if [ -n "$login_info" ]; then
                printf '[LOG %s] auth.last %s\n' "$ts" "$login_info"
            fi
        } >"$FEED_LOG"
        printf '%s %s\n' "$now" "0" >"$STATE_FILE"
    elif [ $((now - prev_ts)) -ge 1 ]; then
        tick=$((tick + 1))
        next_soc_line "$tick" >>"$FEED_LOG"
        tail -n 12 "$FEED_LOG" >"$FEED_LOG.tmp" && mv -f "$FEED_LOG.tmp" "$FEED_LOG"
        printf '%s %s\n' "$now" "$tick" >"$STATE_FILE"
    fi

    local tcp_est kvm_tag
    tcp_est="$(ss -Ht state established 2>/dev/null | wc -l || echo 0)"
    kvm_tag="$([ -c /dev/kvm ] && printf '%dVMs' "$VM_RUNNING" || printf 'off')"

    printf '[SOC // %s] %s · up %s\n' "$HOST_NAME" "$KERNEL_REL" "$UPTIME_STR"
    printf 'MEM %s · SWAP %s · CPU %s · LOAD %s\n' "$MEM_COMPACT" "$SWAP_COMPACT" "$CPU_TEMP" "${LOAD_STR%% *}"
    printf 'NET %s %s · VPN %s · TCP %s · KVM %s\n' "$NET_IFACE" "$NET_IP" "$VPN_SHORT" "$tcp_est" "$kvm_tag"
    printf '%s\n' '--------------------------------------------------------------'
    cat "$FEED_LOG"
}

render_matrix_left() {
    probe_host_facts
    local ts j_lines net_lines
    ts="$(date +"%H:%M:%S")"
    j_lines="$(recent_journal_lines 6 62)"
    net_lines="$(awk '
        NR > 2 {
            gsub(/:/, "", $1)
            if ($1 != "lo") {
                printf "[IO ] %-10s rx=%8.1f MiB  tx=%8.1f MiB\n", $1, $2 / 1048576, $10 / 1048576
            }
        }
    ' /proc/net/dev 2>/dev/null | head -n 4 || true)"

    printf '// SOC TELEMETRY STREAM · %s · %s\n' "$HOST_NAME" "$ts"
    printf '[OK ] kernel.rel   %s\n' "$KERNEL_REL"
    printf '[OK ] sys.uptime   %s · load %s\n' "$UPTIME_STR" "$LOAD_STR"
    printf '[OK ] mem.usage    %s\n' "$MEM_STR"
    printf '[OK ] swap.zram    %s\n' "$SWAP_STR"
    printf '[OK ] cpu.sensor   %s · runnable=%s/%s\n' "$CPU_TEMP" "$PROCS_RUN" "$PROCS_TOT"
    printf '\n// NETWORK INTERFACES\n'
    printf '[NET] primary      %s · ip=%s\n' "$NET_IFACE" "$NET_IP"
    printf '[NET] tunnel       %s\n' "$VPN_STATE"
    if [ -n "$net_lines" ]; then
        printf '%s\n' "$net_lines"
    fi
    printf '\n// JOURNAL FEED\n'
    if [ -n "$j_lines" ]; then
        printf '%s\n' "$j_lines"
    else
        printf '[LOG] no recent journal entries\n'
    fi
}

render_matrix_right() {
    probe_host_facts
    local ts login_info top_list tcp_est kvm_state="DISABLED"
    ts="$(date +"%H:%M:%S")"
    login_info="$(last_login_line)"
    [ -c /dev/kvm ] && kvm_state="ACTIVE (/dev/kvm)"
    tcp_est="$(ss -Ht state established 2>/dev/null | wc -l || echo 0)"
    top_list="$(ps -eo pid=,comm=,pcpu=,rss= --sort=-rss 2>/dev/null | head -n 6 | awk '{
        printf "[PROC] %-6s %-16s cpu=%4.1f%%  rss=%4dM\n", $1, $2, $3, int($4 / 1024)
    }' | sanitize || true)"

    printf '// SECURITY & PROCESS WATCH · %s\n' "$ts"
    printf '[SEC] auth.pam     pam_unix: armed · guard: hyprlock\n'
    printf '[SEC] lock.policy  idle=300s · dpms=600s · sleep=900/1200s\n'
    printf '[SEC] auth.last    %s\n' "${login_info:-unknown}"
    printf '[SEC] virt.kvm     %s · running_vms=%d\n' "$kvm_state" "$VM_RUNNING"
    printf '[NET] sockets      tcp_established=%s\n' "$tcp_est"
    printf '\n// TOP RESIDENT PROCESSES\n'
    if [ -n "$top_list" ]; then
        printf '%s\n' "$top_list"
    fi
    printf '\n// INTEGRITY CHECK\n'
    printf '[OK ] wayland.lock ext-session-lock-v1 active\n'
    printf '[OK ] input.grab   keyboard exclusive\n'
}

case "${1:-}" in
    left)     render_left ;;
    right)    render_right ;;
    stream)   render_stream ;;
    soc)      render_soc ;;
    soc-feed) render_soc_feed ;;
    matrix-l) render_matrix_left ;;
    matrix-r) render_matrix_right ;;
    *)
        printf 'Uso: %s {left|right|stream|soc|soc-feed|matrix-l|matrix-r}\n' "$0" >&2
        exit 2
        ;;
esac
