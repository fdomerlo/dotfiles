-- ==============================================================================
-- Hyprland 0.57+ (Lua) - Escritorio principal para Debian Forky
-- (GNOME estándar como fallback en GDM).
-- ==============================================================================
-- Este archivo se enlaza en ~/.config/hypr/hyprland.lua por `make hyprland`.
-- La configuración está separada en conf/ para facilitar ajustes por equipo.
-- Se usa `dofile` (en lugar de `require`) para que `hyprctl reload` y
-- `theme-switch.sh` re-evalúen todos los módulos sin caché de `package.loaded`.

local home = os.getenv("HOME") or ""
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
    config_home = home .. "/.config"
end
local conf_dir = config_home .. "/hypr/conf"

local function load_optional(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end

dofile(conf_dir .. "/env.lua")
dofile(conf_dir .. "/monitors.lua")
dofile(conf_dir .. "/workspaces.lua")
dofile(conf_dir .. "/appearance.lua")
dofile(conf_dir .. "/keybinds.lua")
dofile(conf_dir .. "/windowrules.lua")
dofile(conf_dir .. "/plugins.lua")
dofile(conf_dir .. "/autostart.lua")

-- Overrides locales por máquina (no versionado; sembrado según perfil desktop/laptop).
load_optional(conf_dir .. "/local.lua")
