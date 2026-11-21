-- ==============================================================================
-- Perfil local de estación: LAPTOP / NOTEBOOK (plantilla para ~/.config/hypr/conf/local.lua)
-- Cargado al final de hyprland.lua; no está versionado por máquina.
-- ==============================================================================

-- Pantalla integrada de notebook (ajustar escala a 1.25 / 1.5 en paneles HiDPI):
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "0x0",
    scale    = 1,
})

-- Monitor externo opcional encima o a la derecha del panel integrado:
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1 })

-- Cierre de tapa: bloquea de inmediato; systemd-logind (/etc/systemd/logind.conf.d/)
-- ejecuta suspend-then-hibernate al cerrar la tapa (con fallback a suspend).
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("pidof hyprlock || hyprlock --immediate"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.dpms({ action = "enable" }),                        { locked = true })

-- Ajustes opcionales de touchpad para notebook:
-- hl.config({
--     input = {
--         touchpad = {
--             natural_scroll       = true,
--             tap_to_click         = true,
--             disable_while_typing = true,
--         },
--     },
-- })
