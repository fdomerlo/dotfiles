import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: pwrWin

    required property bool panelOpen
    required property var sysState
    property bool floatingMode: false
    property var barHitTester: null

    signal closeRequested()
    signal barMenuHovered(var scr, string target)
    signal barMenuClicked(var scr, string target, int button)
    signal barWorkspaceClicked(int wsId)

    readonly property int barH: sysState ? sysState.barHeight : 40
    property bool revealed: false
    property int selectedIndex: -1
    property string pendingConfirmId: ""

    readonly property var actions: [
        {
            id: "lock",
            key: "L",
            glyph: "󰌾",
            title: "Bloquear",
            subtitle: "Super+L",
            danger: false,
            confirm: false
        },
        {
            id: "suspend",
            key: "S",
            glyph: "󰤄",
            title: "Suspender",
            subtitle: "Reposo rápido",
            danger: false,
            confirm: false
        },
        {
            id: "hibernate",
            key: "H",
            glyph: "󰒲",
            title: "Hibernar",
            subtitle: "Guardar en disco",
            danger: false,
            confirm: false
        },
        {
            id: "logout",
            key: "E",
            glyph: "󰍃",
            title: "Cerrar sesión",
            subtitle: "Salir de Hyprland",
            danger: false,
            confirm: true
        },
        {
            id: "reboot",
            key: "R",
            glyph: "󰑐",
            title: "Reiniciar",
            subtitle: "Reiniciar equipo",
            danger: true,
            confirm: true
        },
        {
            id: "shutdown",
            key: "P",
            glyph: "󰐥",
            title: "Apagar",
            subtitle: "Apagar equipo",
            danger: true,
            confirm: true
        }
    ]

    function requestAction(actionIdx) {
        if (actionIdx < 0 || actionIdx >= actions.length)
            return;
        const act = actions[actionIdx];
        if (act.confirm && pendingConfirmId !== act.id) {
            selectedIndex = actionIdx;
            pendingConfirmId = act.id;
            confirmTimer.restart();
            return;
        }
        confirmTimer.stop();
        pendingConfirmId = "";
        triggerAction(act.id);
    }

    function cancelConfirm() {
        confirmTimer.stop();
        pendingConfirmId = "";
    }

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

    Timer {
        id: confirmTimer
        interval: 4000
        repeat: false
        onTriggered: pwrWin.pendingConfirmId = ""
    }

    Component.onCompleted: {
        pwrScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        cancelConfirm();
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    FocusScope {
        id: pwrScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (pwrWin.pendingConfirmId !== "")
                pwrWin.cancelConfirm();
            else
                pwrWin.closeRequested();
        }
        Keys.onRightPressed: {
            pwrWin.cancelConfirm();
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0) ? 0 : ((pwrWin.selectedIndex + 1) % pwrWin.actions.length);
        }
        Keys.onLeftPressed: {
            pwrWin.cancelConfirm();
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0)
                ? (pwrWin.actions.length - 1)
                : ((pwrWin.selectedIndex - 1 + pwrWin.actions.length) % pwrWin.actions.length);
        }
        Keys.onDownPressed: {
            pwrWin.cancelConfirm();
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0) ? 0 : ((pwrWin.selectedIndex + 2) % pwrWin.actions.length);
        }
        Keys.onUpPressed: {
            pwrWin.cancelConfirm();
            pwrWin.selectedIndex = (pwrWin.selectedIndex < 0)
                ? (pwrWin.actions.length - 1)
                : ((pwrWin.selectedIndex - 2 + pwrWin.actions.length) % pwrWin.actions.length);
        }
        Keys.onReturnPressed: pwrWin.requestAction(pwrWin.selectedIndex)
        Keys.onEnterPressed: pwrWin.requestAction(pwrWin.selectedIndex)
        Keys.onPressed: event => {
            const keyMap = {};
            keyMap[Qt.Key_L] = 0;
            keyMap[Qt.Key_S] = 1;
            keyMap[Qt.Key_H] = 2;
            keyMap[Qt.Key_E] = 3;
            keyMap[Qt.Key_R] = 4;
            keyMap[Qt.Key_P] = 5;
            if (keyMap[event.key] !== undefined) {
                event.accepted = true;
                pwrWin.requestAction(keyMap[event.key]);
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: pwrWin.panelOpen
            onClicked: pwrWin.closeRequested()
        }

        TopBarOverlayBridge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: pwrWin.barH
            z: 50
            barH: pwrWin.barH
            screen: pwrWin.screen
            active: pwrWin.panelOpen
            currentTarget: "power"
            barHitTester: pwrWin.barHitTester
            onMenuHovered: (scr, target) => pwrWin.barMenuHovered(scr, target)
            onMenuClicked: (scr, target, btn) => pwrWin.barMenuClicked(scr, target, btn)
            onWorkspaceClicked: wsId => pwrWin.barWorkspaceClicked(wsId)
            onOutsideClicked: pwrWin.closeRequested()
        }

        // Borde sutil inferior de la barra superior a ambos lados del desplegable
        Rectangle {
            visible: !pwrWin.floatingMode
            anchors.left: parent.left
            anchors.right: pwrDock.left
            anchors.rightMargin: pwrDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            y: pwrWin.barH - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: pwrWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: pwrWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: !pwrWin.floatingMode
            anchors.left: pwrDock.right
            anchors.leftMargin: pwrDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            anchors.right: parent.right
            y: pwrWin.barH - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: pwrWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: pwrWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Contenedor acoplado a la barra superior (o flotante a 8px en modo islas)
        Item {
            id: pwrDock
            anchors.top: parent.top
            anchors.topMargin: pwrWin.floatingMode ? (pwrWin.barH + 8) : pwrWin.barH
            anchors.right: parent.right
            anchors.rightMargin: pwrWin.floatingMode ? 12 : 18
            width: 436
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
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.right: pwrSurface.left
                visible: !pwrWin.floatingMode && pwrDock.height >= Theme.concaveRadius
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.left: pwrSurface.right
                visible: !pwrWin.floatingMode && pwrDock.height >= Theme.concaveRadius
            }

            Item {
                id: pwrSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))
                readonly property real halfB: Theme.popoutBorderWidth / 2.0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: pwrWin.floatingMode ? parent.height : (parent.height + Theme.radiusLarge)
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: pwrWin.floatingMode ? Theme.popoutBorderWidth : 0
                    border.color: Theme.popoutBorder
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: !pwrWin.floatingMode && pwrDock.height >= Theme.concaveRadius

                    ShapePath {
                        strokeWidth: Theme.popoutBorderWidth
                        strokeColor: Theme.popoutBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: pwrSurface.halfB
                        startY: Theme.concaveRadius

                        PathLine {
                            x: pwrSurface.halfB
                            y: pwrSurface.height - pwrSurface.cornerR
                        }
                        PathArc {
                            x: pwrSurface.cornerR
                            y: pwrSurface.height - pwrSurface.halfB
                            radiusX: pwrSurface.cornerR - pwrSurface.halfB
                            radiusY: pwrSurface.cornerR - pwrSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: pwrSurface.width - pwrSurface.cornerR
                            y: pwrSurface.height - pwrSurface.halfB
                        }
                        PathArc {
                            x: pwrSurface.width - pwrSurface.halfB
                            y: pwrSurface.height - pwrSurface.cornerR
                            radiusX: pwrSurface.cornerR - pwrSurface.halfB
                            radiusY: pwrSurface.cornerR - pwrSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: pwrSurface.width - pwrSurface.halfB
                            y: Theme.concaveRadius
                        }
                    }
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
                            font.pixelSize: 16
                            color: Theme.error
                        }

                        Text {
                            text: "Energía y sesión"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.fg
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 24
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
                                font.pixelSize: 11
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
                                readonly property bool isConfirming: pwrWin.pendingConfirmId === modelData.id
                                readonly property bool active: isConfirming || tileMouse.containsMouse || pwrWin.selectedIndex === index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: Theme.radiusMedium
                                color: isConfirming
                                    ? (modelData.danger ? Theme.error : Theme.primary)
                                    : (active
                                        ? (modelData.danger ? Theme.errorContainer : Theme.primaryContainer)
                                        : Theme.surfaceContainer)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 10
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: pwrTile.isConfirming
                                            ? (pwrTile.modelData.danger ? Theme.errorContainer : Theme.primaryContainer)
                                            : (pwrTile.active
                                                ? (pwrTile.modelData.danger ? Theme.error : Theme.primary)
                                                : Theme.surfaceContainerHigh)

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: pwrTile.isConfirming ? "󰀪" : pwrTile.modelData.glyph
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: pwrTile.isConfirming
                                                ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                : (pwrTile.active
                                                    ? (pwrTile.modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary)
                                                    : (pwrTile.modelData.danger ? Theme.error : Theme.primary))
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: pwrTile.isConfirming ? "¿Confirmar?" : pwrTile.modelData.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: pwrTile.isConfirming ? Font.Bold : Font.DemiBold
                                            color: pwrTile.isConfirming
                                                ? (pwrTile.modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary)
                                                : (pwrTile.active
                                                    ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                    : Theme.fg)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: pwrTile.isConfirming
                                                ? ("Clic, Enter o " + pwrTile.modelData.key)
                                                : pwrTile.modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: pwrTile.isConfirming
                                                ? (pwrTile.modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary)
                                                : (pwrTile.active
                                                    ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                    : Theme.fgSubtle)
                                            opacity: pwrTile.isConfirming ? 0.92 : (pwrTile.active ? 0.85 : 1.0)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Acelerador de una tecla
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 6
                                        color: pwrTile.isConfirming
                                            ? (pwrTile.modelData.danger ? Theme.errorContainer : Theme.primaryContainer)
                                            : (pwrTile.active ? Theme.surface : Theme.surfaceContainerHigh)

                                        Text {
                                            anchors.centerIn: parent
                                            text: pwrTile.modelData.key
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: pwrTile.isConfirming
                                                ? (pwrTile.modelData.danger ? Theme.fgOnErrorContainer : Theme.fgOnPrimaryContainer)
                                                : (pwrTile.active
                                                    ? (pwrTile.modelData.danger ? Theme.error : Theme.primary)
                                                    : Theme.fgSubtle)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: pwrWin.selectedIndex = pwrTile.index
                                    onClicked: pwrWin.requestAction(pwrTile.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
