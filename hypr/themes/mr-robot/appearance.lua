-- ==============================================================================
-- Apariencia, animaciones e input base (Mr. Robot / fsociety)
-- ==============================================================================

local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 2,
        col = {
            -- Acero fino; el rojo se reserva para alertas en la UI.
            -- El foco se marca solo con el borde: activo brillante, inactivo oscuro.
            active_border   = "rgba(7dc8f0ff)",
            inactive_border = "rgba(1a2a33ff)",
        },
        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = true,
    },

    decoration = {
        rounding = 2,
        -- Transparencia pareja para todas las ventanas, tengan o no foco.
        -- El foco se identifica solo por el color del borde.
        active_opacity   = 0.95,
        inactive_opacity = 0.95,
        dim_inactive     = false,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        smart_resizing = true,
    },

    misc = {
        vrr                          = 1,
        force_default_wallpaper      = 0,
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        focus_on_activate            = true,
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,
        -- XDG_CURRENT_DESKTOP se define como "Hyprland:GNOME" en env.lua (intencional,
        -- para los portales de GNOME). Esto silencia el aviso de "gestionado externamente".
        disable_xdg_env_checks       = true,
    },

    input = {
        kb_layout  = "latam",
        kb_variant = "",
        kb_model   = "pc105",
        kb_options = "",
        -- NumLock encendido al iniciar la sesión (workspaces con el teclado numérico).
        numlock_by_default = true,
        -- Foco "loose": el puntero hace hover y scroll en la ventana bajo el cursor,
        -- pero el foco de teclado solo cambia al hacer clic. Evita que los modales y
        -- menús (DBeaver, fuzzel, rofi, diálogos XWayland) se cierren al mover el mouse.
        -- float_switch_override_focus=0 impide el refoco forzado al cruzar entre una
        -- ventana flotante (modal) y una en mosaico.
        follow_mouse                = 2,
        float_switch_override_focus = 0,
        sensitivity                 = 0,

        touchpad = {
            natural_scroll          = true,
            tap_to_click            = true,
            tap_and_drag            = true,
            clickfinger_behavior    = true,
            disable_while_typing    = true,
            middle_button_emulation = false,
        },
    },

    gestures = {
        workspace_swipe_distance                 = 300,
        workspace_swipe_invert                   = true,
        workspace_swipe_min_speed_to_force       = 30,
        workspace_swipe_cancel_ratio             = 0.5,
        workspace_swipe_create_new               = true,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_forever                  = true,
    },

    cursor = {
        -- Deshabilita cursores por hardware: evita el flickeo del puntero en setups multi-GPU o salidas en NVIDIA/Nouveau
        no_hardware_cursors  = true,
        -- Evita que Hyprland sobreescriba el tema de cursor de GNOME en GSettings/dconf al volver a GNOME.
        sync_gsettings_theme = false,
    },
})

-- Movimiento corto y seco, estilo terminal.
hl.curve("terminal", { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.0 } } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3, bezier = "terminal", style = "slide" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3, bezier = "terminal", style = "slide" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 3, bezier = "terminal" })
hl.animation({ leaf = "fade",             enabled = true, speed = 3, bezier = "terminal" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4, bezier = "terminal", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "terminal", style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true, speed = 3, bezier = "terminal", style = "fade" })

-- Smart Gaps ("no gaps when only"): exclusivo de mr-robot para encajar con su
-- Waybar de borde a borde. Elimina márgenes, bordes y esquinas redondeadas con
-- una sola ventana visible en tiling (w[tv1]) o maximizada (f[1]).
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.window_rule({
    name        = "no-gaps-wtv1",
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name        = "no-gaps-f1",
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- Capas Wayland: transiciones limpias acordes al estilo terminal sin blur
hl.layer_rule({
    name      = "mr-robot-waybar",
    match     = { namespace = "^(waybar)$" },
    animation = "slide top",
})

hl.layer_rule({
    name       = "mr-robot-launcher",
    match      = { namespace = "^(launcher|rofi)$" },
    dim_around = true,
    animation  = "popin 94%",
})

hl.layer_rule({
    name      = "mr-robot-swaync-cc",
    match     = { namespace = "^(swaync-control-center)$" },
    animation = "fade",
})

hl.layer_rule({
    name      = "mr-robot-swaync-notif",
    match     = { namespace = "^(swaync-notification-window)$" },
    animation = "slide right",
})

hl.layer_rule({
    name      = "mr-robot-swayosd",
    match     = { namespace = "^(swayosd)$" },
    animation = "popin 94%",
})

-- Gestos Touchpad estilo GNOME (Hyprland 0.57+)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = function()
        hl.exec_cmd(scripts .. "/launcher-toggle.sh")
    end,
})
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function()
        hl.exec_cmd(scripts .. "/overview-toggle.sh")
    end,
})
