#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/ai.sh - IA integrada en Hyprland mediante OpenCode CLI.
#
# Acciones rápidas sobre el portapapeles y el repo, sin daemons ni modelos
# locales. El proveedor y el modelo se configuran en OpenCode (`/connect` y
# `/models`); se puede forzar uno por invocación con AI_MODEL=provider/model.
#
# Uso:
#   ai.sh menu        # menú de acciones (Super+Shift+A)
#   ai.sh explain     # explicar el portapapeles (Super+Ctrl+I)
#   ai.sh ask|error|summarize|translate|diff|commit|open
#   ai.sh service start|stop|status   # servicio de fondo de OpenCode
#   ai.sh __run <mode> <title> <prompt-file>    # interno
#
# Las llamadas usan `--standalone`: cada acción levanta un servidor privado que
# muere con el proceso, así el servicio de fondo (~250 MB) queda apagado salvo
# que se encienda a propósito con `ai.sh service start`.
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH"

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a "IA" "$@" 2>/dev/null || true
}

die() { notify "IA" "$1"; echo "$1" >&2; exit 1; }

require_foot() {
    command -v foot >/dev/null 2>&1 || die "No se encontró foot para mostrar el resultado."
}

require_opencode() {
    command -v opencode >/dev/null 2>&1 ||
        die "OpenCode no está instalado (ejecutá 'make devai')."
}

clipboard_text() {
    if command -v wl-paste >/dev/null 2>&1; then
        wl-paste --no-newline 2>/dev/null || true
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o 2>/dev/null || true
    fi
}

# Ejecuta OpenCode en una terminal flotante y mantiene el resultado en pantalla.
run_in_terminal() {
    local mode="$1" title="$2" prompt="$3" attach="${4:-}"
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/ai-prompt.XXXXXX")"
    printf '%s' "$prompt" >"$prompt_file"

    setsid foot --title "$title" -e "$SCRIPT_PATH" __run "$mode" "$title" "$prompt_file" "$attach" \
        >/dev/null 2>&1 </dev/null &
}

__run() {
    local mode="$1" title="$2" prompt_file="$3" attach="${4:-}"
    local prompt output rc=0
    prompt="$(cat "$prompt_file")"
    rm -f "$prompt_file"
    output="$(mktemp "${TMPDIR:-/tmp}/ai-out.XXXXXX")"

    command -v opencode >/dev/null 2>&1 || {
        printf 'OpenCode no está instalado (ejecutá "make devai").\n'
        read -r -n1 -s _
        exit 1
    }

    local -a args=(run --archived --standalone)
    [ -n "${AI_MODEL:-}" ] && args+=(--model "$AI_MODEL")
    if [ -n "$attach" ] && [ -f "$attach" ]; then
        args+=(--file "$attach")
    fi

    printf '\033[1;36m%s\033[0m\n\n' "$title"
    opencode "${args[@]}" "$prompt" 2>&1 | tee "$output" || rc=$?

    if [ "$rc" -ne 0 ]; then
        printf '\n\033[1;31m[OpenCode terminó con estado %s]\033[0m\n' "$rc"
        printf 'Verificá la conexión del proveedor con "/connect" dentro de OpenCode.\n'
    else
        case "$mode" in
            commit|translate)
                if command -v wl-copy >/dev/null 2>&1; then
                    wl-copy <"$output" 2>/dev/null && printf '\n\033[2m(copiado al portapapeles)\033[0m\n' || true
                fi
                ;;
        esac
    fi

    if [ -n "$attach" ]; then
        rm -f "$attach"
    fi

    printf '\n[Enter para cerrar]'
    read -r _ || true
}

action_ask() {
    require_foot
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/ai-prompt.XXXXXX")"

    setsid foot --title "IA · Preguntar" -e bash -c '
        printf "Pregunta para la IA (Enter para enviar, vacío para cancelar):\n> "
        IFS= read -r question || exit 0
        [ -n "$question" ] || exit 0
        printf "%s" "$question" > "$1"
        exec "$2" __run ask "IA · Preguntar" "$1"
    ' _ "$prompt_file" "$SCRIPT_PATH" >/dev/null 2>&1 </dev/null &
}

action_explain() {
    local text
    text="$(clipboard_text)"
    [ -n "$text" ] || die "El portapapeles está vacío."
    run_in_terminal explain "IA · Explicar portapapeles" \
        "Explicá de forma clara y breve el siguiente texto. Respondé en español y sé concreto:

$text"
}

