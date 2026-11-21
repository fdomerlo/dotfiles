#!/usr/bin/env bash
# ==============================================================================
# Selector de aplicaciones para Rofi 2.0 (script-mode) con glifos simbólicos
# monocromos por función/categoría (coherente con Fuzzel y el resto de pestañas).
#
# - 0 MB en reposo (sin daemon residente).
# - Caché en $XDG_RUNTIME_DIR invalidada automáticamente por mtime de carpetas
#   .desktop (~15 ms en aperturas posteriores).
# - Ordena por uso reciente (MRU en ~/.cache/rofi-apps-mru.json) + alfabético.
# - Lanza apps vía `gio launch` (o `foot -e` si Terminal=true).
# ==============================================================================
set -euo pipefail

exec python3 - "$@" <<'PY'
import configparser
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

RETV = os.environ.get("ROFI_RETV", "0")
INFO = os.environ.get("ROFI_INFO", "")

XDG_DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
XDG_CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))

CACHE_FILE = RUNTIME_DIR / "rofi-apps-cache.json"
MRU_FILE = XDG_CACHE_HOME / "rofi-apps-mru.json"
TERMINAL_BIN = "foot"

# Mapeo de glifos Nerd Font monocromos por identidad de app (prioridad alta)
APP_GLYPH_HINTS = [
    # Navegadores y web
    (("firefox", "chromium", "chrome", "brave", "vivaldi", "epiphany", "zen-browser", "qutebrowser", "webapp"), "󰖟"),
    # Terminales
    (("foot", "kitty", "alacritty", "wezterm", "kgx", "gnome-terminal", "xterm", "tmux"), "󰆍"),
    # Editores / IDEs / IA dev
    (("zed", "vscode", "code", "codium", "nvim", "neovim", "vim", "antigravity", "opencode", "cursor", "sublime", "geany", "helix"), "󰅩"),
    # Bases de datos / APIs
    (("dbeaver", "bruno", "postman", "insomnia", "pgadmin", "beekeeper", "sqlite"), "󰆼"),
    # Red / Acceso remoto / Análisis de tráfico
    (("wireshark", "remmina", "rustdesk", "nm-connection-editor", "nm-applet", "openvpn", "wireguard"), "󰤨"),
    # Gestores de archivos
    (("nautilus", "files", "thunar", "dolphin", "nemo", "pcmanfm", "yazi", "mc"), "󰉋"),
    # Notas / Oficina / Documentos
    (("obsidian", "logseq", "joplin", "libreoffice", "evince", "papers", "okular", "zathura", "calibre"), "󰈙"),
    # Audio / Video / Control de sonido
    (("pavucontrol", "easyeffects", "helvum", "vlc", "mpv", "spotify", "audacity", "obs", "kdenlive", "rhythmbox", "totem", "amberol"), "󰎆"),
    # Gráficos / Imagen / Captura
    (("gimp", "inkscape", "blender", "krita", "swappy", "loupe", "eog", "imv", "darktable", "shotwell"), "󰏘"),
    # Seguridad / Claves
    (("keepass", "bitwarden", "seahorse", "gpa", "1password"), "󰒃"),
    # Comunicación / Correo
    (("thunderbird", "slack", "discord", "telegram", "signal", "element", "geary", "evolution"), "󰍡"),
    # Calculadora / Ciencia
    (("calculator", "qalculate", "octave", "geogebra"), "󰪚"),
    # Bluetooth
    (("blueman", "bluetooth"), "󰂯"),
    # Sistema / Respaldo / Discos / Monitores
    (("timeshift", "gparted", "baobab", "gnome-disks", "diskutility", "btop", "htop", "missioncenter", "gnome-system-monitor", "gnome-control-center", "nwg-look"), "󰒓"),
]

