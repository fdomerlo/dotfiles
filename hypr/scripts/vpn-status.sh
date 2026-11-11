#!/usr/bin/env bash
# ==============================================================================
# Monitoreo de estado VPN para Waybar (JSON)
# ==============================================================================
set -euo pipefail

active_vpns=()
while IFS= read -r line; do
    [ -n "$line" ] && active_vpns+=("$line")
done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':vpn$' | cut -d: -f1 || true)

if [ "${#active_vpns[@]}" -gt 0 ]; then
    vpn_name="${active_vpns[0]}"
    printf '{"text": "VPN %s", "tooltip": "VPN conectada: %s\\nClick para administrar", "class": "connected"}\n' "$vpn_name" "$vpn_name"
else
    printf '{"text": "", "tooltip": "Sin VPN activa\\nClick para conectar", "class": "disconnected"}\n'
fi