action_error() {
    local text
    text="$(clipboard_text)"
    [ -n "$text" ] || die "El portapapeles está vacío."
    run_in_terminal error "IA · Explicar error" \
        "Explicá el siguiente error o salida de consola: causa probable, impacto y pasos concretos para solucionarlo. Respondé en español y evitá relleno:

$text"
}

action_summarize() {
    local text
    text="$(clipboard_text)"
    [ -n "$text" ] || die "El portapapeles está vacío."
    run_in_terminal summarize "IA · Resumir portapapeles" \
        "Resumí el siguiente texto en 5 viñetas como máximo, conservando datos, cifras y nombres propios. Respondé en español:

$text"
}

action_translate() {
    local text
    text="$(clipboard_text)"
    [ -n "$text" ] || die "El portapapeles está vacío."
    run_in_terminal translate "IA · Traducir portapapeles" \
        "Traducí el siguiente texto al inglés si está en español, o al español si está en inglés. Mantené formato, nombres técnicos y código. Devolvé solo la traducción:

$text"
}

action_window() {
    require_foot
    command -v grim >/dev/null 2>&1 || die "grim no está instalado (make hyprland)."
    command -v hyprctl >/dev/null 2>&1 || die "hyprctl no está disponible."
    command -v jq >/dev/null 2>&1 || die "jq no está instalado."

    local geometry
    geometry="$(hyprctl activewindow -j 2>/dev/null |
        jq -r 'select(.address != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || true)"
    [ -n "$geometry" ] || die "No hay una ventana activa para capturar."

    local image
    image="$(mktemp "${TMPDIR:-/tmp}/ai-window.XXXXXX.png")"
    if ! grim -g "$geometry" "$image" 2>/dev/null || [ ! -s "$image" ]; then
        rm -f "$image"
        die "No se pudo capturar la ventana activa."
    fi

    run_in_terminal window "IA · Ventana activa" \
        "Describí qué se ve en esta captura, explicá el contenido relevante y señalá errores o detalles importantes. Respondé en español y sé concreto." "$image"
}

action_image() {
    require_foot
    command -v wl-paste >/dev/null 2>&1 || die "wl-paste no está disponible."

    local mime ext image
    mime="$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/' || true)"
    [ -n "$mime" ] || die "No hay una imagen en el portapapeles."

    case "$mime" in
        image/png) ext="png" ;;
        image/jpeg) ext="jpg" ;;
        image/webp) ext="webp" ;;
        *) ext="img" ;;
    esac

    image="$(mktemp "${TMPDIR:-/tmp}/ai-clip.XXXXXX.$ext")"
    if ! wl-paste --type "$mime" >"$image" 2>/dev/null || [ ! -s "$image" ]; then
        rm -f "$image"
        die "No se pudo leer la imagen del portapapeles."
    fi

    run_in_terminal image "IA · Imagen del portapapeles" \
        "Describí la imagen adjunta, extraé el texto o los datos relevantes y señalá cualquier detalle importante. Respondé en español." "$image"
}

action_diff() {
    local diff
    diff="$(git -C "$DOTFILES" diff 2>/dev/null || true)"
    [ -n "$diff" ] || die "El repo de dotfiles no tiene cambios sin commitear."
    run_in_terminal diff "IA · Revisar cambios (dotfiles)" \
        "Revisá este diff del repo de dotfiles. Señalá errores, riesgos, efectos secundarios e inconsistencias con el estilo del repo. Priorizá lo accionable y respondé en español:

$diff"
}

action_commit() {
    local diff
    diff="$(git -C "$DOTFILES" diff --staged 2>/dev/null || true)"
    [ -n "$diff" ] || diff="$(git -C "$DOTFILES" diff 2>/dev/null || true)"
    [ -n "$diff" ] || die "No hay cambios para describir en el repo de dotfiles."
    run_in_terminal commit "IA · Mensaje de commit" \
        "Generá SOLO un mensaje de commit en español con formato Conventional Commits, en una sola línea de 72 caracteres como máximo. No agregues explicaciones, comillas ni bloques de código. Si el cambio mezcla cosas, elegí el tipo principal:

$diff"
}

action_open() {
    require_foot
    local start_dir="$HOME/Proyectos"
    [ -d "$start_dir" ] || start_dir="$HOME"
    setsid foot --title "OpenCode" -e opencode --standalone "$start_dir" >/dev/null 2>&1 </dev/null &
}

