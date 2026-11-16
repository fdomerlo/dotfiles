#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/vm-menu.sh - Gestor interactivo de VMs (Quickemu + QEMU/KVM)
#
# Diseñado para Hyprland (Fuzzel dmenu + foot), sin daemons permanentes.
# Explora *.conf dentro de ${VMS_DIR:-$HOME/VMs} y permite iniciar, conectar,
# apagar (ACPI o --kill), gestionar snapshots, crear VMs con quickget o editar
# la configuración.
#
# Uso:
#   vm-menu.sh [menu|list|status|start <vm>|stop <vm>|kill <vm>]
# ==============================================================================
set -euo pipefail

VMS_DIR="${VMS_DIR:-$HOME/VMs}"
PROMPT_PREFIX="${VM_PROMPT_PREFIX:-VMs}"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "VMs · Quickemu" "$@" 2>/dev/null || true
    fi
}

die() {
    notify -u critical "VMs · Quickemu" "$1"
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

dmenu() {
    local prompt="$1" lines="$2" width="$3"
    shift 3
    [ "$lines" -gt 14 ] && lines=14
    [ "$lines" -lt 2 ] && lines=2
    printf '%s\n' "$@" | fuzzel --dmenu \
        --prompt "$prompt" \
        --width "$width" \
        --lines "$lines" 2>/dev/null || true
}

dmenu_input() {
    local prompt="$1" width="${2:-44}"
    printf '' | fuzzel --dmenu \
        --prompt "$prompt" \
        --width "$width" \
        --lines 0 2>/dev/null || true
}

require_quickemu() {
    command -v quickemu >/dev/null 2>&1 ||
        die "Quickemu no está instalado. Ejecutá 'make virt' en ~/.dotfiles."
}

# Resuelve metadata de una VM leyendo su .conf en subshell aislado,
# imitando exactamente la lógica de /usr/bin/quickemu.
# Salida: vmname|vmdir|disk_img|display|monitor|pid
vm_inspect() {
    local conf="$1"
    local vmname vmdir disk_img display monitor pid=""
    vmname="$(basename "$conf" .conf)"

    eval "$(
        bash -c '
            set -e
            disk_img=""
            disk_format="qcow2"
            display="sdl"
            monitor="socket"
            # shellcheck source=/dev/null
            source "$1" >/dev/null 2>&1 || true
            vmname="$(basename "$1" .conf)"
            if [ -n "$disk_img" ]; then
                vmdir="$(dirname "$disk_img")"
            else
                vmdir="$(cd "$(dirname "$1")" && pwd)/$vmname"
                disk_img="$vmdir/disk.${disk_format:-qcow2}"
            fi
            printf "vmdir=%q\ndisk_img=%q\ndisplay=%q\nmonitor=%q\n" \
                "$vmdir" "$disk_img" "$display" "$monitor"
        ' _ "$conf"
    )"

    local pid_file="$vmdir/$vmname.pid"
    if [ -r "$pid_file" ]; then
        pid="$(head -n 1 "$pid_file" 2>/dev/null || true)"
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            pid=""
        fi
    fi

    printf '%s|%s|%s|%s|%s|%s\n' "$vmname" "$vmdir" "$disk_img" "$display" "$monitor" "$pid"
}

