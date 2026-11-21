#!/usr/bin/env bash
# ==============================================================================
# Proveedor de pestañas personalizadas para Rofi 2.0 (protocolo script-mode).
#
# Reemplaza el catálogo de acciones de LauncherWindow.qml sin daemon residente:
#   rofi-actions.sh <dev|capturar|estilo|sistema>
#
# Protocolo Rofi script-mode:
#   ROFI_RETV=0 (o vacío): emite opciones y filas con \0info\x1f<id>\x1fmeta\x1f<keywords>
#   ROFI_RETV=1:           ejecuta la acción identificada por ROFI_INFO en segundo plano
# ==============================================================================
set -euo pipefail

CATEGORY="${1:-}"
SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
RETV="${ROFI_RETV:-0}"
INFO="${ROFI_INFO:-}"

# Escape mínimo para Pango markup
pango_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

emit_row() {
    local id="$1" glyph="$2" title="$3" shortcut="$4" keywords="$5"
    local t_esc s_esc display
    t_esc="$(pango_escape "$title")"
    if [ -n "$shortcut" ]; then
        s_esc="$(pango_escape "$shortcut")"
        display="${glyph}  ${t_esc}   <span alpha='55%' size='small'>[${s_esc}]</span>"
    else
        display="${glyph}  ${t_esc}"
    fi
    printf '%s\0info\x1f%s\x1fmeta\x1f%s\n' "$display" "$id" "$keywords"
}

detach() {
    setsid -f "$@" >/dev/null 2>&1 </dev/null
}

detach_delayed() {
    local delay="$1"
    shift
    setsid -f bash -c 'sleep "$1"; shift; exec "$@"' _ "$delay" "$@" >/dev/null 2>&1 </dev/null
}

detach_term_hold() {
    local title="$1" cmd="$2"
    setsid -f foot --app-id=tui-float --title="$title" -e bash -lc \
        "$cmd; echo; read -n 1 -s -r -p 'Presioná cualquier tecla para cerrar...'" \
        >/dev/null 2>&1 </dev/null
}

list_dev() {
    printf '\0prompt\x1fDev & IA\n'
    printf '\0markup-rows\x1ftrue\n'
    emit_row "ai-menu"       "󰚩" "Asistente IA (acciones rápidas)"          "Super+Shift+A" "ia ai opencode asistente explicar resumir traducir portapapeles commit"
    emit_row "ai-open"       "󰆍" "Abrir OpenCode"                           "Super+Shift+I" "opencode agente ia ai terminal code"
    emit_row "editor"        "󰅩" "Abrir editor (Zed)"                       "Super+C"       "editor zed code vscode nvim codigo abrir"
    emit_row "ai-start"      "󰐊" "Encender servicio OpenCode"               ""              "opencode servicio service daemon start encender background"
    emit_row "ai-stop"       "󰐥" "Apagar servicio OpenCode"                 ""              "opencode servicio service daemon stop apagar background"
    emit_row "ai-status"     "󰒓" "Estado del servicio OpenCode"             ""              "opencode servicio service daemon status estado puerto"
    emit_row "vm-menu"       "󰍹" "Máquinas virtuales (Quickemu)"            ""              "vm virtual machine quickemu quickget qemu windows kvm"
    emit_row "scratchpad"    "󰆍" "Terminal flotante (Scratchpad)"           "Super+Shift+S" "terminal scratchpad flotante foot consola"
    emit_row "devctl-doctor" "󰒍" "Diagnóstico de estación (devctl doctor)"  ""              "devctl doctor diagnostico chequeo sistema"
    emit_row "devctl-update" "󰚰" "Actualizar estación (devctl update)"      ""              "devctl update actualizar upgrade"
    emit_row "devctl-clean"  "󰃢" "Limpieza profunda (devctl clean)"         ""              "devctl clean limpiar cache"
    emit_row "btop"          "󰍛" "Monitor de sistema (btop)"                ""              "btop monitor cpu ram procesos htop"
    emit_row "lazydocker"    "󰡨" "Contenedores (lazydocker)"                ""              "lazydocker podman docker contenedores tui"
    emit_row "yazi"          "󰉋" "Gestor de archivos TUI (yazi)"            "Super+Y"       "yazi archivos gestor file manager tui"
}

