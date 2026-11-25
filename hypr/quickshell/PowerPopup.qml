import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: pwrWin

    required property bool panelOpen
    required property var sysState

    signal closeRequested()

    readonly property int barH: sysState ? sysState.barHeight : 38
    property bool revealed: false
    property int selectedIndex: -1

    readonly property var actions: [
        {
            id: "lock",
            glyph: "󰌾",
            title: "Bloquear",
            subtitle: "Super+L",
            danger: false
        },
        {
            id: "suspend",
            glyph: "󰤄",
            title: "Suspender",
            subtitle: "Reposo rápido",
            danger: false
        },
        {
            id: "hibernate",
            glyph: "󰒲",
            title: "Hibernar",
            subtitle: "Guardar en disco",
            danger: false
        },
        {
            id: "logout",
            glyph: "󰍃",
            title: "Cerrar sesión",
            subtitle: "Salir de Hyprland",
            danger: false
        },
        {
            id: "reboot",
            glyph: "󰑐",
            title: "Reiniciar",
            subtitle: "Reiniciar equipo",
            danger: true
        },
        {
            id: "shutdown",
            glyph: "󰐥",
            title: "Apagar",
            subtitle: "Apagar equipo",
            danger: true
        }
    ]

    function triggerAction(actionId) {
        const home = Quickshell.env("HOME") || "";
        pwrWin.closeRequested();
        if (actionId === "lock") {
            Quickshell.execDetached(["sh", "-c", "pidof hyprlock >/dev/null 2>&1 || exec hyprlock"]);
        } else if (actionId === "suspend") {
            Quickshell.execDetached([home + "/.config/hypr/scripts/idle-suspend.sh"]);
        } else if (actionId === "hibernate") {
            Quickshell.execDetached([
                "sh", "-c",
                "systemctl hibernate 2>/dev/null || notify-send -u critical -a 'Sistema' 'Hibernación no disponible' 'Verificá Secure Boot desactivado en UEFI/BIOS, /swapfile >= RAM y make host.'"
            ]);
        } else if (actionId === "logout") {
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        } else if (actionId === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (actionId === "shutdown") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (pwrWin.panelOpen)
                pwrWin.revealed = true;
        }
    }

    Component.onCompleted: {
        pwrScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            selectedIndex = -1;
            pwrScope.forceActiveFocus();
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
    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    FocusScope {
        id: pwrScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: pwrWin.closeRequested()
        Keys.onRightPressed: {
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0) ? 0 : ((pwrWin.selectedIndex + 1) % pwrWin.actions.length);
        }
        Keys.onLeftPressed: {
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0)
                ? (pwrWin.actions.length - 1)
                : ((pwrWin.selectedIndex - 1 + pwrWin.actions.length) % pwrWin.actions.length);
        }
        Keys.onDownPressed: {
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0) ? 0 : ((pwrWin.selectedIndex + 2) % pwrWin.actions.length);
        }
        Keys.onUpPressed: {
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0)
                ? (pwrWin.actions.length - 1)
                : ((pwrWin.selectedIndex - 2 + pwrWin.actions.length) % pwrWin.actions.length);
        }
        Keys.onReturnPressed: {
            if (pwrWin.selectedIndex >= 0 && pwrWin.selectedIndex < pwrWin.actions.length)
                pwrWin.triggerAction(pwrWin.actions[pwrWin.selectedIndex].id);
        }
        Keys.onEnterPressed: {
            if (pwrWin.selectedIndex >= 0 && pwrWin.selectedIndex < pwrWin.actions.length)
                pwrWin.triggerAction(pwrWin.actions[pwrWin.selectedIndex].id);
        }

        MouseArea {
            anchors.fill: parent
            enabled: pwrWin.panelOpen
            onClicked: pwrWin.closeRequested()
        }

        // Contenedor acoplado a la barra superior (extremo derecho) con esquinas cóncavas
        Item {
            id: pwrDock
            anchors.top: parent.top
            anchors.topMargin: pwrWin.barH
            anchors.right: parent.right
            anchors.rightMargin: 18
            width: 340
            height: pwrWin.revealed ? (pwrBody.implicitHeight + 28) : 0
            opacity: pwrWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: pwrWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: pwrWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: pwrWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.right: pwrSurface.left
                visible: pwrDock.height > 10
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.left: pwrSurface.right
                visible: pwrDock.height > 10
            }

            Item {
                id: pwrSurface
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

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: pwrBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    y: pwrWin.revealed ? 12 : -10
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: pwrWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: pwrWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // Cabecera
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "󰐥"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            color: Theme.error
                        }

                        Text {
                            text: "Energía y sesión"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Theme.fg
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 22
                            width: hostTag.implicitWidth + 14
                            radius: Theme.radiusFull
                            color: Theme.surfaceContainer

                            Text {
                                id: hostTag
                                anchors.centerIn: parent
                                text: pwrWin.sysState
                                    ? (pwrWin.sysState.userName + (pwrWin.sysState.hostName ? "@" + pwrWin.sysState.hostName : ""))
                                    : ""
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 10
                                color: Theme.fgSubtle
                            }
                        }
                    }

                    // Grilla 2x3 de acciones de energía
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: pwrWin.actions

                            Rectangle {
                                id: pwrTile
                                required property var modelData
                                required property int index
                                readonly property bool active: tileMouse.containsMouse || pwrWin.selectedIndex === index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                radius: Theme.radiusMedium
                                color: active
                                    ? (modelData.danger ? Theme.errorContainer : Theme.primaryContainer)
                                    : Theme.surfaceContainer

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: pwrTile.active
                                            ? (pwrTile.modelData.danger ? Theme.error : Theme.primary)
                                            : Theme.surfaceContainerHigh

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: pwrTile.modelData.glyph
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 15
                                            color: pwrTile.active
                                                ? (pwrTile.modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary)
                                                : (pwrTile.modelData.danger ? Theme.error : Theme.primary)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: pwrTile.modelData.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: pwrTile.active
                                                ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                : Theme.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: pwrTile.modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: pwrTile.active
                                                ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                : Theme.fgSubtle
                                            opacity: pwrTile.active ? 0.85 : 1.0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: pwrWin.selectedIndex = pwrTile.index
                                    onClicked: pwrWin.triggerAction(pwrTile.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
