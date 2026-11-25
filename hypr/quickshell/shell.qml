import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    property bool overviewOpen: false
    property string searchQuery: ""
    property int selectedWorkspaceId: -1
    property bool tabNavigated: false

    property bool launcherOpen: false
    property bool launcherPending: false
    property string pendingPrimaryName: ""
    property int pendingScreenRetries: 0
    property string launcherTab: "apps"
    property string launcherSearchQuery: ""
    property var launcherScreen: null
    property string activeThemeName: ""
    property bool recordingActive: false
    property bool nightlightActive: false
    property var pendingCmd: null

    // Estado del OSD (volumen / micrófono / brillo)
    property bool osdVisible: false
    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property var osdScreen: null

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Process {
        id: launcherStateProbe
        command: [
            "sh", "-c",
            "t=$(readlink \"$HOME/.config/hypr/themes/active\" 2>/dev/null || true); " +
            "t=${t##*/}; " +
            "r=0; pgrep -x wf-recorder >/dev/null 2>&1 && r=1; " +
            "n=0; [ -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-nightlight.state\" ] && n=1; " +
            "printf '%s|%s|%s\\n' \"$t\" \"$r\" \"$n\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = String(text || "").trim().split("|");
                if (parts.length >= 3) {
                    root.activeThemeName = parts[0] || "";
                    root.recordingActive = (parts[1] === "1");
                    root.nightlightActive = (parts[2] === "1");
                }
            }
        }
    }

    // Nombre del monitor 1 segun Hyprland (izquierda -> derecha). Se consulta
    // fuera de Quickshell porque al relanzar el daemon su lista de screens
    // todavia puede estar incompleta y terminaria abriendo en el monitor
    // enfocado. Mismo criterio que workspaces-init.sh y main-menu.sh.
    Process {
        id: primaryScreenProbe
        command: [
            "sh", "-c",
            "hyprctl monitors -j 2>/dev/null | " +
            "jq -r 'map(select(.disabled | not)) | sort_by(.x, .y, .id) | .[0].name // empty' " +
            "2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.applyPrimaryScreen(String(text || "").trim())
        }
    }

    Timer {
        id: primaryScreenRetry
        interval: 80
        repeat: false
        onTriggered: root.tryApplyPrimaryScreen()
    }

    Timer {
        id: delayedExecTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.pendingCmd && root.pendingCmd.length > 0) {
                const cmd = root.pendingCmd;
                root.pendingCmd = null;
                Quickshell.execDetached(cmd);
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
    }

    function orderedWorkspaceIds() {
        const list = [];
        const vals = Hyprland.workspaces.values;
        if (!vals)
            return [];
        for (let i = 0; i < vals.length; i++) {
            const ws = vals[i];
            if (!ws || ws.id <= 0)
                continue;
            list.push(ws);
        }
        list.sort((a, b) => {
            const ax = a.monitor ? a.monitor.x : 0;
            const bx = b.monitor ? b.monitor.x : 0;
            if (ax !== bx)
                return ax - bx;
            const ay = a.monitor ? a.monitor.y : 0;
            const by = b.monitor ? b.monitor.y : 0;
            if (ay !== by)
                return ay - by;
            return a.id - b.id;
        });
        const ids = [];
        for (let i = 0; i < list.length; i++) {
            ids.push(list[i].id);
        }
        return ids;
    }

    function screenSortKey(scr) {
        const hm = Hyprland.monitorFor(scr);
        const hasHypr = hm !== null && hm !== undefined;
        const x = hasHypr ? hm.x : (scr.x !== undefined ? scr.x : 0);
        const y = hasHypr ? hm.y : (scr.y !== undefined ? scr.y : 0);
        const id = hasHypr && hm.id !== undefined ? hm.id : 999999;
        const name = String(scr.name || "");
        return { x: x, y: y, id: id, name: name };
    }

    function compareScreenKeys(a, b) {
        if (a.x !== b.x)
            return a.x - b.x;
        if (a.y !== b.y)
            return a.y - b.y;
        if (a.id !== b.id)
            return a.id - b.id;
        return a.name.localeCompare(b.name);
    }

    // Monitor 1: mismo criterio portable que workspaces-init.sh (izquierda ->
    // derecha por coordenada x, desempatando por y, id de Hyprland y nombre).
    function resolvePrimaryScreen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0)
            return null;
        let best = screens[0];
        let bestKey = screenSortKey(best);
        for (let i = 1; i < screens.length; i++) {
            const candidate = screens[i];
            const key = screenSortKey(candidate);
            if (compareScreenKeys(key, bestKey) < 0) {
                best = candidate;
                bestKey = key;
            }
        }
        return best;
    }

    function resolveFocusedScreen() {
        const screens = Quickshell.screens || [];
        const focused = Hyprland.focusedMonitor;
        if (focused && focused.name) {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i] && screens[i].name === focused.name)
                    return screens[i];
            }
        }
        return resolvePrimaryScreen() || (screens.length > 0 ? screens[0] : null);
    }

    function triggerOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(150, value));
        osdMuted = Boolean(muted);
        osdScreen = resolveFocusedScreen();
        osdVisible = true;
        osdHideTimer.restart();
    }

    function applyPrimaryScreen(name) {
        pendingPrimaryName = name || "";
        pendingScreenRetries = 0;
        tryApplyPrimaryScreen();
    }

    function tryApplyPrimaryScreen() {
        if (!launcherPending)
            return;

        const screens = Quickshell.screens || [];
        let target = null;
        if (pendingPrimaryName) {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i] && screens[i].name === pendingPrimaryName) {
                    target = screens[i];
                    break;
                }
            }
        }

        // Si el monitor 1 todavia no esta en la lista de Quickshell, reintentar
        // brevemente. Sin nombre de referencia, no esperar de mas.
        const maxRetries = pendingPrimaryName ? 12 : 2;
        if (!target && pendingScreenRetries < maxRetries) {
            pendingScreenRetries += 1;
            primaryScreenRetry.restart();
            return;
        }

        launcherScreen = target || resolvePrimaryScreen() || (screens.length > 0 ? screens[0] : null);
        if (!launcherStateProbe.running) {
            launcherStateProbe.running = true;
        }
        launcherOpen = true;
        launcherPending = false;
    }

    function openOverview() {
        if (launcherOpen)
            closeLauncher();
        searchQuery = "";
        tabNavigated = false;
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        const activeWs = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
            ? Hyprland.focusedMonitor.activeWorkspace.id
            : -1;
        const ids = orderedWorkspaceIds();
        selectedWorkspaceId = (activeWs > 0 && ids.indexOf(activeWs) !== -1)
            ? activeWs
            : (ids.length > 0 ? ids[0] : -1);
        overviewOpen = true;
    }

    function closeOverview() {
        overviewOpen = false;
        searchQuery = "";
        tabNavigated = false;
        selectedWorkspaceId = -1;
    }

    function toggleOverview() {
        if (overviewOpen) {
            closeOverview();
        } else {
            openOverview();
        }
    }

    function openLauncher(tabId) {
        if (overviewOpen)
            closeOverview();
        launcherSearchQuery = "";
        launcherTab = tabId || "apps";
        launcherPending = true;
        pendingPrimaryName = "";
        pendingScreenRetries = 0;
        primaryScreenRetry.stop();
        Hyprland.refreshMonitors();
        // La ventana se crea recien cuando primaryScreenProbe resolvio el
        // monitor 1 y Quickshell ya lo tiene en su lista de screens.
        primaryScreenProbe.running = true;
    }

    function closeLauncher() {
        primaryScreenRetry.stop();
        launcherPending = false;
        launcherOpen = false;
        launcherSearchQuery = "";
        launcherScreen = null;
    }

    function toggleLauncher(tabId) {
        if (launcherOpen) {
            if (tabId && tabId !== launcherTab) {
                launcherTab = tabId;
                return;
            }
            closeLauncher();
            return;
        }
        if (launcherPending) {
            if (tabId) {
                launcherTab = tabId;
            } else {
                closeLauncher();
            }
            return;
        }
        openLauncher(tabId);
    }

    function launchAppEntry(entry) {
        if (!entry)
            return;
        closeLauncher();
        if (entry.runInTerminal && entry.command && entry.command.length > 0) {
            Quickshell.execDetached(["foot", "-e"].concat(entry.command));
        } else {
            entry.execute();
        }
    }

    function launchAction(act) {
        if (!act)
            return;
        closeLauncher();
        if (act.actionType === "term-hold") {
            const wrapped =
                "export PATH=\"$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/share/fnm:/usr/local/bin:$PATH\"; " +
                act.termCmd +
                "; rc=$?; printf '\\n[Estado: %s] Presioná cualquier tecla para cerrar...' \"$rc\"; read -rn1 -s _";
            Quickshell.execDetached(["foot", "--title", act.termTitle || "Terminal", "-e", "bash", "-lc", wrapped]);
            return;
        }
        if (act.delayMs && act.delayMs > 0) {
            root.pendingCmd = act.cmd;
            delayedExecTimer.interval = act.delayMs;
            delayedExecTimer.restart();
            return;
        }
        if (act.cmd && act.cmd.length > 0) {
            Quickshell.execDetached(act.cmd);
        }
    }

    function cycleWorkspace(delta) {
        const ids = orderedWorkspaceIds();
        if (ids.length === 0)
            return;
        const step = delta < 0 ? -1 : 1;
        let idx = ids.indexOf(selectedWorkspaceId);
        if (idx === -1) {
            const activeWs = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
                ? Hyprland.focusedMonitor.activeWorkspace.id
                : -1;
            idx = ids.indexOf(activeWs);
        }
        const nextIdx = idx === -1
            ? (step > 0 ? 0 : ids.length - 1)
            : (idx + step + ids.length) % ids.length;
        selectedWorkspaceId = ids[nextIdx];
        tabNavigated = true;
    }

    function focusWindow(toplevel) {
        if (!toplevel)
            return;
        const raw = String(toplevel.address || "");
        if (!raw)
            return;
        const addr = raw.startsWith("0x") ? raw : ("0x" + raw);
        closeOverview();
        Hyprland.dispatch("focuswindow address:" + addr);
    }

    function switchWorkspace(wsId) {
        if (!wsId || wsId <= 0)
            return;
        closeOverview();
        Hyprland.dispatch("workspace " + wsId);
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggleOverview();
        }

        function open(): void {
            root.openOverview();
        }

        function close(): void {
            root.closeOverview();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggleLauncher("");
        }

        function open(): void {
            root.openLauncher("apps");
        }

        function openTab(tabId: string): void {
            root.toggleLauncher(tabId);
        }

        function close(): void {
            root.closeLauncher();
        }
    }

    IpcHandler {
        target: "osd"

        function showVolume(percent: int, muted: bool): void {
            root.triggerOsd("volume", percent, muted);
        }

        function showMic(muted: bool): void {
            root.triggerOsd("mic", muted ? 0 : 100, muted);
        }

        function showBrightness(percent: int): void {
            root.triggerOsd("brightness", percent, false);
        }

        function hide(): void {
            osdHideTimer.stop();
            root.osdVisible = false;
        }
    }

    // Ventanas modales y overlays bajo demanda: se instancian solo mientras están visibles.
    LazyLoader {
        active: root.overviewOpen

        Variants {
            model: Quickshell.screens

            OverviewWindow {
                required property var modelData
                screen: modelData
                overviewOpen: root.overviewOpen
                searchQuery: root.searchQuery
                selectedWorkspaceId: root.selectedWorkspaceId
                tabNavigated: root.tabNavigated
                onSearchUpdated: text => {
                    root.searchQuery = text;
                    root.tabNavigated = false;
                }
                onCloseRequested: root.closeOverview()
                onCycleWorkspaceRequested: delta => root.cycleWorkspace(delta)
                onWindowSelected: toplevel => root.focusWindow(toplevel)
                onWorkspaceSelected: wsId => root.switchWorkspace(wsId)
            }
        }
    }

    LazyLoader {
        active: root.launcherOpen

        LauncherWindow {
            screen: root.launcherScreen || root.resolvePrimaryScreen()
            launcherOpen: root.launcherOpen
            activeTab: root.launcherTab
            searchQuery: root.launcherSearchQuery
            activeTheme: root.activeThemeName
            recordingActive: root.recordingActive
            nightlightActive: root.nightlightActive
            onTabSelected: tabId => {
                root.launcherTab = tabId;
            }
            onSearchUpdated: text => {
                root.launcherSearchQuery = text;
            }
            onCloseRequested: root.closeLauncher()
            onAppActivated: entry => root.launchAppEntry(entry)
            onActionActivated: act => root.launchAction(act)
            onOverviewRequested: root.openOverview()
        }
    }

    LazyLoader {
        active: root.osdVisible

        OsdWindow {
            screen: root.osdScreen || root.resolveFocusedScreen()
            osdVisible: root.osdVisible
            osdKind: root.osdKind
            osdValue: root.osdValue
            osdMuted: root.osdMuted
        }
    }
}
