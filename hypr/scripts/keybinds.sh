#!/usr/bin/env bash
# ==============================================================================
# Cheatsheet de atajos: lee los binds activos de Hyprland y los muestra en fuzzel.
#
# El texto "Atajos" se pasa como --prompt para que toggle-menu.sh pueda
# reconocer el menú y cerrarlo con la misma tecla.
# ==============================================================================
set -euo pipefail

for bin in hyprctl jq fuzzel; do
    command -v "$bin" >/dev/null 2>&1 || exit 1
done

mods() {
    local mask="$1" out=()
    (( mask & 64 )) && out+=("Super")
    (( mask & 4 )) && out+=("Ctrl")
    (( mask & 8 )) && out+=("Alt")
    (( mask & 1 )) && out+=("Shift")
    local IFS="+"
    printf '%s' "${out[*]}"
}

keyname() {
    case "$1" in
        grave)              printf '`' ;;
        slash)              printf '/' ;;
        equal)              printf '=' ;;
        Return)             printf 'Enter' ;;
        Escape)             printf 'Esc' ;;
        Space)              printf 'Espacio' ;;
        Page_Down)          printf 'Av.Pág' ;;
        Page_Up)            printf 'Re.Pág' ;;
        left)               printf '←' ;;
        right)              printf '→' ;;
        up)                 printf '↑' ;;
        down)               printf '↓' ;;
        Print)              printf 'Print' ;;
        XF86AudioRaiseVolume) printf 'Volumen +' ;;
        XF86AudioLowerVolume) printf 'Volumen -' ;;
        XF86AudioMute)      printf 'Mute' ;;
        XF86AudioMicMute)   printf 'Mic mute' ;;
        XF86AudioPlay)      printf 'Play/Pausa' ;;
        XF86AudioNext)      printf 'Siguiente' ;;
        XF86AudioPrev)      printf 'Anterior' ;;
        XF86AudioStop)      printf 'Stop' ;;
        XF86MonBrightnessUp)   printf 'Brillo +' ;;
        XF86MonBrightnessDown) printf 'Brillo -' ;;
        # Teclado numérico: mismos nombres para los estados con y sin NumLock.
        KP_[0-9])           printf 'Numpad %s' "${1#KP_}" ;;
        KP_End)             printf 'Numpad 1' ;;
        KP_Down)            printf 'Numpad 2' ;;
        KP_Next)            printf 'Numpad 3' ;;
        KP_Left)            printf 'Numpad 4' ;;
        KP_Begin)           printf 'Numpad 5' ;;
        KP_Right)           printf 'Numpad 6' ;;
        KP_Home)            printf 'Numpad 7' ;;
        KP_Up)              printf 'Numpad 8' ;;
        KP_Prior)           printf 'Numpad 9' ;;
        KP_Insert)          printf 'Numpad 0' ;;
        *)                  printf '%s' "$1" ;;
    esac
}

format_binds() {
    hyprctl binds -j 2>/dev/null | jq -r '
        .[]
        | select(.mouse == false and .key != "")
        | [ (.modmask | tostring), .key, (.dispatcher // ""), (.arg // "") ]
        | @tsv
    '
}

generate_table() {
    while IFS=$'\t' read -r modmask key dispatcher arg; do
        [ -n "$key" ] || continue
        combo="$(mods "$modmask")"
        # Un toque de Super se muestra como "Super", sin repetir la tecla física.
        if [[ "$key" != SUPER_* ]]; then
            name="$(keyname "$key")"
            if [ -n "$combo" ]; then
                combo="$combo+$name"
            else
                combo="$name"
            fi
        fi
        action="$dispatcher"
        [ -n "$arg" ] && action="$action $arg"
        printf '%s\t%s\n' "$combo" "$action"
    done < <(format_binds) | sort -u -f | column -t -s $'\t' -o '   '
}

generate_table | fuzzel --dmenu --prompt 'Atajos: ' --width 90 --lines 22
