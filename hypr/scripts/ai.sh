#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/ai.sh - IA integrada en Hyprland mediante OpenCode CLI.
#
# Acciones rápidas sobre selección, portapapeles, pipes y repo Git activo, sin
# daemons automáticos ni modelos locales. El proveedor se conecta con `/connect`
# y el modelo por tarea se puede forzar con AI_MODEL=provider/model (o por
# categoría con AI_MODEL_TEXT / AI_MODEL_VISION / AI_MODEL_CODE).
#
# Uso:
#   ai.sh menu        # menú de acciones (Super+Shift+A)
#   ai.sh open        # abrir TUI de OpenCode en el repo activo (Super+Shift+I)
#   ai.sh explain     # explicar selección primaria o portapapeles (Super+Ctrl+I)
#   ai.sh ask [texto] # preguntar (interactivo o por CLI/stdin)
#   ai.sh error|summarize|translate|window|image|diff|commit
#   ai.sh service start|stop|toggle|status   # servicio de fondo opcional de OpenCode
#   ai.sh __run <mode> <title> <prompt-file> [attach]   # interno
#
# Por defecto usa `--standalone` (servidor efímero que muere con el proceso).
# Solo reutiliza el servicio de fondo (omitiendo `--standalone`) si ya está
# activo; nunca lo inicia automáticamente.
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH"

_CLEANUP_FILES=()
register_cleanup() {
    local f
    for f in "$@"; do
        if [ -n "$f" ]; then
            _CLEANUP_FILES+=("$f")
        fi
    done
}

cleanup_tmp() {
    if [ "${#_CLEANUP_FILES[@]}" -gt 0 ]; then
        rm -f "${_CLEANUP_FILES[@]}" 2>/dev/null || true
    fi
}
trap cleanup_tmp EXIT HUP INT TERM

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a "IA" "$@" 2>/dev/null || true
}

die() { notify "IA" "$1"; echo "$1" >&2; exit 1; }

require_foot() {
    if ! command -v footclient >/dev/null 2>&1 && ! command -v foot >/dev/null 2>&1; then
        die "No se encontró footclient ni foot para mostrar el resultado."
    fi
}

require_opencode() {
    command -v opencode >/dev/null 2>&1 ||
        die "OpenCode no está instalado (ejecutá 'make devai')."
}

read_stdin() {
    if [ ! -t 0 ] && { [ -p /dev/stdin ] || [ -f /dev/stdin ]; }; then
        cat
    fi
}

clipboard_text() {
    if command -v wl-paste >/dev/null 2>&1; then
        wl-paste --no-newline 2>/dev/null || true
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o 2>/dev/null || true
    fi
}

primary_or_clipboard_text() {
    local text=""
    if command -v wl-paste >/dev/null 2>&1; then
        text="$(wl-paste --primary --no-newline 2>/dev/null || true)"
    elif command -v xclip >/dev/null 2>&1; then
        text="$(xclip -selection primary -o 2>/dev/null || true)"
    fi
    if [ -n "${text//[[:space:]]/}" ]; then
        printf '%s' "$text"
        return 0
    fi
    clipboard_text
}

# Detecta el repo Git actual (CLI) o el de la ventana enfocada en Hyprland.
active_git_repo() {
    local top=""
    top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$top" ]; then
        printf '%s\n' "$top"
        return 0
    fi

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local pid cpid candidate
        pid="$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            for cpid in $(pgrep -P "$pid" 2>/dev/null || true) "$pid"; do
                candidate="$(readlink -f "/proc/$cpid/cwd" 2>/dev/null || true)"
                [ -d "$candidate" ] || continue
                top="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null || true)"
                if [ -n "$top" ]; then
                    printf '%s\n' "$top"
                    return 0
                fi
            done
        fi
    fi

    return 1
}

