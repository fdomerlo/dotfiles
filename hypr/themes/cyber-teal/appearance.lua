-- ==============================================================================
-- Apariencia, animaciones e input base (Look & Feel PikaOS / Cyber-Teal)
-- ==============================================================================

local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 6,
        border_size = 2,
        col = {
            -- Borde activo oficial de PikaOS: degradado Cyan -> Cyber Blue -> Purple
            active_border = {
                colors = { "rgba(0db7d4ff)", "rgba(7aa2f7ff)", "rgba(9778d0ff)" },
                angle  = 45,
            },
            inactive_border = "rgba(04404aaa)",
        },
        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = true,
    },

    decoration = {
        rounding         = 8,
        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled        = true,
            range          = 20,
            render_power   = 3,
            offset         = { 0, 6 },
            color          = "rgba(1a1a1acc)",
            color_inactive = "rgba(1a1a1a99)",
        },

        blur = {
            enabled    = true,
            size       = 3,
            passes     = 3,
            noise      = 0.01,
            contrast   = 1.5,
            brightness = 1.0,
            vibrancy   = 0.2,
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

-- Curva Bézier oficial de PikaOS: fluent_decel
hl.curve("fluent_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })

hl.animation({ leaf = "windows",          enabled = true, speed = 4, bezier = "fluent_decel", style = "slide" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4, bezier = "fluent_decel", style = "slide" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4, bezier = "fluent_decel" })
hl.animation({ leaf = "fade",             enabled = true, speed = 4, bezier = "fluent_decel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "fluent_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "fluent_decel", style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true, speed = 5, bezier = "fluent_decel", style = "fade" })

-- Pulido visual de capas Wayland (glassmorphism y animaciones por superficie)
hl.layer_rule({
    name         = "cyber-teal-waybar",
    match        = { namespace = "^(waybar)$" },
    blur         = true,
    ignore_alpha = 0.2,
    blur_popups  = true,
    animation    = "slide top",
})

hl.layer_rule({
    name         = "cyber-teal-launcher",
    match        = { namespace = "^(launcher|rofi)$" },
    blur         = true,
    ignore_alpha = 0.2,
    dim_around   = true,
    animation    = "popin 88%",
})

hl.layer_rule({
    name         = "cyber-teal-swaync-cc",
    match        = { namespace = "^(swaync-control-center)$" },
    blur         = true,
    ignore_alpha = 0.2,
    animation    = "fade",
})

hl.layer_rule({
    name         = "cyber-teal-swaync-notif",
    match        = { namespace = "^(swaync-notification-window)$" },
    blur         = true,
    ignore_alpha = 0.2,
    animation    = "slide right",
})

hl.layer_rule({
    name         = "cyber-teal-swayosd",
    match        = { namespace = "^(swayosd)$" },
    blur         = true,
    ignore_alpha = 0.2,
    animation    = "popin 90%",
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