list_capturar() {
    printf '\0prompt\x1fCapturar\n'
    printf '\0markup-rows\x1ftrue\n'

    local rec_glyph="󰑋" rec_title="Grabar pantalla (monitor actual)"
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        rec_glyph="󰓛"
        rec_title="Detener grabación en curso"
    fi

    emit_row "shot-region"   "󰆞" "Captura de región (anotar con Swappy)"    "Print"         "screenshot captura region swappy recortar imagen"
    emit_row "shot-raw"      "󰆟" "Captura de región al portapapeles"        "Ctrl+Print"    "screenshot captura portapapeles raw copiar"
    emit_row "shot-full"     "󰍹" "Captura de pantalla completa"             "Shift+Print"   "screenshot full pantalla completa print"
    emit_row "rec-toggle"    "$rec_glyph" "$rec_title"                      "Super+Shift+R" "grabar video pantalla record wf-recorder detener"
    emit_row "rec-region"    "󰩭" "Grabar región de pantalla"                ""              "grabar video region area slurp wf-recorder"
    emit_row "color-picker"  "󰈊" "Selector de color (Hex)"                  "Super+Shift+P" "color picker hex hyprpicker gotero"
    emit_row "ocr-region"    "󰊄" "OCR de región (extraer texto)"            "Super+Ctrl+O"  "ocr texto tesseract copiar imagen"
}

list_estilo() {
    printf '\0prompt\x1fEstilo\n'
    printf '\0markup-rows\x1ftrue\n'

    local theme_label="ninguno"
    if [ -x "$SCRIPTS/theme-switch.sh" ]; then
        theme_label="$("$SCRIPTS/theme-switch.sh" current 2>/dev/null || echo "ninguno")"
    fi

    local nl_title="Activar luz nocturna (4000K)"
    local nl_state="${XDG_RUNTIME_DIR:-/tmp}/hypr-nightlight.state"
    if [ -f "$nl_state" ] && grep -qx 'on' "$nl_state" 2>/dev/null; then
        nl_title="Desactivar luz nocturna (4000K)"
    fi

    emit_row "theme-menu"    "󰔎" "Elegir tema (actual: $theme_label)"       "Super+Shift+T" "tema theme cyber-teal cyber-teal-light mr-robot apariencia estilo"
    emit_row "theme-toggle"  "󰸉" "Alternar tema rápido"                     ""              "tema toggle alternar cambiar estilo"
    emit_row "lock-menu"     "󰌾" "Estilo de pantalla de bloqueo"            ""              "lockscreen bloqueo hyprlock candado soc matrix estilo"
    emit_row "wall-next"     "󰸨" "Siguiente wallpaper"                      "Super+W"       "wallpaper fondo pantalla imagen siguiente"
    emit_row "nightlight"    "󰖔" "$nl_title"                                "Super+Ctrl+N"  "luz nocturna nightlight filtro azul hyprsunset 4000k"
    emit_row "swaync-toggle" "󰂚" "Centro de notificaciones (SwayNC)"        "Super+N"       "notificaciones swaync panel alertas"
}

list_sistema() {
    printf '\0prompt\x1fSistema\n'
    printf '\0markup-rows\x1ftrue\n'
    emit_row "network"       "󰤨" "Red y VPN (NetworkManager)"               ""              "red wifi network vpn nmcli internet"
    emit_row "audio"         "󰕾" "Audio (pavucontrol)"                      ""              "audio volumen sonido microfono pavucontrol pipewire"
    emit_row "bluetooth"     "󰂯" "Bluetooth (blueman)"                      ""              "bluetooth auriculares dispositivos blueman"
    emit_row "clipboard"     "󰅌" "Historial del portapapeles"               "Super+V"       "portapapeles clipboard historial pegar cliphist"
    emit_row "file-search"   "󰈞" "Buscar archivos"                          "Super+Ctrl+F"  "buscar archivos ficheros fd search"
    emit_row "webapps"       "󰖟" "Web Apps / PWAs (instalar, abrir, quitar)" ""             "webapp pwa chrome instalar abrir quitar web"
    emit_row "monitor-scale" "󰍺" "Escala y PPI de monitores"                ""              "monitor escala ppi dpi pantalla resolucion"
    emit_row "keybinds"      "󰌌" "Cheatsheet de atajos"                     "Super+F1"      "atajos keybinds teclas ayuda shortcuts"
    emit_row "hypr-reload"   "󰑐" "Recargar configuración Hyprland"          "Super+Esc"     "recargar reload hyprland configuracion"
    emit_row "powermenu"     "󰐥" "Energía y sesión"                         "Super+X"       "energia sesion apagar reiniciar suspender hibernar bloquear power logout hibernate"
}

