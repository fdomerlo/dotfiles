#!/usr/bin/env bash
# ==============================================================================
# Menú de red y VPN interactivo para Hyprland (Fuzzel)
# ==============================================================================
set -euo pipefail

# 1. Detectar VPNs configuradas y activas
all_vpns=()
while IFS= read -r line; do
    [ -n "$line" ] && all_vpns+=("$line")
done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':vpn$' | cut -d: -f1 || true)

active_vpns=()
while IFS= read -r line; do
    [ -n "$line" ] && active_vpns+=("$line")
done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':vpn$' | cut -d: -f1 || true)

is_vpn_active() {
    local target="$1"
    for v in "${active_vpns[@]:-}"; do
        [ "$v" = "$target" ] && return 0
    done
    return 1
}

# 2. Detectar estado de Wi-Fi y conexión activa
wifi_radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
active_wifi=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1 | head -n1 || true)

options=()

# Bloque VPN
if [ "${#all_vpns[@]}" -gt 0 ]; then
    for vpn in "${all_vpns[@]}"; do
        if is_vpn_active "$vpn"; then
            options+=("󰌆 Desconectar VPN: $vpn [CONECTADA]")
        else
            options+=("󰌆 Conectar VPN: $vpn [DESCONECTADA]")
        fi
    done
fi

# Bloque Wi-Fi
if [ "$wifi_radio" = "enabled" ]; then
    if [ -n "$active_wifi" ]; then
        options+=("󰤨 Wi-Fi actual: $active_wifi")
    fi
    options+=("󰤮 Desactivar Wi-Fi")
else
    options+=("󰤨 Activar Wi-Fi")
fi

options+=("󰢻 Abrir configuración avanzada (nm-connection-editor)")

# 3. Mostrar menú Fuzzel
num_lines=${#options[@]}
[ "$num_lines" -gt 10 ] && num_lines=10
[ "$num_lines" -lt 3 ] && num_lines=3

CHOSEN=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu \
                                              --prompt "Red: " \
                                              --width 42 \
                                              --lines "$num_lines") || exit 0

case "$CHOSEN" in
    "󰌆 Desconectar VPN:"*)
        vpn_name=$(echo "$CHOSEN" | sed -E 's/󰌆 Desconectar VPN: (.*) \[CONECTADA\]/\1/')
        if nmcli connection down "$vpn_name" >/dev/null 2>&1; then
            notify-send -a "NetworkManager" -i network-vpn "VPN Desconectada" "Se ha desconectado de $vpn_name."
        else
            notify-send -a "NetworkManager" -u critical -i dialog-error "Error VPN" "No se pudo desconectar de $vpn_name."
        fi
        ;;
    "󰌆 Conectar VPN:"*)
        vpn_name=$(echo "$CHOSEN" | sed -E 's/󰌆 Conectar VPN: (.*) \[DESCONECTADA\]/\1/')
        notify-send -a "NetworkManager" -i network-vpn "VPN" "Conectando a $vpn_name..."
        if nmcli connection up "$vpn_name" >/dev/null 2>&1; then
            notify-send -a "NetworkManager" -i network-vpn "VPN Conectada" "Conexión establecida con $vpn_name."
        else
            notify-send -a "NetworkManager" -u critical -i dialog-error "Error VPN" "No se pudo conectar a $vpn_name. Revisa tus certificados o conexión."
        fi
        ;;
    "󰤮 Desactivar Wi-Fi"*)
        nmcli radio wifi off
        notify-send -a "NetworkManager" -i network-wireless-offline "Wi-Fi" "Wi-Fi desactivado."
        ;;
    "󰤨 Activar Wi-Fi"*)
        nmcli radio wifi on
        notify-send -a "NetworkManager" -i network-wireless "Wi-Fi" "Wi-Fi activado."
        ;;
    "󰢻 Abrir configuración avanzada"*)
        nm-connection-editor &
        ;;
    "󰤨 Wi-Fi actual:"*)
        nm-connection-editor &
        ;;
esac
