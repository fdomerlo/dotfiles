#!/usr/bin/env bash
# ==============================================================================
# Refresca la configuración de Hyprland desde el repo, sin instalar paquetes.
#
# Re-enlaza los mismos destinos que scripts/hyprland.sh en ~/.config, elimina
# symlinks rotos que apunten al repo y, si hay una sesión Hyprland activa,
# recarga Hyprland, Waybar, Quickshell, swaync e hypridle.
#
# Uso:
#   make refresh
#   bash scripts/hyprland-refresh.sh [--no-reload]
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR_SRC="$REPO_DIR/hypr"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d%H%M%S)"

NO_RELOAD=0
case "${1:-}" in
    --no-reload) NO_RELOAD=1 ;;
    "") ;;
    *) echo "Uso: $0 [--no-reload]" >&2; exit 2 ;;
esac

ok()  { echo "  ✔ $*"; }
warn(){ echo "  ⚠ $*"; }

# Si el perfil nunca se instaló acá, no crear configs sueltas en ~/.config.
if ! command -v hyprctl >/dev/null 2>&1 && [ ! -e "$CONFIG_HOME/hypr/hyprland.conf" ]; then
    echo "Hyprland no está instalado en este equipo; nada que refrescar."
    exit 0
fi

echo "================================================================="
echo "==> Refrescando configuración de Hyprland"
echo "================================================================="

# El tema activo es estado runtime (gitignored); asegurar que exista.
THEMES_DIR="$HYPR_SRC/themes"
ACTIVE_THEME_LINK="$THEMES_DIR/active"
if [ ! -d "$ACTIVE_THEME_LINK" ]; then
    ln -sfn mr-robot "$ACTIVE_THEME_LINK"
    warn "Tema activo ausente; se configuró mr-robot por defecto."
fi

link_file() {
    local src="$1" dest="$2"
    local src_real dest_real

    [ -e "$src" ] || { warn "falta en el repo: ${src#"$REPO_DIR"/}"; return 0; }

    mkdir -p "$(dirname "$dest")"
    src_real="$(readlink -f -- "$src" 2>/dev/null || true)"
    dest_real="$(readlink -f -- "$dest" 2>/dev/null || true)"
    if [ -L "$dest" ] && [ -n "$dest_real" ] && [ "$dest_real" = "$src_real" ]; then
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mv "$dest" "$dest.bak.$STAMP"
        warn "backup: $dest"
    fi
    ln -s "$src" "$dest"
    ok "$dest"
}

