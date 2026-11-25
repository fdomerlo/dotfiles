import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property bool launcherOpen
    required property string activeTab
    required property string searchQuery
    required property string activeTheme
    required property bool recordingActive
    required property bool nightlightActive

    signal tabSelected(string tabId)
    signal searchUpdated(string text)
    signal closeRequested()
    signal appActivated(var entry)
    signal actionActivated(var actionObj)
    signal overviewRequested()

    readonly property var tabs: [
        { id: "apps", label: "Apps", icon: "󰀻" },
        { id: "dev", label: "Dev & IA", icon: "󰅬" },
        { id: "capturar", label: "Capturar", icon: "󰄀" },
        { id: "estilo", label: "Estilo", icon: "󰏘" },
        { id: "sistema", label: "Sistema", icon: "󰒓" }
    ]

    property int selectedIndex: 0
    property int desktopVersion: 0
    property bool revealed: false
    readonly property int panelWidth: Math.min(760, Math.round((screen ? screen.width : 1920) * 0.56))
    readonly property int panelHeight: Math.min(540, Math.round((screen ? screen.height : 1080) * 0.64))
    readonly property int cornerSize: Theme.concaveRadius

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            win.desktopVersion += 1;
        }
    }

    function normalizeText(str) {
        if (!str)
            return "";
        return String(str)
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "");
    }

    function scoreItem(title, subtitle, keywords, queryNorm) {
        if (!queryNorm)
            return 1;
        const t = normalizeText(title);
        const s = normalizeText(subtitle);
        const k = normalizeText(keywords);

        if (t === queryNorm)
            return 1000;
        if (t.indexOf(queryNorm) === 0)
            return 700;

        const words = t.split(/[\s\-_\/:()]+/);
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(queryNorm) === 0)
                return 520;
        }
        if (t.indexOf(queryNorm) !== -1)
            return 350;
        if (s.indexOf(queryNorm) !== -1)
            return 200;
        if (k.indexOf(queryNorm) !== -1)
            return 130;

        // Soporte para búsqueda multi-palabra (ej. "cap swappy", "chrome pwa")
        const tokens = queryNorm.split(/\s+/).filter(tok => tok.length > 0);
        if (tokens.length > 1) {
            const haystack = t + " " + s + " " + k;
            let allMatch = true;
            for (let j = 0; j < tokens.length; j++) {
                if (haystack.indexOf(tokens[j]) === -1) {
                    allMatch = false;
                    break;
                }
            }
            if (allMatch)
                return 240;
        }
        return 0;
    }

    function buildActionCatalog() {
        const themeLabel = activeTheme || "ninguno";
        return [
            // Capturar
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰆞",
                title: "Captura de región (anotar con Swappy)",
                subtitle: "Seleccionar área y editar o copiar",
                keywords: "screenshot captura region swappy recortar imagen",
                shortcut: "Print",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-region.sh\""]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰆟",
                title: "Captura de región al portapapeles",
                subtitle: "Copiar selección directamente sin abrir editor",
                keywords: "screenshot captura portapapeles raw copiar",
                shortcut: "Ctrl+Print",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-region.sh\" --raw"]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰍹",
                title: "Captura de pantalla completa",
                subtitle: "Capturar todo el monitor enfocado",
                keywords: "screenshot full pantalla completa print",
                shortcut: "Shift+Print",
                actionType: "capture",
                delayMs: 260,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-full.sh\""]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: recordingActive ? "󰓛" : "󰑋",
                title: recordingActive ? "Detener grabación en curso" : "Grabar pantalla (monitor actual)",
                subtitle: recordingActive ? "Finalizar video actual con wf-recorder" : "Iniciar grabación MP4 del monitor activo",
                keywords: "grabar video pantalla record wf-recorder detener",
                shortcut: "Super+Shift+R",
                actionType: "capture",
                delayMs: 180,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screen-record.sh\""]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰩭",
                title: "Grabar región de pantalla",
                subtitle: "Seleccionar área a grabar en video",
                keywords: "grabar video region area slurp wf-recorder",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screen-record.sh\" --region"]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰈊",
                title: "Selector de color (Hex)",
                subtitle: "Tomar color de pantalla con hyprpicker",
                keywords: "color picker hex hyprpicker gotero",
                shortcut: "Super+Shift+P",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/color-picker.sh\""]
            },
            {
                kind: "action",
                category: "capturar",
                badge: "Capturar",
                glyph: "󰊄",
                title: "OCR de región (extraer texto)",
                subtitle: "Reconocer texto de la pantalla al portapapeles",
                keywords: "ocr texto tesseract copiar imagen",
                shortcut: "Super+Ctrl+O",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ocr-region.sh\""]
            },

            // Estilo
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰔎",
                title: "Elegir modo (actual: " + themeLabel + ")",
                subtitle: "Selector del tema único Cyber-Teal Material 3 (dark / light)",
                keywords: "tema theme cyber-teal claro oscuro light dark apariencia estilo modo",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Apariencia' \"$HOME/.config/hypr/scripts/theme-switch.sh\" menu"]
            },
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰸉",
                title: "Alternar modo Oscuro ↔ Claro",
                subtitle: "Cambiar en caliente entre modo oscuro y modo claro",
                keywords: "tema toggle alternar cambiar oscuro claro dark light estilo",
                shortcut: "Super+Shift+T",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/theme-switch.sh\" toggle"]
            },
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰌾",
                title: "Estilo de pantalla de bloqueo",
                subtitle: "Elegir entre Tema (Opción A), SOC Console, Matrix SOC, Minimal o Clásico",
                keywords: "lockscreen bloqueo hyprlock candado soc matrix estilo",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Lockscreen' \"$HOME/.config/hypr/scripts/lockscreen-switch.sh\" menu"]
            },
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰸨",
                title: "Siguiente wallpaper",
                subtitle: "Rotar fondo de pantalla del tema activo",
                keywords: "wallpaper fondo pantalla imagen siguiente",
                shortcut: "Super+W",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/wallpaper.sh\" --next"]
            },
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰖔",
                title: nightlightActive ? "Desactivar luz nocturna (4000K)" : "Activar luz nocturna (4000K)",
                subtitle: nightlightActive ? "Volver a temperatura neutra (6500K)" : "Aplicar filtro cálido con hyprsunset",
                keywords: "luz nocturna nightlight filtro azul hyprsunset 4000k",
                shortcut: "Super+Ctrl+N",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/nightlight-toggle.sh\""]
            },
            {
                kind: "action",
                category: "estilo",
                badge: "Estilo",
                glyph: "󰂚",
                title: "Centro de notificaciones",
                subtitle: "Abrir o cerrar el panel de notificaciones",
                keywords: "notificaciones panel alertas dnd no molestar",
                shortcut: "Super+N",
                actionType: "exec",
                delayMs: 40,
                cmd: ["qs", "ipc", "call", "notifications", "toggle"]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰕮",
                title: "Panel de indicadores (Dashboard)",
                subtitle: "Calendario, audio, red, rendimiento y acciones IA",
                keywords: "dashboard indicadores panel calendario audio media rendimiento",
                shortcut: "Super+I",
                actionType: "exec",
                delayMs: 40,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/dashboard-toggle.sh\""]
            },

            // Sistema
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰤨",
                title: "Red y VPN (NetworkManager)",
                subtitle: "Wi-Fi, conexiones y túneles VPN",
                keywords: "red wifi network vpn nmcli internet",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Red:' \"$HOME/.config/hypr/scripts/network-menu.sh\""]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰕾",
                title: "Audio (pavucontrol)",
                subtitle: "Control de volumen, salidas y micrófonos",
                keywords: "audio volumen sonido microfono pavucontrol pipewire",
                actionType: "exec",
                delayMs: 0,
                cmd: ["pavucontrol"]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰂯",
                title: "Bluetooth (blueman)",
                subtitle: "Emparejar y gestionar dispositivos Bluetooth",
                keywords: "bluetooth auriculares dispositivos blueman",
                actionType: "exec",
                delayMs: 0,
                cmd: ["blueman-manager"]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰅌",
                title: "Historial del portapapeles",
                subtitle: "Buscar y pegar entradas recientes de cliphist",
                keywords: "portapapeles clipboard historial pegar cliphist",
                shortcut: "Super+V",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Portapapeles' \"$HOME/.config/hypr/scripts/clipboard.sh\""]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰈞",
                title: "Buscar archivos",
                subtitle: "Búsqueda rápida en HOME con fd + fuzzel",
                keywords: "buscar archivos ficheros fd search",
                shortcut: "Super+Ctrl+F",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Archivo:' \"$HOME/.config/hypr/scripts/file-search.sh\""]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰖟",
                title: "Web Apps / PWAs (instalar, abrir, quitar)",
                subtitle: "Gestionar aplicaciones web aisladas con Chrome",
                keywords: "webapp pwa chrome instalar abrir quitar web",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Web Apps' \"$HOME/.config/hypr/scripts/webapp-install.sh\" menu"]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰍺",
                title: "Escala y PPI de monitores",
                subtitle: "Calcular y aplicar escala fraccional o entera",
                keywords: "monitor escala ppi dpi pantalla resolucion",
                actionType: "term-hold",
                delayMs: 0,
                termTitle: "Escala de monitores",
                termCmd: "\"$HOME/.config/hypr/scripts/monitor-scale.sh\" --hyprconf"
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰌌",
                title: "Cheatsheet de atajos",
                subtitle: "Listar combinaciones de teclas activas en Hyprland",
                keywords: "atajos keybinds teclas ayuda shortcuts",
                shortcut: "Super+F1",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Atajos' \"$HOME/.config/hypr/scripts/keybinds.sh\""]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰑐",
                title: "Recargar configuración Hyprland",
                subtitle: "Ejecutar hyprctl reload en caliente",
                keywords: "recargar reload hyprland configuracion",
                shortcut: "Super+Esc",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "if hyprctl reload >/dev/null 2>&1; then notify-send -a Hyprland 'Hyprland' 'Configuración recargada'; else notify-send -u critical -a Hyprland 'Hyprland' 'Error al recargar configuración'; fi"]
            },
            {
                kind: "action",
                category: "sistema",
                badge: "Sistema",
                glyph: "󰐥",
                title: "Energía y sesión",
                subtitle: "Bloquear, suspender, hibernar, reiniciar, apagar o cerrar sesión",
                keywords: "energia sesion apagar reiniciar suspender hibernar bloquear power logout hibernate",
                shortcut: "Super+X",
                actionType: "submenu",
                delayMs: 40,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/powermenu.sh\""]
            },

            // Dev & IA
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰚩",
                title: "Asistente IA (acciones rápidas)",
                subtitle: "Preguntar, explicar portapapeles, resumir, traducir o revisar cambios",
                keywords: "ia ai opencode asistente explicar resumir traducir portapapeles commit",
                shortcut: "Super+Shift+A",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ai.sh\" menu"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰆍",
                title: "Abrir OpenCode",
                subtitle: "Agente de terminal en ~/Proyectos",
                keywords: "opencode agente ia ai terminal code",
                shortcut: "Super+Shift+I",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ai.sh\" open"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰅩",
                title: "Abrir editor (Zed)",
                subtitle: "Editor predeterminado; respaldo VS Code o Neovim en Foot",
                keywords: "editor zed code vscode nvim codigo abrir",
                shortcut: "Super+C",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/editor.sh\""]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰐊",
                title: "Encender servicio OpenCode",
                subtitle: "Levanta el servidor de fondo compartido (~250 MB)",
                keywords: "opencode servicio service daemon start encender background",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ai.sh\" service start"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰐥",
                title: "Apagar servicio OpenCode",
                subtitle: "Detiene el servidor de fondo; las acciones IA siguen funcionando",
                keywords: "opencode servicio service daemon stop apagar background",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ai.sh\" service stop"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰒓",
                title: "Estado del servicio OpenCode",
                subtitle: "Muestra si el servidor de fondo está activo y en qué puerto",
                keywords: "opencode servicio service daemon status estado puerto",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ai.sh\" service status"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰍹",
                title: "Máquinas virtuales (Quickemu)",
                subtitle: "Iniciar, apagar, snapshots y crear VMs en ~/VMs",
                keywords: "vm virtual machine quickemu quickget qemu windows kvm",
                actionType: "submenu",
                delayMs: 90,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'VMs:' \"$HOME/.config/hypr/scripts/vm-menu.sh\""]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰆍",
                title: "Terminal flotante (Scratchpad)",
                subtitle: "Mostrar u ocultar terminal persistente",
                keywords: "terminal scratchpad flotante foot consola",
                shortcut: "Super+Shift+S",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/scratchpad.sh\""]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰒍",
                title: "Diagnóstico de estación (devctl doctor)",
                subtitle: "Comprobar estado de herramientas, Podman y Hyprland",
                keywords: "devctl doctor diagnostico chequeo sistema",
                actionType: "term-hold",
                delayMs: 0,
                termTitle: "devctl doctor",
                termCmd: "devctl doctor"
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰚰",
                title: "Actualizar estación (devctl update)",
                subtitle: "Actualizar paquetes APT, Flatpak y herramientas",
                keywords: "devctl update actualizar upgrade",
                actionType: "term-hold",
                delayMs: 0,
                termTitle: "devctl update",
                termCmd: "devctl update"
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰃢",
                title: "Limpieza profunda (devctl clean)",
                subtitle: "Limpiar cachés APT, contenedores y huérfanos",
                keywords: "devctl clean limpiar cache",
                actionType: "term-hold",
                delayMs: 0,
                termTitle: "devctl clean",
                termCmd: "devctl clean"
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰍛",
                title: "Monitor de sistema (btop)",
                subtitle: "CPU, RAM y procesos en ventana TUI flotante",
                keywords: "btop monitor cpu ram procesos htop",
                actionType: "exec",
                delayMs: 0,
                cmd: ["foot", "--app-id=tui-float", "-e", "btop"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰡨",
                title: "Contenedores (lazydocker)",
                subtitle: "Gestionar contenedores Podman/Docker en TUI flotante",
                keywords: "lazydocker podman docker contenedores tui",
                actionType: "exec",
                delayMs: 0,
                cmd: ["foot", "--app-id=tui-float", "-e", "lazydocker"]
            },
            {
                kind: "action",
                category: "dev",
                badge: "Dev & IA",
                glyph: "󰉋",
                title: "Gestor de archivos TUI (yazi)",
                subtitle: "Explorar directorios y previsualizar en terminal flotante",
                keywords: "yazi archivos gestor file manager tui",
                shortcut: "Super+Y",
                actionType: "exec",
                delayMs: 0,
                cmd: ["foot", "--app-id=tui-float", "-e", "yazi"]
            }
        ];
    }

    function appPinRank(entry) {
        const id = String(entry.id || "").toLowerCase();
        const pinned = [
            "google-chrome",
            "org.gnome.nautilus",
            "dev.zed.zed",
            "antigravity",
            "foot",
            "code"
        ];
        for (let i = 0; i < pinned.length; i++) {
            if (id === pinned[i] || id === pinned[i] + ".desktop")
                return i + 1;
        }
        return 0;
    }

    function isWebAppEntry(entry) {
        const id = String(entry.id || "").toLowerCase();
        const execStr = String(entry.execString || "");
        return id.indexOf("webapp-") === 0 || execStr.indexOf("--app=") !== -1;
    }

    readonly property var filteredItems: {
        void(win.desktopVersion);
        void(win.activeTheme);
        void(win.recordingActive);
        void(win.nightlightActive);

        const q = normalizeText(win.searchQuery.trim());
        const tab = win.activeTab || "apps";
        const actions = buildActionCatalog();
        const out = [];

        if (tab === "apps") {
            const rawApps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
            if (rawApps) {
                for (let i = 0; i < rawApps.length; i++) {
                    const entry = rawApps[i];
                    if (!entry || entry.noDisplay)
                        continue;

                    const name = String(entry.name || entry.id || "");
                    if (!name)
                        continue;

                    const isPwa = isWebAppEntry(entry);
                    const pinRank = appPinRank(entry);
                    const subtitle = String(entry.comment || entry.genericName || "");
                    const kwList = [];
                    if (entry.categories) {
                        for (let c = 0; c < entry.categories.length; c++)
                            kwList.push(entry.categories[c]);
                    }
                    if (entry.keywords) {
                        for (let k = 0; k < entry.keywords.length; k++)
                            kwList.push(entry.keywords[k]);
                    }
                    if (isPwa)
                        kwList.push("pwa webapp web");
                    kwList.push(entry.id || "");

                    let s = q ? scoreItem(name, subtitle, kwList.join(" "), q) : 1;
                    if (q && s <= 0)
                        continue;

                    if (!q) {
                        if (pinRank > 0)
                            s = 900 - pinRank * 10;
                        else if (isPwa)
                            s = 650;
                        else
                            s = 100;
                    } else if (isPwa || pinRank > 0) {
                        s += 15;
                    }

                    out.push({
                        kind: "app",
                        entry: entry,
                        title: name,
                        subtitle: subtitle || (isPwa ? "Web App aislada" : "Aplicación"),
                        badge: isPwa ? "PWA" : (pinRank > 0 ? "Fijado" : "App"),
                        glyph: isPwa ? "󰖟" : "󰀻",
                        iconName: String(entry.icon || ""),
                        score: s,
                        isQuick: pinRank > 0 || isPwa
                    });
                }
            }

            // Cuando el usuario escribe en "Apps", también busca acciones del sistema
            if (q.length > 0) {
                for (let a = 0; a < actions.length; a++) {
                    const act = actions[a];
                    const s = scoreItem(act.title, act.subtitle, act.keywords + " " + act.badge, q);
                    if (s > 0) {
                        out.push({
                            kind: "action",
                            actionObj: act,
                            title: act.title,
                            subtitle: act.subtitle,
                            badge: act.badge,
                            glyph: act.glyph,
                            iconName: "",
                            shortcut: act.shortcut || "",
                            score: s,
                            isQuick: false
                        });
                    }
                }
            }

            out.sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score;
                return a.title.localeCompare(b.title);
            });
            return out;
        }

        // Pestañas de sistema: Capturar | Estilo | Sistema | Dev & IA
        for (let i = 0; i < actions.length; i++) {
            const act = actions[i];
            if (act.category !== tab)
                continue;
            const s = q ? scoreItem(act.title, act.subtitle, act.keywords, q) : (actions.length - i);
            if (q && s <= 0)
                continue;
            out.push({
                kind: "action",
                actionObj: act,
                title: act.title,
                subtitle: act.subtitle,
                badge: act.badge,
                glyph: act.glyph,
                iconName: "",
                shortcut: act.shortcut || "",
                score: s,
                isQuick: false
            });
        }

        if (q.length > 0) {
            out.sort((a, b) => b.score - a.score);
        }
        return out;
    }

    function resetSelection() {
        // `filteredItems` puede estar todavía sin evaluar cuando la ventana nace
        // ya abierta por LazyLoader; sin el guard el log escupe un TypeError.
        const items = filteredItems;
        selectedIndex = (items && items.length > 0) ? 0 : -1;
        if (resultList.count > 0 && selectedIndex >= 0) {
            resultList.positionViewAtIndex(0, ListView.Beginning);
        }
    }

    function moveSelection(delta) {
        const count = filteredItems.length;
        if (count <= 0) {
            selectedIndex = -1;
            return;
        }
        let next = selectedIndex + delta;
        if (next < 0)
            next = count - 1;
        else if (next >= count)
            next = 0;
        selectedIndex = next;
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function cycleTab(delta) {
        let idx = 0;
        for (let i = 0; i < tabs.length; i++) {
            if (tabs[i].id === activeTab) {
                idx = i;
                break;
            }
        }
        const nextIdx = (idx + delta + tabs.length) % tabs.length;
        tabSelected(tabs[nextIdx].id);
        searchInput.forceActiveFocus();
    }

    function activateIndex(idx) {
        if (idx < 0 || idx >= filteredItems.length)
            return;
        const item = filteredItems[idx];
        if (item.kind === "app") {
            win.appActivated(item.entry);
        } else if (item.kind === "action") {
            win.actionActivated(item.actionObj);
        }
    }

    onFilteredItemsChanged: resetSelection()
    onActiveTabChanged: resetSelection()

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (win.launcherOpen)
                win.revealed = true;
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            searchInput.text = "";
            resetSelection();
            focusTimer.restart();
            revealTimer.restart();
        } else {
            revealTimer.stop();
            revealed = false;
        }
    }

    // La ventana puede crearse ya abierta por LazyLoader; replicamos el foco
    // inicial que normalmente dispara el cambio de launcherOpen.
    Component.onCompleted: {
        if (launcherOpen) {
            searchInput.text = "";
            resetSelection();
            focusTimer.restart();
            revealTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (win.launcherOpen) {
                searchInput.forceActiveFocus();
            }
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: launcherOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [win]
        active: win.launcherOpen
        onCleared: win.closeRequested()
    }

    Item {
        anchors.fill: parent

        // Oscurecimiento suave del fondo (equivalente a dim_around, sin blur)
        Rectangle {
            anchors.fill: parent
            color: Theme.dimAround
            opacity: win.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: win.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.launcherOpen
            onClicked: win.closeRequested()
        }

        // Borde cyan inferior a ambos lados del menú acoplado al borde de pantalla
        Rectangle {
            anchors.left: parent.left
            anchors.right: launcherDock.left
            anchors.rightMargin: launcherDock.height >= win.cornerSize + 2 ? win.cornerSize : 0
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.activeBorder
            opacity: win.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: win.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            anchors.left: launcherDock.right
            anchors.leftMargin: launcherDock.height >= win.cornerSize + 2 ? win.cornerSize : 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.activeBorder
            opacity: win.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: win.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Panel central desplegado desde el borde inferior con curvas fundidas
        Item {
            id: launcherDock
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: win.panelWidth
            height: win.revealed ? win.panelHeight : 0
            opacity: win.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: win.revealed ? Theme.animPop : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: win.revealed ? Theme.curveExpressive : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: win.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            // Base sólida de 2px bajo las curvas inferiores para fundir con el borde inferior
            Rectangle {
                z: 1
                anchors.bottom: parent.bottom
                anchors.right: surface.left
                width: Math.max(0, win.cornerSize - 1)
                height: 2
                color: Theme.surface
                visible: launcherDock.height >= win.cornerSize + 2
            }

            Rectangle {
                z: 1
                anchors.bottom: parent.bottom
                anchors.left: surface.right
                width: Math.max(0, win.cornerSize - 1)
                height: 2
                color: Theme.surface
                visible: launcherDock.height >= win.cornerSize + 2
            }

            ConcaveCorner {
                position: "bottom-right"
                size: win.cornerSize
                color: Theme.surface
                borderWidth: 2
                borderColor: Theme.activeBorder
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.right: surface.left
                visible: launcherDock.height >= win.cornerSize + 2
            }

            ConcaveCorner {
                position: "bottom-left"
                size: win.cornerSize
                color: Theme.surface
                borderWidth: 2
                borderColor: Theme.activeBorder
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.left: surface.right
                visible: launcherDock.height >= win.cornerSize + 2
            }

            Item {
                id: surface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - win.cornerSize - 2))

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height + Theme.radiusLarge
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: launcherDock.height >= win.cornerSize + 2

                    ShapePath {
                        strokeWidth: 2
                        strokeColor: Theme.activeBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: 1
                        startY: surface.height - win.cornerSize - 2

                        PathLine {
                            x: 1
                            y: surface.cornerR
                        }
                        PathArc {
                            x: surface.cornerR
                            y: 1
                            radiusX: surface.cornerR - 1
                            radiusY: surface.cornerR - 1
                            direction: PathArc.Clockwise
                        }
                        PathLine {
                            x: surface.width - surface.cornerR
                            y: 1
                        }
                        PathArc {
                            x: surface.width - 1
                            y: surface.cornerR
                            radiusX: surface.cornerR - 1
                            radiusY: surface.cornerR - 1
                            direction: PathArc.Clockwise
                        }
                        PathLine {
                            x: surface.width - 1
                            y: surface.height - win.cornerSize - 2
                        }
                    }
                }

                // Absorbe clics internos
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    y: win.revealed ? 16 : 32
                    height: Math.max(120, win.panelHeight - 32)
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: win.revealed ? Theme.animPop : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: win.revealed ? Theme.curveExpressive : Theme.curveAccel
                        }
                    }

            // Buscador principal (foco inmediato al abrir)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: Theme.surfaceContainer
                radius: Theme.radiusMedium
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.outline : Theme.outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.textBright
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        clip: true
                        selectByMouse: true
                        activeFocusOnTab: false
                        verticalAlignment: TextInput.AlignVCenter

                        onTextChanged: {
                            if (win.launcherOpen && text !== win.searchQuery) {
                                win.searchUpdated(text);
                            }
                        }

                        Keys.onEscapePressed: win.closeRequested()
                        Keys.onReturnPressed: win.activateIndex(win.selectedIndex)
                        Keys.onEnterPressed: win.activateIndex(win.selectedIndex)
                        Keys.onUpPressed: win.moveSelection(-1)
                        Keys.onDownPressed: win.moveSelection(1)
                        Keys.onTabPressed: event => {
                            event.accepted = true;
                            win.cycleTab((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                        }
                        Keys.onBacktabPressed: event => {
                            event.accepted = true;
                            win.cycleTab(-1);
                        }
                        Keys.onPressed: event => {
                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                                event.accepted = true;
                                win.moveSelection(1);
                            } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                                event.accepted = true;
                                win.moveSelection(-1);
                            } else if (event.key === Qt.Key_PageDown) {
                                event.accepted = true;
                                win.moveSelection(5);
                            } else if (event.key === Qt.Key_PageUp) {
                                event.accepted = true;
                                win.moveSelection(-5);
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: win.activeTab === "apps"
                                ? "Buscar apps, PWAs o acciones del sistema..."
                                : "Filtrar acciones en " + win.activeTab + "..."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            visible: !searchInput.text
                        }
                    }

                    Rectangle {
                        visible: searchInput.text.length > 0
                        width: 24
                        height: 24
                        radius: Theme.cardRadius
                        color: clearHover.containsMouse ? Theme.cardHoverBg : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Tabs M3 tonales con indicador deslizante (mismo lenguaje que DashboardPopup)
            Item {
                id: launcherTabStrip
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                readonly property int tabCount: win.tabs.length
                readonly property real tabW: width / Math.max(1, tabCount)
                readonly property int activeIndex: {
                    for (let i = 0; i < win.tabs.length; i++) {
                        if (win.tabs[i].id === win.activeTab)
                            return i;
                    }
                    return 0;
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.55
                }

                Rectangle {
                    width: Math.min(72, Math.max(36, launcherTabStrip.tabW * 0.46))
                    height: 3
                    radius: 2
                    color: Theme.primary
                    anchors.bottom: parent.bottom
                    x: launcherTabStrip.activeIndex * launcherTabStrip.tabW + (launcherTabStrip.tabW - width) / 2

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animTab
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveExpressive
                        }
                    }
                }

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: win.tabs

                        delegate: Item {
                            id: pill
                            required property var modelData
                            readonly property bool isActive: win.activeTab === modelData.id

                            width: launcherTabStrip.tabW
                            height: launcherTabStrip.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 1
                                anchors.bottomMargin: 5
                                anchors.leftMargin: 3
                                anchors.rightMargin: 3
                                radius: Theme.radiusSmall
                                color: pill.isActive
                                    ? Theme.surfaceContainer
                                    : (pillMouse.containsMouse ? Theme.surfaceContainerLow : "transparent")

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                spacing: 6

                                Text {
                                    text: pill.modelData.icon
                                    color: pill.isActive
                                        ? Theme.primary
                                        : (pillMouse.containsMouse ? Theme.fg : Theme.fgSubtle)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                Text {
                                    text: pill.modelData.label
                                    color: pill.isActive
                                        ? Theme.fg
                                        : (pillMouse.containsMouse ? Theme.fgMuted : Theme.fgSubtle)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: pill.isActive ? Font.Bold : Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.tabSelected(pill.modelData.id);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // Lista principal de resultados (apps, PWAs, accesos rápidos y acciones)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: resultList
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.filteredItems

                    delegate: Rectangle {
                        id: rowItem
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: index === win.selectedIndex
                        readonly property string resolvedIcon: modelData.iconName
                            ? Quickshell.iconPath(modelData.iconName, true)
                            : ""

                        width: resultList.width
                        height: 52
                        radius: Theme.radiusMedium
                        color: isSelected
                            ? Theme.primaryContainer
                            : (rowMouse.containsMouse ? Theme.surfaceContainer : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Icono de aplicación o glifo de acción
                            Item {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: rowItem.resolvedIcon
                                    sourceSize.width: 26
                                    sourceSize.height: 26
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: status === Image.Ready && rowItem.resolvedIcon !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: rowItem.modelData.glyph
                                    color: rowItem.isSelected ? Theme.fgOnPrimaryContainer : Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: rowItem.modelData.title
                                    color: rowItem.isSelected ? Theme.fgOnPrimaryContainer : Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: rowItem.isSelected ? Font.Bold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: rowItem.modelData.subtitle !== ""
                                    text: rowItem.modelData.subtitle
                                    color: rowItem.isSelected ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                    opacity: rowItem.isSelected ? 0.80 : 1.0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            // Atajo de teclado correspondiente (si la acción tiene uno).
                            Rectangle {
                                visible: (rowItem.modelData.shortcut || "") !== ""
                                Layout.preferredWidth: shortcutText.implicitWidth + 12
                                Layout.preferredHeight: 24
                                radius: Theme.radiusFull
                                color: rowItem.isSelected ? Theme.surface : Theme.surfaceContainer

                                Text {
                                    id: shortcutText
                                    anchors.centerIn: parent
                                    text: rowItem.modelData.shortcut || ""
                                    color: rowItem.isSelected ? Theme.primary : Theme.fgSubtle
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }

                            Rectangle {
                                visible: rowItem.modelData.badge !== ""
                                Layout.preferredWidth: badgeText.implicitWidth + 14
                                Layout.preferredHeight: 24
                                radius: Theme.radiusFull
                                color: rowItem.isSelected ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: rowItem.modelData.badge
                                    color: rowItem.isSelected ? Theme.fg : Theme.fgSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: rowItem.isSelected ? Font.DemiBold : Font.Medium
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.selectedIndex = rowItem.index
                            onClicked: win.activateIndex(rowItem.index)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: win.filteredItems.length === 0
                    text: "Sin resultados para \"" + win.searchQuery.trim() + "\""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            // Pie compacto con ayuda de navegación y acceso rápido a Actividades (Super+A)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        text: "Tab: pestaña · ↑↓: mover · Enter: ejecutar · Esc: cerrar"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: ovHint.implicitWidth + 18
                        Layout.preferredHeight: 28
                        radius: Theme.radiusFull
                        color: ovMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: ovHint
                            anchors.centerIn: parent
                            text: "󰕰  Actividades (Super+A)"
                            color: ovMouse.containsMouse ? Theme.fg : Theme.fgSubtle
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: ovMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.overviewRequested()
                        }
                    }
                }
            }
        }
            }
        }
    }
}
