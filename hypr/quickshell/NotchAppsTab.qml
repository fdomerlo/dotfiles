import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: appsRoot

    property string searchQuery: ""
    property string activeTheme: "dark"
    property bool recordingActive: false
    property bool nightlightActive: false

    signal appActivated(var entry)
    signal actionActivated(var actionObj)

    property int selectedIndex: 0
    property int desktopVersion: 0

    readonly property int resultCount: filteredItems.length

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            appsRoot.desktopVersion += 1;
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
            // Capturar (Media)
            {
                kind: "action",
                badge: "Media",
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
                badge: "Media",
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
                badge: "Media",
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
                badge: "Media",
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
                badge: "Media",
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
                badge: "Media",
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
                badge: "Media",
                glyph: "󰊄",
                title: "OCR de región (extraer texto)",
                subtitle: "Reconocer texto de la pantalla al portapapeles",
                keywords: "ocr texto tesseract copiar imagen",
                shortcut: "Super+Ctrl+O",
                actionType: "capture",
                delayMs: 220,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ocr-region.sh\""]
            },

            // Apariencia / Estilo
            {
                kind: "action",
                badge: "Apariencia",
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
                badge: "Apariencia",
                glyph: "󰸉",
                title: "Alternar modo Oscuro ↔ Claro",
                subtitle: "Cambiar en caliente entre modo oscuro y modo claro",
                keywords: "tema toggle alternar cambiar oscuro claro dark light estilo apariencia",
                shortcut: "Super+Shift+T",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/theme-switch.sh\" toggle"]
            },
            {
                kind: "action",
                badge: "Apariencia",
                glyph: "󰌾",
                title: "Estilo de pantalla de bloqueo",
                subtitle: "Elegir entre Tema (Opción A), SOC Console, Matrix SOC, Minimal o Clásico",
                keywords: "lockscreen bloqueo hyprlock candado soc matrix estilo apariencia",
                actionType: "appearance"
            },
            {
                kind: "action",
                badge: "Apariencia",
                glyph: "󰸨",
                title: "Siguiente wallpaper",
                subtitle: "Rotar fondo de pantalla del tema activo",
                keywords: "wallpaper fondo pantalla imagen siguiente apariencia",
                shortcut: "Super+W",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/wallpaper.sh\" --next"]
            },
            {
                kind: "action",
                badge: "Apariencia",
                glyph: "󰖔",
                title: nightlightActive ? "Desactivar luz nocturna (4000K)" : "Activar luz nocturna (4000K)",
                subtitle: nightlightActive ? "Volver a temperatura neutra (6500K)" : "Aplicar filtro cálido con hyprsunset",
                keywords: "luz nocturna nightlight filtro azul hyprsunset 4000k",
                shortcut: "Super+Ctrl+N",
                actionType: "exec",
                delayMs: 0,
                cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/nightlight-toggle.sh\""]
            },

            // Sistema y utilidades
            {
                kind: "action",
                badge: "Sistema",
                glyph: "󰂚",
                title: "Centro de notificaciones",
                subtitle: "Abrir o cerrar el panel de notificaciones",
                keywords: "notificaciones panel alertas no molestar",
                shortcut: "Super+N",
                actionType: "exec",
                delayMs: 40,
                cmd: ["qs", "ipc", "call", "notifications", "toggle"]
            },
            {
                kind: "action",
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
                badge: "Sistema",
                glyph: "󰅌",
                title: "Historial del portapapeles",
                subtitle: "Buscar texto e imágenes copiadas en cliphist",
                keywords: "portapapeles clipboard historial pegar cliphist imagenes",
                shortcut: "Super+V",
                actionType: "clipboard"
            },
            {
                kind: "action",
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
        void(appsRoot.desktopVersion);
        void(appsRoot.activeTheme);
        void(appsRoot.recordingActive);
        void(appsRoot.nightlightActive);

        const q = normalizeText(appsRoot.searchQuery.trim());
        const out = [];
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
                    shortcut: "",
                    score: s
                });
            }
        }

        // Al escribir en el buscador global, también incluye acciones de todas las áreas
        if (q.length > 0) {
            const actions = buildActionCatalog();
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
                        score: s
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

    function resetSelection() {
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

    function activateIndex(idx) {
        if (idx < 0 || idx >= filteredItems.length)
            return;
        const item = filteredItems[idx];
        if (item.kind === "app") {
            appsRoot.appActivated(item.entry);
        } else if (item.kind === "action") {
            appsRoot.actionActivated(item.actionObj);
        }
    }

    function activateSelected() {
        activateIndex(selectedIndex);
    }

    onFilteredItemsChanged: resetSelection()

    ListView {
        id: resultList
        anchors.fill: parent
        anchors.rightMargin: (resultList.contentHeight > resultList.height + 2) ? 10 : 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: appsRoot.filteredItems

        delegate: Rectangle {
            id: rowItem
            required property var modelData
            required property int index

            readonly property bool isSelected: index === appsRoot.selectedIndex
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
                onEntered: appsRoot.selectedIndex = rowItem.index
                onClicked: appsRoot.activateIndex(rowItem.index)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: appsRoot.filteredItems.length === 0
        text: "Sin resultados para \"" + appsRoot.searchQuery.trim() + "\""
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    // Desvanecimiento inferior suave cuando hay más resultados debajo
    Rectangle {
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        readonly property bool hasMoreBelow: resultList.contentHeight > resultList.height + 2
            && (resultList.contentY + resultList.height) < (resultList.contentHeight - 4)
        opacity: hasMoreBelow ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.surfaceSolid }
        }
    }

    // Indicador de scroll delgado
    Item {
        z: 3
        visible: resultList.contentHeight > resultList.height + 2
        width: 4
        anchors.top: resultList.top
        anchors.bottom: resultList.bottom
        anchors.right: parent.right
        anchors.rightMargin: 1

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Theme.outlineVariant
            opacity: 0.25
        }

        Rectangle {
            readonly property real ratio: resultList.contentHeight > 0
                ? Math.min(1.0, resultList.height / resultList.contentHeight)
                : 1.0
            readonly property real maxScroll: Math.max(1, resultList.contentHeight - resultList.height)
            readonly property real frac: Math.max(0, Math.min(1, resultList.contentY / maxScroll))
            width: parent.width
            radius: 2
            height: Math.max(24, Math.round(parent.height * ratio))
            y: Math.round((parent.height - height) * frac)
            color: Theme.primary
            opacity: resultList.moving ? 0.85 : 0.45
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }
    }
}
