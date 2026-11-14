#!/usr/bin/env bash
# ==============================================================================
# Menú Maestro jerárquico estilo Omarchy para Hyprland (Fuzzel dmenu).
#
# Pensado para invocarse vía toggle-menu.sh:
#   toggle-menu.sh 'Menú' ~/.config/hypr/scripts/main-menu.sh
#
# Todos los prompts incluyen la palabra "Menú" para que toggle-menu.sh pueda
# detectar y cerrar fuzzel con la misma tecla (Super+Alt+Space) desde cualquier
# submenú, restaurando input:follow_mouse=1 al salir.
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

command -v fuzzel >/dev/null 2>&1 || exit 1

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "$@" 2>/dev/null || true
}

dmenu() {
    local prompt="$1" lines="$2" width="$3"
    shift 3
    printf '%s\n' "$@" | fuzzel --dmenu \
        --prompt "$prompt" \
        --width "$width" \
        --lines "$lines" 2>/dev/null || true
}

launch_bg() {
    setsid "$@" >/dev/null 2>&1 </dev/null &
}

launch_capture() {
    local delay="$1"
    shift
    setsid bash -c 'sleep "$1"; shift; exec "$@"' _ "$delay" "$@" >/dev/null 2>&1 </dev/null &
}

launch_term_hold() {
    local title="$1" cmd="$2"
    if ! command -v foot >/dev/null 2>&1; then
        notify "Menú Maestro" "No se encontró foot para abrir '$title'"
        return 1
    fi
    local wrapped
    wrapped="export PATH=\"\$HOME/.local/bin:\$HOME/.opencode/bin:\$HOME/.local/share/fnm:/usr/local/bin:\$PATH\"; $cmd; rc=\$?; printf '\n[Estado: %s] Presioná cualquier tecla para cerrar...' \"\$rc\"; read -rn1 -s _"
    setsid foot --title "$title" -e bash -lc "$wrapped" >/dev/null 2>&1 </dev/null &
}

current_theme() {
    local active="$HYPR_DIR/themes/active"
    if [ -L "$active" ]; then
        basename "$(readlink "$active")"
    else
        printf 'ninguno'
    fi
}

menu_capturar() {
    local rec_label="󰑋  Grabar pantalla (monitor actual)"
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        rec_label="󰓛  Detener grabación en curso"
    fi

    local -a opts=(
        "󰆞  Captura de región (anotar con Swappy)"
        "󰆟  Captura de región al portapapeles"
        "󰍹  Captura de pantalla completa"
        "$rec_label"
        "󰩭  Grabar región de pantalla"
        "󰈊  Selector de color (Hex)"
        "󰊄  OCR de región (extraer texto)"
        "󰁍  Volver"
    )

    local choice
    choice="$(dmenu "Menú · Capturar: " "${#opts[@]}" 46 "${opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰆞 "*) launch_capture 0.15 "$SCRIPT_DIR/screenshot-region.sh" ;;
        "󰆟 "*) launch_capture 0.15 "$SCRIPT_DIR/screenshot-region.sh" --raw ;;
        "󰍹 "*) launch_capture 0.25 "$SCRIPT_DIR/screenshot-full.sh" ;;
        "󰑋 "*|"󰓛 "*) launch_capture 0.15 "$SCRIPT_DIR/screen-record.sh" ;;
        "󰩭 "*) launch_capture 0.15 "$SCRIPT_DIR/screen-record.sh" --region ;;
        "󰈊 "*) launch_capture 0.15 "$SCRIPT_DIR/color-picker.sh" ;;
        "󰊄 "*) launch_capture 0.15 "$SCRIPT_DIR/ocr-region.sh" ;;
        "󰁍 "*) return 0 ;;
    esac
    exit 0
}

menu_estilo() {
    local theme night_label
    theme="$(current_theme)"
    if [ -f "$RUNTIME/hypr-nightlight.state" ]; then
        night_label="󰖔  Desactivar luz nocturna (4000K)"
    else
        night_label="󰖔  Activar luz nocturna (4000K)"
    fi

    local -a opts=(
        "󰔎  Elegir tema (actual: $theme)"
        "󰸉  Alternar tema rápido"
        "󰸨  Siguiente wallpaper"
        "$night_label"
        "󰂚  Centro de notificaciones (SwayNC)"
        "󰁍  Volver"
    )

    local choice
    choice="$(dmenu "Menú · Estilo: " "${#opts[@]}" 44 "${opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰔎 "*) "$SCRIPT_DIR/theme-switch.sh" menu ;;
        "󰸉 "*) launch_bg "$SCRIPT_DIR/theme-switch.sh" toggle ;;
        "󰸨 "*) launch_bg "$SCRIPT_DIR/wallpaper.sh" --next ;;
        "󰖔 "*) launch_bg "$SCRIPT_DIR/nightlight-toggle.sh" ;;
        "󰂚 "*) launch_bg swaync-client -t -sw ;;
        "󰁍 "*) return 0 ;;
    esac
    exit 0
}

