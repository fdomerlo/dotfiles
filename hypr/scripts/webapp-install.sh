#!/usr/bin/env bash
# ==============================================================================
# Gestor de Web Apps (PWAs) aisladas para Hyprland y GNOME.
#
# Genera lanzadores .desktop en ~/.local/share/applications/ usando Brave
# (por defecto), Google Chrome o Chromium con --app=<URL>, descarga el favicon
# y escribe reglas opcionales (float / scratchpad) en ~/.config/hypr/conf/webapps.conf
# usando la sintaxis Hyprland 0.55+ (windowrule v3).
#
# Uso CLI:
#   webapp-install.sh install <nombre> <url> [opciones]
#   webapp-install.sh <nombre> <url> [opciones]
#   webapp-install.sh list
#   webapp-install.sh remove <nombre|slug> [--purge]
#   webapp-install.sh menu
#
# Opciones de install:
#   --mode tile|float|scratchpad   Comportamiento en Hyprland (default: tile)
#   --icon <ruta|url>              Icono local o URL PNG/SVG/ICO
#   --isolated                     Usa perfil aislado en ~/.local/share/webapps/<slug>
#   --browser brave|chrome|chromium
#   --purge                        (Con remove) borra también el perfil aislado
# ==============================================================================
set -euo pipefail

APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/webapps"
PROFILE_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/webapps"
WEBAPPS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf/webapps.conf"
PROMPT_PREFIX="${WEBAPP_PROMPT_PREFIX:-}"

die() {
    printf 'Error: %s\n' "$*" >&2
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        notify "Error en Web Apps" "$*"
    fi
    exit 1
}

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a "Web Apps" "$@" 2>/dev/null || true
}

usage() {
    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

ensure_webapps_conf() {
    mkdir -p "$(dirname "$WEBAPPS_CONF")"
    if [ ! -e "$WEBAPPS_CONF" ]; then
        cat >"$WEBAPPS_CONF" <<'EOF'
# ==============================================================================
# Reglas de Web Apps (PWAs) generadas localmente por webapp-install.sh.
# No versionado; incluido al final de hypr/conf/windowrules.conf.
# ==============================================================================
EOF
    fi
}

reload_hyprland() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

refresh_desktop_db() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi
}

slugify() {
    local raw="$1" slug
    slug="$(printf '%s' "$raw" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$raw")"
    slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    [ -n "$slug" ] || slug="webapp"
    printf '%s' "$slug"
}

normalize_url() {
    local u="$1"
    if [[ ! "$u" =~ ^https?:// ]]; then
        u="https://$u"
    fi
    printf '%s' "$u"
}

extract_host() {
    local u="$1" rest host
    rest="${u#http://}"
    rest="${rest#https://}"
    host="${rest%%/*}"
    host="${host##*@}"
    host="${host%%:*}"
    printf '%s' "$host"
}

regex_escape() {
    printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\]/\\&/g'
}

pick_browser() {
    local requested="${1:-}"
    case "$requested" in
        "")
            if command -v brave-browser >/dev/null 2>&1; then
                printf 'brave-browser'
            elif command -v google-chrome >/dev/null 2>&1; then
                printf 'google-chrome'
            elif command -v chromium >/dev/null 2>&1; then
                printf 'chromium'
            else
                die "No se encontró brave-browser, google-chrome ni chromium. Ejecutá 'make tooling'."
            fi
            ;;
        brave|brave-browser)
            command -v brave-browser >/dev/null 2>&1 || die "brave-browser no está instalado."
            printf 'brave-browser'
            ;;
        chrome|google-chrome|google-chrome-stable)
            command -v google-chrome >/dev/null 2>&1 || die "google-chrome no está instalado."
            printf 'google-chrome'
            ;;
        chromium)
            command -v chromium >/dev/null 2>&1 || die "chromium no está instalado."
            printf 'chromium'
            ;;
        *)
            die "Navegador no soportado: '$requested' (usa brave, chrome o chromium)"
            ;;
    esac
}

