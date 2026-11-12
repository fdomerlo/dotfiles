import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property bool overviewOpen
    required property string searchQuery

    signal searchUpdated(string text)
    signal closeRequested()
    signal windowSelected(var toplevel)
    signal workspaceSelected(int wsId)

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool isFocusedMonitor: Boolean(
        Hyprland.focusedMonitor && hyprMonitor && Hyprland.focusedMonitor.name === hyprMonitor.name
    )

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
        const cls = String((toplevel.lastIpcObject && toplevel.lastIpcObject.class) || "").toLowerCase();
        return title.indexOf(q) !== -1 || cls.indexOf(q) !== -1;
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

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: overviewOpen
        ? (isFocusedMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
        : WlrKeyboardFocus.None

    color: "transparent"
    visible: overviewOpen

    onOverviewOpenChanged: {
        if (overviewOpen && isFocusedMonitor) {
            searchInput.text = "";
            searchInput.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeRequested()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 36
            spacing: 20

            // Barra superior: buscador (en el monitor enfocado) o etiqueta del monitor
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: win.isFocusedMonitor
                    Layout.preferredWidth: Math.min(540, win.width * 0.5)
                    Layout.preferredHeight: 42
                    color: Theme.panelBg
                    radius: Theme.radius
                    border.width: Theme.borderWidth
                    border.color: searchInput.activeFocus ? Theme.activeBorder : Theme.border

                    // Absorber clics dentro de la barra de búsqueda
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchInput.forceActiveFocus()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰍉"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Theme.textBright
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: {
                                if (win.isFocusedMonitor && win.overviewOpen && text !== win.searchQuery) {
                                    win.searchUpdated(text);
                                }
                            }

                            Keys.onEscapePressed: win.closeRequested()
                            Keys.onReturnPressed: {
                                const first = win.firstMatchingWindow();
                                if (first)
                                    win.windowSelected(first);
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Buscar ventana abierta... (Esc para cerrar)"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                visible: !searchInput.text
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !win.isFocusedMonitor
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: monLabel.implicitWidth + 28
                    color: Theme.panelBg
                    radius: Theme.radius
                    border.width: Theme.borderWidth
                    border.color: Theme.border

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

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.panelBg
                        radius: Theme.radius
                        border.width: isCurrentWs ? 2 : Theme.borderWidth
                        border.color: ws.urgent
                            ? Theme.urgent
                            : (wsHover.containsMouse || isCurrentWs ? Theme.activeBorder : Theme.border)

                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
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
                                    color: wsCard.isCurrentWs ? Theme.accent : Theme.cardBg
                                    border.width: Theme.borderWidth
                                    border.color: wsCard.isCurrentWs ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: ws.name
                                        color: wsCard.isCurrentWs ? "#05080b" : Theme.textBright
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: wsWindows.length === 0
                                        ? "Vacío"
                                        : (wsWindows.length === 1 ? "1 ventana" : wsWindows.length + " ventanas")
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Ventanas dentro del workspace
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: wsWindows.length === 0
                                    text: win.searchQuery.trim() ? "Sin coincidencias" : "Click para ir al workspace " + ws.name
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
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
                                                (toplevel.lastIpcObject && toplevel.lastIpcObject.class) || "Ventana"
                                            )

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
                                                        text: clientCard.appClass
                                                        color: Theme.muted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 13
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 24
                                                    color: Theme.panelBg
                                                    radius: Theme.cardRadius

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        spacing: 6

                                                        Text {
                                                            text: clientCard.appClass
                                                            color: Theme.accent
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: clientCard.toplevel.title || ""
                                                            color: Theme.text
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 11
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: clientHover
                                                anchors.fill: parent
                                                hoverEnabled: true
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
