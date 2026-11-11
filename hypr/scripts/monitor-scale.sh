#!/usr/bin/env bash
# ==============================================================================
# Escala por monitor para que las tipografías tengan un tamaño físico similar.
#
# La escala de Hyprland es un zoom lógico por salida, no un ajuste automático
# de densidad. La densidad relevante es el PPI lógico:
#
#     PPI lógico = PPI físico / scale
#
# Para que una misma fuente se vea del mismo tamaño físico en todas las
# salidas, hay que igualar el PPI lógico: la escala de cada monitor debe ser
# proporcional a su PPI físico.
#
# Referencia por defecto: el monitor enfocado (el que estás mirando), usando
# su escala actual. Así el resto se ajusta a lo que ya te parece correcto.
#
# Uso:
#   monitor-scale.sh                    # tabla con PPI y escala sugerida
#   monitor-scale.sh --ref HDMI-A-1     # usar otro monitor como referencia
#   monitor-scale.sh --logical-ppi 96   # fijar el PPI lógico objetivo
#   monitor-scale.sh --hyprconf         # líneas monitor = ... sugeridas
# ==============================================================================
set -euo pipefail

# Los números deben usar punto decimal: Hyprland no acepta "1,20".
export LC_ALL=C

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'
}

ref_name=""
target_ppi=""
hyprconf=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref)
            [ "$#" -ge 2 ] || die "--ref necesita un nombre de monitor"
            ref_name="$2"
            shift 2
            ;;
        --logical-ppi)
            [ "$#" -ge 2 ] || die "--logical-ppi necesita un número"
            target_ppi="$2"
            shift 2
            ;;
        --hyprconf)
            hyprconf=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "opción desconocida: $1"
            ;;
    esac
done

command -v hyprctl >/dev/null 2>&1 || die "hyprctl no está disponible"
command -v jq >/dev/null 2>&1 || die "jq no está instalado"

if [ -n "$target_ppi" ] && ! awk -v v="$target_ppi" 'BEGIN { exit !(v ~ /^[0-9]+([.][0-9]+)?$/ && v > 0) }'; then
    die "--logical-ppi debe ser un número positivo"
fi

# Una fila por monitor:
# name  width  height  refresh  x  y  scale  ppi  focused
rows="$(
    hyprctl monitors -j | jq -r '
        def ppi:
            if ((.physicalWidth // 0) > 0) and ((.physicalHeight // 0) > 0) then
                (((.width * .width) + (.height * .height)) | sqrt) /
                (((((.physicalWidth * .physicalWidth) + (.physicalHeight * .physicalHeight)) | sqrt) / 25.4))
            else
                0
            end;
        .[]
        | [ .name, .width, .height, (.refreshRate // 0), .x, .y, .scale, ppi, (.focused // false) ]
        | @tsv
    '
)"

[ -n "$rows" ] || die "no se detectaron monitores activos"

# Elegir la referencia: --logical-ppi, --ref o el monitor enfocado.
ref_row=""
ref_label=""

if [ -n "$target_ppi" ]; then
    ref_label="PPI lógico objetivo"
elif [ -n "$ref_name" ]; then
    ref_row="$(awk -F'\t' -v n="$ref_name" '$1 == n' <<<"$rows")"
    [ -n "$ref_row" ] || die "no existe el monitor '$ref_name' (ver: hyprctl monitors)"
    ref_label="monitor $ref_name"
else
    ref_row="$(awk -F'\t' '$9 == "true" { print; exit }' <<<"$rows")"
    [ -n "$ref_row" ] || ref_row="$(head -n 1 <<<"$rows")"
    ref_name="$(awk -F'\t' '{ print $1 }' <<<"$ref_row")"
    ref_label="monitor enfocado $ref_name"
fi

if [ -z "$target_ppi" ]; then
    target_ppi="$(awk -F'\t' '{
        ppi = $8 + 0
        scale = $7 + 0
        if (ppi > 0 && scale > 0) printf "%.4f", ppi / scale
    }' <<<"$ref_row")"

    if [ -z "$target_ppi" ]; then
        die "el monitor de referencia no informa tamaño físico; usá --logical-ppi"
    fi
fi

printf '%-12s %-15s %8s %8s %10s %10s\n' \
    "MONITOR" "RESOLUCIÓN" "PPI" "ESCALA" "PPI LÓG." "SUGERIDA"
printf '%-12s %-15s %8s %8s %10s %10s\n' \
    "------------" "---------------" "--------" "--------" "----------" "----------"

awk -F'\t' -v ref="$target_ppi" '
    function snap(x) { return int(x * 20 + 0.5) / 20 }
    {
        name = $1
        res = sprintf("%dx%d@%d", $2, $3, $4)
        scale = $7 + 0
        ppi = $8 + 0

        if (ppi > 0 && ref > 0 && scale > 0) {
            logical = ppi / scale
            suggested = snap(ppi / ref)
            printf "%-12s %-15s %8.1f %8.2f %10.1f %10.2f\n", \
                name, res, ppi, scale, logical, suggested
        } else {
            printf "%-12s %-15s %8s %8.2f %10s %10s\n", \
                name, res, "?", scale, "?", "?"
        }
    }
' <<<"$rows"

printf '\nReferencia: %s → PPI lógico %.1f\n' "$ref_label" "$target_ppi"

if awk -F'\t' '{ if (($8 + 0) == 0) bad = 1 } END { exit !bad }' <<<"$rows"; then
    printf 'Aviso: alguna salida no informa tamaño físico (EDID); no se puede calcular su PPI.\n'
fi

if [ "$hyprconf" = "1" ]; then
    printf '\n# Escalas sugeridas (ajustá las posiciones a tu layout físico).\n'
    awk -F'\t' -v ref="$target_ppi" '
        function snap(x) { return int(x * 20 + 0.5) / 20 }
        {
            ppi = $8 + 0
            scale = $7 + 0
            if (ppi > 0 && ref > 0) {
                printf "monitor = %s, %dx%d@%d, auto, %.2f\n", \
                    $1, $2, $3, $4, snap(ppi / ref)
            } else {
                printf "# monitor = %s, %dx%d@%d, auto, ?  (PPI desconocido)\n", \
                    $1, $2, $3, $4
            }
        }
    ' <<<"$rows"
else
    printf '\nAplicá la escala sugerida por salida en hypr/conf/monitors.conf:\n'
    printf '  monitor = <salida>, <resolución>@<hz>, <posición>, <escala>\n'
    printf 'Ejemplo: monitor = HDMI-A-1, 2560x1440@60, auto-right, 1.20\n'
fi

printf '\nLa escala no cambia el tamaño de la fuente: cambia cuántos píxeles\n'
printf 'físicos ocupa cada píxel lógico. Si el texto del monitor de referencia\n'
printf 'te parece correcto, usalo como referencia; si querés todo más chico o\n'
printf 'más grande, ajustá primero la escala de ese monitor o usá --logical-ppi.\n'
