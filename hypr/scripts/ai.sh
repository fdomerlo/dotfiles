#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/ai.sh - IA integrada en Hyprland (OpenCode CLI / Antigravity CLI).
#
# Acciones rápidas sobre selección, portapapeles, pipes y repo Git activo, sin
# daemons automáticos ni modelos locales. El motor activo se elige con
# AI_BACKEND=opencode|agy, `~/.config/quickshell/local.json` (.aiBackend) o
# `ai.sh backend`.
#
# Uso:
#   ai.sh menu        # menú de acciones (Super+Shift+A)
#   ai.sh open        # abrir TUI del motor activo en el repo (Super+Shift+I)
#   ai.sh explain     # explicar selección primaria o portapapeles (Super+Ctrl+I)
#   ai.sh ask [texto] # preguntar (interactivo o por CLI/stdin)
#   ai.sh error|summarize|translate|window|image|diff|commit
#   ai.sh backend [opencode|agy|toggle|status]  # motor activo
#   ai.sh model [status|flash|flash-low|flash-medium|flash-high|default|<id>]
#   ai.sh service start|stop|toggle|status      # servicio de fondo opcional de OpenCode
#   ai.sh __run <mode> <title> <prompt-file> [attach]   # interno
#
# En OpenCode usa `--standalone` por defecto y reutiliza el servicio de fondo
# solo si ya está activo. En Antigravity (`agy`) usa por defecto los modelos
# Flash (`gemini-3.8-flash-low` / `gemini-3.8-flash-medium`) y
# `--disable-slash-commands` (con fallback a OpenCode para imágenes).
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOCAL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/local.json"
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
        rm -rf "${_CLEANUP_FILES[@]}" 2>/dev/null || true
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

require_agy() {
    command -v agy >/dev/null 2>&1 ||
        die "Antigravity CLI (agy) no está instalado (ejecutá 'make devai')."
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

# Servicio de fondo de OpenCode: `service_running` detecta por proceso sin
# levantar el binario; `service_url` consulta la URL solo si está corriendo.
service_running() {
    pgrep -u "${USER:-$(id -un)}" -f '(^|/)opencode[[:space:]]+serve[[:space:]]+--service([[:space:]]|$)' >/dev/null 2>&1
}

service_url() {
    service_running || return 1
    command -v opencode >/dev/null 2>&1 || return 1
    local status
    status="$(opencode service status 2>/dev/null | head -n1 | tr -d '\r' || true)"
    [[ "$status" =~ ^https?:// ]] || return 1
    printf '%s\n' "$status"
}

signal_waybar_ai() {
    command -v qs >/dev/null 2>&1 && qs ipc call system refresh >/dev/null 2>&1 || true
}

normalize_backend() {
    local b="${1:-}"
    b="${b,,}"
    case "$b" in
        agy|antigravity) printf 'agy\n' ;;
        *) printf 'opencode\n' ;;
    esac
}

read_local_config_key() {
    local key="$1"
    [ -f "$LOCAL_CONFIG" ] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$key" '.[$k] // empty' "$LOCAL_CONFIG" 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); print(d.get(sys.argv[2],""))' "$LOCAL_CONFIG" "$key" 2>/dev/null || true
    fi
}

write_local_config_key() {
    local key="$1" val="$2"
    python3 - "$LOCAL_CONFIG" "$key" "$val" <<'PY'
import json, os, sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(p), exist_ok=True)
try:
    with open(p, encoding="utf-8") as f:
        d = json.load(f)
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
d[k] = v
tmp = p + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
os.replace(tmp, p)
PY
}

resolve_backend() {
    if [ -n "${AI_BACKEND:-}" ]; then
        normalize_backend "$AI_BACKEND"
        return 0
    fi
    normalize_backend "$(read_local_config_key aiBackend)"
}

AGY_MODEL_FLASH_LOW="gemini-3.8-flash-low"
AGY_MODEL_FLASH_MEDIUM="gemini-3.8-flash-medium"
AGY_MODEL_FLASH_HIGH="gemini-3.8-flash-high"

