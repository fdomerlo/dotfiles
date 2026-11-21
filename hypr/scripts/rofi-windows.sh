#!/usr/bin/env bash
# ==============================================================================
# Selector de ventanas y workspaces para Rofi 2.0 + Hyprland 0.57 (script-mode).
#
# Reemplaza OverviewWindow.qml sin daemon residente ni streaming ScreencopyView:
# lista todas las ventanas mapeadas con su workspace, clase, título e ícono,
# y enfoca la ventana elegida vía `hl.dsp.focus({ window = 'address:...' })`.
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

while IFS=$'\t' read -r addr ws_id ws_name cls title; do
    [ -n "$addr" ] || continue
    if [[ "$ws_name" == special:* ]]; then
        ws_tag="[${ws_name#special:}]"
    else
        ws_tag="[WS ${ws_id}]"
    fi
    cls_esc="$(pango_escape "$cls")"
    title_esc="$(pango_escape "$title")"
    icon_name="${cls,,}"
    display="<span alpha='70%'>${ws_tag}</span>  <b>${cls_esc}</b>  —  ${title_esc}"
    meta="ws${ws_id} ${ws_name} ${cls} ${title}"
    printf '%s\0info\x1faddr:%s\x1ficon\x1f%s\x1fmeta\x1f%s\n' \
        "$display" "$addr" "$icon_name" "$meta"
done <<<"$clients_tsv"
