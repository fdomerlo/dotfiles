#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/clipboard.sh - Gestor de portapapeles (Quickshell + cliphist + fallback Fuzzel)
#
# Uso:
#   clipboard.sh              # alterna ClipboardPopup en Quickshell (fallback fuzzel)
#   clipboard.sh --fuzzel     # selector dmenu clásico con fuzzel
#   clipboard.sh --json       # lista JSON + thumbnails decodificados en caché runtime
#   clipboard.sh --copy <id>  # copia la entrada <id> al portapapeles (wl-copy)
#   clipboard.sh --delete <id># elimina la entrada <id> de cliphist y su miniatura
#   clipboard.sh --wipe       # vacía todo el historial y limpia la caché
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
THUMB_DIR="${XDG_RUNTIME_DIR:-/tmp}/qs-clipboard-thumbs"

notify_clip() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Hyprland" -t 2200 "Portapapeles" "$1" 2>/dev/null || true
    fi
}

require_cliphist() {
    if ! command -v cliphist >/dev/null 2>&1; then
        notify_clip "Falta cliphist"
        exit 1
    fi
}

run_fuzzel_menu() {
    require_cliphist
    if ! command -v fuzzel >/dev/null 2>&1; then
        notify_clip "Falta fuzzel"
        exit 1
    fi

    local wipe_label="󰃢  Limpiar historial"
    local items selection
    items="$(cliphist list || true)"
    [ -n "$items" ] || exit 0

    selection="$(printf '%s\n%s\n' "$items" "$wipe_label" | fuzzel --dmenu --prompt 'Portapapeles: ' --width 70)" || exit 0
    [ -n "$selection" ] || exit 0

    if [ "$selection" = "$wipe_label" ]; then
        cliphist wipe
        rm -rf "$THUMB_DIR"
        notify_clip "Historial vaciado"
        exit 0
    fi

    printf '%s\n' "$selection" | cliphist decode | wl-copy
}

export_json() {
    require_cliphist
    CLIPHIST_THUMB_DIR="$THUMB_DIR" python3 - <<'PY'
import json
import os
import re
import subprocess

thumb_dir = os.environ["CLIPHIST_THUMB_DIR"]
os.makedirs(thumb_dir, mode=0o700, exist_ok=True)
try:
    os.chmod(thumb_dir, 0o700)
except OSError:
    pass

proc = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
if proc.returncode != 0:
    print(json.dumps({"total": 0, "items": []}, ensure_ascii=False))
    raise SystemExit(0)

raw_lines = [ln for ln in proc.stdout.splitlines() if "\t" in ln]
total = len(raw_lines)
max_entries = 150
max_thumbs = 24
img_re = re.compile(
    r"^\[\[\s*binary data\s+(.+?)\s+(png|jpg|jpeg|webp|bmp|gif|tiff)(?:\s+(\d+x\d+))?\s*\]\]$",
    re.IGNORECASE,
)

items = []
seen_ids = set()
decoded_count = 0

for line in raw_lines[:max_entries]:
    entry_id, preview = line.split("\t", 1)
    entry_id = entry_id.strip()
    if not entry_id.isdigit():
        continue
    seen_ids.add(entry_id)

    m = img_re.match(preview.strip())
    if m:
        size_label = m.group(1).strip()
        fmt = m.group(2).lower()
        dims = (m.group(3) or "").replace("x", "×")
        parts = [fmt.upper()]
        if dims:
            parts.append(dims)
        if size_label:
            parts.append(size_label)
        meta = " · ".join(parts)

        ext = "jpg" if fmt == "jpeg" else fmt
        thumb_path = os.path.join(thumb_dir, f"{entry_id}.{ext}")
        thumb_uri = ""

        if os.path.isfile(thumb_path) and os.path.getsize(thumb_path) > 0:
            thumb_uri = "file://" + thumb_path
        elif decoded_count < max_thumbs:
            decoded_count += 1
            dec = subprocess.run(
                ["cliphist", "decode"],
                input=f"{entry_id}\t\n".encode("utf-8"),
                capture_output=True,
            )
            if dec.returncode == 0 and len(dec.stdout) > 0:
                tmp_path = thumb_path + ".tmp"
                with open(tmp_path, "wb") as fh:
                    fh.write(dec.stdout)
                os.replace(tmp_path, thumb_path)
                thumb_uri = "file://" + thumb_path

        items.append({
            "id": entry_id,
            "preview": f"Imagen {fmt.upper()}",
            "isImage": True,
            "meta": meta,
            "thumbPath": thumb_uri,
        })
    else:
        items.append({
            "id": entry_id,
            "preview": preview,
            "isImage": False,
            "meta": "",
            "thumbPath": "",
        })

try:
    for fname in os.listdir(thumb_dir):
        stem = fname.split(".", 1)[0]
        if stem.isdigit() and stem not in seen_ids:
            try:
                os.remove(os.path.join(thumb_dir, fname))
            except OSError:
                pass
except OSError:
    pass

print(json.dumps({"total": total, "items": items}, ensure_ascii=False))
PY
}

case "${1:-}" in
    "")
        if command -v qs >/dev/null 2>&1 && qs ipc call clipboard toggle >/dev/null 2>&1; then
            exit 0
        fi
        if [ -x "$SCRIPT_DIR/toggle-menu.sh" ]; then
            exec "$SCRIPT_DIR/toggle-menu.sh" 'Portapapeles' "$SCRIPT_PATH" --fuzzel
        fi
        run_fuzzel_menu
        ;;
    --fuzzel)
        run_fuzzel_menu
        ;;
    --json)
        export_json
        ;;
    --copy)
        require_cliphist
        id="${2:-}"
        [[ "$id" =~ ^[0-9]+$ ]] || exit 1
        printf '%s\t\n' "$id" | cliphist decode | wl-copy
        ;;
    --delete)
        require_cliphist
        id="${2:-}"
        [[ "$id" =~ ^[0-9]+$ ]] || exit 1
        printf '%s\t\n' "$id" | cliphist delete
        rm -f "$THUMB_DIR/${id}."* 2>/dev/null || true
        ;;
    --wipe)
        require_cliphist
        cliphist wipe
        rm -rf "$THUMB_DIR"
        notify_clip "Historial vaciado"
        ;;
    *)
        echo "Uso: $(basename "$0") [--fuzzel|--json|--copy <id>|--delete <id>|--wipe]" >&2
        exit 2
        ;;
esac