# Servicio de fondo de OpenCode: `start` lo enciende, `stop` lo apaga,
# `toggle` alterna y `status` imprime la URL activa o "detenido".
service_url() {
    command -v opencode >/dev/null 2>&1 || return 1
    local status
    status="$(opencode service status 2>/dev/null | head -n1 | tr -d '\r' || true)"
    [[ "$status" =~ ^https?:// ]] || return 1
    printf '%s\n' "$status"
}

signal_waybar_ai() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

model_for_mode() {
    local mode="$1"
    if [ -n "${AI_MODEL:-}" ]; then
        printf '%s\n' "$AI_MODEL"
        return 0
    fi
    case "$mode" in
        window|image)
            printf '%s\n' "${AI_MODEL_VISION:-opencode/nemotron-3.5-super-vl-free}"
            ;;
        diff|commit|error)
            printf '%s\n' "${AI_MODEL_CODE:-opencode/deepseek-v4.1-flash-free}"
            ;;
        ask|explain|summarize|translate|*)
            printf '%s\n' "${AI_MODEL_TEXT:-opencode/beam-free}"
            ;;
    esac
}

OPENCODE_ARGS=()
OPENCODE_MODEL=""
OPENCODE_TRANSPORT=""

prepare_opencode_run_args() {
    local mode="$1" attach="${2:-}"
    OPENCODE_ARGS=(run --archived)
    OPENCODE_MODEL="$(model_for_mode "$mode")"

    if service_url >/dev/null 2>&1; then
        # En OpenCode v2.3.0, omitir --standalone conecta al servicio activo
        # usando sus credenciales gestionadas (evita pedir OPENCODE_PASSWORD).
        OPENCODE_TRANSPORT="servicio cálido"
    else
        OPENCODE_ARGS+=(--standalone)
        OPENCODE_TRANSPORT="standalone"
    fi

    OPENCODE_ARGS+=(--model "$OPENCODE_MODEL")
    if [ -n "$attach" ] && [ -f "$attach" ]; then
        OPENCODE_ARGS+=(--file "$attach")
    fi
}

monitor_window_size() {
    local pct_w="$1" pct_h="${2:-$1}"
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local mw mh
        read -r mw mh <<<"$(hyprctl monitors -j 2>/dev/null |
            jq -r '.[] | select(.focused) | "\(.width) \(.height)"' 2>/dev/null | head -n1 || true)"
        if [[ "${mw:-}" =~ ^[0-9]+$ ]] && [[ "${mh:-}" =~ ^[0-9]+$ ]]; then
            printf '%sx%s\n' "$((mw * pct_w / 100))" "$((mh * pct_h / 100))"
            return 0
        fi
    fi
    return 1
}

launch_ai_terminal() {
    local title="$1" pct_w="$2" pct_h="$3"
    shift 3

    if ! command -v footclient >/dev/null 2>&1 && ! command -v foot >/dev/null 2>&1; then
        notify "IA" "No se encontró footclient ni foot para mostrar el resultado."
        echo "No se encontró footclient ni foot para mostrar el resultado." >&2
        return 1
    fi

    local size
    size="$(monitor_window_size "$pct_w" "$pct_h" || true)"
    local -a common_args=(--app-id=ai-float --title="$title")
    if [ -n "$size" ]; then
        common_args+=(--window-size-pixels="$size")
    fi

    local foot_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/foot-${WAYLAND_DISPLAY:-wayland-1}.sock"
    if command -v footclient >/dev/null 2>&1 && [ -S "$foot_sock" ]; then
        if footclient -N -E "${common_args[@]}" -- "$@" >/dev/null 2>&1 </dev/null; then
            return 0
        fi
    fi

    if command -v foot >/dev/null 2>&1; then
        setsid foot "${common_args[@]}" -- "$@" >/dev/null 2>&1 </dev/null &
        return 0
    fi

    notify "IA" "No se pudo abrir la terminal flotante para '$title'."
    echo "No se pudo abrir la terminal flotante para '$title'." >&2
    return 1
}

render_markdown() {
    local file="$1"
    if command -v batcat >/dev/null 2>&1; then
        batcat --language=md --style=plain --paging=never --color=always "$file"
    elif command -v bat >/dev/null 2>&1; then
        bat --language=md --style=plain --paging=never --color=always "$file"
    else
        cat "$file"
    fi
}

