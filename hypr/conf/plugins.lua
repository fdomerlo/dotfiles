-- ==============================================================================
-- Manipulación avanzada con mouse y soporte de plugins (módulo aislado).
-- Cargado desde hyprland.lua antes de local.lua para permitir overrides por
-- estación.
-- ==============================================================================

local mod = "SUPER"
local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

-- 1. Ergonomía nativa de ventanas con mouse (Hyprland 0.57+, sin ABI externo)
hl.config({
    general = {
        resize_on_border        = true,
        extend_border_grab_area = 15,
        hover_icon_on_border    = true,
    },
    binds = {
        -- Evita arrastrar ventanas accidentalmente con toques breves de Super+Click.
        drag_threshold = 10,
    },
})

-- Complementos a los binds base de mouse (Super+Click Izq/Der en keybinds.lua):
-- - Super + Alt + Click Izq: redimensionar (cómodo en touchpads sin botón derecho)
-- - Super + Click Medio:     alternar ventana flotante / mosaico
-- - Super + Rueda:           recorrer workspaces entre monitores
hl.bind(mod .. " + ALT + mouse:272", hl.dsp.window.resize(),                 { mouse = true })
hl.bind(mod .. " + mouse:274",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + mouse_down",      hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh next"))
hl.bind(mod .. " + mouse_up",        hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh prev"))

-- 2. Plugins externos (p. ej. hyprbars):
-- Los plugins C++ quedan deshabilitados por defecto para evitar desfases de ABI
-- entre versiones menores de Hyprland en Testing/Forky. Si se compila o alinea
-- libhyprbars.so para la versión activa, puede cargarse desde conf/local.lua
-- mediante `hl.plugin.load("/ruta/a/libhyprbars.so")`.
