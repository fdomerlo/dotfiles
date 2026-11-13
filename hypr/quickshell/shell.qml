import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool overviewOpen: false
    property string searchQuery: ""
    property int selectedWorkspaceId: -1
    property bool tabNavigated: false

    readonly property string wallpaperStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr_current_wallpaper"
    readonly property string wallpaperName: {
        if (!wallpaperStateFile.loaded)
            return "";
        const raw = String(wallpaperStateFile.text() || "").trim();
        if (!raw)
            return "";
        const slash = raw.lastIndexOf("/");
        return slash >= 0 ? raw.slice(slash + 1) : raw;
    }

    FileView {
        id: wallpaperStateFile
        path: root.wallpaperStatePath
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: wallpaperRetryTimer.restart()
    }

    Timer {
        id: wallpaperRetryTimer
        interval: 1500
        repeat: false
        onTriggered: wallpaperStateFile.reload()
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

    function openOverview() {
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
        target: "wallpaper"

        function refresh(): void {
            wallpaperStateFile.reload();
        }
    }

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

    Variants {
        model: Quickshell.screens

        WallpaperBadge {
            required property var modelData
            screen: modelData
            wallpaperName: root.wallpaperName
        }
    }
}