run_inline() {
    local mode="$1" prompt="$2"
    require_opencode

    local output err_output rc=0
    output="$(mktemp "${TMPDIR:-/tmp}/ai-out.XXXXXX")"
    err_output="$(mktemp "${TMPDIR:-/tmp}/ai-err.XXXXXX")"
    register_cleanup "$output" "$err_output"

    prepare_opencode_run_args "$mode"
    opencode "${OPENCODE_ARGS[@]}" "$prompt" >"$output" 2>"$err_output" || rc=$?

    if [ "$rc" -ne 0 ]; then
        [ -s "$output" ] && cat "$output" >&2
        [ -s "$err_output" ] && cat "$err_output" >&2
        return "$rc"
    fi

    if [ -t 1 ]; then
        render_markdown "$output"
        case "$mode" in
            commit|translate)
                if [ -s "$output" ] && command -v wl-copy >/dev/null 2>&1; then
                    wl-copy <"$output" 2>/dev/null && printf '\n\033[2m(copiado al portapapeles)\033[0m\n' >&2 || true
                fi
                ;;
        esac
    else
        cat "$output"
        if [ -s "$output" ] && [ "$(tail -c1 "$output" | wc -l)" -eq 0 ]; then
            printf '\n'
        fi
    fi
}

# Ejecuta OpenCode en una terminal flotante (`ai-float`) y mantiene el resultado en pantalla.
run_in_terminal() {
    local mode="$1" title="$2" prompt="$3" attach="${4:-}"
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/ai-prompt.XXXXXX")"
    printf '%s' "$prompt" >"$prompt_file"

    if ! launch_ai_terminal "$title" 72 72 "$SCRIPT_PATH" __run "$mode" "$title" "$prompt_file" "$attach"; then
        rm -f "$prompt_file"
        [ -n "$attach" ] && rm -f "$attach"
        exit 1
    fi
}

__run() {
    local mode="$1" title="$2" prompt_file="$3" attach="${4:-}"
    register_cleanup "$prompt_file" "$attach"

    local prompt output err_output rc=0
    prompt="$(cat "$prompt_file")"
    rm -f "$prompt_file"
    output="$(mktemp "${TMPDIR:-/tmp}/ai-out.XXXXXX")"
    err_output="$(mktemp "${TMPDIR:-/tmp}/ai-err.XXXXXX")"
    register_cleanup "$output" "$err_output"

    command -v opencode >/dev/null 2>&1 || {
        printf 'OpenCode no está instalado (ejecutá "make devai").\n'
        printf '\n[Enter para cerrar]'
        read -r _ || true
        exit 1
    }

    prepare_opencode_run_args "$mode" "$attach"

    local first_flag timer_pid=""
    first_flag="$(mktemp "${TMPDIR:-/tmp}/ai-first.XXXXXX")"
    register_cleanup "$first_flag"
    rm -f "$first_flag"

    printf '\033[1;36m%s\033[0m\n' "$title"
    if [ -t 1 ]; then
        (
            local secs=0
            while [ ! -e "$first_flag" ]; do
                printf '\r\033[K\033[2mConsultando %s (%s)... %ds\033[0m' \
                    "$OPENCODE_MODEL" "$OPENCODE_TRANSPORT" "$secs"
                sleep 1
                secs=$((secs + 1))
            done
        ) &
        timer_pid=$!
    else
        printf '\033[2mConsultando %s (%s)...\033[0m\n' "$OPENCODE_MODEL" "$OPENCODE_TRANSPORT"
    fi

    # Streaming en vivo: muestra cada línea en cuanto OpenCode la emite y la
    # guarda en $output para copiar con [c] o auto-copiar en commit/translate.
    opencode "${OPENCODE_ARGS[@]}" "$prompt" 2>"$err_output" | {
        local started=0 line=""
        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$started" -eq 0 ]; then
                started=1
                : >"$first_flag"
                if [ -n "$timer_pid" ]; then
                    kill "$timer_pid" 2>/dev/null || true
                fi
                if [ -t 1 ]; then
                    printf '\r\033[K\n'
                else
                    printf '\n'
                fi
            fi
            printf '%s\n' "$line" >>"$output"
            printf '%s\n' "$line"
        done
    } || rc="${PIPESTATUS[0]}"

    if [ -n "$timer_pid" ]; then
        : >"$first_flag"
        kill "$timer_pid" 2>/dev/null || true
        wait "$timer_pid" 2>/dev/null || true
    fi
    if [ ! -s "$output" ] && [ -t 1 ]; then
        printf '\r\033[K\n'
    fi

    if [ "$rc" -ne 0 ]; then
        [ -s "$err_output" ] && cat "$err_output" >&2
        printf '\n\033[1;31m[OpenCode terminó con estado %s]\033[0m\n' "$rc"
        printf 'Verificá la conexión del proveedor con "/connect" dentro de OpenCode.\n'
    else
        case "$mode" in
            commit|translate)
                if [ -s "$output" ] && command -v wl-copy >/dev/null 2>&1; then
                    wl-copy <"$output" 2>/dev/null && printf '\n\033[2m(copiado al portapapeles)\033[0m\n' || true
                fi
                ;;
        esac
    fi

    if [ "$rc" -eq 0 ] && [ -s "$output" ] && command -v wl-copy >/dev/null 2>&1; then
        printf '\n\033[2m[c] copiar · [Enter] cerrar\033[0m '
        local key=""
        while IFS= read -r -n1 -s key; do
            case "$key" in
                c|C)
                    if wl-copy <"$output" 2>/dev/null; then
                        printf '\r\033[K\033[32m✔ Copiado al portapapeles\033[0m  \033[2m[Enter] cerrar\033[0m '
                    fi
                    ;;
                ""|$'\n'|$'\r'|$'\x1b'|q|Q)
                    printf '\n'
                    break
                    ;;
            esac
        done
    else
        printf '\n[Enter para cerrar]'
        read -r _ || true
    fi
}

