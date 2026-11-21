#!/usr/bin/env bash
# ==============================================================================
# Selector de ventanas y workspaces para Rofi 2.0 + Hyprland 0.57 (script-mode).
#
# Lista todas las ventanas mapeadas con glifo simbólico monocromo por tipo de
# aplicación, workspace, clase y título, y enfoca la elegida vía
# `hl.dsp.focus({ window = 'address:...' })`.
# ==============================================================================
set -euo pipefail

RETV="${ROFI_RETV:-0}"
INFO="${ROFI_INFO:-}"

if [ "$RETV" = "1" ] && [ -n "$INFO" ]; then
    case "$INFO" in
        addr:*)
            addr="${INFO#addr:}"
            setsid -f hyprctl dispatch "hl.dsp.focus({ window = 'address:$addr' })" >/dev/null 2>&1 </dev/null
            ;;
        ws:*)
            ws="${INFO#ws:}"
            setsid -f hyprctl dispatch "hl.dsp.focus({ workspace = $ws })" >/dev/null 2>&1 </dev/null
            ;;
    esac
    exit 0
fi

printf '\0prompt\x1fVentanas\n'
printf '\0markup-rows\x1ftrue\n'

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf '\0message\x1fFaltan hyprctl o jq para listar ventanas.\n'
    exit 0
fi

clients_tsv="$(
    hyprctl clients -j 2>/dev/null | jq -r '
        map(select(.mapped == true))
        | sort_by([
            (if .workspace.id < 0 then 9999 else .workspace.id end),
            (.focusHistoryID // 9999)
          ])
        | .[]
        | [
            .address,
            (.workspace.id | tostring),
            (.workspace.name // ""),
            (.class // .initialClass // "ventana"),
            (.title // .initialTitle // "(sin título)")
          ]
        | @tsv
    '
)"

if [ -z "$clients_tsv" ]; then
    printf '\0message\x1fNo hay ventanas abiertas en esta sesión.\n'
    exit 0
fi

pango_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

glyph_for_class() {
    case "${1,,}" in
        *firefox*|*chrome*|*chromium*|*brave*|*vivaldi*|*epiphany*|*zen*) printf '󰖟' ;;
        *foot*|*kitty*|*alacritty*|*wezterm*|*tmux*|*terminal*|*tui-float*) printf '󰆍' ;;
        *zed*|*code*|*codium*|*nvim*|*neovim*|*antigravity*|*cursor*|*sublime*) printf '󰅩' ;;
        *dbeaver*|*bruno*|*postman*|*insomnia*|*pgadmin*) printf '󰆼' ;;
        *wireshark*|*remmina*|*rustdesk*|*nm-connection*) printf '󰤨' ;;
        *nautilus*|*thunar*|*dolphin*|*nemo*|*yazi*) printf '󰉋' ;;
        *obsidian*|*libreoffice*|*evince*|*papers*|*okular*|*zathura*) printf '󰈙' ;;
        *pavucontrol*|*vlc*|*mpv*|*spotify*|*obs*|*audacity*) printf '󰎆' ;;
        *gimp*|*inkscape*|*blender*|*krita*|*swappy*|*loupe*|*imv*) printf '󰏘' ;;
        *keepass*|*bitwarden*|*seahorse*) printf '󰒃' ;;
        *thunderbird*|*slack*|*discord*|*telegram*|*signal*) printf '󰍡' ;;
        *blueman*) printf '󰂯' ;;
        *calculator*) printf '󰪚' ;;
        *settings*|*control-center*|*qt6ct*|*timeshift*|*gparted*|*btop*) printf '󰒓' ;;
        *) printf '󱂬' ;;
    esac
}

while IFS=$'\t' read -r addr ws_id ws_name cls title; do
    [ -n "$addr" ] || continue
    if [[ "$ws_name" == special:* ]]; then
        ws_tag="[${ws_name#special:}]"
    else
        ws_tag="[WS ${ws_id}]"
    fi
    glyph="$(glyph_for_class "$cls")"
    cls_esc="$(pango_escape "$cls")"
    title_esc="$(pango_escape "$title")"
    display="${glyph}  <b>${cls_esc}</b>  <span alpha='55%' size='small'>${ws_tag}</span>  <span alpha='78%'>${title_esc}</span>"
    meta="ws${ws_id} ${ws_name} ${cls} ${title}"
    printf '%s\0info\x1faddr:%s\x1fmeta\x1f%s\n' \
        "$display" "$addr" "$meta"
done <<< "$clients_tsv"
