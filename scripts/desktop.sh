#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Configurando entorno de escritorio GNOME (Fuentes y Extensiones)"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Configuración de Tipografías
# ------------------------------------------------------------------------------
echo "==> Aplicando configuración de fuentes..."

# Interfaces: Adwaita Sans o Google Sans si está presente
if fc-list : family | grep -iq "Google Sans"; then
    gsettings set org.gnome.desktop.interface font-name 'Google Sans 11' || true
else
    gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11' || true
fi

# Documentos: Noto Sans Regular 12
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 12' || true

# Monoespaciada: Google Sans Code o Fira Code
if fc-list : family | grep -iq "Google Sans Code"; then
    gsettings set org.gnome.desktop.interface monospace-font-name 'Google Sans Code 11' || true
else
    gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code 11' || true
fi

# Título de ventanas
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11' 2>/dev/null || true

echo "    ✔ Interfaz:     $(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo 'N/A')"
echo "    ✔ Documentos:   $(gsettings get org.gnome.desktop.interface document-font-name 2>/dev/null || echo 'N/A')"
echo "    ✔ Monoespacio:  $(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null || echo 'N/A')"

# ------------------------------------------------------------------------------
# 2. Deshabilitar validación estricta de versión de extensiones en GNOME
# ------------------------------------------------------------------------------
gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Instalación de Extensiones
# ------------------------------------------------------------------------------
USER_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SYS_EXT_DIR="/usr/share/gnome-shell/extensions"
mkdir -p "$USER_EXT_DIR"

GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+' | head -1 || echo "47")
echo "==> Versión detectada de GNOME Shell: $GNOME_VER"

install_extension() {
    local uuid="$1"
    local deb_pkg="${2:-}"

    echo "--> Procesando extensión: $uuid"

    # 1. Verificar si ya está instalada a nivel sistema o usuario
    if [ -d "$SYS_EXT_DIR/$uuid" ] || [ -d "$USER_EXT_DIR/$uuid" ]; then
        echo "    ✔ Ya instalada en el sistema o directorio de usuario."
        return 0
    fi

    # 2. Si hay paquete Debian oficial y apt disponible
    if [ -n "$deb_pkg" ] && command -v apt-get &>/dev/null; then
        if dpkg -s "$deb_pkg" &>/dev/null; then
            echo "    ✔ Paquete Debian $deb_pkg ya instalado."
            return 0
        elif sudo -n true 2>/dev/null; then
            echo "    Instalando paquete Debian del sistema: $deb_pkg..."
            if sudo apt-get install -y "$deb_pkg"; then
                echo "    ✔ Instalado exitosamente vía APT."
                return 0
            fi
        fi
    fi

    # 3. Descarga desde la API oficial de extensions.gnome.org
    echo "    Descargando desde extensions.gnome.org..."
    local info_json
    info_json=$(curl -sL "https://extensions.gnome.org/extension-info/?uuid=${uuid}" 2>/dev/null || echo "{}")

    local pk
    pk=$(echo "$info_json" | jq -r '
        .shell_version_map as $map |
        if $map == null then
            empty
        else
            ($map["'"${GNOME_VER}"'"].pk // ($map | to_entries | max_by(.value.version).value.pk))
        end
    ' 2>/dev/null || true)

    if [ -z "$pk" ] || [ "$pk" = "null" ]; then
        echo "    ⚠️ No se pudo obtener información de versión para $uuid desde la API de GNOME."
        return 1
    fi

    local tmp_zip="/tmp/${uuid}.shell-extension.zip"
    echo "    Descargando paquete (version tag: $pk)..."
    curl -sL "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${pk}" -o "$tmp_zip"

    local target_dir="$USER_EXT_DIR/$uuid"
    mkdir -p "$target_dir"
    unzip -oq "$tmp_zip" -d "$target_dir"
    rm -f "$tmp_zip"

    # Compilar esquemas si están presentes
    if [ -d "$target_dir/schemas" ] && command -v glib-compile-schemas &>/dev/null; then
        glib-compile-schemas "$target_dir/schemas" 2>/dev/null || true
    fi

    # Asegurar que la versión actual de GNOME esté listada en metadata.json
    local metadata="$target_dir/metadata.json"
    if [ -f "$metadata" ] && command -v jq &>/dev/null; then
        if ! jq -e '.["shell-version"] | index("'"${GNOME_VER}"'")' "$metadata" >/dev/null 2>&1; then
            jq '.["shell-version"] += ["'"${GNOME_VER}"'"]' "$metadata" > "${metadata}.tmp" && \
            mv "${metadata}.tmp" "$metadata"
        fi
    fi

    echo "    ✔ Extensión $uuid instalada correctamente en $target_dir"
}

# 1) Alphabetical App Grid
install_extension "AlphabeticalAppGrid@stuarthayhurst" ""

# 2) Vitals
install_extension "Vitals@CoreCoding.com" ""

# 3) Dash to Dock (paquete oficial gnome-shell-extension-dash-to-dock en Debian)
install_extension "dash-to-dock@micxgx.gmail.com" "gnome-shell-extension-dash-to-dock"

# 4) Tiling Shell
install_extension "tilingshell@ferrarodomenico.com" ""

# ------------------------------------------------------------------------------
# 4. Habilitar extensiones requeridas en GNOME
# ------------------------------------------------------------------------------
echo "==> Habilitando extensiones requeridas..."

python3 - << 'EOF'
import ast
import subprocess
import sys

schema = "org.gnome.shell"
key = "enabled-extensions"
required = [
    "AlphabeticalAppGrid@stuarthayhurst",
    "Vitals@CoreCoding.com",
    "dash-to-dock@micxgx.gmail.com",
    "tilingshell@ferrarodomenico.com"
]

try:
    proc = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True, check=True)
    val = proc.stdout.strip()
    current = ast.literal_eval(val) if val else []
    if not isinstance(current, list):
        current = []
except Exception:
    current = []

updated = list(current)

if "pop-shell@system76.com" in updated:
    updated.remove("pop-shell@system76.com")

for ext in required:
    if ext not in updated:
        updated.append(ext)

if updated != current:
    val_str = str(updated)
    subprocess.run(["gsettings", "set", schema, key, val_str], check=True)
    print(f"    ✔ Lista de extensiones habilitadas actualizada en GSettings.")
else:
    print(f"    ✔ Todas las extensiones ya estaban registradas en GSettings.")
EOF

gnome-extensions disable "pop-shell@system76.com" 2>/dev/null || true

for uuid in "AlphabeticalAppGrid@stuarthayhurst" "Vitals@CoreCoding.com" "dash-to-dock@micxgx.gmail.com" "tilingshell@ferrarodomenico.com"; do
    gnome-extensions enable "$uuid" 2>/dev/null || true
done

echo "==> Estado actual de extensiones habilitadas:"
gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true

echo "================================================================="
echo "✔ Configuración de escritorio GNOME y fuentes completada."
echo "================================================================="
