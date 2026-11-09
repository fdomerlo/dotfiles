#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Ejecutá este script como usuario normal (sin sudo)." >&2
    exit 1
fi

gsettings_set_if_needed() {
    local schema="$1" key="$2" expected="$3" raw="$4"
    local current
    current="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    if [[ "$current" != "$expected" ]]; then
        gsettings set "$schema" "$key" "$raw" 2>/dev/null || true
    fi
}

echo "================================================================="
echo "==> Configurando entorno de escritorio GNOME (Fuentes y Extensiones)"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Configuración de Tipografías
# ------------------------------------------------------------------------------
echo "==> Aplicando configuración de fuentes..."

# Asegurar instalación de fuentes oficiales de Debian si están disponibles y faltan
DEB_FONTS=(fonts-jetbrains-mono fonts-firacode fonts-noto-core)
MISSING_FONTS=()
for fpkg in "${DEB_FONTS[@]}"; do
    if ! dpkg -s "$fpkg" &>/dev/null; then
        MISSING_FONTS+=("$fpkg")
    fi
done

if [ "${#MISSING_FONTS[@]}" -gt 0 ] && command -v apt-get &>/dev/null; then
    if sudo -n true 2>/dev/null; then
        echo "==> Instalando fuentes de Debian oficiales: ${MISSING_FONTS[*]}..."
        sudo apt-get install -y "${MISSING_FONTS[@]}" || true
    fi
fi

# Adwaita Sans (fuente de interfaz GNOME moderna, provista desde upstream oficial al no estar en repos de Debian)
FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list : family 2>/dev/null | grep -qi "Adwaita Sans"; then
    echo "==> Descargando fuente oficial Adwaita Sans (GNOME)..."
    mkdir -p "$FONT_DIR"
    ADWAITA_BASE_URL="https://raw.githubusercontent.com/gnome/adwaita-fonts/main/sans"
    curl -fsSL -o "$FONT_DIR/AdwaitaSans-Regular.ttf" "$ADWAITA_BASE_URL/AdwaitaSans-Regular.ttf" || true
    curl -fsSL -o "$FONT_DIR/AdwaitaSans-Italic.ttf" "$ADWAITA_BASE_URL/AdwaitaSans-Italic.ttf" || true
    fc-cache -f "$FONT_DIR" 2>/dev/null || true
fi

# Interfaz: Adwaita Sans 11 (la predeterminada del sistema, legibilidad limpia y descansada)
gsettings_set_if_needed org.gnome.desktop.interface font-name "'Adwaita Sans 11'" "Adwaita Sans 11"

# Documentos: Noto Sans Regular 12
gsettings_set_if_needed org.gnome.desktop.interface document-font-name "'Noto Sans 12'" "Noto Sans 12"

# Monoespaciada: JetBrains Mono 11 (óptima legibilidad, ligaduras y descanso visual)
gsettings_set_if_needed org.gnome.desktop.interface monospace-font-name "'JetBrains Mono 11'" "JetBrains Mono 11"

# Título de ventanas
gsettings_set_if_needed org.gnome.desktop.wm.preferences titlebar-font "'Adwaita Sans Bold 11'" "Adwaita Sans Bold 11"

# Modo oscuro predeterminado
gsettings_set_if_needed org.gnome.desktop.interface color-scheme "'prefer-dark'" "prefer-dark"
gsettings_set_if_needed org.gnome.desktop.interface gtk-theme "'Adwaita-dark'" "Adwaita-dark"

echo "    ✔ Interfaz:     $(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo 'N/A')"
echo "    ✔ Documentos:   $(gsettings get org.gnome.desktop.interface document-font-name 2>/dev/null || echo 'N/A')"
echo "    ✔ Monoespacio:  $(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null || echo 'N/A')"

# ------------------------------------------------------------------------------
# 2. Configuración de Ventanas (Botones minimizar, maximizar y cerrar)
# ------------------------------------------------------------------------------
echo "==> Configurando botones de ventana (minimizar, maximizar, cerrar)..."
gsettings_set_if_needed org.gnome.desktop.wm.preferences button-layout "'appmenu:minimize,maximize,close'" "appmenu:minimize,maximize,close"
echo "    ✔ Botones:      $(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || echo 'N/A')"

# ------------------------------------------------------------------------------
# 3. Directorios Dedicados (Proyectos y Aplicaciones / AppImages)
# ------------------------------------------------------------------------------
echo "==> Configurando directorios de Proyectos y Aplicaciones (AppImages)..."
PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/Proyectos}"
mkdir -p "$PROJECTS_DIR"

APPIMAGE_DIR="${XDG_APPLICATIONS_DIR:-$HOME/Aplicaciones}"
mkdir -p "$APPIMAGE_DIR"

if command -v xdg-user-dirs-update &>/dev/null; then
    xdg-user-dirs-update --set PROJECTS "$PROJECTS_DIR" 2>/dev/null || true
fi

USER_DIRS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
if [ -f "$USER_DIRS_CONF" ]; then
    if ! grep -q "^XDG_PROJECTS_DIR=" "$USER_DIRS_CONF"; then
        echo "XDG_PROJECTS_DIR=\"$PROJECTS_DIR\"" >> "$USER_DIRS_CONF"
    fi
fi
echo "    ✔ Directorio de proyectos: $PROJECTS_DIR"
echo "    ✔ Directorio de aplicaciones: $APPIMAGE_DIR"

# ------------------------------------------------------------------------------
# 4. Deshabilitar validación estricta de versión de extensiones en GNOME
# ------------------------------------------------------------------------------
gsettings_set_if_needed org.gnome.shell disable-extension-version-validation "true" "true"

# ------------------------------------------------------------------------------
# 5. Instalación de Extensiones
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

# 3) Dash to Dock (paquete oficial gnome-shell-extension-dashtodock en Debian)
install_extension "dash-to-dock@micxgx.gmail.com" "gnome-shell-extension-dashtodock"

# 4) Tiling Assistant de LelEat (reemplaza a Tiling Shell)
install_extension "tiling-assistant@leleat-on-github" ""

# ------------------------------------------------------------------------------
# 6. Habilitar extensiones requeridas en GNOME
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
    "tiling-assistant@leleat-on-github"
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

# Tiling Shell fue reemplazada por Tiling Assistant: sacarla de la lista
if "tilingshell@ferrarodomenico.com" in updated:
    updated.remove("tilingshell@ferrarodomenico.com")

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
gnome-extensions disable "tilingshell@ferrarodomenico.com" 2>/dev/null || true

# Purgar resto de Tiling Shell en user-space para evitar conflictos con Tiling Assistant
if [ -d "$USER_EXT_DIR/tilingshell@ferrarodomenico.com" ]; then
    echo "  Eliminando extensión reemplazada: tilingshell@ferrarodomenico.com..."
    rm -rf "$USER_EXT_DIR/tilingshell@ferrarodomenico.com"
fi

for uuid in "AlphabeticalAppGrid@stuarthayhurst" "Vitals@CoreCoding.com" "dash-to-dock@micxgx.gmail.com" "tiling-assistant@leleat-on-github"; do
    gnome-extensions enable "$uuid" 2>/dev/null || true
done

echo "==> Estado actual de extensiones habilitadas:"
gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true

echo "================================================================="
echo "✔ Configuración de escritorio GNOME y fuentes completada."
echo "================================================================="
