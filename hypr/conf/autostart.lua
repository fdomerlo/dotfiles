-- Servicios y aplicaciones que se inician con la sesión.

local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    -- Keyring (secretos/PKCS11, desbloqueado por PAM/GDM) y agente SSH único vía systemd --user.
    -- No se lanza `gnome-keyring-daemon --start` manualmente para evitar procesos duplicados;
    -- systemd ya gestiona gnome-keyring-daemon.service y ssh-agent.socket.
    hl.exec_cmd([[sh -c 'systemctl --user start gnome-keyring-daemon.service ssh-agent.socket >/dev/null 2>&1 || true; if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openssh_agent" ]; then export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openssh_agent"; fi; dbus-update-activation-environment --systemd PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS SSH_AUTH_SOCK QT_QPA_PLATFORMTHEME']])

    -- Servidor de terminal Foot para apertura instantánea (<10 ms)
    hl.exec_cmd([[sh -c 'command -v foot >/dev/null 2>&1 && exec foot --server']])

    -- Ciclo de vida de la sesión systemd: los portales son PartOf de este target.
    -- Iniciarlo en Hyprland y detenerlo al salir evita que un xdg-desktop-portal
    -- con el entorno de Hyprland sobreviva y lo herede la siguiente sesión GNOME.
    hl.exec_cmd("systemctl --user start graphical-session.target")
    hl.exec_cmd(scripts .. "/session-gsettings.sh apply")

    -- Workspaces: 6 por monitor, asignados en caliente según las salidas conectadas
    -- (1-6, 7-12, …). Con --watch se re-aplica al conectar/desconectar un monitor.
    -- Va antes de Waybar para que los workspaces existan cuando la barra conecte.
    hl.exec_cmd(scripts .. "/workspaces-init.sh --watch")

    -- Los iconos se heredan del sistema (GNOME) para mantener consistencia entre sesiones.
    hl.exec_cmd(scripts .. "/start-waybar.sh")

    -- Lanzador Unificado + Overview (Rofi 2.0 Wayland nativo): arranca bajo demanda
    -- con Super / Super+A desde launcher-toggle.sh / overview-toggle.sh (0 MB en reposo).

    -- Centro de notificaciones (swaync) y caché de estado del panel.
    hl.exec_cmd([[sh -c 'command -v swaync >/dev/null 2>&1 && exec swaync']])
    hl.exec_cmd(scripts .. "/swaync-state.sh")

    -- OSD de volumen y brillo (opcional).
    hl.exec_cmd([[sh -c 'command -v swayosd-server >/dev/null 2>&1 && exec swayosd-server']])

    -- Filtro de luz azul (luz nocturna). Arranca neutro; el toggle aplica 4000K.
    hl.exec_cmd([[sh -c 'command -v hyprsunset >/dev/null 2>&1 && exec hyprsunset -t 6500']])

    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd(scripts .. "/wallpaper.sh --daemon")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Red y Bluetooth viven en sus módulos de Waybar (sin nm-applet ni blueman-applet).
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd(string.format(
        [[sh -c '%s/session-gsettings.sh reset >/dev/null 2>&1 || true; systemctl --user stop graphical-session.target']],
        scripts
    ))
end)