# Servicio de fondo de OpenCode: `start` lo enciende, `stop` lo apaga y
# `status` imprime la URL activa o "detenido". Sin él, cada acción IA usa su
# propio servidor efímero.
service_url() {
    command -v opencode >/dev/null 2>&1 || return 1
    local status
    status="$(opencode service status 2>/dev/null | head -n1)"
    [ -n "$status" ] && [ "$status" != "stopped" ] || return 1
    printf '%s\n' "$status"
}

action_service() {
    local action="${1:-status}"
    require_opencode

    case "$action" in
        start)
            if [ -n "$(service_url || true)" ]; then
                notify "IA" "El servicio de OpenCode ya está activo."
                return 0
            fi
            opencode service start >/dev/null 2>&1 ||
                die "No se pudo iniciar el servicio de OpenCode."
            notify "IA" "Servicio de OpenCode iniciado."
            ;;
        stop)
            opencode service stop >/dev/null 2>&1 || true
            notify "IA" "Servicio de OpenCode detenido."
            ;;
        status)
            local url
            url="$(service_url || true)"
            if [ -n "$url" ]; then
                printf 'Servicio de OpenCode: activo en %s\n' "$url"
            else
                printf 'Servicio de OpenCode: detenido\n'
            fi
            ;;
        *)
            echo "Uso: $(basename "$0") service {start|stop|status}" >&2
            return 2
            ;;
    esac
}

# Estado del servicio en una terminal flotante (para el menú).
show_service_status() {
    require_foot
    local msg url
    url="$(service_url || true)"
    if [ -n "$url" ]; then
        msg="Servicio de OpenCode: activo en $url"
    else
        msg="Servicio de OpenCode: detenido"
    fi
    setsid foot --title "IA · Servicio OpenCode" -e \
        bash -c 'printf "%s\n\n[Enter para cerrar]" "$1"; read -r _' _ "$msg" \
        >/dev/null 2>&1 </dev/null &
}

menu() {
    command -v fuzzel >/dev/null 2>&1 || die "No se encontró fuzzel."
    local -a opts=(
        "󰚩  Preguntar a la IA"
        "󰆍  Abrir OpenCode"
        "󰐊  Encender servicio OpenCode"
        "󰐥  Apagar servicio OpenCode"
        "󰒓  Estado del servicio OpenCode"
        "󰆧  Explicar el portapapeles"
        "󰆧  Explicar un error del portapapeles"
        "󰈈  Explicar la ventana activa"
        "󰋩  Explicar imagen del portapapeles"
        "󰊄  Resumir el portapapeles"
        "󰗊  Traducir el portapapeles"
        "󰊢  Revisar cambios del repo de dotfiles"
        "󰊢  Generar mensaje de commit (dotfiles)"
        "󰁍  Volver"
    )

    local choice
    choice="$(printf '%s\n' "${opts[@]}" | fuzzel --dmenu --prompt "Menú · IA: " --width 46 -)" || exit 0
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "󰚩 "*) action_ask ;;
        "󰆍 "*) action_open ;;
        "󰐊 "*) action_service start ;;
        "󰐥 "*) action_service stop ;;
        "󰒓 "*) show_service_status ;;
        "󰆧  Explicar el"*) action_explain ;;
        "󰆧  Explicar un"*) action_error ;;
        "󰈈 "*) action_window ;;
        "󰋩 "*) action_image ;;
        "󰊄 "*) action_summarize ;;
        "󰗊 "*) action_translate ;;
        "󰊢  Revisar"*) action_diff ;;
        "󰊢  Generar"*) action_commit ;;
        "󰁍 "*) exit 0 ;;
    esac
}

case "${1:-menu}" in
    menu) menu ;;
    ask) action_ask ;;
    explain) action_explain ;;
    error) action_error ;;
    summarize) action_summarize ;;
    translate) action_translate ;;
    window) action_window ;;
    image) action_image ;;
    diff) action_diff ;;
    commit) action_commit ;;
    open) action_open ;;
    service) shift; action_service "${1:-status}" ;;
    __run) shift; __run "$@" ;;
    *)
        echo "Uso: $(basename "$0") {menu|ask|explain|error|summarize|translate|window|image|diff|commit|open|service}" >&2
        exit 2
        ;;
esac