action_ask() {
    local stdin_text="" query="" prompt=""
    stdin_text="$(read_stdin)"
    [ "$#" -gt 0 ] && query="$*"

    if [ -n "${stdin_text//[[:space:]]/}" ] && [ -n "$query" ]; then
        prompt="$query

$stdin_text"
    elif [ -n "${stdin_text//[[:space:]]/}" ]; then
        prompt="$stdin_text"
    elif [ -n "$query" ]; then
        prompt="$query"
    fi

    if [ -n "$prompt" ]; then
        run_inline ask "$prompt"
        return 0
    fi

    require_foot
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/ai-prompt.XXXXXX")"

    if ! launch_ai_terminal "IA · Preguntar" 72 72 bash -c '
        trap '\''rm -f "$1"'\'' EXIT HUP INT TERM
        printf "Pregunta para la IA (Enter para enviar, vacío para cancelar):\n> "
        IFS= read -r question || exit 0
        [ -n "$question" ] || exit 0
        printf "%s" "$question" > "$1"
        exec "$2" __run ask "IA · Preguntar" "$1"
    ' _ "$prompt_file" "$SCRIPT_PATH"; then
        rm -f "$prompt_file"
        exit 1
    fi
}

run_text_action() {
    local mode="$1" title="$2" use_primary="$3" instruction="$4"
    local text inline=0

    text="$(read_stdin)"
    if [ -n "${text//[[:space:]]/}" ]; then
        inline=1
    elif [ "$use_primary" = "1" ]; then
        text="$(primary_or_clipboard_text)"
        [ -n "${text//[[:space:]]/}" ] || die "La selección y el portapapeles están vacíos."
    else
        text="$(clipboard_text)"
        [ -n "${text//[[:space:]]/}" ] || die "El portapapeles está vacío."
    fi

    local prompt="$instruction

$text"
    if [ "$inline" -eq 1 ]; then
        run_inline "$mode" "$prompt"
    else
        run_in_terminal "$mode" "$title" "$prompt"
    fi
}

action_explain() {
    run_text_action explain "IA · Explicar selección" 1 \
        "Explicá de forma clara y breve el siguiente texto. Respondé en español y sé concreto:"
}

action_error() {
    run_text_action error "IA · Explicar error" 0 \
        "Explicá el siguiente error o salida de consola: causa probable, impacto y pasos concretos para solucionarlo. Respondé en español y evitá relleno:"
}

action_summarize() {
    run_text_action summarize "IA · Resumir portapapeles" 0 \
        "Resumí el siguiente texto en 5 viñetas como máximo, conservando datos, cifras y nombres propios. Respondé en español:"
}