fetch_icon() {
    local slug="$1" url="$2" icon_arg="${3:-}"
    mkdir -p "$ICON_DIR"
    local dest="$ICON_DIR/$slug.png"

    if [ -n "$icon_arg" ]; then
        if [ -f "$icon_arg" ]; then
            cp -f "$icon_arg" "$dest"
            printf '%s' "$dest"
            return 0
        elif [[ "$icon_arg" =~ ^https?:// ]] && command -v curl >/dev/null 2>&1; then
            if curl -fsSL --max-time 8 -o "$dest.tmp" "$icon_arg" 2>/dev/null && [ -s "$dest.tmp" ]; then
                mv "$dest.tmp" "$dest"
                printf '%s' "$dest"
                return 0
            fi
            rm -f "$dest.tmp"
        fi
    fi

    local host
    host="$(extract_host "$url")"
    if [ -n "$host" ] && command -v curl >/dev/null 2>&1; then
        local origin
        origin="$(printf '%s' "$url" | sed -E 's|^(https?://[^/]+).*|\1|')"
        local -a candidates=(
            "https://www.google.com/s2/favicons?domain=${host}&sz=128"
            "${origin}/apple-touch-icon.png"
            "${origin}/favicon.ico"
        )
        local c
        for c in "${candidates[@]}"; do
            if curl -fsSL --max-time 6 -o "$dest.tmp" "$c" 2>/dev/null && [ -s "$dest.tmp" ]; then
                if command -v file >/dev/null 2>&1; then
                    if file -b --mime-type "$dest.tmp" 2>/dev/null | grep -qE '^image/'; then
                        mv "$dest.tmp" "$dest"
                        printf '%s' "$dest"
                        return 0
                    fi
                else
                    mv "$dest.tmp" "$dest"
                    printf '%s' "$dest"
                    return 0
                fi
            fi
            rm -f "$dest.tmp"
        done
    fi

    printf 'web-browser'
}

remove_hypr_rule_block() {
    local slug="$1"
    [ -f "$WEBAPPS_CONF" ] || return 0
    local tmp
    tmp="$(mktemp)"
    awk -v start="# BEGIN webapp-$slug" -v stop="# END webapp-$slug" '
        $0 == start { skip=1; next }
        $0 == stop  { skip=0; next }
        !skip { print }
    ' "$WEBAPPS_CONF" >"$tmp"
    mv "$tmp" "$WEBAPPS_CONF"
}

write_hypr_rule_block() {
    local slug="$1" host="$2" mode="$3"
    ensure_webapps_conf
    remove_hypr_rule_block "$slug"

    [ "$mode" = "tile" ] && return 0

    local host_re cls_re
    host_re="$(regex_escape "$host")"
    # En Wayland nativo Chromium/Brave/Chrome asigna app_id "<navegador>-<host>...-Default"
    # e ignora --class=; en XWayland aplica "webapp-<slug>". Cubrimos ambos casos.
    cls_re="^((brave|chrome|chromium)-${host_re}.*|webapp-${slug})$"

    {
        printf '# BEGIN webapp-%s\n' "$slug"
        case "$mode" in
            float)
                printf 'windowrule = match:class %s, float on\n' "$cls_re"
                printf 'windowrule = match:class %s, center on\n' "$cls_re"
                printf 'windowrule = match:class %s, size 80%% 80%%\n' "$cls_re"
                ;;
            scratchpad)
                printf 'windowrule = match:class %s, workspace special:magic silent\n' "$cls_re"
                printf 'windowrule = match:class %s, float on\n' "$cls_re"
                printf 'windowrule = match:class %s, center on\n' "$cls_re"
                printf 'windowrule = match:class %s, size 80%% 80%%\n' "$cls_re"
                ;;
        esac
        printf '# END webapp-%s\n' "$slug"
    } >>"$WEBAPPS_CONF"
}

cmd_install() {
    local name="" url="" mode="tile" icon_arg="" isolated=0 browser_req=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --mode)
                [ "$#" -ge 2 ] || die "--mode requiere un valor (tile|float|scratchpad)"
                mode="$2"
                shift 2
                ;;
            --icon)
                [ "$#" -ge 2 ] || die "--icon requiere una ruta o URL"
                icon_arg="$2"
                shift 2
                ;;
            --isolated)
                isolated=1
                shift
                ;;
            --browser)
                [ "$#" -ge 2 ] || die "--browser requiere un valor (brave|chrome|chromium)"
                browser_req="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                die "Opción desconocida: $1"
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                elif [ -z "$url" ]; then
                    url="$1"
                else
                    die "Argumento inesperado: $1"
                fi
                shift
                ;;
        esac
    done

    [ -n "$name" ] && [ -n "$url" ] || die "Uso: webapp-install.sh install <nombre> <url> [--mode tile|float|scratchpad] [--isolated]"
    case "$mode" in
        tile|float|scratchpad) ;;
        *) die "Modo inválido '$mode' (usa tile, float o scratchpad)" ;;
    esac

    url="$(normalize_url "$url")"
    local host slug browser_bin icon_val wm_prefix wm_class exec_cmd desktop_file
    host="$(extract_host "$url")"
    [ -n "$host" ] || die "No se pudo extraer el dominio de '$url'"

    slug="$(slugify "$name")"
    browser_bin="$(pick_browser "$browser_req")"
    icon_val="$(fetch_icon "$slug" "$url" "$icon_arg")"

    wm_prefix="brave"
    case "$browser_bin" in
        google-chrome*) wm_prefix="chrome" ;;
        chromium*) wm_prefix="chromium" ;;
    esac
    wm_class="${wm_prefix}-${host}__-Default"

    exec_cmd="$browser_bin --app=\"$url\" --class=webapp-$slug"
    if [ "$isolated" -eq 1 ]; then
        mkdir -p "$PROFILE_ROOT/$slug"
        exec_cmd="$exec_cmd --user-data-dir=\"$PROFILE_ROOT/$slug\" --no-first-run"
    fi

    mkdir -p "$APP_DIR"
    desktop_file="$APP_DIR/webapp-${slug}.desktop"
    cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=Web App ($host)
