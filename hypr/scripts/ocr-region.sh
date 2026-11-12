#!/usr/bin/env bash
# ==============================================================================
# OCR de región de pantalla: `slurp` + `grim` + `tesseract` + `wl-copy`.
#
# Selecciona un área, extrae el texto (español + inglés si están disponibles)
# y lo copia al portapapeles con una notificación de vista previa.
# ==============================================================================
set -euo pipefail

notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Hyprland "$@" 2>/dev/null || true
}

for bin in slurp grim wl-copy; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        notify "OCR" "Falta $bin"
        exit 1
    fi
done

if ! command -v tesseract >/dev/null 2>&1; then
    notify "OCR" "Falta tesseract-ocr (instalar con: sudo apt install tesseract-ocr tesseract-ocr-spa)"
    exit 1
fi

pick_langs() {
    local avail
    avail="$(tesseract --list-langs 2>/dev/null || true)"
    if printf '%s\n' "$avail" | grep -qx 'spa' && printf '%s\n' "$avail" | grep -qx 'eng'; then
        printf 'spa+eng'
    elif printf '%s\n' "$avail" | grep -qx 'spa'; then
        printf 'spa'
    elif printf '%s\n' "$avail" | grep -qx 'eng'; then
        printf 'eng'
    else
        printf 'osd'
    fi
}

REGION="$(slurp)" || exit 0
[ -n "$REGION" ] || exit 0

LANGS="$(pick_langs)"
TEXT="$(
    grim -g "$REGION" - |
        tesseract stdin stdout -l "$LANGS" --psm 6 2>/dev/null |
        sed -e 's/[[:space:]]*$//'
)" || true

# Quitar líneas vacías al inicio y final.
TEXT="$(printf '%s\n' "$TEXT" | awk 'NF {p=1} p' | tac | awk 'NF {p=1} p' | tac)"

if [ -z "$TEXT" ]; then
    notify "OCR ($LANGS)" "No se detectó texto en la región"
    exit 0
fi

printf '%s' "$TEXT" | wl-copy

PREVIEW="$(printf '%s' "$TEXT" | tr '\n' ' ' | cut -c1-140)"
[ "${#TEXT}" -gt 140 ] && PREVIEW="${PREVIEW}..."
notify "OCR copiado ($LANGS)" "$PREVIEW"