link_file "$HYPR_SRC/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
for f in "$HYPR_SRC"/conf/*.conf; do
    [ "$(basename "$f")" = "local.conf" ] && continue
    link_file "$f" "$CONFIG_HOME/hypr/conf/$(basename "$f")"
done

LOCAL_CONF="$CONFIG_HOME/hypr/conf/local.conf"
if [ ! -e "$LOCAL_CONF" ] && [ ! -L "$LOCAL_CONF" ]; then
    mkdir -p "$(dirname "$LOCAL_CONF")"
    cat >"$LOCAL_CONF" <<'EOF'
# ==============================================================================
# Overrides locales por máquina (no versionado).
# Se carga al final de hyprland.conf; sirve para monitores, sensibilidad o
# variables específicas de este equipo sin ensuciar el repositorio.
# ==============================================================================
EOF
    ok "$LOCAL_CONF (plantilla local)"
fi

for f in "$HYPR_SRC"/hypridle.conf "$HYPR_SRC"/hyprlock.conf; do
    link_file "$f" "$CONFIG_HOME/hypr/$(basename "$f")"
done
for f in "$HYPR_SRC"/scripts/*.sh; do
    link_file "$f" "$CONFIG_HOME/hypr/scripts/$(basename "$f")"
done
for f in "$HYPR_SRC"/waybar/*; do
    link_file "$f" "$CONFIG_HOME/waybar/$(basename "$f")"
done
for f in "$HYPR_SRC"/fuzzel/*; do
    link_file "$f" "$CONFIG_HOME/fuzzel/$(basename "$f")"
done
for f in "$HYPR_SRC"/foot/*; do
    link_file "$f" "$CONFIG_HOME/foot/$(basename "$f")"
done
for f in "$HYPR_SRC"/swappy/*; do
    link_file "$f" "$CONFIG_HOME/swappy/$(basename "$f")"
done
for f in "$HYPR_SRC"/swaync/*; do
    link_file "$f" "$CONFIG_HOME/swaync/$(basename "$f")"
done
for f in "$HYPR_SRC"/quickshell/*; do
    link_file "$f" "$CONFIG_HOME/quickshell/$(basename "$f")"
done
link_file "$HYPR_SRC/xdg-desktop-portal/hyprland-portals.conf" "$CONFIG_HOME/xdg-desktop-portal/hyprland-portals.conf"
mkdir -p "$CONFIG_HOME/hypr/wallpapers"
if [ -f "$HYPR_SRC/wallpapers/default.png" ]; then
    link_file "$HYPR_SRC/wallpapers/default.png" "$CONFIG_HOME/hypr/wallpapers/default.png"
fi

# Modo oscuro GTK3/GTK4 y cursor Adwaita. Se converge el valor de las claves
# (no solo se crean si faltan): una instalación previa con «Adwaita-dark» o
# «prefer-dark-theme=0» quedaría con un modelo de tema distinto al actual.
set_gtk_setting() {
    local file="$1" key="$2" value="$3"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        grep -q '^\[Settings\]' "$file" || sed -i '1i [Settings]' "$file"
        sed -i "/^\[Settings\]/a ${key} = ${value}" "$file"
    fi
}

for gtk_ver in gtk-3.0 gtk-4.0; do
    mkdir -p "$CONFIG_HOME/$gtk_ver"
    settings="$CONFIG_HOME/$gtk_ver/settings.ini"
    [ -f "$settings" ] || printf '[Settings]\n' >"$settings"
    set_gtk_setting "$settings" gtk-theme-name Adwaita
    set_gtk_setting "$settings" gtk-application-prefer-dark-theme 1
    set_gtk_setting "$settings" gtk-cursor-theme-name Adwaita
    set_gtk_setting "$settings" gtk-cursor-theme-size 24
done

# Eliminar symlinks rotos que apunten al repo (scripts/configs retirados).
prune_stale_links() {
    local dir link
    for dir in "$CONFIG_HOME/hypr" "$CONFIG_HOME/hypr/conf" "$CONFIG_HOME/hypr/scripts" \
               "$CONFIG_HOME/waybar" "$CONFIG_HOME/fuzzel" "$CONFIG_HOME/foot" \
               "$CONFIG_HOME/swappy" "$CONFIG_HOME/wofi" "$CONFIG_HOME/kitty" \
               "$CONFIG_HOME/mako" "$CONFIG_HOME/swaync" "$CONFIG_HOME/quickshell" \
               "$CONFIG_HOME/xdg-desktop-portal"; do
        [ -d "$dir" ] || continue
        while IFS= read -r -d '' link; do
            rm -f "$link"
            warn "eliminado symlink roto: $link"
        done < <(find "$dir" -maxdepth 1 -type l -lname "$HYPR_SRC/*" -xtype l -print0 2>/dev/null)
    done
}
prune_stale_links

if [ "$NO_RELOAD" = "1" ]; then
    echo "✔ Configuración sincronizada (sin recargar la sesión)."
    exit 0
fi

# Recargar solo si hay una sesión Hyprland activa.
if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    # En GNOME no hay Hyprland que recargar, pero el portal debe releer la
    # configuración si se migró portals.conf -> hyprland-portals.conf.
    if printf '%s' "${XDG_CURRENT_DESKTOP:-}" | grep -qi 'gnome' && command -v systemctl >/dev/null 2>&1; then
        systemctl --user restart xdg-desktop-portal.service 2>/dev/null \
            && ok "xdg-desktop-portal reiniciado para la sesión GNOME."
    fi
    echo "✔ Configuración sincronizada. Hyprland no está activo; se aplicará al iniciar sesión."
    exit 0
fi

echo "==> Recargando Hyprland..."
hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload falló."

# Workspaces dinámicos: asegurar que el watcher esté activo y re-aplicar
# antes de reiniciar Waybar para que los workspaces persistentes existan.
if [ -x "$CONFIG_HOME/hypr/scripts/workspaces-init.sh" ]; then
    if ! pgrep -f "workspaces-init.sh.*--watch" >/dev/null 2>&1; then
        setsid "$CONFIG_HOME/hypr/scripts/workspaces-init.sh" --watch >/dev/null 2>&1 </dev/null &
        ok "workspaces-init iniciado en segundo plano (--watch)."
    else
        "$CONFIG_HOME/hypr/scripts/workspaces-init.sh" --once >/dev/null 2>&1 || true
        ok "workspaces-init re-aplicado."
    fi
fi

# Waybar: reiniciar para releer config.jsonc y style.css.
pkill -x waybar 2>/dev/null || true
sleep 0.3
setsid "$CONFIG_HOME/hypr/scripts/start-waybar.sh" >/dev/null 2>&1 </dev/null &
ok "Waybar reiniciado."

# Quickshell: iniciar o reiniciar para releer QML y Theme.qml.
if command -v qs >/dev/null 2>&1; then
    qs kill >/dev/null 2>&1 || true
    pkill -x quickshell 2>/dev/null || true
    sleep 0.2
    setsid qs -n -d >/dev/null 2>&1 </dev/null &
    ok "Quickshell (re)iniciado."
fi

# Notificaciones: recargar config y CSS de swaync.
if pgrep -x swaync >/dev/null 2>&1 && command -v swaync-client >/dev/null 2>&1; then
    swaync-client -R >/dev/null 2>&1 || true
    swaync-client -rs >/dev/null 2>&1 || true
    ok "swaync recargado (config + CSS)."
fi

# hypridle: reiniciar para releer hypridle.conf.
if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null || true
    sleep 0.2
    setsid hypridle >/dev/null 2>&1 </dev/null &
    ok "hypridle reiniciado."
fi

# Mostrar errores de configuración si los hay.
config_errors="$(hyprctl configerrors 2>/dev/null || true)"
if [ -n "$config_errors" ] && ! printf '%s\n' "$config_errors" | grep -qiE '^no errors|config ok'; then
    warn "hyprctl configerrors: $config_errors"
fi

echo "✔ Configuración y sesión refrescadas."
echo "  Nota: hyprlock, foot y fuzzel toman los cambios en su próxima apertura."
