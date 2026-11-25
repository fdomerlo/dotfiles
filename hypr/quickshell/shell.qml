import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property bool overviewOpen: false
    property string searchQuery: ""
    property int selectedWorkspaceId: -1
    property bool tabNavigated: false

    property bool launcherOpen: false
    property bool launcherMounted: false
    property string launcherTab: "apps"
    property string launcherSearchQuery: ""
    property var launcherScreen: null
    property string activeThemeName: Theme.modeName
    property bool recordingActive: false
    property bool nightlightActive: false
    property var pendingCmd: null

    // Estado del OSD (volumen / micrófono / brillo / bloqueos)
    property bool osdVisible: false
    property bool osdMounted: false
    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property var osdScreen: null

    // Estado del centro de notificaciones y toasts
    property bool notifCenterOpen: false
    property bool notifCenterMounted: false
    property var notifCenterScreen: null
    property bool popupsMounted: false
    property var popupsScreen: null
    property bool dndEnabled: false
    property bool popupHovered: false
    property real popupHoverStartedMs: 0
    property int nextNotifUid: 1
    property var notifEntries: []
    property real notifNowMs: Date.now()

    // Estado de popouts acoplados a la barra superior (dashboard unificado, energía e inhibidor)
    property bool dashboardOpen: false
    property bool dashboardMounted: false
    property int dashboardTab: 0
    property var dashboardScreen: null
    property bool powerOpen: false
    property bool powerMounted: false
    property var powerScreen: null
    property bool idleInhibited: false

    readonly property var activePopups: {
        void(notifEntries);
        if (dndEnabled || notifCenterOpen)
            return [];
        const out = [];
        for (let i = 0; i < notifEntries.length && out.length < 4; i++) {
            if (notifEntries[i] && notifEntries[i].popupActive)
                out.push(notifEntries[i]);
        }
        return out;
    }

    // Pausa real del timeout de toasts durante hover (desplaza expireAt al salir el cursor)
    onPopupHoveredChanged: {
        if (popupHovered) {
            popupHoverStartedMs = Date.now();
        } else if (popupHoverStartedMs > 0) {
            const delta = Math.max(0, Date.now() - popupHoverStartedMs);
            popupHoverStartedMs = 0;
            if (delta > 0) {
                const next = [];
                let changed = false;
                for (let i = 0; i < notifEntries.length; i++) {
                    const e = notifEntries[i];
                    if (!e)
                        continue;
                    if (e.popupActive && e.expireAt > 0) {
                        changed = true;
                        next.push({
                            uid: e.uid,
                            notif: e.notif,
                            timestamp: e.timestamp,
                            durationMs: e.durationMs || 0,
                            popupActive: e.popupActive,
                            keepInHistory: e.keepInHistory,
                            expireAt: e.expireAt + delta
                        });
                    } else {
                        next.push(e);
                    }
                }
                if (changed)
                    notifEntries = next;
            }
        }
    }

    // Ciclo de montaje diferido para permitir animaciones suaves de cierre antes de destruir LazyLoader
    onLauncherOpenChanged: {
        if (launcherOpen) {
            launcherUnmountTimer.stop();
            launcherMounted = true;
        } else {
            launcherUnmountTimer.restart();
        }
    }

    onOsdVisibleChanged: {
        if (osdVisible) {
            osdUnmountTimer.stop();
            osdMounted = true;
        } else {
            osdUnmountTimer.restart();
        }
    }

    onActivePopupsChanged: {
        if (activePopups.length > 0) {
            popupsUnmountTimer.stop();
            popupsMounted = true;
        } else {
            popupsUnmountTimer.restart();
        }
    }

    onNotifCenterOpenChanged: {
        if (notifCenterOpen) {
            notifCenterUnmountTimer.stop();
            notifCenterMounted = true;
        } else {
            notifCenterUnmountTimer.restart();
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            dashboardUnmountTimer.stop();
            dashboardMounted = true;
        } else {
            dashboardUnmountTimer.restart();
        }
    }

    onPowerOpenChanged: {
        if (powerOpen) {
            powerUnmountTimer.stop();
            powerMounted = true;
        } else {
            powerUnmountTimer.restart();
        }
    }

    Timer {
        id: launcherUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.launcherOpen) {
                root.launcherMounted = false;
                root.launcherSearchQuery = "";
                root.launcherScreen = null;
            }
        }
    }

    Timer {
        id: osdUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.osdVisible)
                root.osdMounted = false;
        }
    }

    Timer {
        id: popupsUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.activePopups.length === 0)
                root.popupsMounted = false;
        }
    }

    Timer {
        id: notifCenterUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.notifCenterOpen)
                root.notifCenterMounted = false;
        }
    }

    Timer {
        id: dashboardUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.dashboardOpen)
                root.dashboardMounted = false;
        }
    }

    Timer {
        id: powerUnmountTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.powerOpen)
                root.powerMounted = false;
        }
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    SystemState {
        id: systemState
    }

    property bool osdPipewireArmed: false

    Timer {
        id: pipewireArmTimer
        interval: 1500
        repeat: false
        running: true
        onTriggered: root.osdPipewireArmed = true
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumesChanged() {
            if (!root.osdPipewireArmed || !Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                return;
            const pct = Math.round(Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume || 0)) * 100);
            root.triggerOsd("volume", pct, Boolean(Pipewire.defaultAudioSink.audio.muted));
        }
        function onMutedChanged() {
            if (!root.osdPipewireArmed || !Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                return;
            const pct = Math.round(Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume || 0)) * 100);
            root.triggerOsd("volume", pct, Boolean(Pipewire.defaultAudioSink.audio.muted));
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: n => root.handleIncomingNotification(n)
    }

    // Reloj de expiración de toasts (500 ms; se pausa con hover sobre un toast).
    Timer {
        id: popupExpiryTimer
        interval: 500
        repeat: true
        running: root.activePopups.length > 0 && !root.popupHovered
        onTriggered: root.pruneExpiredPopups()
    }

    // Actualiza timestamps relativos cada 30 s solo mientras haya UI visible.
    Timer {
        id: relativeTimeTimer
        interval: 30000
        repeat: true
        running: root.notifCenterOpen || root.activePopups.length > 0
        onTriggered: root.notifNowMs = Date.now()
    }

    // Lee el modo activo (dark / light) al iniciar el shell residente.
    Process {
        id: themeInitProbe
        command: [
            "sh", "-c",
            "t=$(readlink \"$HOME/.config/hypr/themes/active\" 2>/dev/null || true); " +
            "t=${t##*/}; " +
            "case \"$t\" in *light*) echo light ;; *) echo dark ;; esac"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const mode = String(text || "").trim();
                Theme.setMode(mode);
                root.activeThemeName = Theme.modeName;
            }
        }
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
                    const t = parts[0] || Theme.modeName;
                    root.activeThemeName = t;
                    root.recordingActive = (parts[1] === "1");
                    root.nightlightActive = (parts[2] === "1");
                }
            }
        }
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

    function notifStatusJson() {
        const count = notifEntries.length;
        const alt = (dndEnabled ? "dnd-" : "") + (count > 0 ? "notification" : "none");
        const cls = [alt];
        if (notifCenterOpen)
            cls.push("cc-open");
        const tip = dndEnabled
            ? "No molestar activo (" + count + " notificaciones)"
            : (count > 0 ? (count + (count === 1 ? " notificación" : " notificaciones")) : "Sin notificaciones");
        return JSON.stringify({
            text: count > 0 ? String(count) : "",
            alt: alt,
            tooltip: tip,
            class: cls
        });
    }

    function computePopupDurationMs(n) {
        if (!n)
            return 5000;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout && n.expireTimeout > 0)
            return Math.max(2000, Math.min(5000, Math.round(n.expireTimeout * 1000)));
        if (n.urgency === NotificationUrgency.Low)
            return 4000;
        return 5000;
    }

    function handleIncomingNotification(n) {
        if (!n)
            return;
        const now = Date.now();
        notifNowMs = now;
        const uid = nextNotifUid++;
        const keepTracked = !n.transient;
        n.tracked = true;

        const dur = computePopupDurationMs(n);
        const showPopup = !dndEnabled && !notifCenterOpen;
        if (showPopup)
            popupsScreen = resolveFocusedScreen();

        const item = {
            uid: uid,
            notif: n,
            timestamp: now,
            durationMs: dur,
            popupActive: showPopup,
            keepInHistory: keepTracked,
            expireAt: (showPopup && dur > 0) ? (now + dur) : 0
        };

        n.closed.connect(() => {
            root.removeNotifByUid(uid);
        });

        const next = [item];
        for (let i = 0; i < notifEntries.length; i++) {
            const cur = notifEntries[i];
            if (!cur || !cur.notif)
                continue;
            if (cur.notif.id === n.id && cur.uid !== uid)
                continue;
            next.push(cur);
        }
        while (next.length > 50) {
            const dropped = next.pop();
            if (dropped && dropped.notif && dropped.notif.tracked)
                dropped.notif.tracked = false;
        }
        notifEntries = next;
    }

    function removeNotifByUid(uid) {
        const next = [];
        let changed = false;
        for (let i = 0; i < notifEntries.length; i++) {
            if (notifEntries[i] && notifEntries[i].uid === uid) {
                changed = true;
                continue;
            }
            next.push(notifEntries[i]);
        }
        if (changed)
            notifEntries = next;
    }

    function dismissNotif(uid) {
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (e && e.uid === uid) {
                if (e.notif && e.notif.tracked) {
                    e.notif.dismiss();
                }
                removeNotifByUid(uid);
                return;
            }
        }
    }

    function hidePopup(uid) {
        const next = [];
        let changed = false;
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (!e)
                continue;
            if (e.uid === uid) {
                changed = true;
                if (!e.keepInHistory) {
                    if (e.notif && e.notif.tracked) {
                        e.notif.expire();
                    }
                    continue;
                }
                next.push({
                    uid: e.uid,
                    notif: e.notif,
                    timestamp: e.timestamp,
                    durationMs: e.durationMs || 0,
                    popupActive: false,
                    keepInHistory: e.keepInHistory,
                    expireAt: 0
                });
            } else {
                next.push(e);
            }
        }
        if (changed)
            notifEntries = next;
    }

    function closeAllPopups() {
        const next = [];
        let changed = false;
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (!e)
                continue;
            if (e.popupActive) {
                changed = true;
                if (!e.keepInHistory) {
                    if (e.notif && e.notif.tracked)
                        e.notif.expire();
                    continue;
                }
                next.push({
                    uid: e.uid,
                    notif: e.notif,
                    timestamp: e.timestamp,
                    durationMs: e.durationMs || 0,
                    popupActive: false,
                    keepInHistory: e.keepInHistory,
                    expireAt: 0
                });
            } else {
                next.push(e);
            }
        }
        popupHovered = false;
        popupHoverStartedMs = 0;
        if (changed)
            notifEntries = next;
    }

    function pruneExpiredPopups() {
        const now = Date.now();
        const next = [];
        let changed = false;
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (!e)
                continue;
            if (e.popupActive && e.expireAt > 0 && now >= e.expireAt) {
                changed = true;
                if (!e.keepInHistory) {
                    if (e.notif && e.notif.tracked) {
                        e.notif.expire();
                    }
                    continue;
                }
                next.push({
                    uid: e.uid,
                    notif: e.notif,
                    timestamp: e.timestamp,
                    durationMs: e.durationMs || 0,
                    popupActive: false,
                    keepInHistory: e.keepInHistory,
                    expireAt: 0
                });
            } else {
                next.push(e);
            }
        }
        if (changed)
            notifEntries = next;
    }

    function invokeNotifAction(uid, action) {
        if (!action)
            return;
        action.invoke();
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (e && e.uid === uid) {
                if (!e.notif || !e.notif.resident)
                    dismissNotif(uid);
                else
                    hidePopup(uid);
                break;
            }
        }
        if (notifCenterOpen)
            closeNotifCenter();
    }

    function sendNotifReply(uid, text) {
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (e && e.uid === uid && e.notif) {
                e.notif.sendInlineReply(text);
                if (!e.notif.resident)
                    dismissNotif(uid);
                return;
            }
        }
    }

    function clearAllNotifs() {
        const snapshot = notifEntries.slice();
        notifEntries = [];
        for (let i = 0; i < snapshot.length; i++) {
            const e = snapshot[i];
            if (e && e.notif && e.notif.tracked) {
                e.notif.dismiss();
            }
        }
    }

    function openNotifCenter() {
        if (launcherOpen)
            closeLauncher();
        if (overviewOpen)
            closeOverview();
        if (dashboardOpen)
            closeDashboard();
        if (powerOpen)
            closePower();
        notifNowMs = Date.now();
        const next = [];
        for (let i = 0; i < notifEntries.length; i++) {
            const e = notifEntries[i];
            if (!e)
                continue;
            next.push({
                uid: e.uid,
                notif: e.notif,
                timestamp: e.timestamp,
                durationMs: e.durationMs || 0,
                popupActive: false,
                keepInHistory: e.keepInHistory,
                expireAt: 0
            });
        }
        notifEntries = next;
        popupHovered = false;
        popupHoverStartedMs = 0;
        notifCenterScreen = resolveFocusedScreen();
        notifCenterOpen = true;
    }

    function closeNotifCenter() {
        notifCenterOpen = false;
    }

    function toggleNotifCenter() {
        if (notifCenterOpen)
            closeNotifCenter();
        else
            openNotifCenter();
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled;
        if (dndEnabled) {
            popupHovered = false;
            popupHoverStartedMs = 0;
        }
    }

    function openDashboard(scr, tab) {
        if (launcherOpen)
            closeLauncher();
        if (overviewOpen)
            closeOverview();
        if (notifCenterOpen)
            closeNotifCenter();
        if (powerOpen)
            closePower();
        if (tab !== undefined && tab >= 0 && tab <= 3)
            dashboardTab = tab;
        systemState.refreshAll();
        dashboardScreen = scr || resolveFocusedScreen();
        dashboardOpen = true;
    }

    function closeDashboard() {
        dashboardOpen = false;
    }

    function toggleDashboard(scr, tab) {
        if (dashboardOpen) {
            if (tab !== undefined && tab >= 0 && tab <= 3 && tab !== dashboardTab) {
                dashboardTab = tab;
                return;
            }
            closeDashboard();
        } else {
            openDashboard(scr, tab);
        }
    }

    function openPower(scr) {
        if (launcherOpen)
            closeLauncher();
        if (overviewOpen)
            closeOverview();
        if (notifCenterOpen)
            closeNotifCenter();
        if (dashboardOpen)
            closeDashboard();
        powerScreen = scr || resolveFocusedScreen();
        powerOpen = true;
    }

    function closePower() {
        powerOpen = false;
    }

    function togglePower(scr) {
        if (powerOpen)
            closePower();
        else
            openPower(scr);
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

    function openOverview() {
        if (launcherOpen)
            closeLauncher();
        if (notifCenterOpen)
            closeNotifCenter();
        if (dashboardOpen)
            closeDashboard();
        if (powerOpen)
            closePower();
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

    function openLauncher(tabId, scr) {
        if (overviewOpen)
            closeOverview();
        if (notifCenterOpen)
            closeNotifCenter();
        if (dashboardOpen)
            closeDashboard();
        if (powerOpen)
            closePower();
        launcherSearchQuery = "";
        launcherTab = tabId || "apps";
        launcherScreen = scr || resolveFocusedScreen();
        if (!launcherStateProbe.running) {
            launcherStateProbe.running = true;
        }
        launcherOpen = true;
    }

    function closeLauncher() {
        launcherOpen = false;
    }

    function toggleLauncher(tabId, scr) {
        if (launcherOpen) {
            if (tabId && tabId !== launcherTab) {
                launcherTab = tabId;
                return;
            }
            closeLauncher();
            return;
        }
        openLauncher(tabId, scr);
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
        target: "theme"

        function setMode(mode: string): void {
            Theme.setMode(mode);
            root.activeThemeName = Theme.modeName;
        }

        function toggle(): void {
            Theme.toggleMode();
            root.activeThemeName = Theme.modeName;
        }

        function current(): string {
            return Theme.modeName;
        }
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

        function showLock(lockName: string, active: bool): void {
            const kind = (lockName === "caps") ? "caps" : "num";
            root.triggerOsd(kind, active ? 100 : 0, !active);
        }

        function hide(): void {
            osdHideTimer.stop();
            root.osdVisible = false;
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.toggleNotifCenter();
        }

        function open(): void {
            root.openNotifCenter();
        }

        function close(): void {
            root.closeNotifCenter();
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clearAll(): void {
            root.clearAllNotifs();
        }

        function status(): string {
            return root.notifStatusJson();
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.toggleDashboard(null, -1);
        }

        function open(): void {
            root.openDashboard(null, 0);
        }

        function openTab(tabIndex: int): void {
            root.toggleDashboard(null, tabIndex);
        }

        function close(): void {
            root.closeDashboard();
        }
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            root.toggleDashboard(null, 0);
        }

        function open(): void {
            root.openDashboard(null, 0);
        }

        function close(): void {
            root.closeDashboard();
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.toggleDashboard(null, 0);
        }

        function open(): void {
            root.openDashboard(null, 0);
        }

        function close(): void {
            root.closeDashboard();
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.togglePower(null);
        }

        function open(): void {
            root.openPower(null);
        }

        function close(): void {
            root.closePower();
        }
    }

    IpcHandler {
        target: "ai"

        function toggle(): void {
            root.toggleDashboard(null, 3);
        }

        function open(): void {
            root.openDashboard(null, 3);
        }

        function close(): void {
            root.closeDashboard();
        }
    }

    IpcHandler {
        target: "system"

        function refresh(): void {
            systemState.refreshAll();
        }

        function toggleIdleInhibit(): void {
            root.idleInhibited = !root.idleInhibited;
        }
    }

    // Barra superior residente en todos los monitores (siempre arriba)
    Variants {
        model: Quickshell.screens

        BarWindow {
            required property var modelData
            screen: modelData
            sysState: systemState
            currentDate: sysClock.date
            notifCount: root.notifEntries.length
            dndEnabled: root.dndEnabled
            notifCenterOpen: root.notifCenterOpen
            launcherOpen: root.launcherOpen
            overviewOpen: root.overviewOpen
            dashboardOpen: root.dashboardOpen
            powerOpen: root.powerOpen
            popupsVisible: root.popupsMounted
            dashboardScreen: root.dashboardScreen
            notifCenterScreen: root.notifCenterScreen
            powerScreen: root.powerScreen
            popupsScreen: root.popupsScreen
            idleInhibited: root.idleInhibited

            onLauncherRequested: scr => root.toggleLauncher("", scr)
            onOverviewRequested: root.toggleOverview()
            onNotifCenterRequested: root.toggleNotifCenter()
            onDndToggled: root.toggleDnd()
            onDashboardRequested: (scr, tab) => root.toggleDashboard(scr, tab)
            onPowerRequested: scr => root.togglePower(scr)
            onIdleInhibitToggled: root.idleInhibited = !root.idleInhibited
        }
    }

    // Ventanas modales y overlays bajo demanda: se instancian al abrir y se desmontan tras la animación de cierre.
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
        active: root.launcherMounted

        LauncherWindow {
            screen: root.launcherScreen || root.resolveFocusedScreen()
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
        active: root.osdMounted

        Variants {
            model: Quickshell.screens

            OsdWindow {
                required property var modelData
                screen: modelData
                osdVisible: root.osdVisible
                osdKind: root.osdKind
                osdValue: root.osdValue
                osdMuted: root.osdMuted
            }
        }
    }

    LazyLoader {
        active: root.popupsMounted

        NotificationPopups {
            screen: root.popupsScreen || root.resolveFocusedScreen()
            popups: root.activePopups
            nowMs: root.notifNowMs
            barHeight: systemState.barHeight
            onDismissRequested: uid => root.dismissNotif(uid)
            onPopupCloseRequested: uid => root.hidePopup(uid)
            onCloseAllPopupsRequested: root.closeAllPopups()
            onActionInvoked: (uid, action) => root.invokeNotifAction(uid, action)
            onHoverChanged: h => { root.popupHovered = h; }
        }
    }

    LazyLoader {
        active: root.notifCenterMounted

        NotificationCenter {
            screen: root.notifCenterScreen || root.resolveFocusedScreen()
            panelOpen: root.notifCenterOpen
            notifications: root.notifEntries
            dndEnabled: root.dndEnabled
            nowMs: root.notifNowMs
            barHeight: systemState.barHeight
            onCloseRequested: root.closeNotifCenter()
            onToggleDndRequested: root.toggleDnd()
            onClearAllRequested: root.clearAllNotifs()
            onDismissRequested: uid => root.dismissNotif(uid)
            onActionInvoked: (uid, action) => root.invokeNotifAction(uid, action)
            onReplySent: (uid, msg) => root.sendNotifReply(uid, msg)
        }
    }

    LazyLoader {
        active: root.dashboardMounted

        DashboardPopup {
            screen: root.dashboardScreen || root.resolveFocusedScreen()
            panelOpen: root.dashboardOpen
            activeTab: root.dashboardTab
            sysState: systemState
            currentDate: sysClock.date
            dndEnabled: root.dndEnabled
            idleInhibited: root.idleInhibited
            onCloseRequested: root.closeDashboard()
            onTabSelected: tabIdx => { root.dashboardTab = tabIdx; }
            onToggleDndRequested: root.toggleDnd()
            onToggleIdleInhibitRequested: root.idleInhibited = !root.idleInhibited
            onPowerRequested: root.openPower(root.dashboardScreen)
        }
    }

    LazyLoader {
        active: root.powerMounted

        PowerPopup {
            screen: root.powerScreen || root.resolveFocusedScreen()
            panelOpen: root.powerOpen
            sysState: systemState
            onCloseRequested: root.closePower()
        }
    }

}