# Mapeo por categoría XDG estándar (fallback limpio por función)
CATEGORY_GLYPHS = [
    ("WebBrowser", "󰖟"),
    ("TerminalEmulator", "󰆍"),
    ("IDE", "󰅩"),
    ("Development", "󰅩"),
    ("TextEditor", "󰅩"),
    ("Database", "󰆼"),
    ("FileManager", "󰉋"),
    ("RemoteAccess", "󰤨"),
    ("Network", "󰤨"),
    ("Security", "󰒃"),
    ("InstantMessaging", "󰍡"),
    ("Email", "󰍡"),
    ("Chat", "󰍡"),
    ("Office", "󰈙"),
    ("WordProcessor", "󰈙"),
    ("Spreadsheet", "󰈙"),
    ("Presentation", "󰈙"),
    ("Calendar", "󰈙"),
    ("Graphics", "󰏘"),
    ("Photography", "󰏘"),
    ("AudioVideo", "󰎆"),
    ("Audio", "󰎆"),
    ("Video", "󰎆"),
    ("Player", "󰎆"),
    ("Calculator", "󰪚"),
    ("Science", "󰪚"),
    ("Education", "󰪚"),
    ("Game", "󰊗"),
    ("Settings", "󰒓"),
    ("HardwareSettings", "󰒓"),
    ("Monitor", "󰒓"),
    ("PackageManager", "󰒓"),
    ("System", "󰒓"),
]


