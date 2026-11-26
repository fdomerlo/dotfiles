import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: appWin

    required property bool panelOpen
    property int barHeight: 40
    property bool floatingMode: false
    property string barStyle: "bar"
    property var barHitTester: null

    signal closeRequested()
    signal barStyleSelected(string style)
    signal barMenuHovered(var scr, string target)
    signal barMenuClicked(var scr, string target, int button)
    signal barWorkspaceClicked(int wsId)

    property bool revealed: false
    property string activeLockscreen: "theme"
    property var lockscreenPresets: ["theme", "minimal-tech", "matrix-soc", "soc-console", "classic"]

    function runTheme(mode) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/theme-switch.sh", mode]);
    }

    function nextWallpaper() {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/wallpaper.sh", "--next"]);
    }

    function lockscreenTitle(presetId) {
        switch (String(presetId || "")) {
            case "theme":        return "Tema · HUD";
            case "minimal-tech": return "Minimal";
            case "matrix-soc":   return "Matrix SOC";
            case "soc-console":  return "SOC Console";
            case "classic":      return "Clásico";
            default:             return String(presetId || "Tema");
        }
    }

    function lockscreenSub(presetId) {
        switch (String(presetId || "")) {
            case "theme":        return "Opción A";
            case "minimal-tech": return "Candado limpio";
            case "matrix-soc":   return "Feed + tarjeta";
            case "soc-console":  return "Telemetría";
            case "classic":      return "Reloj + clave";
            default:             return "Preset";
        }
    }

    function selectLockscreen(presetId) {
        const id = String(presetId || "").trim();
        if (!id)
            return;
        appWin.activeLockscreen = id;
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/lockscreen-switch.sh", "set", id]);
    }

    function cycleLockscreen() {
        const list = appWin.lockscreenPresets;
        if (!list || list.length === 0)
            return;
        const idx = list.indexOf(appWin.activeLockscreen);
        const nextIdx = (idx === -1) ? 0 : ((idx + 1) % list.length);
        selectLockscreen(list[nextIdx]);
    }

    function refreshLockscreen() {
        if (!lockProbe.running)
            lockProbe.running = true;
    }

    Process {
        id: lockProbe
        command: [
            "sh", "-c",
            "cur=\"$(\"$HOME/.config/hypr/scripts/lockscreen-switch.sh\" current 2>/dev/null | awk '{print $1}')\"; printf 'CUR=%s\\n' \"${cur:-theme}\"; \"$HOME/.config/hypr/scripts/lockscreen-switch.sh\" list 2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split("\n");
                let cur = "theme";
                const list = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line)
                        continue;
                    if (line.indexOf("CUR=") === 0) {
                        const v = line.slice(4).trim();
                        if (v)
                            cur = v;
                    } else if (list.indexOf(line) === -1) {
                        list.push(line);
                    }
                }
                appWin.activeLockscreen = cur;
                if (list.length > 0)
                    appWin.lockscreenPresets = list;
            }
        }
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (appWin.panelOpen)
                appWin.revealed = true;
        }
    }

    Component.onCompleted: {
        appScope.forceActiveFocus();
        if (panelOpen) {
            refreshLockscreen();
            revealTimer.restart();
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            appScope.forceActiveFocus();
            refreshLockscreen();
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
    WlrLayershell.namespace: "quickshell-appearance"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    FocusScope {
        id: appScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: appWin.closeRequested()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_D) {
                appWin.runTheme("dark");
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                appWin.runTheme("light");
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                appWin.runTheme("toggle");
                event.accepted = true;
            } else if (event.key === Qt.Key_W) {
                appWin.nextWallpaper();
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                appWin.cycleLockscreen();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: appWin.panelOpen
            onClicked: appWin.closeRequested()
        }

        TopBarOverlayBridge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: appWin.barHeight
            z: 50
            barH: appWin.barHeight
            screen: appWin.screen
            active: appWin.panelOpen
            currentTarget: "appearance"
            barHitTester: appWin.barHitTester
            onMenuHovered: (scr, target) => appWin.barMenuHovered(scr, target)
            onMenuClicked: (scr, target, btn) => appWin.barMenuClicked(scr, target, btn)
            onWorkspaceClicked: wsId => appWin.barWorkspaceClicked(wsId)
            onOutsideClicked: appWin.closeRequested()
        }

        // Borde sutil inferior de la barra superior a ambos lados del desplegable
        Rectangle {
            visible: !appWin.floatingMode
            anchors.left: parent.left
            anchors.right: appDock.left
            anchors.rightMargin: appDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            y: appWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: appWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: appWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: !appWin.floatingMode
            anchors.left: appDock.right
            anchors.leftMargin: appDock.height >= Theme.concaveRadius ? Theme.concaveRadius : 0
            anchors.right: parent.right
            y: appWin.barHeight - Theme.popoutBorderWidth
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: appWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: appWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Popout compacto de Apariencia acoplado arriba-derecha (o flotante a 8px en modo islas)
        Item {
            id: appDock
            anchors.top: parent.top
            anchors.topMargin: appWin.floatingMode ? (appWin.barHeight + 8) : appWin.barHeight
            anchors.right: parent.right
            anchors.rightMargin: appWin.floatingMode ? 12 : 18
            width: 376
            height: appWin.revealed ? (appBody.implicitHeight + 28) : 0
            opacity: appWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: appWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: appWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: appWin.revealed ? Theme.animFast : Theme.animClose
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
                anchors.right: appSurface.left
                visible: !appWin.floatingMode && appDock.height >= Theme.concaveRadius
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                borderWidth: Theme.popoutBorderWidth
                borderColor: Theme.popoutBorder
                anchors.top: parent.top
                anchors.left: appSurface.right
                visible: !appWin.floatingMode && appDock.height >= Theme.concaveRadius
            }

            Item {
                id: appSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))
                readonly property real halfB: Theme.popoutBorderWidth / 2.0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: appWin.floatingMode ? parent.height : (parent.height + Theme.radiusLarge)
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: appWin.floatingMode ? Theme.popoutBorderWidth : 0
                    border.color: Theme.popoutBorder
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: !appWin.floatingMode && appDock.height >= Theme.concaveRadius

                    ShapePath {
                        strokeWidth: Theme.popoutBorderWidth
                        strokeColor: Theme.popoutBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: appSurface.halfB
                        startY: Theme.concaveRadius

                        PathLine {
                            x: appSurface.halfB
                            y: appSurface.height - appSurface.cornerR
                        }
                        PathArc {
                            x: appSurface.cornerR
                            y: appSurface.height - appSurface.halfB
                            radiusX: appSurface.cornerR - appSurface.halfB
                            radiusY: appSurface.cornerR - appSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: appSurface.width - appSurface.cornerR
                            y: appSurface.height - appSurface.halfB
                        }
                        PathArc {
                            x: appSurface.width - appSurface.halfB
                            y: appSurface.height - appSurface.cornerR
                            radiusX: appSurface.cornerR - appSurface.halfB
                            radiusY: appSurface.cornerR - appSurface.halfB
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: appSurface.width - appSurface.halfB
                            y: Theme.concaveRadius
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: appBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    y: appWin.revealed ? 12 : -10
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: appWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: appWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // Cabecera
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "󰏘"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            color: Theme.primary
                        }

                        Text {
                            text: "Apariencia"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.fg
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 24
                            width: modePillTxt.implicitWidth + 14
                            radius: Theme.radiusFull
                            color: Theme.surfaceContainer

                            Text {
                                id: modePillTxt
                                anchors.centerIn: parent
                                text: Theme.isDark ? "Oscuro" : "Claro"
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 11
                                color: Theme.fgSubtle
                            }
                        }
                    }

                    // Selector segmentado Oscuro / Claro
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Theme.radiusMedium
                            color: Theme.isDark
                                ? Theme.primaryContainer
                                : (darkBtnM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                            border.width: Theme.isDark ? 1 : 0
                            border.color: Qt.alpha(Theme.primary, 0.55)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰖔  Oscuro"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Theme.isDark ? Font.Bold : Font.Medium
                                color: Theme.isDark ? Theme.fgOnPrimaryContainer : Theme.fg
                            }

                            MouseArea {
                                id: darkBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appWin.runTheme("dark")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Theme.radiusMedium
                            color: !Theme.isDark
                                ? Theme.primaryContainer
                                : (lightBtnM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                            border.width: !Theme.isDark ? 1 : 0
                            border.color: Qt.alpha(Theme.primary, 0.55)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰖨  Claro"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: !Theme.isDark ? Font.Bold : Font.Medium
                                color: !Theme.isDark ? Theme.fgOnPrimaryContainer : Theme.fg
                            }

                            MouseArea {
                                id: lightBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appWin.runTheme("light")
                            }
                        }
                    }

                    // Siguiente wallpaper
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: Theme.radiusMedium
                        color: wallM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 17
                                color: wallM.containsMouse ? Theme.primary : Theme.primaryContainer
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰸨"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: wallM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Siguiente wallpaper"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Rotar fondo del modo activo"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.fgSubtle
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: wallKeyTxt.implicitWidth + 12
                                radius: Theme.radiusFull
                                color: Theme.surfaceContainerHigh

                                Text {
                                    id: wallKeyTxt
                                    anchors.centerIn: parent
                                    text: "Super+W"
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Theme.fgSubtle
                                }
                            }
                        }

                        MouseArea {
                            id: wallM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appWin.nextWallpaper()
                        }
                    }

                    // Estilo de barra superior (Barra | Islas | Auto)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "󰕮"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.primary
                            }

                            Text {
                                text: "BARRA SUPERIOR"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgSubtle
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: barStylePillTxt.implicitWidth + 14
                                radius: Theme.radiusFull
                                color: Theme.surfaceContainer

                                Text {
                                    id: barStylePillTxt
                                    anchors.centerIn: parent
                                    text: appWin.barStyle === "islands"
                                        ? "Islas"
                                        : (appWin.barStyle === "auto" ? "Auto" : "Barra")
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Theme.fgSubtle
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "bar", label: "Barra" },
                                    { id: "islands", label: "Islas" },
                                    { id: "auto", label: "Auto" }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool selected: appWin.barStyle === modelData.id

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: Theme.radiusSmall
                                    color: selected
                                        ? Theme.primaryContainer
                                        : (bsM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                    border.width: selected ? 1 : 0
                                    border.color: Qt.alpha(Theme.primary, 0.55)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: selected ? Font.Bold : Font.Medium
                                        color: selected ? Theme.fgOnPrimaryContainer : Theme.fg
                                    }

                                    MouseArea {
                                        id: bsM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appWin.barStyleSelected(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // Pantalla de bloqueo (selector inline sin salir a fuzzel)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "󰌾"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.primary
                            }

                            Text {
                                text: "PANTALLA DE BLOQUEO"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgSubtle
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: activeLockPillTxt.implicitWidth + 14
                                radius: Theme.radiusFull
                                color: Theme.primaryContainer

                                Text {
                                    id: activeLockPillTxt
                                    anchors.centerIn: parent
                                    text: appWin.lockscreenTitle(appWin.activeLockscreen)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.fgOnPrimaryContainer
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8

                            Repeater {
                                model: appWin.lockscreenPresets

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool selected: appWin.activeLockscreen === modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    radius: Theme.radiusSmall
                                    color: selected
                                        ? Theme.primaryContainer
                                        : (presetM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                    border.width: selected ? 1 : 0
                                    border.color: Qt.alpha(Theme.primary, 0.55)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 6

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: appWin.lockscreenTitle(modelData)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: selected ? Font.Bold : Font.DemiBold
                                                color: selected ? Theme.fgOnPrimaryContainer : Theme.fg
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: appWin.lockscreenSub(modelData)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: selected ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                                opacity: selected ? 0.85 : 1.0
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            visible: selected
                                            text: "󰄬"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: Theme.fgOnPrimaryContainer
                                        }
                                    }

                                    MouseArea {
                                        id: presetM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appWin.selectLockscreen(modelData)
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