Exec=$exec_cmd
Icon=$icon_val
Terminal=false
Categories=Network;WebApp;
StartupNotify=true
StartupWMClass=$wm_class
X-WebApp-Slug=$slug
X-WebApp-URL=$url
X-WebApp-Mode=$mode
X-WebApp-Browser=$browser_bin
EOF
    chmod 0644 "$desktop_file"

    write_hypr_rule_block "$slug" "$host" "$mode"
    refresh_desktop_db
    reload_hyprland

    printf '✔ Web App instalada: %s (%s)\n' "$name" "$desktop_file"
    printf '  URL: %s | Navegador: %s | Modo: %s | Perfil: %s\n' \
        "$url" "$browser_bin" "$mode" "$( [ "$isolated" -eq 1 ] && echo "aislado" || echo "compartido" )"
    notify "Web App instalada" "$name ($mode)"
}

list_webapps_tsv() {
    [ -d "$APP_DIR" ] || return 0
    local f name url mode browser slug
    for f in "$APP_DIR"/webapp-*.desktop; do
        [ -e "$f" ] || continue
        slug="$(basename "$f" .desktop)"
        slug="${slug#webapp-}"
        name="$(sed -n 's/^Name=//p' "$f" | head -n1)"
        url="$(sed -n 's/^X-WebApp-URL=//p' "$f" | head -n1)"
        mode="$(sed -n 's/^X-WebApp-Mode=//p' "$f" | head -n1)"
        browser="$(sed -n 's/^X-WebApp-Browser=//p' "$f" | head -n1)"
        printf '%s\t%s\t%s\t%s\t%s\n' "$slug" "${name:-$slug}" "${mode:-tile}" "${browser:-brave-browser}" "${url:-}"
    done
}

cmd_list() {
    local rows
    rows="$(list_webapps_tsv)"
    if [ -z "$rows" ]; then
        echo "No hay Web Apps instaladas en $APP_DIR."
        return 0
    fi
    printf '%-18s %-22s %-12s %-15s %s\n' "SLUG" "NOMBRE" "MODO" "NAVEGADOR" "URL"
    printf '%-18s %-22s %-12s %-15s %s\n' "----" "------" "----" "---------" "---"
    while IFS=$'\t' read -r slug name mode browser url; do
        printf '%-18s %-22s %-12s %-15s %s\n' "$slug" "$name" "$mode" "$browser" "$url"
    done <<<"$rows"
}

cmd_remove() {
    local target="" purge=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --purge) purge=1; shift ;;
            -h|--help) usage; exit 0 ;;
            -*) die "Opción desconocida: $1" ;;
            *) target="$1"; shift ;;
        esac
    done
    [ -n "$target" ] || die "Uso: webapp-install.sh remove <nombre|slug> [--purge]"

    local slug desktop_file
    slug="$(slugify "${target#webapp-}")"
    desktop_file="$APP_DIR/webapp-${slug}.desktop"
    [ -e "$desktop_file" ] || die "No existe la Web App '$slug' ($desktop_file)"

    rm -f "$desktop_file" "$ICON_DIR/$slug.png"
    remove_hypr_rule_block "$slug"
    if [ "$purge" -eq 1 ] && [ -d "$PROFILE_ROOT/$slug" ]; then
        rm -rf "$PROFILE_ROOT/$slug"
    fi

    refresh_desktop_db
    reload_hyprland
    printf '✔ Web App eliminada: %s\n' "$slug"
    notify "Web App eliminada" "$slug"
}

fuzzel_pick() {
    local prompt="${PROMPT_PREFIX}$1" lines="$2" width="$3"
    shift 3
    printf '%s\n' "$@" | fuzzel --dmenu --prompt "$prompt" --lines "$lines" --width "$width" 2>/dev/null || true
}

fuzzel_input() {
    local prompt="${PROMPT_PREFIX}$1" width="${2:-48}"
    fuzzel --dmenu --prompt-only="$prompt" --width "$width" 2>/dev/null || true
}