def load_mru() -> dict:
    try:
        return json.loads(MRU_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_mru(mru: dict) -> None:
    try:
        MRU_FILE.parent.mkdir(parents=True, exist_ok=True)
        MRU_FILE.write_text(json.dumps(mru), encoding="utf-8")
    except Exception:
        pass


def strip_field_codes(exec_str: str) -> list[str]:
    parts = shlex.split(exec_str)
    out = []
    for p in parts:
        if p in ("%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m"):
            continue
        out.append(p)
    return out


def launch_desktop(desktop_path: str) -> None:
    path = Path(desktop_path)
    if not path.is_file():
        return

    mru = load_mru()
    mru[desktop_path] = int(time.time())
    save_mru(mru)

    terminal = False
    exec_line = ""
    try:
        cp = configparser.RawConfigParser(interpolation=None, strict=False)
        cp.read(path, encoding="utf-8")
        if cp.has_section("Desktop Entry"):
            terminal = cp.get("Desktop Entry", "Terminal", fallback="false").strip().lower() == "true"
            exec_line = cp.get("Desktop Entry", "Exec", fallback="").strip()
    except Exception:
        pass

    devnull = subprocess.DEVNULL
    if terminal and exec_line:
        cmd = strip_field_codes(exec_line)
        if cmd:
            subprocess.Popen(
                [TERMINAL_BIN, "-e", *cmd],
                stdin=devnull,
                stdout=devnull,
                stderr=devnull,
                start_new_session=True,
            )
            return

    subprocess.Popen(
        ["gio", "launch", str(path)],
        stdin=devnull,
        stdout=devnull,
        stderr=devnull,
        start_new_session=True,
    )


def app_dirs() -> list[Path]:
    dirs = [
        XDG_DATA_HOME / "applications",
        XDG_DATA_HOME / "flatpak/exports/share/applications",
    ]
    xdg_data_dirs = os.environ.get(
        "XDG_DATA_DIRS",
        "/usr/local/share:/usr/share:/var/lib/flatpak/exports/share",
    )
    for d in xdg_data_dirs.split(":"):
        if d:
            p = Path(d) / "applications"
            if p not in dirs:
                dirs.append(p)
    extra = Path("/var/lib/flatpak/exports/share/applications")
    if extra not in dirs:
        dirs.append(extra)
    return [d for d in dirs if d.is_dir()]


def dirs_fingerprint(dirs: list[Path]) -> str:
    h = hashlib.sha256()
    lang = os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    h.update(f"v1|{lang}|".encode())
    for d in dirs:
        try:
            st = d.stat()
            h.update(f"{d}:{st.st_mtime_ns}:{st.st_ctime_ns}|".encode())
        except OSError:
            pass
    return h.hexdigest()


def localized_get(sec, key: str) -> str:
    lang = (os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or "").split(".")[0]
    short = lang.split("_")[0] if "_" in lang else lang
    for suffix in (f"[{lang}]" if lang else "", f"[{short}]" if short else "", ""):
        k = f"{key}{suffix}"
        if k in sec and sec[k].strip():
            return sec[k].strip()
    return ""


def pick_glyph(desktop_id: str, name: str, wmclass: str, categories: list[str]) -> str:
    haystack = f"{desktop_id} {name} {wmclass}".lower()
    for needles, glyph in APP_GLYPH_HINTS:
        if any(n in haystack for n in needles):
            return glyph
    cat_set = set(categories)
    for cat, glyph in CATEGORY_GLYPHS:
        if cat in cat_set:
            return glyph
    return "󰀻"


def pango_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def scan_apps(dirs: list[Path]) -> list[dict]:
    seen_ids: set[str] = set()
    entries: list[dict] = []

    for base in dirs:
        try:
            files = sorted(base.glob("*.desktop"))
        except OSError:
            continue
        for f in files:
            desktop_id = f.name
            if desktop_id in seen_ids:
                continue
            seen_ids.add(desktop_id)

            cp = configparser.RawConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
            except Exception:
                continue
            if not cp.has_section("Desktop Entry"):
                continue
            sec = cp["Desktop Entry"]

            if sec.get("Type", "").strip() != "Application":
                continue
            if sec.get("NoDisplay", "false").strip().lower() == "true":
                continue
            if sec.get("Hidden", "false").strip().lower() == "true":
                continue
            if not sec.get("Exec", "").strip():
                continue
            try_exec = sec.get("TryExec", "").strip()
            if try_exec and not (Path(try_exec).is_file() or shutil.which(try_exec)):
                continue

            only_in = [x for x in sec.get("OnlyShowIn", "").split(";") if x]
            if only_in and not ({"Hyprland", "GNOME"} & set(only_in)):
                continue
            not_in = [x for x in sec.get("NotShowIn", "").split(";") if x]
            if "Hyprland" in not_in:
                continue

            name = localized_get(sec, "Name")
            if not name:
                continue
            generic = localized_get(sec, "GenericName")
            comment = localized_get(sec, "Comment")
            keywords = localized_get(sec, "Keywords").replace(";", " ")
            wmclass = sec.get("StartupWMClass", "").strip()
            categories = [c for c in sec.get("Categories", "").split(";") if c]

            glyph = pick_glyph(desktop_id, name, wmclass, categories)
            meta = " ".join(
                p for p in (desktop_id.removesuffix(".desktop"), generic, comment, keywords, wmclass, " ".join(categories))
                if p
            )
            entries.append({
                "path": str(f),
                "name": name,
                "glyph": glyph,
                "meta": meta,
            })

    return entries


def load_catalog() -> list[dict]:
    dirs = app_dirs()
    fp = dirs_fingerprint(dirs)
    try:
        cached = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        if cached.get("fp") == fp and isinstance(cached.get("entries"), list):
            return cached["entries"]
    except Exception:
        pass

    entries = scan_apps(dirs)
    try:
        CACHE_FILE.write_text(json.dumps({"fp": fp, "entries": entries}), encoding="utf-8")
    except Exception:
        pass
    return entries


def main() -> None:
    if RETV == "1" and INFO:
        launch_desktop(INFO)
        return

    sys.stdout.write("\0prompt\x1fApps\n")
    sys.stdout.write("\0markup-rows\x1ftrue\n")

    entries = load_catalog()
    mru = load_mru()
    entries.sort(key=lambda e: (-mru.get(e["path"], 0), e["name"].casefold()))

    out_lines = []
    for e in entries:
        display = f"{e['glyph']}  {pango_escape(e['name'])}"
        out_lines.append(f"{display}\0info\x1f{e['path']}\x1fmeta\x1f{e['meta']}\n")
    sys.stdout.write("".join(out_lines))


if __name__ == "__main__":
    main()
PY
