import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Widgets

PanelWindow {
    id: dashWin

    required property bool panelOpen
    required property int activeTab
    required property var sysState
    required property date currentDate
    required property bool dndEnabled
    required property bool idleInhibited
    property string activeTheme: "dark"
    property string searchQuery: ""
    property bool floatingMode: false
    property var barHitTester: null

    signal closeRequested()
    signal tabSelected(int tabIndex)
    signal toggleDndRequested()
    signal toggleIdleInhibitRequested()
    signal powerRequested()
    signal appActivated(var entry)
    signal actionActivated(var actionObj)
    signal overviewRequested()
    signal barMenuHovered(var scr, string target)
    signal barMenuClicked(var scr, string target, int button)
    signal barWorkspaceClicked(int wsId)

    readonly property int barH: sysState ? sysState.barHeight : 40
    readonly property int panelWidth: Math.min(860, Math.max(680, (dashWin.screen ? dashWin.screen.width : 1280) - 64))
    readonly property int cornerSize: Theme.concaveRadius
    property bool revealed: false
    property int mediaTick: 0
    property int selectedPlayerIndex: 0
    property bool draggingBrightness: false

    // Navegación por teclado del contenido (pestañas 1–4)
    property int focusIndex: -1
    property bool helpOpen: false
    property Item focusRingItem: null
    property real focusRingX: 0
    property real focusRingY: 0
    property real focusRingW: 0
    property real focusRingH: 0

    // Navegación del calendario en Dashboard (Tab 1)
    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth()
    readonly property bool isViewingCurrentMonth:
        displayYear === currentDate.getFullYear() && displayMonth === currentDate.getMonth()

    readonly property var tabMeta: [
        { id: "apps", label: "Apps", glyph: "󰀻" },
        { id: "dev", label: "Dev & IA", glyph: "󰚩" },
        { id: "dashboard", label: "Dashboard", glyph: "󰕮" },
        { id: "media", label: "Media", glyph: "󰎆" },
        { id: "system", label: "Sistema", glyph: "󰓅" }
    ]

    readonly property var monthNames: [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    readonly property var weekdayShort: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]

    readonly property var calendarCells: {
        const y = displayYear;
        const m = displayMonth;
        const first = new Date(y, m, 1);
        const startOffset = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const prevMonthDays = new Date(y, m, 0).getDate();
        const todayY = currentDate.getFullYear();
        const todayM = currentDate.getMonth();
        const todayD = currentDate.getDate();
        const prevDate = new Date(y, m - 1, 1);
        const nextDate = new Date(y, m + 1, 1);

        const cells = [];
        for (let i = startOffset - 1; i >= 0; i--)
            cells.push({
                day: prevMonthDays - i,
                inMonth: false,
                isToday: false,
                year: prevDate.getFullYear(),
                month: prevDate.getMonth()
            });
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                inMonth: true,
                isToday: (y === todayY && m === todayM && d === todayD),
                year: y,
                month: m
            });
        }
        let nextDay = 1;
        while (cells.length % 7 !== 0 || cells.length < 42)
            cells.push({
                day: nextDay++,
                inMonth: false,
                isToday: false,
                year: nextDate.getFullYear(),
                month: nextDate.getMonth()
            });
        return cells;
    }

    // Audio (PipeWire)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: Boolean(defaultSink && defaultSink.audio)
    readonly property int sinkVolumePct: sinkReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSink.audio.volume || 0)) * 100)
        : 0
    readonly property bool sinkMuted: sinkReady ? Boolean(defaultSink.audio.muted) : false

    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property bool sourceReady: Boolean(defaultSource && defaultSource.audio)
    readonly property int sourceVolumePct: sourceReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSource.audio.volume || 0)) * 100)
        : 0
    readonly property bool sourceMuted: sourceReady ? Boolean(defaultSource.audio.muted) : false

    // Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool hasBluetooth: Boolean(btAdapter)
    readonly property bool btEnabled: Boolean(btAdapter && btAdapter.enabled)
    readonly property var btConnectedDevice: {
        if (!btAdapter || !btAdapter.enabled || !btAdapter.devices)
            return null;
        const devs = btAdapter.devices.values;
        if (!devs)
            return null;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].connected)
                return devs[i];
        }
        return null;
    }

    // Reproductores MPRIS
    readonly property var playersList: {
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i])
                out.push(list[i]);
        }
        return out;
    }

    readonly property var activePlayer: {
        if (!playersList || playersList.length === 0)
            return null;
        if (selectedPlayerIndex >= 0 && selectedPlayerIndex < playersList.length)
            return playersList[selectedPlayerIndex];
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].isPlaying)
                return playersList[i];
        }
        return playersList[0];
    }

    // Batería (solo laptops)
    readonly property var batteryDev: UPower.displayDevice
    readonly property bool hasBattery: Boolean(batteryDev && batteryDev.isLaptopBattery && batteryDev.isPresent)
    readonly property int batteryPct: hasBattery ? Math.round((batteryDev.percentage || 0) * 100) : 0
    readonly property bool batteryCharging: hasBattery && (
        batteryDev.state === UPowerDeviceState.Charging ||
        batteryDev.state === UPowerDeviceState.PendingCharge
    )

    // Acciones IA unificadas
    readonly property var aiQuickActions: [
        { cmd: "ask", glyph: "󰚩", title: "Preguntar", subtitle: "Consulta rápida", delay: false },
        { cmd: "open", glyph: "󰆍", title: "Abrir OpenCode", subtitle: "Super+Shift+I", delay: false },
        { cmd: "explain", glyph: "󰆧", title: "Explicar texto", subtitle: "Selección o clip", delay: false },
        { cmd: "error", glyph: "󰀪", title: "Explicar error", subtitle: "Desde portapapeles", delay: false }
    ]

    readonly property var aiContextActions: [
        { cmd: "window", glyph: "󰈈", title: "Ventana activa", subtitle: "Captura y análisis", delay: true },
        { cmd: "image", glyph: "󰋩", title: "Imagen clip", subtitle: "Analizar captura", delay: false },
        { cmd: "summarize", glyph: "󰊄", title: "Resumir", subtitle: "Viñetas clave", delay: false },
        { cmd: "translate", glyph: "󰗊", title: "Traducir", subtitle: "ES ↔ EN + copiar", delay: false },
        { cmd: "diff", glyph: "󰊢", title: "Revisar cambios", subtitle: "Diff del repo activo", delay: false },
        { cmd: "commit", glyph: "󰜘", title: "Mensaje commit", subtitle: "Conventional + copiar", delay: false }
    ]

    readonly property var captureActions: [
        { glyph: "󰆞", title: "Región (Swappy)", shortcut: "Print", isRec: false, delayMs: 220, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-region.sh\""] },
        { glyph: "󰆟", title: "Región al clip", shortcut: "Ctrl+Print", isRec: false, delayMs: 220, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-region.sh\" --raw"] },
        { glyph: "󰍹", title: "Pantalla completa", shortcut: "Shift+Print", isRec: false, delayMs: 260, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screenshot-full.sh\""] },
        { glyph: (sysState && sysState.recordingActive) ? "󰓛" : "󰑋", title: (sysState && sysState.recordingActive) ? "Detener REC" : "Grabar monitor", shortcut: "Super+Shift+R", isRec: Boolean(sysState && sysState.recordingActive), delayMs: 180, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screen-record.sh\""] },
        { glyph: "󰩭", title: "Grabar región", shortcut: "", isRec: false, delayMs: 220, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/screen-record.sh\" --region"] },
        { glyph: "󰈊", title: "Color (Hex)", shortcut: "Super+Shift+P", isRec: false, delayMs: 220, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/color-picker.sh\""] },
        { glyph: "󰊄", title: "OCR texto", shortcut: "Super+Ctrl+O", isRec: false, delayMs: 220, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/ocr-region.sh\""] }
    ]

    readonly property var devToolsActions: [
        { glyph: "󰅩", title: "Editor (Zed)", subtitle: "Super+C", actionType: "exec", delayMs: 0, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/editor.sh\""] },
        { glyph: "󰆍", title: "Scratchpad", subtitle: "Super+Shift+S", actionType: "exec", delayMs: 0, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/scratchpad.sh\""] },
        { glyph: "󰍹", title: "VMs (Quickemu)", subtitle: "~/VMs", actionType: "submenu", delayMs: 90, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'VMs:' \"$HOME/.config/hypr/scripts/vm-menu.sh\""] },
        { glyph: "󰡨", title: "lazydocker", subtitle: "Contenedores", actionType: "exec", delayMs: 0, cmd: ["foot", "--app-id=tui-float", "-e", "lazydocker"] },
        { glyph: "󰉋", title: "yazi", subtitle: "Super+Y", actionType: "exec", delayMs: 0, cmd: ["foot", "--app-id=tui-float", "-e", "yazi"] },
        { glyph: "󰒍", title: "devctl doctor", subtitle: "Diagnóstico", actionType: "term-hold", delayMs: 0, termTitle: "devctl doctor", termCmd: "devctl doctor" },
        { glyph: "󰚰", title: "devctl update", subtitle: "Actualizar", actionType: "term-hold", delayMs: 0, termTitle: "devctl update", termCmd: "devctl update" },
        { glyph: "󰃢", title: "devctl clean", subtitle: "Limpieza", actionType: "term-hold", delayMs: 0, termTitle: "devctl clean", termCmd: "devctl clean" }
    ]

    readonly property var systemUtilActions: [
        { glyph: "󰅌", title: "Portapapeles", subtitle: "Super+V", actionType: "clipboard" },
        { glyph: "󰈞", title: "Buscar archivos", subtitle: "Super+Ctrl+F", actionType: "submenu", delayMs: 90, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Archivo:' \"$HOME/.config/hypr/scripts/file-search.sh\""] },
        { glyph: "󰖟", title: "Web Apps / PWAs", subtitle: "Instalar o quitar", actionType: "submenu", delayMs: 90, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Web Apps' \"$HOME/.config/hypr/scripts/webapp-install.sh\" menu"] },
        { glyph: "󰍺", title: "Escala monitores", subtitle: "PPI y resolución", actionType: "term-hold", delayMs: 0, termTitle: "Escala de monitores", termCmd: "\"$HOME/.config/hypr/scripts/monitor-scale.sh\" --hyprconf" },
        { glyph: "󰌌", title: "Atajos activos", subtitle: "Super+F1", actionType: "submenu", delayMs: 90, cmd: ["bash", "-c", "\"$HOME/.config/hypr/scripts/toggle-menu.sh\" 'Atajos' \"$HOME/.config/hypr/scripts/keybinds.sh\""] },
        { glyph: "󰑐", title: "Recargar Hyprland", subtitle: "Super+Esc", actionType: "exec", delayMs: 0, cmd: ["bash", "-c", "if hyprctl reload >/dev/null 2>&1; then notify-send -a Hyprland 'Hyprland' 'Configuración recargada'; else notify-send -u critical -a Hyprland 'Hyprland' 'Error al recargar configuración'; fi"] }
    ]

    function shiftMonth(delta) {
        let m = displayMonth + delta;
        let y = displayYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        displayYear = y;
        displayMonth = m;
    }

    function resetToToday() {
        displayYear = currentDate.getFullYear();
        displayMonth = currentDate.getMonth();
    }

    // Abre GNOME Calendar en la fecha indicada. --date usa el formato de fecha
    // corto del locale, así que se toma de `locale -k d_fmt` y se fuerza año
    // de 4 dígitos (en es_AR, por ejemplo, d_fmt es %d/%m/%y).
    function openSystemCalendar(year, month, day) {
        const pad = n => String(n).padStart(2, "0");
        const iso = year + "-" + pad(month + 1) + "-" + pad(day);
        dashWin.closeRequested();
        Quickshell.execDetached([
            "sh", "-c",
            "if ! command -v gnome-calendar >/dev/null 2>&1; then " +
            "notify-send -a Dashboard 'Calendario' 'GNOME Calendar no está instalado'; exit 0; fi; " +
            "fmt=$(locale -k d_fmt 2>/dev/null | sed -n 's/^d_fmt=\"\\(.*\\)\"$/\\1/p'); " +
            "fmt=$(printf '%s' \"${fmt:-%Y-%m-%d}\" | sed 's/%y/%Y/g'); " +
            "exec gnome-calendar --date \"$(date -d \"$1\" +\"$fmt\")\"",
            "_", iso
        ]);
    }

    function runScript(relPath, args) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/" + relPath].concat(args || []));
    }

    function runAiAction(cmd, delayForWindowCapture) {
        const script = (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ai.sh";
        dashWin.closeRequested();
        if (delayForWindowCapture)
            Quickshell.execDetached(["sh", "-c", "sleep 0.30 && exec \"$1\" \"$2\"", "_", script, cmd]);
        else
            Quickshell.execDetached([script, cmd]);
    }

    function cyclePowerProfile() {
        const cur = PowerProfiles.profile;
        if (cur === PowerProfile.PowerSaver) {
            PowerProfiles.profile = PowerProfile.Balanced;
        } else if (cur === PowerProfile.Balanced) {
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile
                ? PowerProfile.Performance
                : PowerProfile.PowerSaver;
        } else {
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }

    function powerProfileLabel() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "Rendimiento";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "Ahorro";
        return "Equilibrado";
    }

    function powerProfileGlyph() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "󰓅";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "󰌪";
        return "󰾅";
    }

    function formatTrackTime(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds) || 0));
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return m + ":" + String(rem).padStart(2, "0");
    }

    function resolveTrayIcon(rawIcon) {
        const s = String(rawIcon || "");
        if (!s)
            return "";
        if (s.startsWith("image://") || s.startsWith("file://") || s.startsWith("qrc:/"))
            return s;
        if (s.startsWith("/"))
            return "file://" + s;
        return Quickshell.iconPath(s, true);
    }

    function trayItemLabel(item) {
        if (!item)
            return "App";
        const candidates = [item.tooltipTitle, item.title, item.id];
        for (let i = 0; i < candidates.length; i++) {
            const s = String(candidates[i] || "").trim();
            if (s.length > 0)
                return s;
        }
        return "App";
    }

    // ---------------------------------------------------------------------
    // Navegación por teclado del contenido (pestañas 1–4)
    // Cada descriptor apunta a un control visible y sabe cómo activarse.
    // ---------------------------------------------------------------------
    function descriptorItem(fd) {
        if (!fd)
            return null;
        if (fd.item)
            return fd.item;
        if (fd.repeater)
            return fd.repeater.itemAt(fd.index) || null;
        return null;
    }

    function focusableDescriptors() {
        const out = [];
        if (activeTab === 1) {
            out.push({ item: aiSvcM, id: "aiService" });
            for (let i = 0; i < aiQuickRepeater.count; i++)
                out.push({ repeater: aiQuickRepeater, index: i, id: "aiQuick", data: aiQuickActions[i] });
            for (let i = 0; i < aiContextRepeater.count; i++)
                out.push({ repeater: aiContextRepeater, index: i, id: "aiContext", data: aiContextActions[i] });
            for (let i = 0; i < devToolsRepeater.count; i++)
                out.push({ repeater: devToolsRepeater, index: i, id: "dev", data: devToolsActions[i] });
        } else if (activeTab === 2) {
            out.push({ item: qNetTile, id: "net" });
            out.push({ item: qBtTile, id: "bt" });
            out.push({ item: qDndTile, id: "dnd" });
            out.push({ item: qNlTile, id: "nightlight" });
            out.push({ item: qIdleTile, id: "idle" });
            out.push({ item: qPpTile, id: "powerprofile" });
            out.push({ item: volSliderM, id: "vol", kind: "vslider" });
            out.push({ item: micSliderM, id: "mic", kind: "vslider" });
            if (sysState && sysState.hasBacklight)
                out.push({ item: brSliderM, id: "bright", kind: "vslider" });
            out.push({ item: dPrevM, id: "mediaPrev" });
            out.push({ item: dPlayM, id: "mediaPlay" });
            out.push({ item: dNextM, id: "mediaNext" });
            out.push({ item: cPrevM, id: "calPrev" });
            if (!isViewingCurrentMonth)
                out.push({ item: todayChipM, id: "calToday" });
            out.push({ item: cNextM, id: "calNext" });
            out.push({ item: dashPerfSummaryCard, id: "perf" });
        } else if (activeTab === 3) {
            for (let i = 0; i < playerPillRepeater.count; i++)
                out.push({ repeater: playerPillRepeater, index: i, id: "player", data: i });
            out.push({ item: mPrevM, id: "mediaPrev" });
            out.push({ item: mPlayM, id: "mediaPlay" });
            out.push({ item: mNextM, id: "mediaNext" });
            out.push({ item: outMuteM, id: "outMute" });
            out.push({ item: outSliderM, id: "outVol", kind: "hslider" });
            out.push({ item: micMuteM, id: "micMute" });
            out.push({ item: micSliderHM, id: "micVol", kind: "hslider" });
            for (let i = 0; i < capRepeater.count; i++)
                out.push({ repeater: capRepeater, index: i, id: "capture", data: captureActions[i] });
            out.push({ item: pavuM, id: "pavu" });
        } else if (activeTab === 4) {
            out.push({ item: openBtopM, id: "btop" });
            for (let i = 0; i < trayRepeater.count; i++)
                out.push({ repeater: trayRepeater, index: i, id: "tray", data: SystemTray.items.values[i] });
            for (let i = 0; i < sysUtilRepeater.count; i++)
                out.push({ repeater: sysUtilRepeater, index: i, id: "sysUtil", data: systemUtilActions[i] });
        }
        return out;
    }

    function visibleFocusDescriptors() {
        return focusableDescriptors().filter(fd => {
            const it = descriptorItem(fd);
            return Boolean(it && it.visible && it.width > 0 && it.height > 0);
        });
    }

    function focusItemCenter(it) {
        return it.mapToItem(dashSurface, it.width / 2, it.height / 2);
    }

    function updateFocusRing() {
        const list = visibleFocusDescriptors();
        if (focusIndex < 0 || focusIndex >= list.length) {
            focusRingItem = null;
            return;
        }
        const it = descriptorItem(list[focusIndex]);
        if (!it) {
            focusRingItem = null;
            return;
        }
        const p = it.mapToItem(dashSurface, 0, 0);
        focusRingItem = it;
        focusRingX = p.x;
        focusRingY = p.y;
        focusRingW = it.width;
        focusRingH = it.height;
    }

    function moveFocus(dx, dy) {
        if (activeTab === 0)
            return false;
        const list = visibleFocusDescriptors();
        if (list.length === 0)
            return false;
        if (focusIndex < 0 || focusIndex >= list.length) {
            focusIndex = 0;
            updateFocusRing();
            return true;
        }
        const cur = list[focusIndex];
        const curItem = descriptorItem(cur);
        if (!curItem)
            return false;

        // Los sliders ajustan con las flechas de su eje; el otro eje mueve el foco.
        if (cur.kind === "vslider" && dy !== 0) {
            adjustFocus(dy * 0.05);
            return true;
        }
        if (cur.kind === "hslider" && dx !== 0) {
            adjustFocus(dx * 0.05);
            return true;
        }

        const c = focusItemCenter(curItem);
        let best = -1;
        let bestScore = Infinity;
        for (let i = 0; i < list.length; i++) {
            if (i === focusIndex)
                continue;
            const it = descriptorItem(list[i]);
            if (!it)
                continue;
            const p = focusItemCenter(it);
            const vx = p.x - c.x;
            const vy = p.y - c.y;
            if (dx !== 0 && Math.sign(vx) !== dx)
                continue;
            if (dy !== 0 && Math.sign(vy) !== dy)
                continue;
            const primary = Math.abs(dx !== 0 ? vx : vy);
            const secondary = Math.abs(dx !== 0 ? vy : vx);
            if (primary < 2)
                continue;
            const score = primary + secondary * 2.5;
            if (score < bestScore) {
                bestScore = score;
                best = i;
            }
        }
        if (best >= 0) {
            focusIndex = best;
            updateFocusRing();
        }
        return true;
    }

    function focusEdge(toFirst) {
        if (activeTab === 0)
            return false;
        const list = visibleFocusDescriptors();
        if (list.length === 0)
            return false;
        focusIndex = toFirst ? 0 : list.length - 1;
        updateFocusRing();
        return true;
    }

    function adjustFocus(delta) {
        const list = visibleFocusDescriptors();
        if (focusIndex < 0 || focusIndex >= list.length)
            return;
        const fd = list[focusIndex];
        if (fd.id === "vol" || fd.id === "outVol") {
            if (!sinkReady)
                return;
            const next = Math.max(0.0, Math.min(1.0, (defaultSink.audio.volume || 0) + delta));
            defaultSink.audio.muted = false;
            defaultSink.audio.volume = next;
        } else if (fd.id === "mic" || fd.id === "micVol") {
            if (!sourceReady)
                return;
            const next = Math.max(0.0, Math.min(1.0, (defaultSource.audio.volume || 0) + delta));
            defaultSource.audio.muted = false;
            defaultSource.audio.volume = next;
        } else if (fd.id === "bright") {
            const base = sysState ? sysState.brightnessPercent : 50;
            const pct = Math.max(5, Math.min(100, Math.round(base + delta * 100)));
            if (sysState)
                sysState.brightnessPercent = pct;
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", pct + "%"]);
        }
    }

    function activateFocus() {
        const list = visibleFocusDescriptors();
        if (focusIndex < 0 || focusIndex >= list.length)
            return false;
        const fd = list[focusIndex];
        switch (fd.id) {
        case "net":
            closeRequested();
            runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"]);
            break;
        case "bt":
            closeRequested();
            Quickshell.execDetached(["blueman-manager"]);
            break;
        case "dnd":
            toggleDndRequested();
            break;
        case "nightlight":
            runScript("nightlight-toggle.sh", []);
            if (sysState)
                sysState.refreshAll();
            break;
        case "idle":
            toggleIdleInhibitRequested();
            break;
        case "powerprofile":
            cyclePowerProfile();
            break;
        case "perf":
            tabSelected(4);
            break;
        case "vol":
        case "outVol":
            if (sinkReady)
                defaultSink.audio.muted = !defaultSink.audio.muted;
            break;
        case "mic":
        case "micVol":
            if (sourceReady)
                defaultSource.audio.muted = !defaultSource.audio.muted;
            break;
        case "bright":
            break;
        case "mediaPrev":
            if (activePlayer && activePlayer.canGoPrevious)
                activePlayer.previous();
            break;
        case "mediaPlay":
            if (activePlayer && activePlayer.canTogglePlaying)
                activePlayer.togglePlaying();
            break;
        case "mediaNext":
            if (activePlayer && activePlayer.canGoNext)
                activePlayer.next();
            break;
        case "calPrev": {
            const wasCurrent = isViewingCurrentMonth;
            shiftMonth(-1);
            if (wasCurrent !== isViewingCurrentMonth)
                focusIndex = -1;
            break;
        }
        case "calToday":
            resetToToday();
            focusIndex = -1;
            break;
        case "calNext": {
            const wasCurrent = isViewingCurrentMonth;
            shiftMonth(1);
            if (wasCurrent !== isViewingCurrentMonth)
                focusIndex = -1;
            break;
        }
        case "player":
            selectedPlayerIndex = fd.data;
            break;
        case "capture":
            actionActivated(fd.data);
            break;
        case "aiService":
            runScript("ai.sh", ["service", "toggle"]);
            break;
        case "aiQuick":
        case "aiContext":
            runAiAction(fd.data.cmd, fd.data.delay);
            break;
        case "dev":
        case "sysUtil":
            actionActivated(fd.data);
            break;
        case "btop":
            closeRequested();
            Quickshell.execDetached(["foot", "-e", "btop"]);
            break;
        case "tray": {
            if (fd.data)
                fd.data.activate();
            break;
        }
        case "pavu":
            closeRequested();
            Quickshell.execDetached(["pavucontrol"]);
            break;
        }
        return true;
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (dashWin.panelOpen)
                dashWin.revealed = true;
        }
    }

    Timer {
        id: mediaProgressTimer
        interval: 1000
        repeat: true
        running: dashWin.panelOpen && dashWin.activeTab === 3 && Boolean(dashWin.activePlayer && dashWin.activePlayer.isPlaying)
        onTriggered: dashWin.mediaTick += 1
    }

    Timer {
        id: focusTimer
        interval: 20
        repeat: false
        onTriggered: dashWin.applyCurrentFocus()
    }

    // Reubica el anillo de foco mientras se animan las transiciones de pestaña.
    Timer {
        id: focusRingTimer
        interval: 80
        repeat: true
        running: dashWin.panelOpen && dashWin.activeTab !== 0 && dashWin.focusIndex >= 0
        onTriggered: dashWin.updateFocusRing()
    }

    function applyCurrentFocus() {
        if (!panelOpen)
            return;
        if (activeTab === 0) {
            globalSearchInput.forceActiveFocus();
            globalSearchInput.cursorPosition = globalSearchInput.text.length;
        } else {
            dashScope.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        resetToToday();
        if (panelOpen) {
            globalSearchInput.text = "";
            searchQuery = "";
            tabApps.resetSelection();
            applyCurrentFocus();
            focusTimer.restart();
            revealTimer.restart();
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            resetToToday();
            globalSearchInput.text = "";
            searchQuery = "";
            tabApps.resetSelection();
            focusIndex = -1;
            helpOpen = false;
            updateFocusRing();
            applyCurrentFocus();
            focusTimer.restart();
            revealTimer.restart();
        } else {
            revealTimer.stop();
            focusTimer.stop();
            focusIndex = -1;
            helpOpen = false;
            focusRingItem = null;
            revealed = false;
        }
    }

    onActiveTabChanged: {
        focusIndex = -1;
        helpOpen = false;
        updateFocusRing();
        if (panelOpen)
            focusTimer.restart();
    }

    onFocusIndexChanged: updateFocusRing()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dashboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    FocusScope {
        id: dashScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (dashWin.helpOpen) {
                dashWin.helpOpen = false;
                return;
            }
            dashWin.closeRequested();
        }
        Keys.onPressed: event => {
            const tabCount = dashWin.tabMeta.length;

            if (event.key === Qt.Key_F1) {
                dashWin.helpOpen = !dashWin.helpOpen;
                event.accepted = true;
                return;
            }
            if (dashWin.helpOpen) {
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_1) {
                dashWin.tabSelected(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                dashWin.tabSelected(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                dashWin.tabSelected(2);
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                dashWin.tabSelected(3);
                event.accepted = true;
            } else if (event.key === Qt.Key_5) {
                dashWin.tabSelected(4);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                dashWin.tabSelected((dashWin.activeTab + 1) % tabCount);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                dashWin.tabSelected((dashWin.activeTab + tabCount - 1) % tabCount);
                event.accepted = true;
            } else if (
                dashWin.activeTab !== 0 &&
                (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                 event.key === Qt.Key_Up || event.key === Qt.Key_Down) &&
                !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            ) {
                event.accepted = dashWin.moveFocus(
                    event.key === Qt.Key_Left ? -1 : (event.key === Qt.Key_Right ? 1 : 0),
                    event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0)
                );
            } else if (dashWin.activeTab !== 0 && (event.key === Qt.Key_Home || event.key === Qt.Key_End)) {
                event.accepted = dashWin.focusEdge(event.key === Qt.Key_Home);
            } else if (
                dashWin.activeTab !== 0 &&
                dashWin.focusIndex >= 0 &&
                (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            ) {
                event.accepted = dashWin.activateFocus();
            } else if (event.key === Qt.Key_Slash || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K)) {
                dashWin.tabSelected(0);
                focusTimer.restart();
                event.accepted = true;
            } else if (
                dashWin.activeTab !== 0 &&
                !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) &&
                event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
            ) {
                globalSearchInput.text = event.text;
                dashWin.searchQuery = event.text;
                dashWin.tabSelected(0);
                focusTimer.restart();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: dashWin.panelOpen
            onClicked: dashWin.closeRequested()
        }

        TopBarOverlayBridge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: dashWin.barH
            z: 50
            barH: dashWin.barH
            screen: dashWin.screen
            active: dashWin.panelOpen
            currentTarget: dashWin.activeTab === 0 ? "apps" : (dashWin.activeTab === 1 ? "ai" : (dashWin.activeTab === 4 ? "system" : "dashboard"))
            barHitTester: dashWin.barHitTester
            onMenuHovered: (scr, target) => dashWin.barMenuHovered(scr, target)
            onMenuClicked: (scr, target, btn) => dashWin.barMenuClicked(scr, target, btn)
            onWorkspaceClicked: wsId => dashWin.barWorkspaceClicked(wsId)
            onOutsideClicked: dashWin.closeRequested()
        }

        // Borde sutil inferior de la barra superior a ambos lados del desplegable
        Rectangle {
            visible: !dashWin.floatingMode
            anchors.left: parent.left
            anchors.right: dashDock.left
            anchors.rightMargin: dashDock.height >= dashWin.cornerSize ? dashWin.cornerSize : 0
            y: dashWin.barH - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: !dashWin.floatingMode
            anchors.left: dashDock.right
            anchors.leftMargin: dashDock.height >= dashWin.cornerSize ? dashWin.cornerSize : 0
            anchors.right: parent.right
            y: dashWin.barH - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Popout central grande acoplado a la barra superior (o flotante a 8px en modo islas)
        Item {
            id: dashDock
            anchors.top: parent.top
            anchors.topMargin: dashWin.floatingMode ? (dashWin.barH + 8) : dashWin.barH
            anchors.horizontalCenter: parent.horizontalCenter
            width: dashWin.panelWidth
            height: dashWin.revealed ? (dashBody.implicitHeight + 32) : 0
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animTab : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: dashWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: dashWin.cornerSize
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.right: dashSurface.left
                visible: !dashWin.floatingMode && dashDock.height >= dashWin.cornerSize
            }

            ConcaveCorner {
                position: "top-left"
                size: dashWin.cornerSize
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.left: dashSurface.right
                visible: !dashWin.floatingMode && dashDock.height >= dashWin.cornerSize
            }

            Item {
                id: dashSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))
                readonly property real halfB: Theme.popoutBorderWidth / 2.0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: dashWin.floatingMode ? parent.height : (parent.height + Theme.radiusLarge)
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: dashWin.floatingMode ? Theme.popoutBorderWidth : 0
                    border.color: Theme.popoutBorder
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: !dashWin.floatingMode && dashDock.height >= Theme.concaveRadius

                    ShapePath {
                        strokeWidth: Theme.popoutBorderWidth
                        strokeColor: Theme.popoutBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: dashSurface.halfB
                        startY: Theme.concaveRadius

                        PathLine {
                            x: dashSurface.halfB
                            y: dashSurface.height - dashSurface.cornerR
                        }
                        PathArc {
                            x: dashSurface.cornerR
                            y: dashSurface.height - dashSurface.halfB
                            radiusX: dashSurface.cornerR - dashSurface.halfB
                            radiusY: dashSurface.cornerR - dashSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: dashSurface.width - dashSurface.cornerR
                            y: dashSurface.height - dashSurface.halfB
                        }
                        PathArc {
                            x: dashSurface.width - dashSurface.halfB
                            y: dashSurface.height - dashSurface.cornerR
                            radiusX: dashSurface.cornerR - dashSurface.halfB
                            radiusY: dashSurface.cornerR - dashSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: dashSurface.width - dashSurface.halfB
                            y: Theme.concaveRadius
                        }
                    }
                }

                // Absorbe clics internos
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: dashBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    y: dashWin.revealed ? 14 : -14
                    spacing: 16

                    Behavior on y {
                        NumberAnimation {
                            duration: dashWin.revealed ? Theme.animPop : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: dashWin.revealed ? Theme.curveExpressive : Theme.curveAccel
                        }
                    }

                    // =========================================================
                    // CABECERA CON PESTAÑAS + INDICADOR DESLIZANTE
                    // =========================================================
                    // Tabs estilo Caelestia con indicador deslizante Material 3
                    Item {
                        id: tabStrip
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        readonly property int tabCount: dashWin.tabMeta.length
                        readonly property real tabW: width / Math.max(1, tabCount)
                        property int pendingHoverTab: -1
                        property int entryTab: -1
                        property real entryX: -1
                        property real entryY: -1

                        Timer {
                            id: tabHoverTimer
                            interval: 80
                            repeat: false
                            onTriggered: {
                                if (dashWin.panelOpen && !dashWin.helpOpen
                                        && tabStrip.pendingHoverTab >= 0
                                        && tabStrip.pendingHoverTab !== dashWin.activeTab) {
                                    dashWin.tabSelected(tabStrip.pendingHoverTab);
                                }
                                tabStrip.pendingHoverTab = -1;
                            }
                        }

                        Connections {
                            target: dashWin
                            function onPanelOpenChanged() {
                                if (!dashWin.panelOpen) {
                                    tabHoverTimer.stop();
                                    tabStrip.pendingHoverTab = -1;
                                    tabStrip.entryTab = -1;
                                    tabStrip.entryX = -1;
                                    tabStrip.entryY = -1;
                                }
                            }
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
                            x: dashWin.activeTab * tabStrip.tabW + 4
                            y: 2
                            width: Math.max(0, tabStrip.tabW - 8)
                            height: tabStrip.height - 8
                            radius: Theme.radiusSmall
                            color: Theme.surfaceContainer

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveDecel
                                }
                            }
                        }

                        Rectangle {
                            width: Math.min(76, Math.max(40, tabStrip.tabW * 0.48))
                            height: 3
                            radius: 2
                            color: Theme.primary
                            anchors.bottom: parent.bottom
                            x: dashWin.activeTab * tabStrip.tabW + (tabStrip.tabW - width) / 2

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveDecel
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: dashWin.tabMeta

                                Item {
                                    id: tabBtn
                                    required property var modelData
                                    required property int index
                                    readonly property bool isCurrent: dashWin.activeTab === index

                                    width: tabStrip.tabW
                                    height: tabStrip.height

                                    Row {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        spacing: 7

                                        Text {
                                            text: tabBtn.modelData.glyph
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: tabBtn.isCurrent ? Theme.primary : Theme.fgSubtle
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }

                                        Text {
                                            text: tabBtn.modelData.label
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: tabBtn.isCurrent ? Font.Bold : Font.Medium
                                            color: tabBtn.isCurrent ? Theme.fg : Theme.fgSubtle
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            tabStrip.entryTab = tabBtn.index;
                                            tabStrip.entryX = tabMouse.mouseX;
                                            tabStrip.entryY = tabMouse.mouseY;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!dashWin.panelOpen || dashWin.helpOpen)
                                                return;
                                            if (tabStrip.entryTab === tabBtn.index && tabStrip.entryX >= 0) {
                                                if (Math.abs(mouse.x - tabStrip.entryX) + Math.abs(mouse.y - tabStrip.entryY) < 0.5)
                                                    return;
                                                tabStrip.entryTab = -1;
                                                tabStrip.entryX = -1;
                                                tabStrip.entryY = -1;
                                            }
                                            if (tabBtn.index !== dashWin.activeTab) {
                                                if (tabStrip.pendingHoverTab !== tabBtn.index || !tabHoverTimer.running) {
                                                    tabStrip.pendingHoverTab = tabBtn.index;
                                                    tabHoverTimer.restart();
                                                }
                                            } else {
                                                tabHoverTimer.stop();
                                                tabStrip.pendingHoverTab = -1;
                                            }
                                        }
                                        onExited: {
                                            if (tabStrip.pendingHoverTab === tabBtn.index) {
                                                tabHoverTimer.stop();
                                                tabStrip.pendingHoverTab = -1;
                                            }
                                            if (tabStrip.entryTab === tabBtn.index) {
                                                tabStrip.entryTab = -1;
                                                tabStrip.entryX = -1;
                                                tabStrip.entryY = -1;
                                            }
                                        }
                                        onClicked: {
                                            tabHoverTimer.stop();
                                            tabStrip.pendingHoverTab = -1;
                                            dashWin.tabSelected(tabBtn.index);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // CUERPO DE PESTAÑAS (altura y transición fluidas)
                    // =========================================================
                    Item {
                        id: tabContentHost
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            if (dashWin.activeTab === 0) return 376;
                            if (dashWin.activeTab === 1) return tabDevAi.implicitHeight;
                            if (dashWin.activeTab === 2) return tabDashboard.implicitHeight;
                            if (dashWin.activeTab === 3) return tabMedia.implicitHeight;
                            return tabSystem.implicitHeight;
                        }
                        clip: true

                        // -----------------------------------------------------
                        // TAB 0: APPS Y BUSCADOR GLOBAL
                        // -----------------------------------------------------
                        NotchAppsTab {
                            id: tabApps
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 376
                            y: 0
                            opacity: dashWin.activeTab === 0 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 0

                            searchQuery: dashWin.searchQuery
                            activeTheme: dashWin.activeTheme
                            recordingActive: Boolean(dashWin.sysState && dashWin.sysState.recordingActive)
                            nightlightActive: Boolean(dashWin.sysState && dashWin.sysState.nightlightActive)

                            onAppActivated: entry => dashWin.appActivated(entry)
                            onActionActivated: act => dashWin.actionActivated(act)

                            Behavior on opacity {
                                enabled: dashWin.activeTab === 0
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 2: DASHBOARD (estilo Caelestia + Quick Controls)
                        // -----------------------------------------------------
                        RowLayout {
                            id: tabDashboard
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: 0
                            opacity: dashWin.activeTab === 2 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 2
                            spacing: 12

                            Behavior on opacity {
                                enabled: dashWin.activeTab === 2
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }

                            // COLUMNA PRINCIPAL IZQUIERDA (Estado + Identidad arriba · Calendario + Sliders abajo)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 12

                                // Fila superior: Conectividad/Estado + Tarjeta OS/Hyprland/Uptime
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Tarjeta Resumen de Rendimiento (CPU / RAM / Temp · clic abre Tab 2)
                                    Rectangle {
                                        id: dashPerfSummaryCard
                                        readonly property int cpuPct: dashWin.sysState ? dashWin.sysState.cpuUsage : 0
                                        readonly property int memPct: (dashWin.sysState && dashWin.sysState.memTotalGiB > 0)
                                            ? Math.round((dashWin.sysState.memUsedGiB * 100) / dashWin.sysState.memTotalGiB)
                                            : 0
                                        readonly property int tempC: dashWin.sysState ? dashWin.sysState.cpuTempC : -1
                                        Layout.preferredWidth: 216
                                        Layout.preferredHeight: 112
                                        radius: Theme.radiusMedium
                                        color: perfSumM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: "󰓅"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    color: Theme.primary
                                                }

                                                Text {
                                                    text: "Rendimiento"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: Theme.fg
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    visible: dashPerfSummaryCard.tempC >= 0
                                                    height: 20
                                                    width: tempChipTxt.implicitWidth + 10
                                                    radius: Theme.radiusFull
                                                    color: dashPerfSummaryCard.tempC >= 80 ? Theme.errorContainer : Theme.surfaceContainerHighest

                                                    Text {
                                                        id: tempChipTxt
                                                        anchors.centerIn: parent
                                                        text: dashPerfSummaryCard.tempC + "°C"
                                                        font.family: Theme.monoFontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        color: dashPerfSummaryCard.tempC >= 80 ? Theme.fgOnErrorContainer : Theme.fgMuted
                                                    }
                                                }
                                            }

                                            // Barra compacta CPU
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.preferredWidth: 32
                                                    text: "CPU"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: Theme.fgSubtle
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 7
                                                    radius: 4
                                                    color: Theme.surfaceContainerHighest

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(dashPerfSummaryCard.cpuPct > 0 ? 7 : 0, parent.width * Math.min(1.0, dashPerfSummaryCard.cpuPct / 100.0))
                                                        radius: 4
                                                        color: dashPerfSummaryCard.cpuPct >= 85 ? Theme.error : Theme.primary
                                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }

                                                Text {
                                                    Layout.preferredWidth: 36
                                                    horizontalAlignment: Text.AlignRight
                                                    text: dashPerfSummaryCard.cpuPct + "%"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: dashPerfSummaryCard.cpuPct >= 85 ? Theme.error : Theme.fg
                                                }
                                            }

                                            // Barra compacta RAM
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.preferredWidth: 32
                                                    text: "RAM"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: Theme.fgSubtle
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 7
                                                    radius: 4
                                                    color: Theme.surfaceContainerHighest

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(dashPerfSummaryCard.memPct > 0 ? 7 : 0, parent.width * Math.min(1.0, dashPerfSummaryCard.memPct / 100.0))
                                                        radius: 4
                                                        color: dashPerfSummaryCard.memPct >= 90 ? Theme.error : Theme.secondary
                                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }

                                                Text {
                                                    Layout.preferredWidth: 36
                                                    horizontalAlignment: Text.AlignRight
                                                    text: dashPerfSummaryCard.memPct + "%"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: dashPerfSummaryCard.memPct >= 90 ? Theme.error : Theme.fg
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: perfSumM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.tabSelected(4)
                                        }
                                    }

                                    // Tarjeta Identidad (Debian / Hyprland / Uptime / Batería opcional)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredHeight: 112
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 50
                                                radius: 25
                                                color: Theme.primaryContainer

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 26
                                                    color: Theme.fgOnPrimaryContainer
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "  " + (dashWin.sysState ? dashWin.sysState.osLabel : "Debian Stable")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: Theme.fg
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "  Hyprland · " + (dashWin.sysState && dashWin.sysState.hostName
                                                        ? (dashWin.sysState.userName + "@" + dashWin.sysState.hostName)
                                                        : (dashWin.sysState ? dashWin.sysState.userName : "sesión"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    color: Theme.fgMuted
                                                    elide: Text.ElideRight
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Text {
                                                        text: "󰥔  activo " + (dashWin.sysState ? dashWin.sysState.uptimeText : "0m")
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        color: Theme.fgSubtle
                                                    }

                                                    Rectangle {
                                                        visible: dashWin.hasBattery
                                                        height: 20
                                                        width: batChipTxt.implicitWidth + 12
                                                        radius: Theme.radiusFull
                                                        color: dashWin.batteryCharging ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                                                        Text {
                                                            id: batChipTxt
                                                            anchors.centerIn: parent
                                                            text: (dashWin.batteryCharging ? "󰂄 " : "󰁹 ") + dashWin.batteryPct + "%"
                                                            font.family: Theme.monoFontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: dashWin.batteryCharging ? Theme.fgOnSecondaryContainer : Theme.fg
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Fila inferior estilo Caelestia: Calendario · Sliders verticales
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Calendario mensual interactivo
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 306
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            onWheel: wheel => {
                                                if (wheel.angleDelta.y > 0)
                                                    dashWin.shiftMonth(-1);
                                                else if (wheel.angleDelta.y < 0)
                                                    dashWin.shiftMonth(1);
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: cPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "‹"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 16
                                                        font.weight: Font.Bold
                                                        color: Theme.fg
                                                    }
                                                    MouseArea {
                                                        id: cPrevM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.shiftMonth(-1)
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: dashWin.monthNames[dashWin.displayMonth] + " " + dashWin.displayYear
                                                    elide: Text.ElideRight
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    color: Theme.fg
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.resetToToday()
                                                    }
                                                }

                                                Rectangle {
                                                    visible: !dashWin.isViewingCurrentMonth
                                                    Layout.preferredHeight: 24
                                                    Layout.preferredWidth: todayChipTxt.implicitWidth + 16
                                                    radius: Theme.radiusFull
                                                    color: todayChipM.containsMouse ? Theme.primary : Theme.primaryContainer
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                    Text {
                                                        id: todayChipTxt
                                                        anchors.centerIn: parent
                                                        text: "Hoy"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        color: todayChipM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer
                                                    }

                                                    MouseArea {
                                                        id: todayChipM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.resetToToday()
                                                    }
                                                }

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: cNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "›"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 16
                                                        font.weight: Font.Bold
                                                        color: Theme.fg
                                                    }
                                                    MouseArea {
                                                        id: cNextM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.shiftMonth(1)
                                                    }
                                                }
                                            }

                                            GridLayout {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                columns: 7
                                                columnSpacing: 2
                                                rowSpacing: 4

                                                Repeater {
                                                    model: dashWin.weekdayShort
                                                    Text {
                                                        required property string modelData
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: modelData
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.Bold
                                                        color: Theme.fgSubtle
                                                    }
                                                }

                                                Repeater {
                                                    model: dashWin.calendarCells
                                                    Rectangle {
                                                        id: calCell
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 32
                                                        radius: 16
                                                        color: modelData.isToday
                                                            ? Theme.primary
                                                            : (calCellM.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                        MouseArea {
                                                            id: calCellM
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: dashWin.openSystemCalendar(
                                                                calCell.modelData.year,
                                                                calCell.modelData.month,
                                                                calCell.modelData.day)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: String(modelData.day)
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: modelData.isToday ? Font.Bold : Font.Medium
                                                            color: modelData.isToday
                                                                ? Theme.fgOnPrimary
                                                                : (modelData.inMonth ? Theme.fg : Theme.fgSubtle)
                                                            opacity: modelData.inMonth ? 1.0 : 0.42
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Sliders verticales estilo Caelestia (Volumen · Mic · Brillo opcional)
                                    Rectangle {
                                        readonly property bool showBr: Boolean(dashWin.sysState && dashWin.sysState.hasBacklight)
                                        Layout.preferredWidth: showBr ? 154 : 110
                                        Layout.preferredHeight: 306
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 12

                                            // Slider Vertical 1: Volumen
                                            Column {
                                                spacing: 8

                                                Text {
                                                    width: 34
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: dashWin.sinkMuted ? "Mudo" : (dashWin.sinkVolumePct + "%")
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: (dashWin.sinkMuted || dashWin.sinkVolumePct > 100)
                                                        ? Theme.error
                                                        : ((volSliderM.containsMouse || volSliderM.pressed) ? Theme.fg : Theme.fgSubtle)
                                                }

                                                Item {
                                                    width: 24
                                                    height: 204
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            height: dashWin.sinkMuted
                                                                ? 0
                                                                : Math.max(18, parent.height * Math.min(1.0, dashWin.sinkVolumePct / 100.0))
                                                            radius: 12
                                                            color: dashWin.sinkVolumePct > 100 ? Theme.error : Theme.primary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: volSliderM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            if (!dashWin.sinkReady) return;
                                                            const frac = Math.max(0.0, Math.min(1.0, 1.0 - (my / Math.max(1, height))));
                                                            dashWin.defaultSink.audio.muted = false;
                                                            dashWin.defaultSink.audio.volume = frac;
                                                        }
                                                        onPressed: mouse => applyY(mouse.y)
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onWheel: wheel => {
                                                            if (!dashWin.sinkReady) return;
                                                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                                            dashWin.defaultSink.audio.muted = false;
                                                            dashWin.defaultSink.audio.volume = Math.max(0.0, Math.min(1.0, (dashWin.defaultSink.audio.volume || 0) + step));
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: dashWin.sinkMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: dashWin.sinkMuted ? "󰖁" : "󰕾"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 14
                                                        color: dashWin.sinkMuted ? Theme.fgOnErrorContainer : Theme.primary
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (dashWin.sinkReady)
                                                                dashWin.defaultSink.audio.muted = !dashWin.defaultSink.audio.muted;
                                                        }
                                                    }
                                                }
                                            }

                                            // Slider Vertical 2: Micrófono
                                            Column {
                                                spacing: 8

                                                Text {
                                                    width: 34
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: dashWin.sourceMuted ? "Mudo" : (dashWin.sourceVolumePct + "%")
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: dashWin.sourceMuted
                                                        ? Theme.error
                                                        : ((micSliderM.containsMouse || micSliderM.pressed) ? Theme.fg : Theme.fgSubtle)
                                                }

                                                Item {
                                                    width: 24
                                                    height: 204
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            height: dashWin.sourceMuted
                                                                ? 0
                                                                : Math.max(18, parent.height * Math.min(1.0, dashWin.sourceVolumePct / 100.0))
                                                            radius: 12
                                                            color: Theme.secondary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: micSliderM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            if (!dashWin.sourceReady) return;
                                                            const frac = Math.max(0.0, Math.min(1.0, 1.0 - (my / Math.max(1, height))));
                                                            dashWin.defaultSource.audio.muted = false;
                                                            dashWin.defaultSource.audio.volume = frac;
                                                        }
                                                        onPressed: mouse => applyY(mouse.y)
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onWheel: wheel => {
                                                            if (!dashWin.sourceReady) return;
                                                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                                            dashWin.defaultSource.audio.muted = false;
                                                            dashWin.defaultSource.audio.volume = Math.max(0.0, Math.min(1.0, (dashWin.defaultSource.audio.volume || 0) + step));
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: dashWin.sourceMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: dashWin.sourceMuted ? "󰍭" : "󰍬"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 14
                                                        color: dashWin.sourceMuted ? Theme.fgOnErrorContainer : Theme.secondary
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (dashWin.sourceReady)
                                                                dashWin.defaultSource.audio.muted = !dashWin.defaultSource.audio.muted;
                                                        }
                                                    }
                                                }
                                            }

                                            // Slider Vertical 3: Brillo (solo equipos con backlight)
                                            Column {
                                                visible: Boolean(dashWin.sysState && dashWin.sysState.hasBacklight)
                                                spacing: 8

                                                Text {
                                                    width: 34
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: (dashWin.sysState ? dashWin.sysState.brightnessPercent : 0) + "%"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: (brSliderM.containsMouse || brSliderM.pressed) ? Theme.fg : Theme.fgSubtle
                                                }

                                                Item {
                                                    width: 24
                                                    height: 204
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            readonly property int pct: dashWin.sysState ? dashWin.sysState.brightnessPercent : 0
                                                            height: Math.max(18, parent.height * Math.min(1.0, pct / 100.0))
                                                            radius: 12
                                                            color: Theme.tertiary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: brSliderM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            const pct = Math.max(5, Math.min(100, Math.round((1.0 - (my / Math.max(1, height))) * 100)));
                                                            if (dashWin.sysState)
                                                                dashWin.sysState.brightnessPercent = pct;
                                                            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", pct + "%"]);
                                                        }
                                                        onPressed: mouse => {
                                                            dashWin.draggingBrightness = true;
                                                            applyY(mouse.y);
                                                        }
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onReleased: dashWin.draggingBrightness = false
                                                    }
                                                }

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰃠"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 14
                                                        color: Theme.tertiary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // COLUMNA DERECHA: Quick Toggles 2x3 + Media compacta estilo Caelestia
                            ColumnLayout {
                                Layout.preferredWidth: 288
                                Layout.minimumWidth: 288
                                Layout.maximumWidth: 288
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                                spacing: 12

                                // Grilla 2x3 de controles rápidos
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 8
                                    rowSpacing: 10

                                    // Red / VPN
                                    Rectangle {
                                        id: qNetTile
                                        readonly property bool active: Boolean(dashWin.sysState && dashWin.sysState.netKind !== "disconnected")
                                        readonly property bool hasVpn: Boolean(dashWin.sysState && dashWin.sysState.vpnName.length > 0)
                                        readonly property color tileFg: active
                                            ? (qNetM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qNetM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qNetM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                readonly property string kind: dashWin.sysState ? dashWin.sysState.netKind : "disconnected"
                                                text: qNetTile.hasVpn ? "󰒃" : (kind === "wifi" ? "" : (kind === "ethernet" ? "󰈀" : "󰪎"))
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: qNetTile.active ? qNetTile.tileFg : Theme.fgSubtle
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: qNetTile.hasVpn ? "VPN" : "Red"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qNetTile.tileFg
                                                }
                                                Text {
                                                    text: qNetTile.hasVpn
                                                        ? dashWin.sysState.vpnName
                                                        : (dashWin.sysState && dashWin.sysState.netLabel ? dashWin.sysState.netLabel : "Sin red")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: qNetTile.active ? qNetTile.tileFg : Theme.fgSubtle
                                                    opacity: qNetTile.active ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qNetM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.closeRequested();
                                                dashWin.runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"]);
                                            }
                                        }
                                    }

                                    // Bluetooth
                                    Rectangle {
                                        id: qBtTile
                                        readonly property bool active: dashWin.btEnabled
                                        readonly property color tileFg: active
                                            ? (qBtM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qBtM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qBtM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.btConnectedDevice ? "󰂱" : (dashWin.btEnabled ? "󰂯" : "󰂲")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: qBtTile.active ? qBtTile.tileFg : Theme.fgSubtle
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Bluetooth"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qBtTile.tileFg
                                                }
                                                Text {
                                                    text: !dashWin.hasBluetooth
                                                        ? "Ausente"
                                                        : (dashWin.btConnectedDevice
                                                            ? String(dashWin.btConnectedDevice.name || dashWin.btConnectedDevice.deviceName || "Conectado")
                                                            : (dashWin.btEnabled ? "Activo" : "Apagado"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: qBtTile.active ? qBtTile.tileFg : Theme.fgSubtle
                                                    opacity: qBtTile.active ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qBtM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.closeRequested();
                                                Quickshell.execDetached(["blueman-manager"]);
                                            }
                                        }
                                    }

                                    // No molestar
                                    Rectangle {
                                        id: qDndTile
                                        readonly property color tileFg: dashWin.dndEnabled
                                            ? (qDndM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: dashWin.dndEnabled
                                            ? (qDndM.containsMouse ? Theme.error : Theme.errorContainer)
                                            : (qDndM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.dndEnabled ? "󰂛" : "󰂚"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: dashWin.dndEnabled ? qDndTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "No molestar"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qDndTile.tileFg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: dashWin.dndEnabled ? "Silenciado" : "Normal"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: dashWin.dndEnabled ? qDndTile.tileFg : Theme.fgSubtle
                                                    opacity: dashWin.dndEnabled ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qDndM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.toggleDndRequested()
                                        }
                                    }

                                    // Luz nocturna
                                    Rectangle {
                                        id: qNlTile
                                        readonly property bool active: Boolean(dashWin.sysState && dashWin.sysState.nightlightActive)
                                        readonly property color tileFg: active
                                            ? (qNlM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qNlM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qNlM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: qNlTile.active ? qNlTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Luz nocturna"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qNlTile.tileFg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: qNlTile.active ? "4000K" : "Apagada"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: qNlTile.active ? qNlTile.tileFg : Theme.fgSubtle
                                                    opacity: qNlTile.active ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qNlM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.runScript("nightlight-toggle.sh", []);
                                                if (dashWin.sysState)
                                                    dashWin.sysState.refreshAll();
                                            }
                                        }
                                    }

                                    // Reposo (IdleInhibit)
                                    Rectangle {
                                        id: qIdleTile
                                        readonly property color tileFg: dashWin.idleInhibited
                                            ? (qIdleM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: dashWin.idleInhibited
                                            ? (qIdleM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                            : (qIdleM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.idleInhibited ? "󰅶" : "󰾪"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: dashWin.idleInhibited ? qIdleTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Reposo"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qIdleTile.tileFg
                                                }
                                                Text {
                                                    text: dashWin.idleInhibited ? "Inhibido" : "Auto"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: dashWin.idleInhibited ? qIdleTile.tileFg : Theme.fgSubtle
                                                    opacity: dashWin.idleInhibited ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qIdleM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.toggleIdleInhibitRequested()
                                        }
                                    }

                                    // Perfil de energía
                                    Rectangle {
                                        id: qPpTile
                                        readonly property bool isPerf: PowerProfiles.profile === PowerProfile.Performance
                                        readonly property bool isSaver: PowerProfiles.profile === PowerProfile.PowerSaver
                                        readonly property color tileFg: isPerf
                                            ? (qPpM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                            : (isSaver
                                                ? (qPpM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                                : Theme.fg)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: Theme.radiusMedium
                                        color: isPerf
                                            ? (qPpM.containsMouse ? Theme.error : Theme.errorContainer)
                                            : (isSaver
                                                ? (qPpM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                                : (qPpM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.powerProfileGlyph()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: (qPpTile.isPerf || qPpTile.isSaver) ? qPpTile.tileFg : Theme.primary
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Energía"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: qPpTile.tileFg
                                                }
                                                Text {
                                                    text: dashWin.powerProfileLabel()
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: (qPpTile.isPerf || qPpTile.isSaver) ? qPpTile.tileFg : Theme.fgSubtle
                                                    opacity: (qPpTile.isPerf || qPpTile.isSaver) ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qPpM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.cyclePowerProfile()
                                        }
                                    }
                                }

                                // Tarjeta Media estilo Caelestia (portada circular + pista + controles)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 210
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        ClippingRectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 78
                                            height: 78
                                            radius: 39
                                            antialiasing: true
                                            color: Theme.primaryContainer
                                            border.width: 2
                                            border.color: (dashWin.activePlayer && dashWin.activePlayer.isPlaying)
                                                ? Theme.primary
                                                : Theme.outlineVariant

                                            Image {
                                                id: tab0ArtImg
                                                anchors.fill: parent
                                                source: dashWin.activePlayer ? (dashWin.activePlayer.trackArtUrl || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: tab0ArtImg.status !== Image.Ready
                                                text: "󰎆"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 26
                                                color: Theme.fgOnPrimaryContainer
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: dashWin.tabSelected(2)
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackTitle || dashWin.activePlayer.identity || "Multimedia")
                                                    : "Sin reproducción"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackArtist || dashWin.activePlayer.identity || "Listo")
                                                    : ("Salida: " + (dashWin.sinkMuted ? "Mudo" : dashWin.sinkVolumePct + "%"))
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgSubtle
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 10

                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: 15
                                                color: dPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰒮"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    color: dashWin.activePlayer ? Theme.fg : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    id: dPrevM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoPrevious) dashWin.activePlayer.previous()
                                                }
                                            }

                                            Rectangle {
                                                width: 36
                                                height: 30
                                                radius: 15
                                                color: dashWin.activePlayer ? Theme.primary : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (dashWin.activePlayer && dashWin.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 16
                                                    color: dashWin.activePlayer ? Theme.fgOnPrimary : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    id: dPlayM
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (dashWin.activePlayer && dashWin.activePlayer.canTogglePlaying)
                                                            dashWin.activePlayer.togglePlaying();
                                                        else
                                                            dashWin.tabSelected(2);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: 15
                                                color: dNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰒭"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    color: dashWin.activePlayer ? Theme.fg : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    id: dNextM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoNext) dashWin.activePlayer.next()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 2: MEDIA, AUDIO Y CAPTURA DE PANTALLA
                        // -----------------------------------------------------
                        ColumnLayout {
                            id: tabMedia
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: 0
                            opacity: dashWin.activeTab === 3 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 3
                            spacing: 10

                            Behavior on opacity {
                                enabled: dashWin.activeTab === 3
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                            // Tarjeta izquierda: Reproductor MPRIS completo
                            Rectangle {
                                Layout.preferredWidth: 360
                                Layout.preferredHeight: 316
                                radius: Theme.radiusMedium
                                color: Theme.surfaceContainer

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    // Selector de reproductor si hay >1
                                    RowLayout {
                                        visible: dashWin.playersList.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            id: playerPillRepeater
                                            model: dashWin.playersList

                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                readonly property bool isSel: dashWin.activePlayer === modelData
                                                height: 26
                                                width: Math.min(148, pPillTxt.implicitWidth + 20)
                                                radius: Theme.radiusFull
                                                color: isSel ? Theme.primaryContainer : Theme.surfaceContainerHigh

                                                Text {
                                                    id: pPillTxt
                                                    anchors.centerIn: parent
                                                    width: Math.min(implicitWidth, 128)
                                                    text: String(modelData.identity || "Reproductor")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: isSel ? Font.Bold : Font.Medium
                                                    color: isSel ? Theme.fgOnPrimaryContainer : Theme.fgMuted
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: dashWin.selectedPlayerIndex = index
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    // Portada + info de pista
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 14

                                        ClippingRectangle {
                                            Layout.preferredWidth: 124
                                            Layout.preferredHeight: 124
                                            radius: Theme.radiusMedium
                                            antialiasing: true
                                            color: Theme.primaryContainer

                                            Image {
                                                id: tab1ArtImg
                                                anchors.fill: parent
                                                source: dashWin.activePlayer ? (dashWin.activePlayer.trackArtUrl || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: tab1ArtImg.status !== Image.Ready
                                                text: "󰎆"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 42
                                                color: Theme.fgOnPrimaryContainer
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Text {
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackTitle || dashWin.activePlayer.identity || "Sin título")
                                                    : "Ningún reproductor activo"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: Theme.fg
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackArtist || dashWin.activePlayer.identity || "")
                                                    : "Abrí un reproductor o navegador para controlar la reproducción"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                color: Theme.fgMuted
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: Boolean(dashWin.activePlayer && dashWin.activePlayer.trackAlbum)
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer ? String(dashWin.activePlayer.trackAlbum || "") : ""
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgSubtle
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    // Barra de progreso + tiempos
                                    ColumnLayout {
                                        id: mediaSeekBox
                                        Layout.fillWidth: true
                                        spacing: 4

                                        readonly property real trackLen: (dashWin.activePlayer && Number(dashWin.activePlayer.length) > 0)
                                            ? Number(dashWin.activePlayer.length) : 0
                                        readonly property real trackPos: {
                                            void(dashWin.mediaTick);
                                            return dashWin.activePlayer ? Math.max(0, Number(dashWin.activePlayer.position) || 0) : 0;
                                        }
                                        readonly property real posFrac: trackLen > 0 ? Math.max(0, Math.min(1, trackPos / trackLen)) : 0

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 6
                                                radius: 3
                                                color: Theme.surfaceContainerHighest

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: Math.max(mediaSeekBox.posFrac > 0 ? 6 : 0, parent.width * mediaSeekBox.posFrac)
                                                    radius: 3
                                                    color: Theme.primary
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: Boolean(dashWin.activePlayer && dashWin.activePlayer.canSeek && mediaSeekBox.trackLen > 0)
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: mouse => {
                                                    const frac = Math.max(0.0, Math.min(1.0, mouse.x / Math.max(1, width)));
                                                    dashWin.activePlayer.position = frac * mediaSeekBox.trackLen;
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: dashWin.formatTrackTime(mediaSeekBox.trackPos)
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: mediaSeekBox.trackLen > 0 ? dashWin.formatTrackTime(mediaSeekBox.trackLen) : "--:--"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgSubtle
                                            }
                                        }
                                    }

                                    // Controles grandes de transporte
                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 14

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: mPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒮"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                color: Theme.fg
                                            }
                                            MouseArea {
                                                id: mPrevM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoPrevious) dashWin.activePlayer.previous()
                                            }
                                        }

                                        Rectangle {
                                            width: 56
                                            height: 40
                                            radius: 20
                                            color: Theme.primary
                                            Text {
                                                anchors.centerIn: parent
                                                text: (dashWin.activePlayer && dashWin.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 20
                                                color: Theme.fgOnPrimary
                                            }
                                            MouseArea {
                                                id: mPlayM
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canTogglePlaying) dashWin.activePlayer.togglePlaying()
                                            }
                                        }

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: mNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒭"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                color: Theme.fg
                                            }
                                            MouseArea {
                                                id: mNextM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoNext) dashWin.activePlayer.next()
                                            }
                                        }
                                    }
                                }
                            }

                            // Columna derecha: Mezclador PipeWire (Volumen · Micrófono · pavucontrol)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 316
                                spacing: 10

                                // Tarjeta Volumen de salida
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 102
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "SALIDA DE AUDIO"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.6
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: dashWin.sinkReady
                                                    ? String(dashWin.defaultSink.description || dashWin.defaultSink.nickname || "Predeterminada")
                                                    : "No disponible"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgMuted
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 230
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34
                                                radius: 17
                                                color: dashWin.sinkMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: dashWin.sinkMuted ? "󰖁" : (dashWin.sinkVolumePct <= 33 ? "󰕿" : (dashWin.sinkVolumePct <= 66 ? "󰖀" : "󰕾"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 16
                                                    color: dashWin.sinkMuted ? Theme.fgOnErrorContainer : Theme.primary
                                                }
                                                MouseArea {
                                                    id: outMuteM
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.sinkReady) dashWin.defaultSink.audio.muted = !dashWin.defaultSink.audio.muted
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 14
                                                    radius: 7
                                                    color: Theme.surfaceContainerHighest
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: dashWin.sinkMuted ? 0 : Math.max(14, parent.width * Math.min(1.0, dashWin.sinkVolumePct / 100.0))
                                                        radius: 7
                                                        color: dashWin.sinkVolumePct > 100 ? Theme.error : Theme.primary
                                                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
                                                    }
                                                }
                                                MouseArea {
                                                    id: outSliderM
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function applyX(mx) {
                                                        if (!dashWin.sinkReady) return;
                                                        const frac = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                                        dashWin.defaultSink.audio.muted = false;
                                                        dashWin.defaultSink.audio.volume = frac;
                                                    }
                                                    onPressed: mouse => applyX(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
                                                }
                                            }

                                            Text {
                                                Layout.preferredWidth: 48
                                                horizontalAlignment: Text.AlignRight
                                                text: dashWin.sinkMuted ? "Mudo" : (dashWin.sinkVolumePct + "%")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: dashWin.sinkMuted ? Theme.error : Theme.fg
                                            }
                                        }
                                    }
                                }

                                // Tarjeta Micrófono
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 102
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "MICRÓFONO"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.6
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: dashWin.sourceReady
                                                    ? String(dashWin.defaultSource.description || dashWin.defaultSource.nickname || "Entrada")
                                                    : "No disponible"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgMuted
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 230
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34
                                                radius: 17
                                                color: dashWin.sourceMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: dashWin.sourceMuted ? "󰍭" : "󰍬"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 16
                                                    color: dashWin.sourceMuted ? Theme.fgOnErrorContainer : Theme.secondary
                                                }
                                                MouseArea {
                                                    id: micMuteM
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.sourceReady) dashWin.defaultSource.audio.muted = !dashWin.defaultSource.audio.muted
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 14
                                                    radius: 7
                                                    color: Theme.surfaceContainerHighest
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: dashWin.sourceMuted ? 0 : Math.max(14, parent.width * Math.min(1.0, dashWin.sourceVolumePct / 100.0))
                                                        radius: 7
                                                        color: Theme.secondary
                                                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
                                                    }
                                                }
                                                MouseArea {
                                                    id: micSliderHM
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function applyX(mx) {
                                                        if (!dashWin.sourceReady) return;
                                                        const frac = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                                        dashWin.defaultSource.audio.muted = false;
                                                        dashWin.defaultSource.audio.volume = frac;
                                                    }
                                                    onPressed: mouse => applyX(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
                                                }
                                            }

                                            Text {
                                                Layout.preferredWidth: 48
                                                horizontalAlignment: Text.AlignRight
                                                text: dashWin.sourceMuted ? "Mudo" : (dashWin.sourceVolumePct + "%")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: dashWin.sourceMuted ? Theme.error : Theme.fg
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Acción inferior: Mezclador pavucontrol
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: Theme.radiusFull
                                    color: pavuM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰓃  Abrir mezclador avanzado (pavucontrol)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: pavuM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                    }

                                    MouseArea {
                                        id: pavuM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dashWin.closeRequested();
                                            Quickshell.execDetached(["pavucontrol"]);
                                        }
                                    }
                                }
                            }
                            }

                            // Franja inferior: Captura, grabación, color y OCR
                            Text {
                                text: "CAPTURA Y PANTALLA"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgSubtle
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    id: capRepeater
                                    model: dashWin.captureActions

                                    Rectangle {
                                        id: capTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        radius: Theme.radiusMedium
                                        color: modelData.isRec
                                            ? Theme.error
                                            : (capM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: capTile.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: capTile.modelData.isRec
                                                    ? Theme.fgOnError
                                                    : (capM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.primary)
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    text: capTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: capTile.modelData.isRec
                                                        ? Theme.fgOnError
                                                        : (capM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    visible: capTile.modelData.shortcut !== ""
                                                    text: capTile.modelData.shortcut
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    color: capTile.modelData.isRec
                                                        ? Theme.fgOnError
                                                        : (capM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle)
                                                    opacity: capTile.modelData.isRec || capM.containsMouse ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: capM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.actionActivated(capTile.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 4: SISTEMA, TELEMETRÍA Y UTILIDADES
                        // -----------------------------------------------------
                        ColumnLayout {
                            id: tabSystem
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: 0
                            opacity: dashWin.activeTab === 4 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 4
                            spacing: 10

                            Behavior on opacity {
                                enabled: dashWin.activeTab === 4
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }

                            // 3 tarjetas métricas con sparklines en vivo
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                // CPU
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "  CPU"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                visible: dashWin.sysState && dashWin.sysState.cpuTempC >= 0
                                                text: (dashWin.sysState ? dashWin.sysState.cpuTempC : 0) + "°C"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 12
                                                color: (dashWin.sysState && dashWin.sysState.cpuTempC >= 80) ? Theme.error : Theme.fgSubtle
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: (dashWin.sysState ? dashWin.sysState.cpuUsage : 0) + "%"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 26
                                                font.weight: Font.Bold
                                                color: (dashWin.sysState && dashWin.sysState.cpuUsage >= 85) ? Theme.error : Theme.fg
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "carga " + (dashWin.sysState ? dashWin.sysState.loadAvg : "0.00")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgSubtle
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (dashWin.sysState && dashWin.sysState.cpuModel) ? dashWin.sysState.cpuModel : "Procesador"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.fgMuted
                                            elide: Text.ElideRight
                                        }

                                        // Sparkline de CPU (24 muestras)
                                        Row {
                                            id: cpuSparkRow
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 68
                                            spacing: 3

                                            Repeater {
                                                model: 24
                                                Item {
                                                    required property int index
                                                    readonly property var hist: dashWin.sysState ? dashWin.sysState.cpuHistory : []
                                                    readonly property int offset: Math.max(0, 24 - hist.length)
                                                    readonly property int val: index >= offset ? (hist[index - offset] || 0) : 0
                                                    width: Math.max(4, Math.floor((cpuSparkRow.width - 23 * 3) / 24))
                                                    height: 68

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: Math.max(3, Math.round(68 * Math.max(0, Math.min(100, parent.val)) / 100.0))
                                                        radius: 2
                                                        color: parent.val >= 85 ? Theme.error : (parent.val > 0 ? Theme.primary : Theme.surfaceContainerHighest)
                                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Memoria + Swap/zRAM
                                Rectangle {
                                    id: memPerfCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    readonly property int memPct: (dashWin.sysState && dashWin.sysState.memTotalGiB > 0)
                                        ? Math.round((dashWin.sysState.memUsedGiB * 100) / dashWin.sysState.memTotalGiB)
                                        : 0

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "󰍛  MEMORIA"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: Theme.secondary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: memPerfCard.memPct + "%"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.fgMuted
                                            }
                                        }

                                        Text {
                                            text: (dashWin.sysState ? dashWin.sysState.memUsedGiB.toFixed(1) : "0.0") + " / " +
                                                  (dashWin.sysState ? dashWin.sysState.memTotalGiB.toFixed(1) : "0.0") + " GiB"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 20
                                            font.weight: Font.Bold
                                            color: Theme.fg
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (dashWin.sysState && dashWin.sysState.swapTotalGiB > 0)
                                                ? ("Swap/zRAM: " + dashWin.sysState.swapUsedGiB.toFixed(1) + " / " + dashWin.sysState.swapTotalGiB.toFixed(1) + " GiB")
                                                : "Sin swap activo"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 11
                                            color: Theme.fgMuted
                                            elide: Text.ElideRight
                                        }

                                        // Sparkline de Memoria (24 muestras)
                                        Row {
                                            id: memSparkRow
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 68
                                            spacing: 3

                                            Repeater {
                                                model: 24
                                                Item {
                                                    required property int index
                                                    readonly property var hist: dashWin.sysState ? dashWin.sysState.memHistory : []
                                                    readonly property int offset: Math.max(0, 24 - hist.length)
                                                    readonly property int val: index >= offset ? (hist[index - offset] || 0) : 0
                                                    width: Math.max(4, Math.floor((memSparkRow.width - 23 * 3) / 24))
                                                    height: 68

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: Math.max(3, Math.round(68 * Math.max(0, Math.min(100, parent.val)) / 100.0))
                                                        radius: 2
                                                        color: parent.val >= 90 ? Theme.error : (parent.val > 0 ? Theme.secondary : Theme.surfaceContainerHighest)
                                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Disco + btop + Kernel
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "󰋊  SISTEMA"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: Theme.tertiary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: (dashWin.sysState && dashWin.sysState.kernelVersion) ? ("Linux " + dashWin.sysState.kernelVersion) : ""
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgSubtle
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Raíz /"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    color: Theme.fgMuted
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: (dashWin.sysState ? dashWin.sysState.diskUsed : "0G") + " / " +
                                                          (dashWin.sysState ? dashWin.sysState.diskTotal : "0G") + " (" +
                                                          (dashWin.sysState ? dashWin.sysState.diskPercent : 0) + "%)"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    color: Theme.fg
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 8
                                                radius: 4
                                                color: Theme.surfaceContainerHighest
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    readonly property int pct: dashWin.sysState ? dashWin.sysState.diskPercent : 0
                                                    width: Math.max(8, parent.width * Math.min(1.0, pct / 100.0))
                                                    radius: 4
                                                    color: pct >= 90 ? Theme.error : Theme.tertiary
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Botón Abrir btop
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 38
                                            radius: Theme.radiusFull
                                            color: openBtopM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerLow
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰄨  Abrir btop"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: openBtopM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                            }

                                            MouseArea {
                                                id: openBtopM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    dashWin.closeRequested();
                                                    Quickshell.execDetached(["foot", "-e", "btop"]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bandeja del sistema (ancho completo)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                                radius: Theme.radiusMedium
                                color: Theme.surfaceContainer

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 10

                                    Text {
                                        text: "BANDEJA"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.6
                                        color: Theme.fgSubtle
                                    }

                                    Text {
                                        visible: SystemTray.items.values.length === 0
                                        text: "Sin aplicaciones en segundo plano"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.fgSubtle
                                    }

                                    Flow {
                                        visible: SystemTray.items.values.length > 0
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            id: trayRepeater
                                            model: SystemTray.items

                                            Rectangle {
                                                required property var modelData
                                                height: 32
                                                width: trayItemRow.implicitWidth + 16
                                                radius: Theme.radiusFull
                                                color: trayItemM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                Row {
                                                    id: trayItemRow
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    Image {
                                                        width: 16
                                                        height: 16
                                                        source: dashWin.resolveTrayIcon(modelData.icon)
                                                        sourceSize.width: 16
                                                        sourceSize.height: 16
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: true
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        text: dashWin.trayItemLabel(modelData)
                                                        width: Math.min(implicitWidth, 160)
                                                        elide: Text.ElideRight
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                        color: Theme.fg
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }

                                                MouseArea {
                                                    id: trayItemM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                                    onClicked: mouse => {
                                                        if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu)) {
                                                            if (modelData.hasMenu) {
                                                                const pt = mapToItem(null, width / 2, height);
                                                                modelData.display(dashWin, Math.round(pt.x), Math.round(pt.y));
                                                            } else {
                                                                modelData.secondaryActivate();
                                                            }
                                                        } else if (mouse.button === Qt.MiddleButton) {
                                                            modelData.secondaryActivate();
                                                        } else {
                                                            modelData.activate();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Utilidades del sistema (3 columnas x 2 filas, sin repetir Dashboard)
                            Text {
                                text: "UTILIDADES DEL SISTEMA"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgSubtle
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    id: sysUtilRepeater
                                    model: dashWin.systemUtilActions

                                    Rectangle {
                                        id: sysUtilTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        radius: Theme.radiusMedium
                                        color: sysUtilM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Text {
                                                text: sysUtilTile.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: sysUtilM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.primary
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    text: sysUtilTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: sysUtilM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: sysUtilTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: sysUtilM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                                    opacity: sysUtilM.containsMouse ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: sysUtilM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.actionActivated(sysUtilTile.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 3: DEV & IA (OpenCode + herramientas dev)
                        // -----------------------------------------------------
                        ColumnLayout {
                            id: tabDevAi
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: 0
                            opacity: dashWin.activeTab === 1 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 1
                            spacing: 10

                            Behavior on opacity {
                                enabled: dashWin.activeTab === 1
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }

                            readonly property bool aiOn: Boolean(dashWin.sysState && dashWin.sysState.aiActive)
                            readonly property string aiDet: dashWin.sysState ? String(dashWin.sysState.aiDetail || "") : ""

                            // Barra de servicio OpenCode
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Theme.radiusFull
                                    color: tabDevAi.aiOn ? Theme.tertiaryContainer : Theme.surfaceContainer
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 8

                                        Text {
                                            text: "󰚩"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: tabDevAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.tertiary
                                        }
                                        Text {
                                            text: "OpenCode · Asistente IA"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: tabDevAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.fg
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: tabDevAi.aiOn
                                                ? (tabDevAi.aiDet ? ("Servicio activo · " + tabDevAi.aiDet) : "Servicio activo")
                                                : "Modo independiente"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 12
                                            color: tabDevAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.fgSubtle
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 40
                                    Layout.preferredWidth: aiSvcRow.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: tabDevAi.aiOn
                                        ? (aiSvcM.containsMouse ? Theme.errorContainer : Theme.surfaceContainer)
                                        : (aiSvcM.containsMouse ? Theme.tertiaryContainer : Theme.surfaceContainer)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Row {
                                        id: aiSvcRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: tabDevAi.aiOn ? "󰐥" : "󰐊"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: tabDevAi.aiOn
                                                ? (aiSvcM.containsMouse ? Theme.fgOnErrorContainer : Theme.error)
                                                : (aiSvcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.tertiary)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: tabDevAi.aiOn ? "Detener servicio" : "Iniciar servicio"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: tabDevAi.aiOn
                                                ? (aiSvcM.containsMouse ? Theme.fgOnErrorContainer : Theme.fg)
                                                : (aiSvcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.fg)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: aiSvcM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dashWin.runScript("ai.sh", ["service", "toggle"])
                                    }
                                }
                            }

                            // 4 acciones principales IA en fila
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    id: aiQuickRepeater
                                    model: dashWin.aiQuickActions

                                    Rectangle {
                                        id: aiQTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        radius: Theme.radiusMedium
                                        color: aiQM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                radius: 14
                                                color: aiQM.containsMouse ? Theme.primary : Theme.tertiaryContainer
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: aiQTile.modelData.glyph
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnTertiaryContainer
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: aiQTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: aiQTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                                    opacity: aiQM.containsMouse ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: aiQM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.runAiAction(aiQTile.modelData.cmd, aiQTile.modelData.delay)
                                        }
                                    }
                                }
                            }

                            // 6 acciones de contexto y Git (3 columnas x 2 filas)
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    id: aiContextRepeater
                                    model: dashWin.aiContextActions

                                    Rectangle {
                                        id: aiCTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: aiCM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Text {
                                                text: aiCTile.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: aiCM.containsMouse ? Theme.primary : Theme.fgMuted
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: aiCTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: aiCTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: Theme.fgSubtle
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: aiCM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.runAiAction(aiCTile.modelData.cmd, aiCTile.modelData.delay)
                                        }
                                    }
                                }
                            }

                            // Herramientas Dev y estación (4 columnas x 2 filas)
                            Text {
                                text: "HERRAMIENTAS DEV"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgSubtle
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    id: devToolsRepeater
                                    model: dashWin.devToolsActions

                                    Rectangle {
                                        id: devTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        radius: Theme.radiusMedium
                                        color: devM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: devTile.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: devM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.primary
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    text: devTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: devM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: devTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: devM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                                    opacity: devM.containsMouse ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: devM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.actionActivated(devTile.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // BARRA DE BÚSQUEDA GLOBAL INFERIOR (a la altura de los ojos)
                    // =========================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: Theme.radiusMedium
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: globalSearchInput.activeFocus ? Theme.primary : Theme.outlineVariant
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: {
                                if (dashWin.activeTab !== 0)
                                    dashWin.tabSelected(0);
                                globalSearchInput.forceActiveFocus();
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                text: "󰍉"
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                color: Theme.primary
                            }

                            TextInput {
                                id: globalSearchInput
                                Layout.fillWidth: true
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                clip: true
                                selectByMouse: true
                                activeFocusOnTab: false
                                verticalAlignment: TextInput.AlignVCenter

                                onTextChanged: {
                                    if (dashWin.panelOpen && text !== dashWin.searchQuery) {
                                        dashWin.searchQuery = text;
                                        if (text.length > 0 && dashWin.activeTab !== 0)
                                            dashWin.tabSelected(0);
                                    }
                                }

                                Keys.onEscapePressed: dashWin.closeRequested()
                                Keys.onReturnPressed: tabApps.activateSelected()
                                Keys.onEnterPressed: tabApps.activateSelected()
                                Keys.onUpPressed: tabApps.moveSelection(-1)
                                Keys.onDownPressed: tabApps.moveSelection(1)
                                Keys.onTabPressed: event => {
                                    event.accepted = true;
                                    dashWin.tabSelected((dashWin.activeTab + 1) % dashWin.tabMeta.length);
                                }
                                Keys.onBacktabPressed: event => {
                                    event.accepted = true;
                                    dashWin.tabSelected((dashWin.activeTab + dashWin.tabMeta.length - 1) % dashWin.tabMeta.length);
                                }
                                Keys.onPressed: event => {
                                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_1) {
                                        event.accepted = true; dashWin.tabSelected(0);
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_2) {
                                        event.accepted = true; dashWin.tabSelected(1);
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_3) {
                                        event.accepted = true; dashWin.tabSelected(2);
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_4) {
                                        event.accepted = true; dashWin.tabSelected(3);
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_5) {
                                        event.accepted = true; dashWin.tabSelected(4);
                                    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                                        event.accepted = true;
                                        tabApps.moveSelection(1);
                                    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                                        event.accepted = true;
                                        tabApps.moveSelection(-1);
                                    } else if (event.key === Qt.Key_PageDown) {
                                        event.accepted = true;
                                        tabApps.moveSelection(5);
                                    } else if (event.key === Qt.Key_PageUp) {
                                        event.accepted = true;
                                        tabApps.moveSelection(-5);
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: dashWin.activeTab === 0
                                        ? "Buscar apps, PWAs o acciones del sistema..."
                                        : "Escribí desde cualquier pestaña para buscar apps o acciones..."
                                    color: Theme.fgSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    visible: !globalSearchInput.text
                                }
                            }

                            Rectangle {
                                visible: dashWin.activeTab === 0 || globalSearchInput.text.length > 0
                                height: 22
                                width: searchCountTxt.implicitWidth + 14
                                radius: Theme.radiusFull
                                color: Theme.surfaceContainerHigh

                                Text {
                                    id: searchCountTxt
                                    anchors.centerIn: parent
                                    text: tabApps.resultCount === 1
                                        ? "1 resultado"
                                        : (tabApps.resultCount + " resultados")
                                    color: Theme.fgSubtle
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }

                            Rectangle {
                                visible: globalSearchInput.text.length > 0
                                width: 24
                                height: 24
                                radius: 12
                                color: clearSearchM.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: Theme.fgSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: clearSearchM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        globalSearchInput.text = "";
                                        dashWin.searchQuery = "";
                                        globalSearchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    // Pie compacto con ayuda contextual y acceso rápido a Actividades (Super+A)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -4
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: dashWin.activeTab === 0
                                ? "↑↓: mover · Enter: ejecutar · Tab: pestaña · F1: ayuda · Esc: cerrar"
                                : "←↑→↓: mover · Enter: activar · Tab: pestaña · F1: ayuda · Esc: cerrar"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.fgSubtle
                            opacity: 0.78
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: ovHintTxt.implicitWidth + 18
                            Layout.preferredHeight: 26
                            radius: Theme.radiusFull
                            color: ovHintM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: ovHintTxt
                                anchors.centerIn: parent
                                text: "󰕰  Actividades (Super+A)"
                                color: ovHintM.containsMouse ? Theme.fg : Theme.fgSubtle
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: ovHintM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dashWin.overviewRequested()
                            }
                        }
                    }
                }

                // Anillo de foco para navegación por teclado (pestañas 1–4)
                Rectangle {
                    id: focusRing
                    visible: dashWin.focusRingItem !== null && dashWin.activeTab !== 0 && !dashWin.helpOpen
                    x: dashWin.focusRingX
                    y: dashWin.focusRingY
                    width: dashWin.focusRingW
                    height: dashWin.focusRingH
                    z: 200
                    color: Qt.alpha(Theme.primary, 0.08)
                    border.width: 2
                    border.color: Theme.primary
                    radius: Theme.radiusMedium
                    Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Theme.primary, 0.35)
                    }
                }

                // Ayuda contextual de teclado (F1)
                Rectangle {
                    id: helpOverlay
                    visible: dashWin.helpOpen
                    anchors.fill: parent
                    z: 300
                    color: Qt.alpha(Theme.surfaceSolid, 0.94)
                    radius: Theme.radiusLarge

                    MouseArea {
                        anchors.fill: parent
                        onClicked: dashWin.helpOpen = false
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 48, 520)
                        height: helpCol.implicitHeight + 40
                        radius: Theme.radiusLarge
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.outlineVariant

                        Column {
                            id: helpCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 10

                            Text {
                                text: "Atajos de teclado · " + (dashWin.activeTab === 0 ? "Apps" : dashWin.tabMeta[dashWin.activeTab].label)
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: Theme.fg
                            }

                            Text {
                                text: dashWin.activeTab === 0
                                    ? "↑ ↓  mover ·  Enter  abrir ·  Tab  pestaña ·  Ctrl+K  buscar ·  Esc  cerrar"
                                    : "← ↑ → ↓  mover ·  Home/End  primero/último ·  Enter/Espacio  activar\n" +
                                      "↑ ↓ o ← →  ajustar sliders ·  Enter  mute ·  Tab  pestaña ·  Esc  cerrar"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.fgMuted
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Text {
                                text: "1–5  pestañas ·  Escribí en cualquier pestaña para buscar ·  F1  cerrar ayuda"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.fgSubtle
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }
    }
}
