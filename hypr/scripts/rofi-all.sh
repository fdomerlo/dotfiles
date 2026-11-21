#!/usr/bin/env bash
# ==============================================================================
# Pestaña global "Todo" para Rofi 2.0 (script-mode).
#
# Agrega en un solo buscador: Apps + Ventanas + Dev + Capturar + Estilo + Sistema,
# reutilizando los scripts existentes en paralelo (~35-45 ms, 0 MB en reposo)
# con markup Pango intacto y despacho directo a cada proveedor.
# ==============================================================================
set -euo pipefail

exec python3 - "$@" <<'PY'
import concurrent.futures
import os
import subprocess
import sys
from pathlib import Path

RETV = os.environ.get("ROFI_RETV", "0")
INFO = os.environ.get("ROFI_INFO", "")
SCRIPTS = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr/scripts"

SOURCES = [
    ("app",  None,       [str(SCRIPTS / "rofi-apps.sh")],                   "app aplicacion"),
    ("win",  "Ventana",  [str(SCRIPTS / "rofi-windows.sh")],                "ventana window"),
    ("dev",  "Dev",      [str(SCRIPTS / "rofi-actions.sh"), "dev"],         "dev ia"),
    ("cap",  "Capturar", [str(SCRIPTS / "rofi-actions.sh"), "capturar"],    "capturar captura"),
    ("est",  "Estilo",   [str(SCRIPTS / "rofi-actions.sh"), "estilo"],      "estilo tema"),
    ("sis",  "Sistema",  [str(SCRIPTS / "rofi-actions.sh"), "sistema"],     "sistema"),
]


def dispatch(info: str) -> None:
    env = os.environ.copy()
    env["ROFI_RETV"] = "1"
    if info.startswith("app:"):
        env["ROFI_INFO"] = info[4:]
        subprocess.run([str(SCRIPTS / "rofi-apps.sh")], env=env, check=False)
    elif info.startswith("win:"):
        env["ROFI_INFO"] = info[4:]
        subprocess.run([str(SCRIPTS / "rofi-windows.sh")], env=env, check=False)
    elif info.startswith("act:"):
        rest = info[4:]
        cat, _, act_id = rest.partition(":")
        if cat and act_id:
            env["ROFI_INFO"] = act_id
            subprocess.run([str(SCRIPTS / "rofi-actions.sh"), cat], env=env, check=False)


def run_source(src: tuple[str, str | None, list[str], str]) -> list[str]:
    kind, badge, cmd, extra_meta = src
    env = os.environ.copy()
    env["ROFI_RETV"] = "0"
    env.pop("ROFI_INFO", None)
    try:
        res = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=2)
    except Exception:
        return []
    if res.returncode != 0:
        return []

    cat_map = {"dev": "dev", "cap": "capturar", "est": "estilo", "sis": "sistema"}
    rows: list[str] = []

    for line in res.stdout.splitlines():
        if not line or line.startswith("\0"):
            continue
        display, sep, rest = line.partition("\0")
        if not sep:
            continue

        fields = rest.split("\x1f")
        kv: dict[str, str] = {}
        for i in range(0, len(fields) - 1, 2):
            kv[fields[i]] = fields[i + 1]

        orig_info = kv.get("info", "")
        if not orig_info:
            continue

        if kind == "app":
            new_info = f"app:{orig_info}"
        elif kind == "win":
            new_info = f"win:{orig_info}"
        else:
            new_info = f"act:{cat_map[kind]}:{orig_info}"

        orig_meta = kv.get("meta", "")
        meta = f"{orig_meta} {extra_meta}".strip()

        if badge and kind not in ("app", "win"):
            display = f"{display}  <span alpha='38%' size='small'>· {badge}</span>"

        rows.append(f"{display}\0info\x1f{new_info}\x1fmeta\x1f{meta}\n")

    return rows


def main() -> None:
    if RETV == "1" and INFO:
        dispatch(INFO)
        return

    sys.stdout.write("\0prompt\x1fTodo\n")
    sys.stdout.write("\0markup-rows\x1ftrue\n")

    with concurrent.futures.ThreadPoolExecutor(max_workers=len(SOURCES)) as ex:
        results = list(ex.map(run_source, SOURCES))

    out = []
    for chunk in results:
        out.extend(chunk)
    sys.stdout.write("".join(out))


if __name__ == "__main__":
    main()
PY
