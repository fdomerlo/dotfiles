import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: clipWin

    required property bool panelOpen
    property int barHeight: 40
    property bool notchMode: false
    property var barHitTester: null

    signal closeRequested()
    signal barMenuHovered(var scr, string target)
    signal barMenuClicked(var scr, string target, int button)
    signal barWorkspaceClicked(int wsId)

    readonly property int panelWidth: Math.min(680, Math.max(520, (clipWin.screen ? clipWin.screen.width : 1280) - 64))
    readonly property int panelHeight: Math.min(560, (clipWin.screen ? clipWin.screen.height : 900) - clipWin.barHeight - 80)

    property bool revealed: false
    property bool loading: false
    property var allItems: []
    property int totalCount: 0
    property string searchQuery: ""
    property string filterMode: "all" // "all" | "text" | "images"
    property int selectedIndex: 0
    property bool confirmWipe: false
    property string pendingDeleteId: ""

    readonly property var filteredItems: {
        const items = allItems || [];
        const q = String(searchQuery || "").trim().toLowerCase();
        const mode = filterMode;
        const out = [];
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            if (!it)
                continue;
            if (mode === "images" && !it.isImage)
                continue;
            if (mode === "text" && it.isImage)
                continue;
            if (q.length > 0) {
                const hay = (String(it.preview || "") + " " + String(it.meta || "") + (it.isImage ? " imagen img captura" : " texto")).toLowerCase();
                if (hay.indexOf(q) === -1)
                    continue;
            }
            out.push(it);
        }
        return out;
    }

    function normalizePreview(raw) {
        return String(raw || "").replace(/[\r\n\t]+/g, " ").replace(/\s{2,}/g, " ").trim();
    }

    function cycleFilterMode() {
        if (filterMode === "all")
            filterMode = "text";
        else if (filterMode === "text")
            filterMode = "images";
        else
            filterMode = "all";
        selectedIndex = 0;
    }

    function setFilterMode(mode) {
        filterMode = mode;
        selectedIndex = 0;
        if (clipList.count > 0)
            clipList.positionViewAtIndex(0, ListView.Beginning);
        clipSearchInput.forceActiveFocus();
    }

    function moveSelection(delta) {
        const len = filteredItems.length;
        if (len <= 0)
            return;
        let next = selectedIndex + delta;
        if (next < 0)
            next = len - 1;
        else if (next >= len)
            next = 0;
        selectedIndex = next;
        clipList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function refreshList() {
        loading = true;
        if (listProc.running)
            listProc.running = false;
        listProc.running = true;
    }

    function copyItem(item) {
        if (!item || !item.id)
            return;
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/clipboard.sh", "--copy", String(item.id)]);
        clipWin.closeRequested();
    }

    function deleteItem(item) {
        if (!item || !item.id)
            return;
        const idStr = String(item.id);
        const nextAll = [];
        for (let i = 0; i < allItems.length; i++) {
            if (allItems[i] && String(allItems[i].id) !== idStr)
                nextAll.push(allItems[i]);
        }
        allItems = nextAll;
        totalCount = Math.max(0, totalCount - 1);
        if (selectedIndex >= filteredItems.length)
            selectedIndex = Math.max(0, filteredItems.length - 1);

        pendingDeleteId = idStr;
        if (deleteProc.running)
            deleteProc.running = false;
        deleteProc.running = true;
    }

    function triggerWipe() {
        if (totalCount <= 0 && allItems.length === 0)
            return;
        if (!confirmWipe) {
            confirmWipe = true;
            wipeConfirmTimer.restart();
            return;
        }
        wipeConfirmTimer.stop();
        confirmWipe = false;
        allItems = [];
        totalCount = 0;
        selectedIndex = 0;
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/clipboard.sh", "--wipe"]);
    }

    onFilteredItemsChanged: {
        const len = filteredItems.length;
        if (len === 0)
            selectedIndex = 0;
        else if (selectedIndex >= len)
            selectedIndex = len - 1;
    }

    Process {
        id: listProc
        command: [
            "sh", "-c",
            "\"$HOME/.config/hypr/scripts/clipboard.sh\" --json"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                clipWin.loading = false;
                try {
                    const parsed = JSON.parse(String(text || "{}"));
                    clipWin.totalCount = Number(parsed.total) || 0;
                    clipWin.allItems = Array.isArray(parsed.items) ? parsed.items : [];
                    clipWin.selectedIndex = 0;
                } catch (err) {
                    clipWin.totalCount = 0;
                    clipWin.allItems = [];
                }
            }
        }
    }

    Process {
        id: deleteProc
        command: [
            "sh", "-c",
            "\"$HOME/.config/hypr/scripts/clipboard.sh\" --delete \"$1\"",
            "_",
            clipWin.pendingDeleteId
        ]
        onExited: (code, status) => {
            if (clipWin.panelOpen)
                clipWin.refreshList();
        }
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (clipWin.panelOpen)
                clipWin.revealed = true;
        }
    }

    Timer {
        id: wipeConfirmTimer
        interval: 3000
        repeat: false
        onTriggered: clipWin.confirmWipe = false
    }

    Component.onCompleted: {
        if (panelOpen) {
            searchQuery = "";
            filterMode = "all";
            selectedIndex = 0;
            confirmWipe = false;
            refreshList();
            revealTimer.restart();
            clipSearchInput.forceActiveFocus();
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            searchQuery = "";
            filterMode = "all";
            selectedIndex = 0;
            confirmWipe = false;
            refreshList();
            revealTimer.restart();
            clipSearchInput.forceActiveFocus();
        } else {
            revealTimer.stop();
            wipeConfirmTimer.stop();
            confirmWipe = false;
            revealed = false;
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
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    FocusScope {
        id: clipScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (clipWin.searchQuery.length > 0) {
                clipWin.searchQuery = "";
                clipSearchInput.text = "";
            } else {
                clipWin.closeRequested();
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up) {
                clipWin.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                clipWin.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (clipWin.filteredItems.length > 0)
                    clipWin.copyItem(clipWin.filteredItems[clipWin.selectedIndex]);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                clipWin.cycleFilterMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete && ((event.modifiers & Qt.ShiftModifier) || (event.modifiers & Qt.ControlModifier))) {
                if (clipWin.filteredItems.length > 0)
                    clipWin.deleteItem(clipWin.filteredItems[clipWin.selectedIndex]);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: clipWin.panelOpen
            onClicked: clipWin.closeRequested()
        }

        TopBarOverlayBridge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: clipWin.barHeight
            z: 50
            barH: clipWin.barHeight
            screen: clipWin.screen
            active: clipWin.panelOpen
            currentTarget: ""
            barHitTester: clipWin.barHitTester
            onMenuHovered: (scr, target) => clipWin.barMenuHovered(scr, target)
            onMenuClicked: (scr, target, btn) => clipWin.barMenuClicked(scr, target, btn)
            onWorkspaceClicked: wsId => clipWin.barWorkspaceClicked(wsId)
            onOutsideClicked: clipWin.closeRequested()
        }

        // Borde sutil inferior de la barra superior a ambos lados del panel
        Rectangle {
            visible: !clipWin.notchMode
            anchors.left: parent.left
            anchors.right: clipDock.left
            anchors.rightMargin: clipDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            y: clipWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: clipWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: clipWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: !clipWin.notchMode
            anchors.left: clipDock.right
            anchors.leftMargin: clipDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            anchors.right: parent.right
            y: clipWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: clipWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: clipWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Panel superior-central de Portapapeles acoplado (o flotante a 8px en modo notch)
        Item {
            id: clipDock
            anchors.top: parent.top
            anchors.topMargin: clipWin.notchMode ? (clipWin.barHeight + 8) : clipWin.barHeight
            anchors.horizontalCenter: parent.horizontalCenter
            width: clipWin.panelWidth
            height: clipWin.revealed ? clipWin.panelHeight : 0
            opacity: clipWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: clipWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: clipWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: clipWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.right: clipSurface.left
                visible: !clipWin.notchMode && clipDock.height >= Theme.concaveRadius
                z: 2
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.left: clipSurface.right
                visible: !clipWin.notchMode && clipDock.height >= Theme.concaveRadius
                z: 2
            }

            Item {
                id: clipSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))
                readonly property real halfB: Theme.popoutBorderWidth / 2.0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: clipWin.notchMode ? parent.height : (parent.height + Theme.radiusLarge)
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: clipWin.notchMode ? Theme.popoutBorderWidth : 0
                    border.color: Theme.popoutBorder
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: !clipWin.notchMode && clipDock.height >= Theme.concaveRadius
                    z: 2

                    ShapePath {
                        strokeWidth: Theme.popoutBorderWidth
                        strokeColor: Theme.popoutBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: clipSurface.halfB
                        startY: Theme.concaveRadius

                        PathLine {
                            x: clipSurface.halfB
                            y: clipSurface.height - clipSurface.cornerR
                        }
                        PathArc {
                            x: clipSurface.cornerR
                            y: clipSurface.height - clipSurface.halfB
                            radiusX: clipSurface.cornerR - clipSurface.halfB
                            radiusY: clipSurface.cornerR - clipSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: clipSurface.width - clipSurface.cornerR
                            y: clipSurface.height - clipSurface.halfB
                        }
                        PathArc {
                            x: clipSurface.width - clipSurface.halfB
                            y: clipSurface.height - clipSurface.cornerR
                            radiusX: clipSurface.cornerR - clipSurface.halfB
                            radiusY: clipSurface.cornerR - clipSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: clipSurface.width - clipSurface.halfB
                            y: Theme.concaveRadius
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 14
                    anchors.bottomMargin: 12
                    spacing: 10

                    // Cabecera + filtros + Vaciar historial
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "󰅌"
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            color: Theme.primary
                        }

                        Text {
                            text: "Portapapeles"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.fg
                        }

                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: countTxt.implicitWidth + 14
                            radius: Theme.radiusFull
                            color: Theme.surfaceContainer

                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: clipWin.filteredItems.length + (clipWin.filteredItems.length === 1 ? " elemento" : " elementos")
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 11
                                color: Theme.fgSubtle
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Chips de filtro: Todo / Texto / Imágenes
                        RowLayout {
                            spacing: 4

                            Repeater {
                                model: [
                                    { id: "all", label: "Todo" },
                                    { id: "text", label: "Texto" },
                                    { id: "images", label: "Imágenes" }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active: clipWin.filterMode === modelData.id

                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: chipTxt.implicitWidth + 18
                                    radius: Theme.radiusFull
                                    color: active
                                        ? Theme.primaryContainer
                                        : (chipM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        id: chipTxt
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: active ? Font.Bold : Font.Medium
                                        color: active ? Theme.fgOnPrimaryContainer : Theme.fgMuted
                                    }

                                    MouseArea {
                                        id: chipM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipWin.setFilterMode(modelData.id)
                                    }
                                }
                            }
                        }

                        // Vaciar todo en 2 pasos
                        Rectangle {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: wipeRow.implicitWidth + 16
                            radius: Theme.radiusFull
                            enabled: clipWin.allItems.length > 0
                            opacity: enabled ? 1.0 : 0.45
                            color: clipWin.confirmWipe
                                ? Theme.errorContainer
                                : (wipeM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                id: wipeRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: clipWin.confirmWipe ? "󰀦" : "󰃢"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: clipWin.confirmWipe ? Theme.fgOnErrorContainer : Theme.error
                                }

                                Text {
                                    text: clipWin.confirmWipe ? "¿Confirmar?" : "Vaciar"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: clipWin.confirmWipe ? Theme.fgOnErrorContainer : Theme.fgMuted
                                }
                            }

                            MouseArea {
                                id: wipeM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: clipWin.triggerWipe()
                            }
                        }
                    }

                    // Lista principal de entradas
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: clipList
                            anchors.fill: parent
                            anchors.rightMargin: 8
                            clip: true
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            model: clipWin.filteredItems
                            currentIndex: clipWin.selectedIndex

                            delegate: Rectangle {
                                id: rowCard
                                required property var modelData
                                required property int index

                                readonly property bool isImg: Boolean(modelData && modelData.isImage)
                                readonly property bool isSelected: clipWin.selectedIndex === index

                                width: clipList.width
                                height: isImg ? 76 : 54
                                radius: Theme.radiusMedium
                                color: isSelected
                                    ? Theme.primaryContainer
                                    : (rowM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow)
                                border.width: isSelected ? 1 : 0
                                border.color: Qt.alpha(Theme.primary, 0.5)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    // Miniatura real para imágenes / glifo para texto
                                    Item {
                                        Layout.preferredWidth: rowCard.isImg ? 96 : 34
                                        Layout.preferredHeight: rowCard.isImg ? 56 : 34

                                        ClippingRectangle {
                                            visible: rowCard.isImg
                                            anchors.fill: parent
                                            radius: Theme.radiusSmall
                                            color: Theme.surfaceContainerHighest

                                            Image {
                                                id: thumbImg
                                                anchors.fill: parent
                                                source: rowCard.isImg ? String(rowCard.modelData.thumbPath || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                                sourceSize.width: 192
                                                sourceSize.height: 112
                                            }

                                            Text {
                                                visible: thumbImg.status !== Image.Ready
                                                anchors.centerIn: parent
                                                text: "󰋩"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 22
                                                color: rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.primary
                                            }
                                        }

                                        Rectangle {
                                            visible: !rowCard.isImg
                                            anchors.fill: parent
                                            radius: Theme.radiusSmall
                                            color: rowCard.isSelected
                                                ? Qt.alpha(Theme.fgOnPrimaryContainer, 0.14)
                                                : Theme.surfaceContainerHigh

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰦨"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 16
                                                color: rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.primary
                                            }
                                        }
                                    }

                                    // Contenido textual / metadata imagen
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            visible: rowCard.isImg
                                            text: "Imagen copiada"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: rowCard.isSelected ? Font.Bold : Font.DemiBold
                                            color: rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: rowCard.isImg
                                            text: String(rowCard.modelData.meta || rowCard.modelData.preview || "")
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 11
                                            color: rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                            opacity: rowCard.isSelected ? 0.85 : 1.0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: !rowCard.isImg
                                            text: clipWin.normalizePreview(rowCard.modelData.preview)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: rowCard.isSelected ? Font.DemiBold : Font.Normal
                                            color: rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.fg
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Botón eliminar entrada individual
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        z: 2
                                        color: delM.containsMouse
                                            ? Theme.errorContainer
                                            : Qt.alpha(Theme.surfaceContainerHighest, rowCard.isSelected ? 0.35 : 0.65)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰆴"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: delM.containsMouse
                                                ? Theme.fgOnErrorContainer
                                                : (rowCard.isSelected ? Theme.fgOnPrimaryContainer : Theme.fgSubtle)
                                        }

                                        MouseArea {
                                            id: delM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: clipWin.deleteItem(rowCard.modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowM
                                    anchors.fill: parent
                                    anchors.rightMargin: 44
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: clipWin.selectedIndex = rowCard.index
                                    onClicked: clipWin.copyItem(rowCard.modelData)
                                }
                            }
                        }

                        // Scrollbar delgada
                        Rectangle {
                            visible: clipList.contentHeight > clipList.height
                            anchors.top: clipList.top
                            anchors.bottom: clipList.bottom
                            anchors.right: parent.right
                            width: 4
                            radius: 2
                            color: Qt.alpha(Theme.outlineVariant, 0.28)

                            Rectangle {
                                width: parent.width
                                radius: 2
                                color: Qt.alpha(Theme.primary, 0.65)
                                y: clipList.contentHeight > 0
                                    ? (clipList.contentY / clipList.contentHeight) * parent.height
                                    : 0
                                height: clipList.contentHeight > 0
                                    ? Math.max(24, (clipList.height / clipList.contentHeight) * parent.height)
                                    : parent.height
                            }
                        }

                        // Estado vacío
                        ColumnLayout {
                            visible: clipWin.filteredItems.length === 0
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clipWin.loading ? "󰔟" : "󰅌"
                                font.family: Theme.fontFamily
                                font.pixelSize: 28
                                color: Theme.fgSubtle
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clipWin.loading
                                    ? "Cargando historial..."
                                    : (clipWin.searchQuery.length > 0 || clipWin.filterMode !== "all"
                                        ? "Sin coincidencias para este filtro"
                                        : "El portapapeles está vacío")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Theme.fgSubtle
                            }
                        }
                    }

                    // Barra de búsqueda persistente abajo
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.radiusMedium
                        color: Theme.surfaceContainerLowest
                        border.width: clipSearchInput.activeFocus ? 1 : 1
                        border.color: clipSearchInput.activeFocus
                            ? Qt.alpha(Theme.primary, 0.72)
                            : Theme.outlineVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰍉"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                color: Theme.primary
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: "Filtrar historial del portapapeles..."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.fgSubtle
                                    elide: Text.ElideRight
                                    visible: clipSearchInput.text.length === 0
                                }

                                TextInput {
                                    id: clipSearchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.fg
                                    selectionColor: Theme.primaryContainer
                                    selectedTextColor: Theme.fgOnPrimaryContainer
                                    clip: true
                                    text: clipWin.searchQuery
                                    onTextChanged: {
                                        if (clipWin.panelOpen && text !== clipWin.searchQuery) {
                                            clipWin.searchQuery = text;
                                            clipWin.selectedIndex = 0;
                                        }
                                    }
                                    Keys.onUpPressed: clipWin.moveSelection(-1)
                                    Keys.onDownPressed: clipWin.moveSelection(1)
                                    Keys.onReturnPressed: {
                                        if (clipWin.filteredItems.length > 0)
                                            clipWin.copyItem(clipWin.filteredItems[clipWin.selectedIndex]);
                                    }
                                    Keys.onEnterPressed: {
                                        if (clipWin.filteredItems.length > 0)
                                            clipWin.copyItem(clipWin.filteredItems[clipWin.selectedIndex]);
                                    }
                                    Keys.onTabPressed: event => {
                                        clipWin.cycleFilterMode();
                                        event.accepted = true;
                                    }
                                    Keys.onEscapePressed: {
                                        if (clipWin.searchQuery.length > 0) {
                                            clipWin.searchQuery = "";
                                            clipSearchInput.text = "";
                                        } else {
                                            clipWin.closeRequested();
                                        }
                                    }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Delete && ((event.modifiers & Qt.ShiftModifier) || (event.modifiers & Qt.ControlModifier))) {
                                            if (clipWin.filteredItems.length > 0)
                                                clipWin.deleteItem(clipWin.filteredItems[clipWin.selectedIndex]);
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: clipWin.searchQuery.length > 0
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 12
                                color: clearM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.fgSubtle
                                }

                                MouseArea {
                                    id: clearM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        clipWin.searchQuery = "";
                                        clipSearchInput.text = "";
                                        clipSearchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    // Pie con atajos
                    Text {
                        Layout.fillWidth: true
                        text: "↑↓: mover · Enter: copiar · Shift+Supr: borrar · Tab: filtro · Esc: cerrar"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.fgSubtle
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