action_translate() {
    run_text_action translate "IA · Traducir portapapeles" 0 \
        "Traducí el siguiente texto al inglés si está en español, o al español si está en inglés. Mantené formato, nombres técnicos y código. Devolvé solo la traducción:"
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
    local stdin_diff=""
    stdin_diff="$(read_stdin)"
    if [ -n "${stdin_diff//[[:space:]]/}" ]; then
        run_inline diff "Revisá este diff. Señalá errores, riesgos, efectos secundarios e inconsistencias. Priorizá lo accionable y respondé en español:

$stdin_diff"
        return 0
    fi

    local repo repo_name diff
    repo="$(active_git_repo || printf '%s\n' "$DOTFILES")"
    repo_name="$(basename "$repo")"
    diff="$(git -C "$repo" diff 2>/dev/null || true)"
    [ -n "$diff" ] || diff="$(git -C "$repo" diff --staged 2>/dev/null || true)"
    [ -n "$diff" ] || die "El repo '$repo_name' no tiene cambios sin commitear."

    run_in_terminal diff "IA · Revisar cambios ($repo_name)" \
        "Revisá este diff del repo '$repo_name'. Señalá errores, riesgos, efectos secundarios e inconsistencias con el estilo del repo. Priorizá lo accionable y respondé en español:

$diff"
}

action_commit() {
    local stdin_diff=""
    stdin_diff="$(read_stdin)"
    if [ -n "${stdin_diff//[[:space:]]/}" ]; then
        run_inline commit "Generá SOLO un mensaje de commit en español con formato Conventional Commits, en una sola línea de 72 caracteres como máximo. No agregues explicaciones, comillas ni bloques de código. Si el cambio mezcla cosas, elegí el tipo principal:

$stdin_diff"
        return 0
    fi

    local repo repo_name diff
    repo="$(active_git_repo || printf '%s\n' "$DOTFILES")"
    repo_name="$(basename "$repo")"
    diff="$(git -C "$repo" diff --staged 2>/dev/null || true)"
    [ -n "$diff" ] || diff="$(git -C "$repo" diff 2>/dev/null || true)"
    [ -n "$diff" ] || die "No hay cambios para describir en el repo '$repo_name'."

    run_in_terminal commit "IA · Mensaje de commit ($repo_name)" \
        "Generá SOLO un mensaje de commit en español con formato Conventional Commits, en una sola línea de 72 caracteres como máximo. No agregues explicaciones, comillas ni bloques de código. Si el cambio mezcla cosas, elegí el tipo principal:

$diff"
}

action_open() {
    require_opencode
    local start_dir
    start_dir="$(active_git_repo || true)"
    if [ -z "$start_dir" ] || [ ! -d "$start_dir" ]; then
        start_dir="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
        [ -d "$start_dir" ] || start_dir="$HOME"
    fi

    if service_url >/dev/null 2>&1; then
        launch_ai_terminal "OpenCode" 85 85 opencode "$start_dir"
    else
        launch_ai_terminal "OpenCode" 85 85 opencode --standalone "$start_dir"
    fi
}

action_service() {
    local action="${1:-status}"
    require_opencode

    case "$action" in
        start)
            if [ -n "$(service_url || true)" ]; then
                notify "IA" "El servicio de OpenCode ya está activo."
                signal_waybar_ai
                return 0
            fi
            opencode service start >/dev/null 2>&1 ||
                die "No se pudo iniciar el servicio de OpenCode."
            signal_waybar_ai
            notify "IA" "Servicio de OpenCode iniciado."
            ;;
        stop)
            opencode service stop >/dev/null 2>&1 || true
            signal_waybar_ai
            notify "IA" "Servicio de OpenCode detenido."
            ;;
        toggle)
            if [ -n "$(service_url || true)" ]; then
                action_service stop
            else
                action_service start
            fi
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
            echo "Uso: $(basename "$0") service {start|stop|toggle|status}" >&2
            return 2
            ;;
    esac
}

# Estado del servicio en una terminal flotante (para el menú).
show_service_status() {
    local msg url
    url="$(service_url || true)"
    if [ -n "$url" ]; then
        msg="Servicio de OpenCode: activo en $url"
    else
        msg="Servicio de OpenCode: detenido"
    fi
    launch_ai_terminal "IA · Servicio OpenCode" 50 28 \
        bash -c 'printf "%s\n\n[Enter para cerrar]" "$1"; read -r _ || true' _ "$msg"
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
        "󰊢  Revisar cambios Git (repo activo)"
        "󰊢  Generar mensaje de commit (repo activo)"
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
    ask) shift; action_ask "$@" ;;
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