list_vm_confs() {
    [ -d "$VMS_DIR" ] || return 0
    shopt -s nullglob
    local -a confs=("$VMS_DIR"/*.conf)
    shopt -u nullglob
    if [ "${#confs[@]}" -gt 0 ]; then
        printf '%s\n' "${confs[@]}" | LC_ALL=C sort
    fi
}

__launch() {
    local conf="$1" vmname="$2" log="$3"
    shift 3
    mkdir -p "$(dirname "$log")"
    local rc=0
    quickemu --vm "$conf" "$@" >"$log" 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        local err
        err="$(tail -n 3 "$log" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
        notify -u critical "Error al iniciar $vmname (código $rc)" "${err:-Revisá $log}"
        if command -v foot >/dev/null 2>&1; then
            setsid foot --title "Error · $vmname" -e bash -c '
                printf "\033[1;31mError al iniciar %s (código %s)\033[0m\n\n" "$1" "$2"
                cat "$3" 2>/dev/null || true
                printf "\n[Presioná cualquier tecla para cerrar]"
                read -rn1 -s _
            ' _ "$vmname" "$rc" "$log" >/dev/null 2>&1 </dev/null &
        fi
        exit "$rc"
    fi
}

launch_quickemu() {
    local conf="$1"
    shift
    local info vmname vmdir disk_img display monitor pid
    info="$(vm_inspect "$conf")"
    IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"

    local launch_log="$vmdir/${vmname}.launch.log"
    local self
    self="$(readlink -f "${BASH_SOURCE[0]}")"
    setsid "$self" __launch "$conf" "$vmname" "$launch_log" "$@" >/dev/null 2>&1 </dev/null &

    notify "VM: $vmname" "Iniciando con Quickemu..."
}

acpi_shutdown_vm() {
    local conf="$1"
    local info vmname vmdir disk_img display monitor pid
    info="$(vm_inspect "$conf")"
    IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"

    local sock="$vmdir/${vmname}-monitor.socket"
    if [ -S "$sock" ] && command -v socat >/dev/null 2>&1; then
        if printf 'system_powerdown\n' | socat -,shut-down "unix-connect:$sock" >/dev/null 2>&1; then
            notify "VM: $vmname" "Señal ACPI de apagado enviada."
            return 0
        fi
    fi

    if quickemu --vm "$conf" --monitor-cmd system_powerdown >/dev/null 2>&1; then
        notify "VM: $vmname" "Señal ACPI de apagado enviada."
    else
        notify -u critical "VM: $vmname" "No se pudo enviar apagado ACPI; probá forzar apagado (--kill)."
    fi
}

kill_vm() {
    local conf="$1"
    local info vmname vmdir disk_img display monitor pid
    info="$(vm_inspect "$conf")"
    IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"

    if quickemu --vm "$conf" --kill >/dev/null 2>&1; then
        notify "VM: $vmname" "Proceso QEMU detenido (--kill)."
    else
        notify -u critical "VM: $vmname" "No se pudo detener la VM."
    fi
}

open_term_hold() {
    local title="$1" cmd="$2"
    command -v foot >/dev/null 2>&1 || die "No se encontró foot."
    setsid foot --title "$title" -e bash -lc \
        "$cmd; rc=\$?; printf '\n[Estado: %s] Presioná cualquier tecla para cerrar...' \"\$rc\"; read -rn1 -s _" \
        >/dev/null 2>&1 </dev/null &
}

open_quickget_shell() {
    mkdir -p "$VMS_DIR"
    command -v foot >/dev/null 2>&1 || die "No se encontró foot."
    setsid foot --title "Quickget · Nueva VM" --working-directory "$VMS_DIR" -e bash -lc '
        printf "\033[1;36mCrear nueva VM en %s\033[0m\n\n" "'"$VMS_DIR"'"
        printf "Ejemplos:\n"
        printf "  quickget ubuntu 24.04\n"
        printf "  quickget windows 10\n"
        printf "  quickget fedora 41\n"
        printf "  quickget --list | less\n\n"
        exec "${SHELL:-/bin/bash}" -i
    ' >/dev/null 2>&1 </dev/null &
}

menu_snapshots() {
    local conf="$1" vmname="$2" disk_img="$3"
    if [ ! -e "$disk_img" ]; then
        notify -u critical "Snapshots · $vmname" "No existe el disco: $disk_img"
        return 0
    fi

    while true; do
        local -a opts=(
            "󰐕  Crear snapshot nuevo"
            "󰋼  Ver detalle en terminal (qemu-img info)"
        )

        if command -v qemu-img >/dev/null 2>&1; then
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                # qemu-img snapshot -l: ID  TAG  VM_SIZE (num unit)  DATE  TIME  VM_CLOCK ...
                local tag snap_dt
                tag="$(awk '{print $2}' <<<"$line")"
                snap_dt="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<<"$line" | head -n1 || true)"
                [ -n "$tag" ] || continue
                if [ -n "$snap_dt" ]; then
                    opts+=("󰁯  Restaurar: $tag ($snap_dt)")
                else
                    opts+=("󰁯  Restaurar: $tag")
                fi
            done < <(qemu-img snapshot -l "$disk_img" 2>/dev/null | tail -n +3 || true)
        fi

        opts+=("󰁍  Volver")

        local choice
        choice="$(dmenu "${PROMPT_PREFIX} · $vmname · Snapshots: " "${#opts[@]}" 54 "${opts[@]}")"
        [ -n "$choice" ] || exit 0

        case "$choice" in
            "󰐕 "*)
                local new_tag
                new_tag="$(dmenu_input "Nombre del snapshot (ej. pre-update): " 46)"
                [ -n "$new_tag" ] || continue
                new_tag="${new_tag// /_}"
                open_term_hold "Snapshot · $vmname" \
                    "quickemu --vm $(printf '%q' "$conf") --snapshot create $(printf '%q' "$new_tag")"
                return 0
                ;;
            "󰋼 "*)
                open_term_hold "Snapshots · $vmname" \
                    "quickemu --vm $(printf '%q' "$conf") --snapshot info"
                return 0
                ;;
            "󰁯  Restaurar: "*)
                local chosen_tag
                chosen_tag="$(sed -E 's/^󰁯  Restaurar: (.*)( \([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\))$/\1/; s/^󰁯  Restaurar: //' <<<"$choice")"
                local confirm
                confirm="$(dmenu "¿Restaurar '$chosen_tag' en $vmname?: " 2 46 \
                    "󰁯  Sí, restaurar '$chosen_tag'" \
                    "󰁍  Cancelar")"
                if [[ "$confirm" == "󰁯 "* ]]; then
                    open_term_hold "Restaurar snapshot · $vmname" \
                        "quickemu --vm $(printf '%q' "$conf") --snapshot apply $(printf '%q' "$chosen_tag")"
                    return 0
                fi
                ;;
            "󰁍 "*)
                return 0
                ;;
        esac
    done
}

menu_vm_actions() {
    local conf="$1"
    local info vmname vmdir disk_img display monitor pid

    while true; do
        # Refrescar PID en cada iteración del submenú
        info="$(vm_inspect "$conf")"
        IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"

        local -a opts=()
        if [ -n "$pid" ]; then
            opts+=(
                "󰓦  Conectar visor / abrir ventana (PID $pid)"
                "󰐥  Apagar limpio (ACPI system_powerdown)"
                "󰅖  Forzar apagado (--kill)"
            )
            if [ -f "$vmdir/$vmname.log" ]; then
                opts+=("󰜷  Ver log de QEMU en vivo")
            fi
            opts+=(
                "󰒓  Editar configuración ($vmname.conf)"
                "󰁍  Volver"
            )

            local choice
            choice="$(dmenu "${PROMPT_PREFIX} · $vmname [CORRIENDO]: " "${#opts[@]}" 52 "${opts[@]}")"
            [ -n "$choice" ] || exit 0

            case "$choice" in
                "󰓦 "*) launch_quickemu "$conf"; exit 0 ;;
                "󰐥 "*) acpi_shutdown_vm "$conf"; exit 0 ;;
                "󰅖 "*) kill_vm "$conf"; exit 0 ;;
                "󰜷 "*)
                    setsid foot --title "Log · $vmname" -e tail -n 80 -f "$vmdir/$vmname.log" \
                        >/dev/null 2>&1 </dev/null &
                    exit 0
                    ;;
                "󰒓 "*)
                    setsid foot --title "Config · $vmname.conf" -e "${EDITOR:-nvim}" "$conf" \
                        >/dev/null 2>&1 </dev/null &
                    exit 0
                    ;;
                "󰁍 "*) return 0 ;;
            esac
        else
            opts+=(
                "󰐊  Iniciar VM (config: $display)"
                "󰓦  Iniciar con SPICE (qxl-vga · spicy)"
                "󰔟  Iniciar temporal sin guardar cambios (--status-quo)"
                "󰆓  Snapshots (ver / crear / restaurar)"
                "󰒓  Editar configuración ($vmname.conf)"
            )
            if [ -f "$vmdir/$vmname.log" ] || [ -f "$vmdir/$vmname.launch.log" ]; then
                opts+=("󰜷  Ver último log")
            fi
            opts+=("󰁍  Volver")

            local choice
            choice="$(dmenu "${PROMPT_PREFIX} · $vmname [APAGADA]: " "${#opts[@]}" 56 "${opts[@]}")"
            [ -n "$choice" ] || exit 0

            case "$choice" in
                "󰐊 "*) launch_quickemu "$conf"; exit 0 ;;
                "󰓦 "*) launch_quickemu "$conf" --display spice; exit 0 ;;
                "󰔟 "*) launch_quickemu "$conf" --status-quo; exit 0 ;;
                "󰆓 "*) menu_snapshots "$conf" "$vmname" "$disk_img" ;;
                "󰒓 "*)
                    setsid foot --title "Config · $vmname.conf" -e "${EDITOR:-nvim}" "$conf" \
                        >/dev/null 2>&1 </dev/null &
                    exit 0
                    ;;
                "󰜷 "*)
                    local log_cmd=""
                    if [ -f "$vmdir/$vmname.launch.log" ]; then
                        log_cmd+="printf '=== Launch log ===\n'; cat $(printf '%q' "$vmdir/$vmname.launch.log"); printf '\n'"
                    fi
                    if [ -f "$vmdir/$vmname.log" ]; then
                        [ -n "$log_cmd" ] && log_cmd+="; "
                        log_cmd+="printf '=== QEMU log ===\n'; cat $(printf '%q' "$vmdir/$vmname.log")"
                    fi
                    open_term_hold "Log · $vmname" "$log_cmd"
                    exit 0
                    ;;
                "󰁍 "*) return 0 ;;
            esac
        fi
    done
}

menu_main() {
    command -v fuzzel >/dev/null 2>&1 || die "Fuzzel no está instalado."
    require_quickemu

    while true; do
        local -a confs=() opts=()
        while IFS= read -r c; do
            [ -n "$c" ] || continue
            confs+=("$c")
        done < <(list_vm_confs)

        for c in "${confs[@]}"; do
            local info vmname vmdir disk_img display monitor pid
            info="$(vm_inspect "$c")"
            IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"
            if [ -n "$pid" ]; then
                opts+=("󰐊  $vmname  [CORRIENDO · PID $pid]")
            else
                opts+=("󰍹  $vmname  [APAGADA]")
            fi
        done

        opts+=(
            "󰐕  Nueva VM (quickget en terminal)"
            "󰉋  Abrir carpeta de VMs ($VMS_DIR)"
        )
        if [ "${#confs[@]}" -eq 0 ]; then
            opts+=("󰒍  Comprobar entorno KVM/Quickemu")
        fi

        local choice
        choice="$(dmenu "${PROMPT_PREFIX}: " "${#opts[@]}" 54 "${opts[@]}")"
        [ -n "$choice" ] || exit 0

        case "$choice" in
            "󰐕 "*)
                open_quickget_shell
                exit 0
                ;;
            "󰉋 "*)
                mkdir -p "$VMS_DIR"
                setsid xdg-open "$VMS_DIR" >/dev/null 2>&1 </dev/null &
                exit 0
                ;;
            "󰒍 "*)
                open_term_hold "Verificación Quickemu/KVM" \
                    "bash \"${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/virt.sh\" --check"
                exit 0
                ;;
            *)
                local chosen_name
                chosen_name="$(sed -E 's/^(󰐊|󰍹)  (.*)  \[[^]]*\]$/\2/' <<<"$choice")"
                local target_conf="$VMS_DIR/$chosen_name.conf"
                if [ -f "$target_conf" ]; then
                    menu_vm_actions "$target_conf"
                else
                    notify -u critical "VMs" "No se encontró $target_conf"
                fi
                ;;
        esac
    done
}

cli_list() {
    local -a confs=()
    while IFS= read -r c; do
        [ -n "$c" ] && confs+=("$c")
    done < <(list_vm_confs)

    if [ "${#confs[@]}" -eq 0 ]; then
        printf 'No hay VMs (.conf) en %s\n' "$VMS_DIR"
        return 0
    fi

    for c in "${confs[@]}"; do
        local info vmname vmdir disk_img display monitor pid
        info="$(vm_inspect "$c")"
        IFS='|' read -r vmname vmdir disk_img display monitor pid <<<"$info"
        if [ -n "$pid" ]; then
            printf '%-20s CORRIENDO (PID %s)  %s\n' "$vmname" "$pid" "$disk_img"
        else
            printf '%-20s APAGADA               %s\n' "$vmname" "$disk_img"
        fi
    done
}

case "${1:-menu}" in
    __launch)
        shift
        __launch "$@"
        ;;
    menu|"")
        menu_main
        ;;
    list|status)
        cli_list
        ;;
    start)
        require_quickemu
        [ -n "${2:-}" ] || die "Uso: $0 start <nombre-vm>"
        conf="$VMS_DIR/${2%.conf}.conf"
        [ -f "$conf" ] || die "No existe $conf"
        shift 2
        launch_quickemu "$conf" "$@"
        ;;
    stop)
        require_quickemu
        [ -n "${2:-}" ] || die "Uso: $0 stop <nombre-vm>"
        conf="$VMS_DIR/${2%.conf}.conf"
        [ -f "$conf" ] || die "No existe $conf"
        acpi_shutdown_vm "$conf"
        ;;
    kill)
        require_quickemu
        [ -n "${2:-}" ] || die "Uso: $0 kill <nombre-vm>"
        conf="$VMS_DIR/${2%.conf}.conf"
        [ -f "$conf" ] || die "No existe $conf"
        kill_vm "$conf"
        ;;
    *)
        printf 'Uso: %s [menu|list|status|start <vm>|stop <vm>|kill <vm>]\n' "$0" >&2
        exit 2
        ;;
esac