run_action() {
    case "$1" in
        # Dev & IA
        ai-menu)       detach "$SCRIPTS/ai.sh" menu ;;
        ai-open)       detach "$SCRIPTS/ai.sh" open ;;
        editor)        detach "$SCRIPTS/editor.sh" ;;
        ai-start)      detach "$SCRIPTS/ai.sh" service start ;;
        ai-stop)       detach "$SCRIPTS/ai.sh" service stop ;;
        ai-status)     detach "$SCRIPTS/ai.sh" service status ;;
        vm-menu)       detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'VMs:' "$SCRIPTS/vm-menu.sh" ;;
        scratchpad)    detach "$SCRIPTS/scratchpad.sh" ;;
        devctl-doctor) detach_term_hold "devctl doctor" "devctl doctor" ;;
        devctl-update) detach_term_hold "devctl update" "devctl update" ;;
        devctl-clean)  detach_term_hold "devctl clean"  "devctl clean" ;;
        btop)          detach foot --app-id=tui-float -e btop ;;
        lazydocker)    detach "$SCRIPTS/tui-float.sh" lazydocker ;;
        yazi)          detach "$SCRIPTS/tui-float.sh" yazi ;;

        # Capturar
        shot-region)   detach_delayed 0.22 "$SCRIPTS/screenshot-region.sh" ;;
        shot-raw)      detach_delayed 0.22 "$SCRIPTS/screenshot-region.sh" --raw ;;
        shot-full)     detach_delayed 0.26 "$SCRIPTS/screenshot-full.sh" ;;
        rec-toggle)    detach_delayed 0.18 "$SCRIPTS/screen-record.sh" ;;
        rec-region)    detach_delayed 0.22 "$SCRIPTS/screen-record.sh" --region ;;
        color-picker)  detach_delayed 0.22 "$SCRIPTS/color-picker.sh" ;;
        ocr-region)    detach_delayed 0.22 "$SCRIPTS/ocr-region.sh" ;;

        # Estilo
        theme-menu)    detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Temas' "$SCRIPTS/theme-switch.sh" menu ;;
        theme-toggle)  detach "$SCRIPTS/theme-switch.sh" toggle ;;
        lock-menu)     detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Lockscreen' "$SCRIPTS/lockscreen-switch.sh" menu ;;
        wall-next)     detach "$SCRIPTS/wallpaper.sh" --next ;;
        nightlight)    detach "$SCRIPTS/nightlight-toggle.sh" ;;
        swaync-toggle) detach_delayed 0.04 swaync-client -t -sw ;;

        # Sistema
        network)       detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Red:' "$SCRIPTS/network-menu.sh" ;;
        audio)         detach pavucontrol ;;
        bluetooth)     detach blueman-manager ;;
        clipboard)     detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Portapapeles' "$SCRIPTS/clipboard.sh" ;;
        file-search)   detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Archivo:' "$SCRIPTS/file-search.sh" ;;
        webapps)       detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Web Apps' "$SCRIPTS/webapp-install.sh" menu ;;
        monitor-scale) detach_term_hold "Escala de monitores" "\"$SCRIPTS/monitor-scale.sh\" --lua" ;;
        keybinds)      detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Atajos' "$SCRIPTS/keybinds.sh" ;;
        hypr-reload)
            detach bash -c "if hyprctl reload >/dev/null 2>&1; then notify-send -a Hyprland 'Hyprland' 'Configuración recargada'; else notify-send -u critical -a Hyprland 'Hyprland' 'Error al recargar configuración'; fi"
            ;;
        powermenu)     detach_delayed 0.09 "$SCRIPTS/toggle-menu.sh" 'Sistema:' "$SCRIPTS/powermenu.sh" ;;
    esac
}

if [ "$RETV" = "1" ] && [ -n "$INFO" ]; then
    run_action "$INFO"
    exit 0
fi

case "$CATEGORY" in
    dev)      list_dev ;;
    capturar) list_capturar ;;
    estilo)   list_estilo ;;
    sistema)  list_sistema ;;
    *)
        printf '\0message\x1fCategoría desconocida: %s\n' "$CATEGORY"
        ;;
esac
