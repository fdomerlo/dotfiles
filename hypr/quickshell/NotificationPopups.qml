import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Notificaciones push acopladas directamente a la barra superior con esquinas
// cóncavas a ambos lados (mismo lenguaje arquitectónico que CalendarPopup y QuickSettings).
PanelWindow {
    id: popupWin

    required property var popups
    required property real nowMs
    property int barHeight: 38

    signal dismissRequested(int uid)
    signal popupCloseRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal hoverChanged(bool hovered)

    property int hoverCount: 0
    property bool revealed: false
    property var displayPopups: []
    readonly property bool hasItems: Boolean(popups && popups.length > 0)
    readonly property int cardWidth: 384
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
        }
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
                duration: popupWin.revealed ? Theme.animNormal : Theme.animClose
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
                y: popupWin.revealed ? 10 : -8
                spacing: 8

                Behavior on y {
                    NumberAnimation {
                        duration: popupWin.revealed ? Theme.animNormal : Theme.animClose
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: popupWin.revealed ? Theme.curveDecel : Theme.curveAccel
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
                        onHoverStateChanged: h => {
                            popupWin.hoverCount = Math.max(0, popupWin.hoverCount + (h ? 1 : -1));
                            popupWin.hoverChanged(popupWin.hoverCount > 0);
                        }
                    }
                }
            }
        }
    }
}