menu_sistema() {
    local -a opts=(
        "󰤨  Red y VPN (NetworkManager)"
        "󰕾  Audio (pavucontrol)"
        "󰂯  Bluetooth (blueman)"
        "󰍺  Escala y PPI de monitores"
        "󰌌  Cheatsheet de atajos"
        "󰑐  Recargar configuración Hyprland"
        "󰐥  Energía y sesión"
        "󰁍  Volver"
    )

    local choice
    choice="$(dmenu "Menú · Sistema: " "${#opts[@]}" 42 "${opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰤨 "*) "$SCRIPT_DIR/network-menu.sh" ;;
        "󰕾 "*) launch_bg pavucontrol ;;
        "󰂯 "*) launch_bg blueman-manager ;;
        "󰍺 "*) launch_term_hold "Escala de monitores" "\"$SCRIPT_DIR/monitor-scale.sh\" --hyprconf" ;;
        "󰌌 "*) "$SCRIPT_DIR/keybinds.sh" ;;
        "󰑐 "*)
            if hyprctl reload >/dev/null 2>&1; then
                notify "Hyprland" "Configuración recargada"
            else
                notify -u critical "Hyprland" "Error al recargar configuración"
            fi
            ;;
        "󰐥 "*) "$SCRIPT_DIR/powermenu.sh" ;;
        "󰁍 "*) return 0 ;;
    esac
    exit 0
}

menu_dev() {
    local -a opts=(
        "󰒍  Diagnóstico de estación (devctl doctor)"
        "󰚰  Actualizar estación (devctl update)"
        "󰃢  Limpieza profunda (devctl clean)"
        "󰍛  Monitor de sistema (btop)"
        "󰡨  Contenedores (lazydocker)"
        "󰉋  Gestor de archivos TUI (yazi)"
        "󰁍  Volver"
    )

    local choice
    choice="$(dmenu "Menú · Dev & IA: " "${#opts[@]}" 46 "${opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰒍 "*) launch_term_hold "devctl doctor" "devctl doctor" ;;
        "󰚰 "*) launch_term_hold "devctl update" "devctl update" ;;
        "󰃢 "*) launch_term_hold "devctl clean" "devctl clean" ;;
        "󰍛 "*) launch_bg foot --app-id=tui-float -e btop ;;
        "󰡨 "*) launch_bg foot --app-id=tui-float -e lazydocker ;;
        "󰉋 "*) launch_bg foot --app-id=tui-float -e yazi ;;
        "󰁍 "*) return 0 ;;
    esac
    exit 0
}

menu_buscar() {
    local -a opts=(
        "󰀻  Lanzador de aplicaciones"
        "󰖟  Web Apps / PWAs (instalar, abrir, quitar)"
        "󰕰  Overview de workspaces (Quickshell)"
        "󰅌  Historial del portapapeles"
        "󰈞  Buscar archivos"
        "󰆍  Terminal flotante (Scratchpad)"
        "󰁍  Volver"
    )

    local choice
    choice="$(dmenu "Menú · Buscar: " "${#opts[@]}" 48 "${opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰀻 "*) exec env XDG_CURRENT_DESKTOP=Hyprland:GNOME fuzzel --placeholder 'Buscar aplicaciones...' ;;
        "󰖟 "*) WEBAPP_PROMPT_PREFIX="Menú · " "$SCRIPT_DIR/webapp-install.sh" menu ;;
        "󰕰 "*) launch_bg "$SCRIPT_DIR/overview-toggle.sh" ;;
        "󰅌 "*) "$SCRIPT_DIR/clipboard.sh" ;;
        "󰈞 "*) "$SCRIPT_DIR/file-search.sh" ;;
        "󰆍 "*) launch_bg "$SCRIPT_DIR/scratchpad.sh" ;;
        "󰁍 "*) return 0 ;;
    esac
    exit 0
}

while true; do
    root_opts=(
        "󰄀  Capturar"
        "󰏘  Estilo"
        "󰒓  Sistema"
        "󰅬  Dev & IA"
        "󰍉  Buscar & Utilidades"
    )

    choice="$(dmenu "Menú: " "${#root_opts[@]}" 34 "${root_opts[@]}")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰄀 "*) menu_capturar ;;
        "󰏘 "*) menu_estilo ;;
        "󰒓 "*) menu_sistema ;;
        "󰅬 "*) menu_dev ;;
        "󰍉 "*) menu_buscar ;;
    esac
done
