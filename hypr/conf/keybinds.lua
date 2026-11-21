-- ==============================================================================
-- Atajos de teclado (Look & Feel y ergonomía PikaOS). mod = SUPER.
-- ==============================================================================

local mod = "SUPER"
local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

local terminal    = "foot"
local launcher    = scripts .. "/launcher-toggle.sh"
local menuToggle  = scripts .. "/toggle-menu.sh"
local fileManager = "nautilus"
local browser     = scripts .. "/browser.sh"
local editor      = scripts .. "/editor.sh"

-- Aplicaciones principales
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal .. " -e tmux new-session -A -s main"))

-- Un solo toque de Super (o Super+D / Super+Space) abre el Centro Unificado (Rofi 2.0).
hl.bind("Super_L", hl.dsp.exec_cmd(launcher), { release = true })
hl.bind(mod .. " + D", hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(launcher))

-- Overview / selector rápido de ventanas y workspaces (Rofi 2.0 + hyprctl)
hl.bind(mod .. " + A", hl.dsp.exec_cmd(scripts .. "/overview-toggle.sh"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + Y", hl.dsp.exec_cmd(scripts .. "/tui-float.sh yazi"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + C", hl.dsp.exec_cmd(editor))
hl.bind(mod .. " + W", hl.dsp.exec_cmd(scripts .. "/wallpaper.sh --next"))

-- Búsqueda y acciones rápidas
-- Calculadora: "C" de calculadora. No se usa "=" porque en latam/es se escribe
-- con Shift+0, que es justamente "mover ventana al workspace 10".
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind(mod .. " + CTRL + F", hl.dsp.exec_cmd(menuToggle .. " 'Archivo:' " .. scripts .. "/file-search.sh"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(scripts .. "/color-picker.sh"))
hl.bind(mod .. " + CTRL + O", hl.dsp.exec_cmd(scripts .. "/ocr-region.sh"))

-- IA integrada (OpenCode): menú de acciones, TUI directa y explicación del portapapeles.
-- Se usa "I" (de IA) en lugar de "O": las letras existen en cualquier layout y
-- no comparten tecla física con los dígitos de workspace.
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd(scripts .. "/ai.sh menu"))
hl.bind(mod .. " + SHIFT + I", hl.dsp.exec_cmd(scripts .. "/ai.sh open"))
hl.bind(mod .. " + CTRL + I", hl.dsp.exec_cmd(scripts .. "/ai.sh explain"))

-- Intercambiador de temas (Cyber-Teal / Cyber-Teal Light).
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(menuToggle .. " 'Temas' " .. scripts .. "/theme-switch.sh menu"))

-- Descubrimiento: cheatsheet de atajos activos.
-- En latam "/" es Shift+7 y colisiona con mover ventana a workspace 7; usamos F1.
hl.bind(mod .. " + F1", hl.dsp.exec_cmd(menuToggle .. " 'Atajos' " .. scripts .. "/keybinds.sh"))

-- Gestión de ventanas
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + S", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd(menuToggle .. " 'Sistema:' " .. scripts .. "/powermenu.sh"))
hl.bind(mod .. " + Escape", hl.dsp.reload_config())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + V", hl.dsp.exec_cmd(menuToggle .. " 'Portapapeles' " .. scripts .. "/clipboard.sh"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(menuToggle .. " 'Portapapeles' " .. scripts .. "/clipboard.sh"))

-- Cambio de ventanas estilo GNOME
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
-- Alternar entre la ventana actual y la anterior. No se usa grave/backtick
-- porque su keysym cambia por layout (latam: "|", es: "º", us: "`").
hl.bind(mod .. " + CTRL + Tab", hl.dsp.focus({ last = true }))

-- Scratchpad (terminal flotante persistente).
-- No se usa la tecla grave/backtick: en latam produce "|" y "°", en es "º" y
-- en us "`" y "~", así que su keysym cambia por layout. "S" de scratchpad es
-- genérico y no colisiona con ningún workspace.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(scripts .. "/scratchpad.sh"))
hl.bind(mod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic", follow = false }))

-- Grupos de ventanas (tabs dentro de una misma ventana)
hl.bind(mod .. " + G", hl.dsp.group.toggle())
hl.bind(mod .. " + Tab", hl.dsp.group.next())
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.group.prev())
hl.bind(mod .. " + CTRL + G", hl.dsp.window.move({ into_group = "left" }))
hl.bind(mod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))

-- Notificaciones (swaync)
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -d -sw"))

-- Luz nocturna (filtro de luz azul de hyprsunset)
hl.bind(mod .. " + CTRL + N", hl.dsp.exec_cmd(scripts .. "/nightlight-toggle.sh"))

-- Capturas de pantalla (Print abre swappy para anotar; Ctrl+Print copia directo)
hl.bind("Print", hl.dsp.exec_cmd(scripts .. "/screenshot-region.sh"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd(scripts .. "/screenshot-region.sh --raw"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/screenshot-full.sh"))

-- Grabación de pantalla (alterna inicio/parada; el indicador aparece en Waybar)
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(scripts .. "/screen-record.sh"))

-- Workspaces (fila numérica, teclado numérico con y sin NumLock)
-- Mover ventana sin seguirla (equivalente a GNOME: follow = false).
local kp_nolock = {
    "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin",
    "KP_Right", "KP_Home", "KP_Up", "KP_Prior", "KP_Insert",
}

for i = 1, 10 do
    local digit = tostring(i % 10) -- 10 -> "0"
    local kp_num = "KP_" .. digit
    local kp_nav = kp_nolock[i]

    hl.bind(mod .. " + " .. digit,  hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + " .. kp_num, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + " .. kp_nav, hl.dsp.focus({ workspace = i }))

    hl.bind(mod .. " + SHIFT + " .. digit,  hl.dsp.window.move({ workspace = i, follow = false }))
    hl.bind(mod .. " + SHIFT + " .. kp_num, hl.dsp.window.move({ workspace = i, follow = false }))
    hl.bind(mod .. " + SHIFT + " .. kp_nav, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Ciclo de workspaces entre monitores (con wrap global: 1..N*5).
-- Page_Down/Page_Up recorren los workspaces cubriendo todos los monitores.
hl.bind(mod .. " + Page_Down", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh next"))
hl.bind(mod .. " + Page_Up", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh prev"))
hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh next --move"))
hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh prev --move"))

-- Foco de ventanas (flechas y vim-keys; Super+L se reserva para hyprlock)
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + h",     hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + k",     hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + j",     hl.dsp.focus({ direction = "down" }))

-- Mover ventanas
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Redimensionar
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

-- Movimiento y redimensionado con mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Audio (OSD de swayosd; respaldo directo con wpctl si no está disponible)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/osd.sh volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/osd.sh volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(scripts .. "/osd.sh volume mute"),  { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(scripts .. "/osd.sh mic mute"),     { locked = true })

-- Brillo (OSD de swayosd; respaldo directo con brightnessctl)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/osd.sh brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/osd.sh brightness lower"), { locked = true, repeating = true })

-- Controles Multimedia
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"),       { locked = true })
