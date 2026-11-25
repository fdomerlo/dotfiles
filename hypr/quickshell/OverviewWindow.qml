import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property bool overviewOpen
    required property string searchQuery
    required property int selectedWorkspaceId
    required property bool tabNavigated
    required property bool isFocusedOverviewScreen
    property int barHeight: 40

    signal searchUpdated(string text)
    signal closeRequested()
    signal cycleWorkspaceRequested(int delta)
    signal windowSelected(var toplevel)
    signal workspaceSelected(int wsId)

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool isFocusedMonitor: {
        if (Hyprland.focusedMonitor && hyprMonitor)
            return Hyprland.focusedMonitor.name === hyprMonitor.name;
        return isFocusedOverviewScreen;
    }

    function resolveDesktopEntry(cls) {
        const raw = String(cls || "").trim();
        if (!raw)
            return null;
        if (DesktopEntries.heuristicLookup) {
            const h = DesktopEntries.heuristicLookup(raw);
            if (h)
                return h;
        }
        if (DesktopEntries.byId) {
            const direct = DesktopEntries.byId(raw) || DesktopEntries.byId(raw.toLowerCase());
            if (direct)
                return direct;
        }
        const rawLow = raw.toLowerCase();
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        if (apps) {
            for (let i = 0; i < apps.length; i++) {
                const e = apps[i];
                if (!e)
                    continue;
                const eid = String(e.id || "").toLowerCase().replace(/\.desktop$/, "");
                const sc = String(e.startupClass || "").toLowerCase();
                const nm = String(e.name || "").toLowerCase();
                if (eid === rawLow || sc === rawLow || nm === rawLow)
                    return e;
            }
        }
        return null;
    }

    function friendlyAppName(cls, entry) {
        if (entry && entry.name)
            return String(entry.name);
        const raw = String(cls || "").trim();
        if (!raw)
            return "Ventana";
        let clean = raw;
        if (clean.indexOf(".") !== -1) {
            const parts = clean.split(".").filter(p => p.length > 0);
            if (parts.length > 0)
                clean = parts[parts.length - 1];
        }
        if (clean.length > 0 && clean === clean.toLowerCase())
            return clean.charAt(0).toUpperCase() + clean.slice(1);
        return clean;
    }

    function resolveAppIcon(cls, entry) {
        if (entry && entry.icon) {
            const p = Quickshell.iconPath(String(entry.icon), true);
            if (p)
                return p;
        }
        const raw = String(cls || "").trim();
        if (!raw)
            return "";
        return Quickshell.iconPath(raw, true) || Quickshell.iconPath(raw.toLowerCase(), true);
    }

    readonly property var monitorWorkspaces: {
        void(Hyprland.workspaces.values);
        void(overviewOpen);
        const list = [];
        const vals = Hyprland.workspaces.values;
        if (!vals || !hyprMonitor)
            return list;
        for (let i = 0; i < vals.length; i++) {
            const ws = vals[i];
            if (!ws || ws.id <= 0)
                continue;
            if (ws.monitor && ws.monitor.name === hyprMonitor.name) {
                list.push(ws);
            }
        }
        list.sort((a, b) => a.id - b.id);
        return list;
    }

    function matchesQuery(toplevel) {
        const q = searchQuery.trim().toLowerCase();
        if (!q)
            return true;
        const title = String(toplevel.title || "").toLowerCase();
        const cls = String((toplevel.lastIpcObject && toplevel.lastIpcObject.class) || "");
        const clsLow = cls.toLowerCase();
        const friendly = friendlyAppName(cls, resolveDesktopEntry(cls)).toLowerCase();
        return title.indexOf(q) !== -1 || clsLow.indexOf(q) !== -1 || friendly.indexOf(q) !== -1;
    }

    function windowsForWorkspace(wsId) {
        void(Hyprland.toplevels.values);
        void(overviewOpen);
        void(searchQuery);
        const out = [];
        const vals = Hyprland.toplevels.values;
        if (!vals)
            return out;
        for (let i = 0; i < vals.length; i++) {
            const t = vals[i];
            if (!t || !t.workspace || t.workspace.id !== wsId)
                continue;
            if (matchesQuery(t)) {
                out.push(t);
            }
        }
        return out;
    }

    function firstMatchingWindow() {
        const vals = Hyprland.toplevels.values;
        if (!vals)
            return null;
        for (let i = 0; i < vals.length; i++) {
            const t = vals[i];
            if (!t || !t.workspace || t.workspace.id <= 0)
                continue;
            if (matchesQuery(t))
                return t;
        }
        return null;
    }

    function confirmSelection() {
        if (!win.tabNavigated && win.searchQuery.trim().length > 0) {
            const first = win.firstMatchingWindow();
            if (first) {
                win.windowSelected(first);
                return;
            }
        }
        if (win.selectedWorkspaceId > 0) {
            win.workspaceSelected(win.selectedWorkspaceId);
        } else {
            win.closeRequested();
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
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: isFocusedMonitor
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    color: "transparent"
    visible: overviewOpen

    Timer {
        id: focusTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (win.overviewOpen && win.isFocusedMonitor)
                searchInput.forceActiveFocus();
        }
    }

    onOverviewOpenChanged: {
        if (overviewOpen && isFocusedMonitor) {
            searchInput.text = "";
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    onIsFocusedMonitorChanged: {
        if (overviewOpen && isFocusedMonitor) {
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    // Con LazyLoader la ventana puede nacer ya abierta; el handler de cambio no
    // se dispara en ese caso y el buscador quedaría sin foco de teclado.
    Component.onCompleted: {
        if (overviewOpen && isFocusedMonitor) {
            searchInput.text = "";
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    Item {
        anchors.fill: parent

        // Oscurecimiento suave del fondo debajo de la barra superior (igual que los demás overlays)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: win.barHeight
            color: Theme.dimAround
        }

        // Línea cyan inferior de la barra superior para cohesión visual con el resto de overlays
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: win.barHeight - 2
            height: 2
            color: Theme.activeBorder
        }

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeRequested()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: win.barHeight + 24
            anchors.bottomMargin: 32
            anchors.leftMargin: 36
            anchors.rightMargin: 36
            spacing: 20

            // Barra superior: buscador (en el monitor enfocado) o etiqueta del monitor
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: win.isFocusedMonitor
                    Layout.preferredWidth: Math.min(580, win.width * 0.55)
                    Layout.preferredHeight: 46
                    color: Theme.surface
                    radius: Theme.radiusLarge
                    border.width: 2
                    border.color: Theme.activeBorder

                    // Absorber clics dentro de la barra de búsqueda
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchInput.forceActiveFocus()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10

                        Text {
                            text: "󰍉"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Theme.textBright
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            activeFocusOnTab: false
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: {
                                if (win.isFocusedMonitor && win.overviewOpen && text !== win.searchQuery) {
                                    win.searchUpdated(text);
                                }
                            }

                            Keys.onEscapePressed: win.closeRequested()
                            Keys.onReturnPressed: win.confirmSelection()
                            Keys.onEnterPressed: win.confirmSelection()
                            Keys.onTabPressed: event => {
                                event.accepted = true;
                                win.cycleWorkspaceRequested((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                            }
                            Keys.onBacktabPressed: event => {
                                event.accepted = true;
                                win.cycleWorkspaceRequested(-1);
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Buscar ventana... (Tab: actividades · Enter: ir · Esc: cerrar)"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                visible: !searchInput.text
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !win.isFocusedMonitor
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: monLabel.implicitWidth + 28
                    color: Theme.surface
                    radius: Theme.radiusLarge
                    border.width: 1
                    border.color: Theme.outlineVariant

                    Text {
                        id: monLabel
                        anchors.centerIn: parent
                        text: win.hyprMonitor ? win.hyprMonitor.name : ""
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Grilla de workspaces del monitor
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: win.width >= 1500 ? 3 : 2
                columnSpacing: 18
                rowSpacing: 18

                Repeater {
                    model: win.monitorWorkspaces

                    delegate: Rectangle {
                        id: wsCard
                        required property var modelData
                        readonly property var ws: modelData
                        readonly property var wsWindows: win.windowsForWorkspace(ws.id)
                        readonly property bool isCurrentWs: Boolean(
                            win.hyprMonitor && win.hyprMonitor.activeWorkspace && win.hyprMonitor.activeWorkspace.id === ws.id
                        )
                        readonly property bool isSelectedWs: win.selectedWorkspaceId > 0 && ws.id === win.selectedWorkspaceId

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: (isSelectedWs && win.tabNavigated) ? Theme.surfaceContainerHigh : Theme.surface
                        radius: Theme.radiusLarge
                        border.width: (isSelectedWs || wsHover.containsMouse || isCurrentWs) ? 2 : 1
                        border.color: ws.urgent
                            ? Theme.error
                            : ((isSelectedWs || wsHover.containsMouse)
                                ? Theme.activeBorder
                                : (isCurrentWs ? Theme.primary : Theme.outlineVariant))

                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.workspaceSelected(ws.id)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Encabezado del workspace
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 24
                                    radius: Theme.cardRadius
                                    color: (wsCard.isCurrentWs || wsCard.isSelectedWs) ? Theme.accent : Theme.cardBg
                                    border.width: Theme.borderWidth
                                    border.color: (wsCard.isCurrentWs || wsCard.isSelectedWs) ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: ws.name
                                        color: (wsCard.isCurrentWs || wsCard.isSelectedWs) ? Theme.accentText : Theme.textBright
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: wsWindows.length === 0
                                        ? "Vacío"
                                        : (wsWindows.length === 1 ? "1 ventana" : wsWindows.length + " ventanas")
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    visible: wsCard.isSelectedWs && win.tabNavigated
                                    width: enterHint.implicitWidth + 12
                                    height: 22
                                    radius: Theme.cardRadius
                                    color: Theme.cardBg
                                    border.width: Theme.borderWidth
                                    border.color: Theme.activeBorder

                                    Text {
                                        id: enterHint
                                        anchors.centerIn: parent
                                        text: "Enter ↵"
                                        color: Theme.activeBorder
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }

                            // Ventanas dentro del workspace
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: wsWindows.length === 0 && win.searchQuery.trim().length > 0
                                    text: "Sin coincidencias"
                                    color: Theme.fgSubtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Column {
                                    anchors.centerIn: parent
                                    visible: wsWindows.length === 0 && win.searchQuery.trim().length === 0
                                    spacing: 8

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 34
                                        height: 34
                                        radius: 17
                                        color: (wsHover.containsMouse || wsCard.isSelectedWs) ? Theme.primaryContainer : Theme.surfaceContainer
                                        opacity: (wsHover.containsMouse || wsCard.isSelectedWs) ? 1.0 : 0.45

                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰐕"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: (wsHover.containsMouse || wsCard.isSelectedWs) ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Clic para ir al workspace " + ws.name
                                        color: Theme.fgMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        opacity: (wsHover.containsMouse || wsCard.isSelectedWs) ? 1.0 : 0.0

                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                    }
                                }

                                GridLayout {
                                    anchors.fill: parent
                                    visible: wsWindows.length > 0
                                    columns: wsWindows.length <= 1 ? 1 : (wsWindows.length <= 4 ? 2 : 3)
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: wsWindows

                                        delegate: Rectangle {
                                            id: clientCard
                                            required property var modelData
                                            readonly property var toplevel: modelData
                                            readonly property string appClass: String(
                                                (toplevel.lastIpcObject && toplevel.lastIpcObject.class) || ""
                                            )
                                            readonly property var desktopEntry: win.resolveDesktopEntry(appClass)
                                            readonly property string appDisplayName: win.friendlyAppName(appClass, desktopEntry)
                                            readonly property string appIconSource: win.resolveAppIcon(appClass, desktopEntry)

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: clientHover.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                                            radius: Theme.cardRadius
                                            border.width: (clientHover.containsMouse || toplevel.activated) ? 2 : Theme.borderWidth
                                            border.color: toplevel.urgent
                                                ? Theme.urgent
                                                : (clientHover.containsMouse || toplevel.activated ? Theme.activeBorder : Theme.border)
                                            clip: true

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 6

                                                Item {
                                                    id: previewBox
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    ScreencopyView {
                                                        anchors.centerIn: parent
                                                        captureSource: clientCard.toplevel.wayland
                                                        live: win.overviewOpen
                                                        paintCursor: false
                                                        constraintSize: Qt.size(Math.max(1, previewBox.width), Math.max(1, previewBox.height))
                                                        readonly property real srcAspect: (sourceSize.width > 0 && sourceSize.height > 0)
                                                            ? (sourceSize.width / sourceSize.height)
                                                            : (previewBox.width / Math.max(1, previewBox.height))
                                                        readonly property real boxAspect: previewBox.width / Math.max(1, previewBox.height)
                                                        width: srcAspect >= boxAspect
                                                            ? previewBox.width
                                                            : Math.round(previewBox.height * srcAspect)
                                                        height: srcAspect >= boxAspect
                                                            ? Math.round(previewBox.width / Math.max(0.01, srcAspect))
                                                            : previewBox.height
                                                        visible: win.overviewOpen && clientCard.toplevel.wayland !== null
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !clientCard.toplevel.wayland
                                                        text: clientCard.appDisplayName
                                                        color: Theme.muted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 13
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 28
                                                    color: Theme.surfaceContainerLow
                                                    radius: Theme.radiusSmall

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        spacing: 6

                                                        Item {
                                                            Layout.preferredWidth: 16
                                                            Layout.preferredHeight: 16

                                                            Image {
                                                                id: clientIconImg
                                                                anchors.fill: parent
                                                                source: clientCard.appIconSource
                                                                sourceSize.width: 16
                                                                sourceSize.height: 16
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: true
                                                                visible: status === Image.Ready && clientCard.appIconSource !== ""
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: !clientIconImg.visible
                                                                text: "󰖯"
                                                                color: Theme.primary
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 13
                                                            }
                                                        }

                                                        Text {
                                                            text: clientCard.appDisplayName
                                                            color: Theme.primary
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 12
                                                            font.weight: Font.DemiBold
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: clientCard.toplevel.title || ""
                                                            color: Theme.fgMuted
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 12
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: clientHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    mouse.accepted = true;
                                                    win.windowSelected(clientCard.toplevel);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
