#!/usr/bin/env bash
# ==============================================================================
# Monitoreo de estado VPN (OpenVPN / WireGuard) para Waybar (JSON)
# ==============================================================================
set -euo pipefail

active_vpns=()
while IFS= read -r line; do
    [ -n "$line" ] && active_vpns+=("$line")
done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -E ':(vpn|wireguard)$' | sed -E 's/:(vpn|wireguard)$//' || true)

if [ "${#active_vpns[@]}" -gt 0 ]; then
    vpn_name="${active_vpns[0]}"
    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg name "$vpn_name" \
            '{text: (" " + $name), tooltip: ("VPN conectada: " + $name + "\nClick para administrar"), class: "connected"}'
    else
        printf '{"text": "\uf132 %s", "tooltip": "VPN conectada: %s\\nClick para administrar", "class": "connected"}\n' "$vpn_name" "$vpn_name"
    fi
else
    printf '{"text": "", "tooltip": "Sin VPN activa\\nClick para conectar", "class": "disconnected"}\n'
fi