normalize_agy_model_pref() {
    local pref="${1:-}" lower
    lower="${pref,,}"
    case "$lower" in
        ""|auto|flash) printf 'flash\n' ;;
        flash-low|low) printf 'flash-low\n' ;;
        flash-medium|flash-med|medium|med) printf 'flash-medium\n' ;;
        flash-high|high) printf 'flash-high\n' ;;
        default|pro) printf 'default\n' ;;
        *) printf '%s\n' "$pref" ;;
    esac
}

resolve_agy_model_pref() {
    if [ -n "${AI_AGY_MODEL:-}" ]; then
        printf '%s\n' "$AI_AGY_MODEL"
        return 0
    fi
    if [ -n "${AI_MODEL:-}" ] && [[ "$AI_MODEL" != opencode/* ]]; then
        printf '%s\n' "$AI_MODEL"
        return 0
    fi
    local val
    val="$(read_local_config_key aiAgyModel)"
    printf '%s\n' "${val:-flash}"
}

agy_model_for_mode() {
    local mode="$1" pref
    pref="$(normalize_agy_model_pref "$(resolve_agy_model_pref)")"
    case "$pref" in
        default)
            printf '\n'
            ;;
        flash-low)
            printf '%s\n' "$AGY_MODEL_FLASH_LOW"
            ;;
        flash-medium)
            printf '%s\n' "$AGY_MODEL_FLASH_MEDIUM"
            ;;
        flash-high)
            printf '%s\n' "$AGY_MODEL_FLASH_HIGH"
            ;;
        flash)
            case "$mode" in
                error|diff) printf '%s\n' "$AGY_MODEL_FLASH_MEDIUM" ;;
                ask|explain|summarize|translate|commit|*) printf '%s\n' "$AGY_MODEL_FLASH_LOW" ;;
            esac
            ;;
        *)
            printf '%s\n' "$pref"
            ;;
    esac
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

    if service_running; then
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

BACKEND_USED=""
BACKEND_LABEL=""
BACKEND_WORK_DIR=""
BACKEND_CMD=()

prepare_backend_cmd() {
    local mode="$1" attach="${2:-}" requested effort model
    requested="$(resolve_backend)"
    BACKEND_CMD=()
    BACKEND_WORK_DIR=""

    if [ "$requested" = "agy" ]; then
        if [ -n "$attach" ] && [ -f "$attach" ]; then
            if command -v opencode >/dev/null 2>&1; then
                prepare_opencode_run_args "$mode" "$attach"
                BACKEND_USED="opencode"
                BACKEND_LABEL="opencode · $OPENCODE_MODEL (fallback visión)"
                BACKEND_CMD=(opencode "${OPENCODE_ARGS[@]}")
                return 0
            fi
            notify "IA" "El análisis de imágenes requiere OpenCode (ejecutá 'make devai')."
            echo "El análisis de imágenes requiere OpenCode (ejecutá 'make devai')." >&2
            return 1
        fi

        if ! command -v agy >/dev/null 2>&1; then
            notify "IA" "Antigravity CLI (agy) no está instalado (ejecutá 'make devai')."
            echo "Antigravity CLI (agy) no está instalado (ejecutá 'make devai')." >&2
            return 1
        fi

        model="$(agy_model_for_mode "$mode")"
        BACKEND_USED="agy"
        BACKEND_CMD=(agy --output-format text --disable-slash-commands)
        if [ -n "$model" ]; then
            BACKEND_CMD+=(--model "$model")
            if [ -n "${AI_AGY_EFFORT:-}" ]; then
                BACKEND_CMD+=(--effort "$AI_AGY_EFFORT")
            fi
            BACKEND_LABEL="agy · $model${AI_AGY_EFFORT:+, effort=$AI_AGY_EFFORT}"
        else
            effort="${AI_AGY_EFFORT:-low}"
            BACKEND_CMD+=(--effort "$effort")
            BACKEND_LABEL="agy · default (effort=$effort)"
        fi
        BACKEND_CMD+=(-p)
        BACKEND_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-agy-wd.XXXXXX")"
        register_cleanup "$BACKEND_WORK_DIR"
        return 0
    fi

    if ! command -v opencode >/dev/null 2>&1; then
        notify "IA" "OpenCode no está instalado (ejecutá 'make devai')."
        echo "OpenCode no está instalado (ejecutá 'make devai')." >&2
        return 1
    fi

    prepare_opencode_run_args "$mode" "$attach"
    BACKEND_USED="opencode"
    BACKEND_LABEL="$OPENCODE_MODEL ($OPENCODE_TRANSPORT)"
    BACKEND_CMD=(opencode "${OPENCODE_ARGS[@]}")
    return 0
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

run_backend_streaming() {
    local output_file="$1" err_file="$2" metrics_file="$3" work_dir="$4" stream_flag="$5"
    shift 5
    [ "${1:-}" = "--" ] && shift

    python3 - "$output_file" "$err_file" "$metrics_file" "$work_dir" "$stream_flag" "$@" <<'PY'
import os
import subprocess
import sys
import time

output_file, err_file, metrics_file, work_dir, stream_flag = sys.argv[1:6]
cmd = sys.argv[6:]
stream = stream_flag == "1"

t0 = time.monotonic()
ttft = None
first_chunk = False
ends_nl = True

with open(output_file, "wb") as out_f, open(err_file, "wb") as err_f:
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=err_f,
        cwd=work_dir or None,
    )
    fd = proc.stdout.fileno()
    is_tty = sys.stdout.isatty()
    while True:
        chunk = os.read(fd, 1024)
        if not chunk:
            break
        if not first_chunk:
            ttft = time.monotonic() - t0
            first_chunk = True
            if stream and is_tty:
                sys.stdout.buffer.write(b"\033[1A\033[K")
                sys.stdout.buffer.flush()
        out_f.write(chunk)
        out_f.flush()
        if stream:
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
        ends_nl = chunk.endswith(b"\n")
    proc.stdout.close()
    rc = proc.wait()

total = time.monotonic() - t0
if ttft is None:
    ttft = total

if stream:
    if first_chunk and not ends_nl:
        sys.stdout.buffer.write(b"\n")
        sys.stdout.buffer.flush()
    elif not first_chunk and is_tty:
        sys.stdout.buffer.write(b"\033[1A\033[K")
        sys.stdout.buffer.flush()

with open(metrics_file, "w", encoding="utf-8") as mf:
    mf.write(f"{ttft:.2f}|{total:.2f}|{1 if first_chunk else 0}\n")

sys.exit(rc)
PY
}

run_inline() {
    local mode="$1" prompt="$2"
    prepare_backend_cmd "$mode" "" || return 1

    local output err_output metrics_file rc=0 stream_flag=0
    local ttft="0.00" total="0.00" streamed="0"
    output="$(mktemp "${TMPDIR:-/tmp}/ai-out.XXXXXX")"
    err_output="$(mktemp "${TMPDIR:-/tmp}/ai-err.XXXXXX")"
    metrics_file="$(mktemp "${TMPDIR:-/tmp}/ai-metrics.XXXXXX")"
    register_cleanup "$output" "$err_output" "$metrics_file"

    [ -t 1 ] && stream_flag=1
    run_backend_streaming "$output" "$err_output" "$metrics_file" "$BACKEND_WORK_DIR" "$stream_flag" -- "${BACKEND_CMD[@]}" "$prompt" || rc=$?
    IFS='|' read -r ttft total streamed <"$metrics_file" || true

    if [ "$rc" -ne 0 ]; then
        if [ "${streamed:-0}" != "1" ] && [ -s "$output" ]; then
            cat "$output" >&2
        fi
        if [ -s "$err_output" ]; then
            cat "$err_output" >&2
        fi
        return "$rc"
    fi

    if [ "$stream_flag" -eq 1 ]; then
        case "$mode" in
            commit|translate)
                if [ -s "$output" ] && command -v wl-copy >/dev/null 2>&1; then
                    wl-copy <"$output" 2>/dev/null && printf '\n\033[2m(copiado al portapapeles)\033[0m\n' >&2 || true
                fi
                ;;
        esac
        printf '\n\033[2m⏱ %ss primer token · %ss total · %s\033[0m\n' "${ttft:-0.00}" "${total:-0.00}" "$BACKEND_LABEL" >&2
    else
        cat "$output"
        if [ -s "$output" ] && [ "$(tail -c1 "$output" | wc -l)" -eq 0 ]; then
            printf '\n'
        fi
    fi
}

# Ejecuta el motor activo en una terminal flotante (`ai-float`) y mantiene el resultado en pantalla.
run_in_terminal() {
    local mode="$1" title="$2" prompt="$3" attach="${4:-}"
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/ai-prompt.XXXXXX")"
    printf '%s' "$prompt" >"$prompt_file"

    if ! launch_ai_terminal "$title" 72 72 "$SCRIPT_PATH" __run "$mode" "$title" "$prompt_file" "$attach"; then
        rm -f "$prompt_file"
        if [ -n "$attach" ]; then
            rm -f "$attach"
        fi
        exit 1
    fi
}

__run() {
    local mode="$1" title="$2" prompt_file="$3" attach="${4:-}"
    register_cleanup "$prompt_file" "$attach"

    local prompt output err_output metrics_file rc=0
    local ttft="0.00" total="0.00" streamed="0"
    prompt="$(cat "$prompt_file")"
    rm -f "$prompt_file"
    output="$(mktemp "${TMPDIR:-/tmp}/ai-out.XXXXXX")"
    err_output="$(mktemp "${TMPDIR:-/tmp}/ai-err.XXXXXX")"
    metrics_file="$(mktemp "${TMPDIR:-/tmp}/ai-metrics.XXXXXX")"
    register_cleanup "$output" "$err_output" "$metrics_file"

    if ! prepare_backend_cmd "$mode" "$attach"; then
        printf '\n[Enter para cerrar]'
        read -r _ || true
        exit 1
    fi

    printf '\033[1;36m%s\033[0m\n' "$title"
    printf '\033[2mConsultando %s...\033[0m\n' "$BACKEND_LABEL"

    run_backend_streaming "$output" "$err_output" "$metrics_file" "$BACKEND_WORK_DIR" 1 -- "${BACKEND_CMD[@]}" "$prompt" || rc=$?
    IFS='|' read -r ttft total streamed <"$metrics_file" || true

    if [ "$rc" -ne 0 ]; then
        if [ "${streamed:-0}" != "1" ] && [ -s "$output" ]; then
            cat "$output"
        fi
        if [ -s "$err_output" ]; then
            cat "$err_output" >&2
        fi
        if [ "$BACKEND_USED" = "agy" ]; then
            printf '\n\033[1;31m[Antigravity CLI terminó con estado %s]\033[0m\n' "$rc"
            printf 'Verificá tu sesión ejecutando "agy" en una terminal.\n'
        else
            printf '\n\033[1;31m[OpenCode terminó con estado %s]\033[0m\n' "$rc"
            printf 'Verificá la conexión del proveedor con "/connect" dentro de OpenCode.\n'
        fi
    else
        case "$mode" in
            commit|translate)
                if [ -s "$output" ] && command -v wl-copy >/dev/null 2>&1; then
                    wl-copy <"$output" 2>/dev/null && printf '\n\033[2m(copiado al portapapeles)\033[0m\n' || true
                fi
                ;;
        esac
        printf '\n\033[2m⏱ %ss primer token · %ss total · %s\033[0m\n' "${ttft:-0.00}" "${total:-0.00}" "$BACKEND_LABEL"
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
        printf "Pregunta para la IA (Enter para enviar, vacío para cancelar):\n"
        IFS= read -r -e -p "> " question || exit 0
        [ -n "${question//[[:space:]]/}" ] || exit 0
        printf "%s" "$question" > "$1"
        "$2" __run ask "IA · Preguntar" "$1" || {
            rc=$?
            printf "\n\033[1;31m[Error al ejecutar la consulta (estado %s)]\033[0m\n[Enter para cerrar]" "$rc"
            read -r _ || true
            exit "$rc"
        }
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
    local start_dir backend
    start_dir="$(active_git_repo || true)"
    if [ -z "$start_dir" ] || [ ! -d "$start_dir" ]; then
        start_dir="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
        [ -d "$start_dir" ] || start_dir="$HOME"
    fi

    backend="$(resolve_backend)"
    if [ "$backend" = "agy" ]; then
        require_agy
        launch_ai_terminal "Antigravity" 85 85 bash -c 'cd "$1" && exec agy' _ "$start_dir"
        return 0
    fi

    require_opencode
    if service_running; then
        launch_ai_terminal "OpenCode" 85 85 opencode "$start_dir"
    else
        launch_ai_terminal "OpenCode" 85 85 opencode --standalone "$start_dir"
    fi
}

action_backend() {
    local action="${1:-status}" current next label
    current="$(resolve_backend)"
    case "$action" in
        status)
            if [ "$current" = "agy" ]; then
                printf 'Motor activo: agy (Antigravity CLI)\n'
            else
                printf 'Motor activo: opencode (OpenCode CLI)\n'
            fi
            return 0
            ;;
        toggle)
            if [ "$current" = "agy" ]; then
                next="opencode"
            else
                next="agy"
            fi
            ;;
        opencode|agy|antigravity)
            next="$(normalize_backend "$action")"
            ;;
        *)
            echo "Uso: $(basename "$0") backend {opencode|agy|toggle|status}" >&2
            return 2
            ;;
    esac

    write_local_config_key aiBackend "$next"
    signal_waybar_ai
    if [ "$next" = "agy" ]; then
        label="Antigravity (agy)"
    else
        label="OpenCode (opencode)"
    fi
    notify "IA" "Motor activo: $label"
    printf 'Motor activo: %s\n' "$next"
}

action_model() {
    local arg="${1:-status}" pref ask_m err_m next
    if [ "$arg" = "status" ]; then
        pref="$(normalize_agy_model_pref "$(resolve_agy_model_pref)")"
        ask_m="$(agy_model_for_mode ask)"
        err_m="$(agy_model_for_mode error)"
        printf 'Modelo Antigravity: %s (ask=%s, error=%s)\n' \
            "$pref" "${ask_m:-default}" "${err_m:-default}"
        return 0
    fi

    next="$(normalize_agy_model_pref "$arg")"
    write_local_config_key aiAgyModel "$next"
    signal_waybar_ai
    notify "IA" "Modelo Antigravity: $next"
    printf 'Modelo Antigravity: %s\n' "$next"
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
    if command -v qs >/dev/null 2>&1 && qs ipc call ai toggle >/dev/null 2>&1; then
        return 0
    fi
    command -v fuzzel >/dev/null 2>&1 || die "No se encontró fuzzel."
    local backend open_label
    backend="$(resolve_backend)"
    if [ "$backend" = "agy" ]; then
        open_label="󰆍  Abrir Antigravity"
    else
        open_label="󰆍  Abrir OpenCode"
    fi
    local -a opts=(
        "󰚩  Preguntar a la IA"
        "$open_label"
        "󰔡  Cambiar motor IA (actual: $backend)"
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
        "󰔡 "*) action_backend toggle ;;
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
    backend) shift; action_backend "${1:-status}" ;;
    model) shift; action_model "${1:-status}" ;;
    service) shift; action_service "${1:-status}" ;;
    __run) shift; __run "$@" ;;
    *)
        echo "Uso: $(basename "$0") {menu|ask|explain|error|summarize|translate|window|image|diff|commit|open|backend|model|service}" >&2
        exit 2
        ;;
esac
