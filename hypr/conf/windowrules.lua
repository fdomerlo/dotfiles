-- ==============================================================================
-- Reglas de ventanas y optimizaciones gaming (Look & Feel PikaOS).
-- Sintaxis Lua nativa de Hyprland 0.57+.
-- ==============================================================================

-- Waybar debe quedar por encima del panel de swaync (mismo nivel "top").
-- Sin esto, la superficie a pantalla completa del panel tapa la barra y sus
-- clics no llegan a Waybar mientras el centro de notificaciones está abierto.
hl.layer_rule({
    name  = "waybar-above-swaync",
    match = { namespace = "^(waybar)$" },
    order = -1,
})

-- Diálogos y paneles de configuración flotantes
hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
    size  = { 900, 600 },
})

hl.window_rule({
    name  = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    size  = { 900, 600 },
})

hl.window_rule({
    name  = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
    size  = { 900, 600 },
})

hl.window_rule({
    name  = "float-seahorse",
    match = { class = "^(org\\.gnome\\.seahorse\\.Application|seahorse)$" },
    float = true,
    size  = { 950, 620 },
})

hl.window_rule({
    name   = "float-calculator",
    match  = { class = "^(org\\.gnome\\.Calculator|gnome-calculator)$" },
    float  = true,
    center = true,
    size   = { 420, 560 },
})

hl.window_rule({
    name   = "float-hyprpolkitagent",
    match  = { class = "^(hyprpolkitagent)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-swappy",
    match  = { class = "^(swappy)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "float-archivers",
    match = { class = "^(file-roller|ark)$" },
    float = true,
})

-- TUIs modales flotantes y centradas (lazydocker, yazi dedicado).
-- btop queda fuera a propósito: es un dashboard y se lee mejor tileado
-- (se lanza sin --app-id, así hereda la clase «foot» y entra en tiling).
-- El tamaño lo aplica tui-float.sh con --window-size-pixels; size queda como fallback.
hl.window_rule({
    name       = "modal-tui-float",
    match      = { class = "^(tui-float)$" },
    float      = true,
    center     = true,
    size       = { "monitor_w * 0.85", "monitor_h * 0.85" },
    dim_around = true,
})

-- Ventanas modales de IA (hypr/scripts/ai.sh con footclient --app-id=ai-float).
hl.window_rule({
    name       = "modal-ai-float",
    match      = { class = "^(ai-float)$" },
    float      = true,
    center     = true,
    size       = { "monitor_w * 0.72", "monitor_h * 0.72" },
    dim_around = true,
})

-- Scratchpad: terminal flotante en el workspace especial "magic"
hl.window_rule({
    name      = "scratchpad-magic",
    match     = { class = "^(scratchpad)$" },
    workspace = "special:magic silent",
    float     = true,
    size      = { 1000, 600 },
    center    = true,
})

-- Reglas Gaming (PikaOS: Steam, Gamescope, juegos nativos y Proton)
-- Sin idle_inhibit automático: el único inhibidor del ciclo de energía es el
-- botón idle_inhibitor en Waybar.
hl.window_rule({
    name  = "gaming-steamwebhelper",
    match = { class = "^(steamwebhelper)$" },
    float = true,
})

hl.window_rule({
    name  = "gaming-friends-list",
    match = { title = "^(Friends List)$" },
    float = true,
})

hl.window_rule({
    name       = "gaming-steam-app",
    match      = { class = "^(steam_app_.*)$" },
    fullscreen = true,
    immediate  = true,
})

-- Picture-in-Picture
hl.window_rule({
    name  = "pip-floating",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    size  = { 480, 270 },
})

-- Reglas de Web Apps (PWAs) generadas localmente por webapp-install.sh (no versionado)
local home = os.getenv("HOME") or ""
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
    config_home = home .. "/.config"
end
local webapps_lua = config_home .. "/hypr/conf/webapps.lua"
local wf = io.open(webapps_lua, "r")
if wf then
    wf:close()
    dofile(webapps_lua)
end
