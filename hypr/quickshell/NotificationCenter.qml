import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: centerWin

    required property bool panelOpen
    required property var notifications
    required property bool dndEnabled
    required property real nowMs
    property int barHeight: 40
    property bool notchMode: false
    property var barHitTester: null

    signal closeRequested()
    signal toggleDndRequested()
    signal clearAllRequested()
    signal dismissRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal replySent(int uid, string text)
    signal barMenuHovered(var scr, string target)
    signal barMenuClicked(var scr, string target, int button)
    signal barWorkspaceClicked(int wsId)

    property bool revealed: false
    property int selectedIndex: -1
    property bool keyboardNavActive: false

    function ensureSelectedVisible() {
        if (selectedIndex < 0 || !notifRepeater || selectedIndex >= notifRepeater.count)
            return;
        const item = notifRepeater.itemAt(selectedIndex);
        if (!item)
            return;
        const itemTop = item.y;
        const itemBottom = item.y + item.height;
        const maxY = Math.max(0, notifFlick.contentHeight - notifFlick.height);
        if (itemTop < notifFlick.contentY) {
            notifFlick.contentY = Math.max(0, itemTop);
        } else if (itemBottom > notifFlick.contentY + notifFlick.height) {
            notifFlick.contentY = Math.min(maxY, itemBottom - notifFlick.height);
        }
    }

    function moveSelection(delta) {
        if (!notifications || notifications.length === 0) {
            selectedIndex = -1;
            keyboardNavActive = false;
            return;
        }
        if (!keyboardNavActive) {
            keyboardNavActive = true;
            selectedIndex = delta > 0 ? 0 : (notifications.length - 1);
        } else {
            selectedIndex = (selectedIndex + delta + notifications.length) % notifications.length;
        }
        ensureSelectedVisible();
    }

    function dismissSelected() {
        if (!notifications || selectedIndex < 0 || selectedIndex >= notifications.length)
            return;
        const entry = notifications[selectedIndex];
        if (entry)
            centerWin.dismissRequested(entry.uid);
    }

    function activateSelected() {
        if (!notifications || selectedIndex < 0 || selectedIndex >= notifications.length)
            return;
        const entry = notifications[selectedIndex];
        if (!entry || !entry.notif || !entry.notif.actions)
            return;
        let defAct = null;
        let firstAct = null;
        for (let i = 0; i < entry.notif.actions.length; i++) {
            const act = entry.notif.actions[i];
            if (!act)
                continue;
            if (act.identifier === "default") {
                defAct = act;
                break;
            }
            if (!firstAct && String(act.text || "").trim().length > 0)
                firstAct = act;
        }
        const targetAct = defAct || firstAct;
        if (targetAct)
            centerWin.actionInvoked(entry.uid, targetAct);
    }

    onNotificationsChanged: {
        if (!notifications || notifications.length === 0) {
            selectedIndex = -1;
            keyboardNavActive = false;
        } else if (selectedIndex >= notifications.length) {
            selectedIndex = notifications.length - 1;
        } else if (selectedIndex < 0 && panelOpen) {
            selectedIndex = 0;
        }
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (centerWin.panelOpen)
                centerWin.revealed = true;
        }
    }

    Component.onCompleted: {
        keyboardNavActive = false;
        selectedIndex = (notifications && notifications.length > 0) ? 0 : -1;
        escScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            keyboardNavActive = false;
            selectedIndex = (notifications && notifications.length > 0) ? 0 : -1;
            escScope.forceActiveFocus();
            revealTimer.restart();
        } else {
            revealTimer.stop();
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
    WlrLayershell.namespace: "quickshell-notif-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    FocusScope {
        id: escScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: centerWin.closeRequested()
        Keys.onDownPressed: centerWin.moveSelection(1)
        Keys.onUpPressed: centerWin.moveSelection(-1)
        Keys.onDeletePressed: centerWin.dismissSelected()
        Keys.onReturnPressed: centerWin.activateSelected()
        Keys.onEnterPressed: centerWin.activateSelected()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
                event.accepted = true;
                centerWin.dismissSelected();
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: centerWin.panelOpen
            onClicked: centerWin.closeRequested()
        }

        TopBarOverlayBridge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: centerWin.barHeight
            z: 50
            barH: centerWin.barHeight
            screen: centerWin.screen
            active: centerWin.panelOpen
            currentTarget: "notifications"
            barHitTester: centerWin.barHitTester
            onMenuHovered: (scr, target) => centerWin.barMenuHovered(scr, target)
            onMenuClicked: (scr, target, btn) => centerWin.barMenuClicked(scr, target, btn)
            onWorkspaceClicked: wsId => centerWin.barWorkspaceClicked(wsId)
            onOutsideClicked: centerWin.closeRequested()
        }

        // Borde sutil inferior de la barra superior a ambos lados del desplegable
        Rectangle {
            visible: !centerWin.notchMode
            anchors.left: parent.left
            anchors.right: drawerDock.left
            anchors.rightMargin: drawerDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            y: centerWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: centerWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: centerWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: !centerWin.notchMode
            anchors.left: drawerDock.right
            anchors.leftMargin: drawerDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            anchors.right: parent.right
            y: centerWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: centerWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: centerWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Desplegable de notificaciones acoplado a la barra superior (o tarjeta centrada flotante a 8px en modo notch)
        Item {
            id: drawerDock
            readonly property int availHeight: Math.max(440, (centerWin.height > 0 ? centerWin.height : (centerWin.screen ? centerWin.screen.height : 1080)) - centerWin.barHeight - (centerWin.notchMode ? 16 : 0))
            readonly property int maxDrawerHeight: Math.round(availHeight * 0.80)
            readonly property int targetDrawerHeight: centerWin.notifications.length === 0
                ? 380
                : Math.min(maxDrawerHeight, Math.max(380, notifListCol.implicitHeight + 118))

            anchors.top: parent.top
            anchors.topMargin: centerWin.notchMode ? (centerWin.barHeight + 8) : centerWin.barHeight
            x: centerWin.notchMode ? Math.round((parent.width - width) / 2) : Math.max(0, parent.width - width - 18)
            width: 424
            height: centerWin.revealed ? targetDrawerHeight : 0
            opacity: centerWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: centerWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: centerWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: centerWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            // Uniones cóncavas superiores con la barra
            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.right: drawerSurface.left
                visible: !centerWin.notchMode && drawerDock.height >= Theme.concaveRadius
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.left: drawerSurface.right
                visible: !centerWin.notchMode && drawerDock.height >= Theme.concaveRadius
            }

            Item {
                id: drawerSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))
                readonly property real halfB: Theme.popoutBorderWidth / 2.0

                // Fondo redondeado (4 esquinas en modo flotante, o esquinas inferiores en modo acoplado)
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: centerWin.notchMode ? parent.height : (parent.height + Theme.radiusLarge)
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: centerWin.notchMode ? Theme.popoutBorderWidth : 0
                    border.color: Theme.popoutBorder
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: !centerWin.notchMode && drawerDock.height >= Theme.concaveRadius && drawerSurface.height >= Theme.concaveRadius + 4

                    ShapePath {
                        strokeWidth: Theme.popoutBorderWidth
                        strokeColor: Theme.popoutBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: drawerSurface.halfB
                        startY: Theme.concaveRadius

                        PathLine {
                            x: drawerSurface.halfB
                            y: drawerSurface.height - drawerSurface.cornerR
                        }
                        PathArc {
                            x: drawerSurface.cornerR
                            y: drawerSurface.height - drawerSurface.halfB
                            radiusX: drawerSurface.cornerR - drawerSurface.halfB
                            radiusY: drawerSurface.cornerR - drawerSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: drawerSurface.width - drawerSurface.cornerR
                            y: drawerSurface.height - drawerSurface.halfB
                        }
                        PathArc {
                            x: drawerSurface.width - drawerSurface.halfB
                            y: drawerSurface.height - drawerSurface.cornerR
                            radiusX: drawerSurface.cornerR - drawerSurface.halfB
                            radiusY: drawerSurface.cornerR - drawerSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: drawerSurface.width - drawerSurface.halfB
                            y: Theme.concaveRadius
                        }
                    }
                }

                // Absorber clics dentro del drawer
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    height: Math.max(120, drawerDock.targetDrawerHeight - 28)
                    spacing: 12

                    // Encabezado
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Notificaciones"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: Theme.fg
                        }

                        Rectangle {
                            visible: centerWin.notifications.length > 0
                            height: 24
                            width: Math.max(24, countTxt.implicitWidth + 12)
                            radius: Theme.radiusFull
                            color: Theme.primaryContainer

                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: String(centerWin.notifications.length)
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.fgOnPrimaryContainer
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Toggle compacto de No Molestar
                        Rectangle {
                            height: 32
                            width: dndBtnRow.implicitWidth + 18
                            radius: Theme.radiusFull
                            color: centerWin.dndEnabled
                                ? Theme.errorContainer
                                : (dndBtnM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Row {
                                id: dndBtnRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: centerWin.dndEnabled ? "󰂛" : "󰂚"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    color: centerWin.dndEnabled ? Theme.fgOnErrorContainer : Theme.fgMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "No molestar"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: centerWin.dndEnabled ? Theme.fgOnErrorContainer : Theme.fgMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: dndBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: centerWin.toggleDndRequested()
                            }
                        }

                        // Botón Limpiar todo
                        Rectangle {
                            visible: centerWin.notifications.length > 0
                            height: 32
                            width: clearTxt.implicitWidth + 18
                            radius: Theme.radiusFull
                            color: clearMouse.containsMouse ? Theme.errorContainer : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: clearTxt
                                anchors.centerIn: parent
                                text: "Limpiar"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: clearMouse.containsMouse ? Theme.fgOnErrorContainer : Theme.fg
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: centerWin.clearAllRequested()
                            }
                        }
                    }

                    // Lista scrollable de notificaciones
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: notifFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: notifListCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: centerWin.notifications.length > 0

                            ColumnLayout {
                                id: notifListCol
                                width: notifFlick.width
                                spacing: 10

                                Repeater {
                                    id: notifRepeater
                                    model: centerWin.notifications

                                    NotificationCard {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        entry: modelData
                                        nowMs: centerWin.nowMs
                                        compact: false
                                        keyboardSelected: centerWin.keyboardNavActive && (index === centerWin.selectedIndex)

                                        onDismissRequested: uid => centerWin.dismissRequested(uid)
                                        onActionInvoked: (uid, action) => centerWin.actionInvoked(uid, action)
                                        onReplySent: (uid, msg) => centerWin.replySent(uid, msg)
                                    }
                                }
                            }
                        }

                        // Estado vacío estilizado
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: centerWin.notifications.length === 0
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 64
                                height: 64
                                radius: 32
                                color: centerWin.dndEnabled ? Theme.errorContainer : Theme.surfaceContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: centerWin.dndEnabled ? "󰂛" : "󰂜"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    color: centerWin.dndEnabled ? Theme.fgOnErrorContainer : Theme.fgSubtle
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: centerWin.dndEnabled ? "No molestar activo" : "Todo al día"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: Theme.fg
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: centerWin.dndEnabled
                                    ? "Las notificaciones emergentes están silenciadas"
                                    : "No hay notificaciones pendientes"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.fgSubtle
                            }
                        }
                    }

                    Text {
                        visible: centerWin.notifications.length > 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "↑↓: seleccionar · Enter: acción · Supr: descartar · Esc: cerrar"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.fgSubtle
                        opacity: 0.78
                    }
                }
            }
        }
    }
}
