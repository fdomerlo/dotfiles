import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: centerWin

    required property bool panelOpen
    required property var notifications
    required property bool dndEnabled
    required property real nowMs
    property int barHeight: 38

    signal closeRequested()
    signal toggleDndRequested()
    signal clearAllRequested()
    signal dismissRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal replySent(int uid, string text)

    property bool revealed: false

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
        escScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
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
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    FocusScope {
        id: escScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: centerWin.closeRequested()

        MouseArea {
            anchors.fill: parent
            enabled: centerWin.panelOpen
            onClicked: centerWin.closeRequested()
        }

        // Panel derecho acoplado a la barra superior con esquina cóncava izquierda
        Item {
            id: drawerDock
            anchors.top: parent.top
            anchors.topMargin: centerWin.barHeight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.right: parent.right
            width: centerWin.revealed ? 404 : 0
            opacity: centerWin.revealed ? 1.0 : 0.0

            Behavior on width {
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

            // Unión cóncava superior izquierda con la barra superior
            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.right: drawerSurface.left
                visible: drawerDock.width > 12
            }

            Item {
                id: drawerSurface
                anchors.fill: parent
                clip: true

                // Fondo redondeado solo en la esquina inferior izquierda (arriba y derecha fundidos)
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width + Theme.radiusLarge
                    height: parent.height + Theme.radiusLarge
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                // Absorber clics dentro del drawer
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    x: centerWin.revealed ? 16 : 36
                    width: 404 - 32
                    anchors.topMargin: 12
                    anchors.bottomMargin: 16
                    spacing: 12

                    Behavior on x {
                        NumberAnimation {
                            duration: centerWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: centerWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

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
                            height: 22
                            width: Math.max(24, countTxt.implicitWidth + 12)
                            radius: Theme.radiusFull
                            color: Theme.primaryContainer

                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: String(centerWin.notifications.length)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.fgOnPrimaryContainer
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Toggle compacto de No Molestar
                        Rectangle {
                            height: 30
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
                                    font.pixelSize: 13
                                    color: centerWin.dndEnabled ? Theme.fgOnErrorContainer : Theme.fgMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "DND"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
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
                            height: 30
                            width: clearTxt.implicitWidth + 18
                            radius: Theme.radiusFull
                            color: clearMouse.containsMouse ? Theme.errorContainer : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: clearTxt
                                anchors.centerIn: parent
                                text: "Limpiar"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
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
                                spacing: 8

                                Repeater {
                                    model: centerWin.notifications

                                    NotificationCard {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        entry: modelData
                                        nowMs: centerWin.nowMs
                                        compact: false

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
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.fg
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: centerWin.dndEnabled
                                    ? "Las notificaciones emergentes están silenciadas"
                                    : "No hay notificaciones pendientes"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.fgSubtle
                            }
                        }
                    }
                }
            }
        }
    }
}
