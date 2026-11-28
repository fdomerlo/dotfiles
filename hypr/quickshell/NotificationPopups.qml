import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Notificaciones push acopladas directamente a la barra superior con esquinas
// cóncavas a ambos lados (mismo lenguaje arquitectónico que DashboardPopup).
PanelWindow {
    id: popupWin

    required property var popups
    required property real nowMs
    property int barHeight: 40
    property bool notchMode: false

    signal dismissRequested(int uid)
    signal popupCloseRequested(int uid)
    signal closeAllPopupsRequested()
    signal actionInvoked(int uid, var action)
    signal hoverChanged(bool hovered)

    property bool revealed: false
    property var displayPopups: []
    readonly property bool dockHovered: dockHover.hovered
    readonly property bool hasItems: Boolean(popups && popups.length > 0)
    readonly property int cardWidth: 396
    readonly property int cornerSize: Theme.concaveRadius
    readonly property int targetHeight: (displayPopups && displayPopups.length > 0) ? (stackCol.implicitHeight + 22) : 0

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (popupWin.hasItems)
                popupWin.revealed = true;
        }
    }

    Component.onCompleted: {
        if (hasItems) {
            displayPopups = popups;
            revealTimer.restart();
        }
    }

    onPopupsChanged: {
        if (popups && popups.length > 0)
            displayPopups = popups;
    }

    onHasItemsChanged: {
        if (hasItems) {
            displayPopups = popups;
            revealTimer.restart();
        } else {
            revealTimer.stop();
            revealed = false;
            popupWin.hoverChanged(false);
        }
    }

    onDockHoveredChanged: {
        popupWin.hoverChanged(hasItems && dockHovered);
    }

    anchors {
        top: true
        right: !popupWin.notchMode
    }
    margins {
        top: popupWin.notchMode ? (popupWin.barHeight + 8) : popupWin.barHeight
        right: popupWin.notchMode ? 0 : (18 - cornerSize)
    }

    implicitWidth: cardWidth + cornerSize * 2
    implicitHeight: Math.min(620, Math.max(320, (popupWin.screen ? popupWin.screen.height : 900) - barHeight - 32))

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: (popupWin.hasItems && dockContainer.height > 1) ? popupMask : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    Region {
        id: popupMask
        item: dockContainer
    }

    Item {
        id: dockContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: popupWin.cardWidth
        height: popupWin.revealed ? Math.min(popupWin.implicitHeight - 4, popupWin.targetHeight) : 0
        opacity: popupWin.revealed ? 1.0 : 0.0

        Behavior on height {
            NumberAnimation {
                duration: popupWin.revealed ? Theme.animTab : Theme.animClose
                easing.type: Easing.BezierSpline
                easing.bezierCurve: popupWin.revealed ? Theme.curveDecel : Theme.curveAccel
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: popupWin.revealed ? Theme.animFast : Theme.animClose
                easing.type: Easing.OutCubic
            }
        }

        // Esquina cóncava izquierda fundida con la barra superior
        ConcaveCorner {
            position: "top-right"
            size: popupWin.cornerSize
            color: Theme.surface
            borderWidth: Theme.popoutBorderWidth
            borderColor: Theme.popoutBorder
            anchors.top: parent.top
            anchors.right: dockBody.left
            visible: !popupWin.notchMode && dockContainer.height >= popupWin.cornerSize
        }

        // Esquina cóncava derecha fundida con la barra superior
        ConcaveCorner {
            position: "top-left"
            size: popupWin.cornerSize
            color: Theme.surface
            borderWidth: Theme.popoutBorderWidth
            borderColor: Theme.popoutBorder
            anchors.top: parent.top
            anchors.left: dockBody.right
            visible: !popupWin.notchMode && dockContainer.height >= popupWin.cornerSize
        }

        Item {
            id: dockBody
            anchors.fill: parent
            clip: true

            readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - popupWin.cornerSize))
            readonly property real halfB: Theme.popoutBorderWidth / 2.0

            HoverHandler {
                id: dockHover
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: popupWin.notchMode ? parent.height : (parent.height + Theme.radiusLarge)
                radius: Theme.radiusLarge
                color: Theme.surface
                border.width: popupWin.notchMode ? Theme.popoutBorderWidth : 0
                border.color: Theme.popoutBorder
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true
                visible: !popupWin.notchMode && dockContainer.height >= popupWin.cornerSize && dockBody.height >= popupWin.cornerSize + 4

                ShapePath {
                    strokeWidth: Theme.popoutBorderWidth
                    strokeColor: Theme.popoutBorder
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: dockBody.halfB
                    startY: popupWin.cornerSize

                    PathLine {
                        x: dockBody.halfB
                        y: dockBody.height - dockBody.cornerR
                    }
                    PathArc {
                        x: dockBody.cornerR
                        y: dockBody.height - dockBody.halfB
                        radiusX: dockBody.cornerR - dockBody.halfB
                        radiusY: dockBody.cornerR - dockBody.halfB
                        direction: PathArc.Counterclockwise
                    }
                    PathLine {
                        x: dockBody.width - dockBody.cornerR
                        y: dockBody.height - dockBody.halfB
                    }
                    PathArc {
                        x: dockBody.width - dockBody.halfB
                        y: dockBody.height - dockBody.cornerR
                        radiusX: dockBody.cornerR - dockBody.halfB
                        radiusY: dockBody.cornerR - dockBody.halfB
                        direction: PathArc.Counterclockwise
                    }
                    PathLine {
                        x: dockBody.width - dockBody.halfB
                        y: popupWin.cornerSize
                    }
                }
            }

            ColumnLayout {
                id: stackCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                y: popupWin.revealed ? 10 : -10
                spacing: 8

                Behavior on y {
                    NumberAnimation {
                        duration: popupWin.revealed ? Theme.animTab : Theme.animClose
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: popupWin.revealed ? Theme.curveDecel : Theme.curveAccel
                    }
                }

                // Cabecera compacta solo cuando hay múltiples toasts apilados
                RowLayout {
                    visible: popupWin.displayPopups.length > 1
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: popupWin.displayPopups.length + " avisos activos"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.fgSubtle
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 22
                        width: dismissAllTxt.implicitWidth + 16
                        radius: Theme.radiusFull
                        color: dismissAllM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: dismissAllTxt
                            anchors.centerIn: parent
                            text: "Ocultar todos"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: dismissAllM.containsMouse ? Theme.fg : Theme.fgMuted
                        }

                        MouseArea {
                            id: dismissAllM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupWin.closeAllPopupsRequested()
                        }
                    }
                }

                Repeater {
                    model: popupWin.displayPopups

                    NotificationCard {
                        required property var modelData
                        Layout.fillWidth: true
                        entry: modelData
                        nowMs: popupWin.nowMs
                        compact: true

                        onDismissRequested: uid => popupWin.dismissRequested(uid)
                        onPopupCloseRequested: uid => popupWin.popupCloseRequested(uid)
                        onActionInvoked: (uid, action) => popupWin.actionInvoked(uid, action)
                    }
                }
            }
        }
    }
}
