import QtQuick
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
        right: true
    }
    margins {
        top: barHeight
        right: 18 - cornerSize
    }

    implicitWidth: cardWidth + cornerSize * 2
    implicitHeight: Math.max(1, dockContainer.height)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    Item {
        id: dockContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: popupWin.cardWidth
        height: popupWin.revealed ? popupWin.targetHeight : 0
        opacity: popupWin.revealed ? 1.0 : 0.0

        Behavior on height {
            NumberAnimation {
                duration: popupWin.revealed ? Theme.animPop : Theme.animClose
                easing.type: Easing.BezierSpline
                easing.bezierCurve: popupWin.revealed ? Theme.curveExpressive : Theme.curveAccel
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
            anchors.top: parent.top
            anchors.right: dockBody.left
            visible: dockContainer.height > 10
        }

        // Esquina cóncava derecha fundida con la barra superior
        ConcaveCorner {
            position: "top-left"
            size: popupWin.cornerSize
            color: Theme.surface
            anchors.top: parent.top
            anchors.left: dockBody.right
            visible: dockContainer.height > 10
        }

        Item {
            id: dockBody
            anchors.fill: parent
            clip: true

            HoverHandler {
                id: dockHover
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height + Theme.radiusLarge
                radius: Theme.radiusLarge
                color: Theme.surface
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
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
                        duration: popupWin.revealed ? Theme.animPop : Theme.animClose
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: popupWin.revealed ? Theme.curveExpressive : Theme.curveAccel
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
