-- Entorno de la sesión Hyprland.
-- Cursor único en Hyprland, XWayland, GTK y Qt: Bibata-Modern-Classic 24 px
-- (paquete Debian `bibata-cursor-theme`).

local home = os.getenv("HOME") or ""
local cur_path = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"

hl.env("PATH", home .. "/.local/bin:" .. home .. "/.opencode/bin:" .. home .. "/.local/share/fnm:" .. cur_path)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland:GNOME")
hl.env("XDG_DATA_DIRS", home .. "/.local/share:" .. home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share/:/usr/share/")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- No se fija GTK_THEME: es una variable de depuración que solo heredan las apps
-- lanzadas desde Hyprland (no las de systemd/portales ni siempre las Flatpak) y
-- hace que cada vía resuelva el tema distinto. El tema y fuentes se definen en
-- session-gsettings.sh (portales/libadwaita) y en gtk-3.0/gtk-4.0 settings.ini.