cmd_menu() {
    command -v fuzzel >/dev/null 2>&1 || die "fuzzel no está instalado"

    local action
    action="$(fuzzel_pick "Web Apps: " 4 38 \
        "󰐕  Instalar nueva Web App" \
        "󰏌  Abrir Web App" \
        "󰆴  Eliminar Web App" \
        "󰋗  Listar Web Apps")"
    [ -n "$action" ] || return 0

    case "$action" in
        "󰐕 "*)
            local name url mode_choice mode="tile" iso_choice isolated=0
            name="$(fuzzel_input "Nombre (ej. WhatsApp): " 44)"
            [ -n "$name" ] || return 0
            url="$(fuzzel_input "URL (ej. https://web.whatsapp.com): " 56)"
            [ -n "$url" ] || return 0
            mode_choice="$(fuzzel_pick "Modo ventana ($name): " 3 44 \
                "tile        (mosaico normal)" \
                "float       (flotante centrada 80%)" \
                "scratchpad  (oculta en magic, Super+\`)")"
            [ -n "$mode_choice" ] || return 0
            mode="${mode_choice%% *}"
            iso_choice="$(fuzzel_pick "Perfil de sesión: " 2 48 \
                "Compartido  (usa tus sesiones de Brave)" \
                "Aislado     (perfil separado para esta Web App)")"
            [ -n "$iso_choice" ] || return 0
            [[ "$iso_choice" == Aislado* ]] && isolated=1

            local -a args=("$name" "$url" --mode "$mode")
            [ "$isolated" -eq 1 ] && args+=(--isolated)
            cmd_install "${args[@]}"
            ;;
        "󰏌 "*)
            local rows entries=() picked slug
            rows="$(list_webapps_tsv)"
            if [ -z "$rows" ]; then
                notify "No hay Web Apps" "Instalala primero desde 'Instalar nueva Web App'"
                return 0
            fi
            while IFS=$'\t' read -r slug name mode _browser url; do
                entries+=("$name  [$mode]  ($slug)")
            done <<<"$rows"
            picked="$(fuzzel_pick "Abrir Web App: " "${#entries[@]}" 52 "${entries[@]}")"
            [ -n "$picked" ] || return 0
            slug="$(printf '%s' "$picked" | sed -E 's/.*\(([^)]+)\)$/\1/')"
            if command -v gio >/dev/null 2>&1; then
                setsid gio launch "$APP_DIR/webapp-${slug}.desktop" >/dev/null 2>&1 </dev/null &
            else
                local cmd
                cmd="$(sed -n 's/^Exec=//p' "$APP_DIR/webapp-${slug}.desktop" | head -n1)"
                setsid bash -c "exec $cmd" >/dev/null 2>&1 </dev/null &
            fi
            ;;
        "󰆴 "*)
            local rows entries=() picked slug purge_choice
            rows="$(list_webapps_tsv)"
            if [ -z "$rows" ]; then
                notify "No hay Web Apps" "Nada para eliminar"
                return 0
            fi
            while IFS=$'\t' read -r slug name mode _browser _url; do
                entries+=("$name  [$mode]  ($slug)")
            done <<<"$rows"
            picked="$(fuzzel_pick "Eliminar Web App: " "${#entries[@]}" 52 "${entries[@]}")"
            [ -n "$picked" ] || return 0
            slug="$(printf '%s' "$picked" | sed -E 's/.*\(([^)]+)\)$/\1/')"
            if [ -d "$PROFILE_ROOT/$slug" ]; then
                purge_choice="$(fuzzel_pick "¿Borrar también perfil aislado de $slug?: " 2 48 "No (solo lanzador y regla)" "Sí (borrar perfil completo)")"
                if [[ "$purge_choice" == Sí* ]]; then
                    cmd_remove "$slug" --purge
                else
                    cmd_remove "$slug"
                fi
            else
                cmd_remove "$slug"
            fi
            ;;
        "󰋗 "*)
            local rows lines=()
            rows="$(list_webapps_tsv)"
            if [ -z "$rows" ]; then
                notify "Web Apps" "No hay Web Apps instaladas"
                return 0
            fi
            while IFS=$'\t' read -r slug name mode browser url; do
                lines+=("$name  [$mode · $browser]  $url")
            done <<<"$rows"
            fuzzel_pick "Web Apps instaladas: " "${#lines[@]}" 72 "${lines[@]}" >/dev/null || true
            ;;
    esac
}

case "${1:-}" in
    "")
        if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v fuzzel >/dev/null 2>&1; then
            cmd_menu
        else
            usage
        fi
        ;;
    menu)
        cmd_menu
        ;;
    install)
        shift
        cmd_install "$@"
        ;;
    list)
        cmd_list
        ;;
    remove|rm)
        shift
        cmd_remove "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        cmd_install "$@"
        ;;
esac
