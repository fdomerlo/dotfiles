import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool overviewOpen: false
    property string searchQuery: ""

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

    function openOverview() {
        searchQuery = "";
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        overviewOpen = true;
    }

    function closeOverview() {
        overviewOpen = false;
        searchQuery = "";
    }

    function toggleOverview() {
        if (overviewOpen) {
            closeOverview();
        } else {
            openOverview();
        }
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
            onSearchUpdated: text => root.searchQuery = text
            onCloseRequested: root.closeOverview()
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
