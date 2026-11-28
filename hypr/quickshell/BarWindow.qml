import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: barWin

    required property var sysState
    required property date currentDate
    required property int notifCount
    required property bool dndEnabled
    required property bool notifCenterOpen
    required property bool launcherOpen
    required property bool overviewOpen
    required property bool dashboardOpen
    required property int dashboardTab
    required property bool appearanceOpen
    required property bool clipboardOpen
    required property bool powerOpen
    required property bool notchMode
    property string barStyle: "bar"
    required property bool popupsVisible
    required property var dashboardScreen
    required property var notifCenterScreen
    required property var appearanceScreen
    required property var clipboardScreen
    required property var powerScreen
    required property var popupsScreen
    required property bool idleInhibited
    required property bool sinkMuted
    required property bool batteryLow
    required property int batteryPct

    signal launcherRequested(var scr)
    signal overviewRequested()
    signal notifCenterRequested()
    signal dndToggled()
    signal dashboardRequested(var scr, int tab)
    signal appearanceRequested(var scr)
    signal powerRequested(var scr)
    signal idleInhibitToggled()

    readonly property int baseBarH: sysState ? sysState.barHeight : 40
    readonly property int notchExtraH: 6
    readonly property int notchH: baseBarH + notchExtraH
    readonly property int barH: notchMode ? notchH : baseBarH
    readonly property int pillH: Math.max(26, baseBarH - 10)
    readonly property int notchConcaveSize: Math.min(Theme.concaveRadius, Math.floor(notchH * 0.36))
    readonly property int notchCornerR: Math.min(Theme.radiusLarge, Math.floor(notchH * 0.44))
    readonly property real notchHalfB: Theme.popoutBorderWidth / 2.0
    readonly property int notchInnerPad: 14
    readonly property int notchGroupGap: 8
    readonly property color notchBorderColor: (anyDockedOpen || hasPopupsHere)
        ? Theme.popoutBorder
        : Qt.alpha(Theme.outline, Theme.isDark ? 0.32 : 0.38)
    property bool animReady: false

    Timer {
        interval: 60
        repeat: false
        running: true
        onTriggered: barWin.animReady = true
    }
    readonly property bool isDashboardHere: dashboardOpen && (!dashboardScreen || dashboardScreen === screen)
    readonly property bool isNotchAppsHere: isDashboardHere && dashboardTab === 0
    readonly property bool isNotchAiHere: isDashboardHere && dashboardTab === 1
    readonly property bool isNotchSysHere: isDashboardHere && dashboardTab === 4
    readonly property bool isNotchDashHere: isDashboardHere && (dashboardTab === 2 || dashboardTab === 3)
    readonly property bool aiActive: Boolean(sysState && sysState.aiActive)
    readonly property int cpuTempC: sysState ? sysState.cpuTempC : -1
    readonly property int memPercent: (sysState && sysState.memTotalGiB > 0) ? Math.round((sysState.memUsedGiB / sysState.memTotalGiB) * 100) : 0
    readonly property bool isNotifCenterHere: notifCenterOpen && (!notifCenterScreen || notifCenterScreen === screen)
    readonly property bool isAppearanceHere: appearanceOpen && (!appearanceScreen || appearanceScreen === screen)
    readonly property bool isClipboardHere: clipboardOpen && (!clipboardScreen || clipboardScreen === screen)
    readonly property bool isPowerHere: powerOpen && (!powerScreen || powerScreen === screen)
    readonly property bool hasPopupsHere: popupsVisible && (!popupsScreen || popupsScreen === screen)
    readonly property bool anyDockedOpen: isDashboardHere || isNotifCenterHere || isAppearanceHere || isClipboardHere || isPowerHere
    readonly property var hyprMonitor: Hyprland.monitorFor(screen)

    function itemContainsBarPoint(item, px, py) {
        if (!item || !item.visible || !barFrame)
            return false;
        const pt = item.mapToItem(barFrame, 0, 0);
        return px >= pt.x && px <= pt.x + item.width
            && py >= 0 && py <= barWin.barH;
    }

    function hitTestTopBar(px, py) {
        if (py < 0 || py > barH)
            return { kind: "none", target: "", wsId: -1 };
        if (itemContainsBarPoint(appsBtn, px, py))
            return { kind: "menu", target: "apps", wsId: -1 };
        if (itemContainsBarPoint(aiBtn, px, py))
            return { kind: "menu", target: "ai", wsId: -1 };
        if (itemContainsBarPoint(centerClock, px, py))
            return { kind: "menu", target: "dashboard", wsId: -1 };
        if (itemContainsBarPoint(sysBtn, px, py))
            return { kind: "menu", target: "system", wsId: -1 };
        if (itemContainsBarPoint(themeBtn, px, py))
            return { kind: "menu", target: "appearance", wsId: -1 };
        if (itemContainsBarPoint(notifBtn, px, py))
            return { kind: "menu", target: "notifications", wsId: -1 };
        if (itemContainsBarPoint(pwrBtn, px, py))
            return { kind: "menu", target: "power", wsId: -1 };
        for (let i = 0; i < wsRepeater.count; i++) {
            const wsItem = wsRepeater.itemAt(i);
            if (!wsItem || !wsItem.modelData)
                continue;
            if (itemContainsBarPoint(wsItem, px, py))
                return { kind: "workspace", target: "", wsId: Number(wsItem.modelData.id) };
        }
        return { kind: "empty", target: "", wsId: -1 };
    }

    // Workspaces asignados a este monitor, ordenados por ID
    readonly property var monitorWorkspaces: {
        void(Hyprland.workspaces.values);
        const list = [];
        const vals = Hyprland.workspaces.values;
        if (!vals || !hyprMonitor)
            return list;
        for (let i = 0; i < vals.length; i++) {
            const ws = vals[i];
            if (!ws || ws.id <= 0)
                continue;
            if (ws.monitor && ws.monitor.name === hyprMonitor.name)
                list.push(ws);
        }
        list.sort((a, b) => a.id - b.id);
        return list;
    }

    function runScript(relPath, args) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/" + relPath].concat(args || []));
    }

    function workspaceHasWindows(wsId) {
        void(Hyprland.toplevels.values);
        const vals = Hyprland.toplevels.values;
        if (!vals)
            return false;
        for (let i = 0; i < vals.length; i++) {
            const t = vals[i];
            if (t && t.workspace && t.workspace.id === wsId)
                return true;
        }
        return false;
    }

    // Reloj en español
    readonly property var esDays: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    readonly property var esMonths: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property string formattedDate: {
        const d = currentDate;
        const wd = esDays[d.getDay()] || "";
        const day = String(d.getDate()).padStart(2, "0");
        const mon = esMonths[d.getMonth()] || "";
        return barWin.notchMode ? (day + " " + mon) : (wd + " " + day + " " + mon);
    }
    readonly property string formattedTime: {
        const d = currentDate;
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return hh + ":" + mm;
    }

    // Inhibidor real de reposo Wayland
    IdleInhibitor {
        window: barWin
        enabled: barWin.idleInhibited
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: barH
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: (barStyle === "notch" && notchMode) ? notchH : baseBarH
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: notchMode ? notchMask : null

    color: "transparent"

    Region {
        id: notchMask
        item: notchMaskBox
    }

    // Superficie superior continua estilo Material 3 / Caelestia (o notch central unificado)
    Item {
        id: barFrame
        anchors.fill: parent

        readonly property int leftW: leftIsland.visible ? leftIsland.width : 0
        readonly property int notchContentW: (leftW > 0 ? (leftW + barWin.notchGroupGap) : 0)
            + centerIsland.width + barWin.notchGroupGap + rightIsland.width
        readonly property int notchTargetW: Math.max(
            320,
            Math.min(
                Math.max(320, barFrame.width - barWin.notchConcaveSize * 2 - 24),
                notchContentW + barWin.notchInnerPad * 2
            )
        )
        readonly property real notchTargetX: Math.round((barFrame.width - notchTargetW) / 2)

        Item {
            id: notchMaskBox
            x: notchBody.x - barWin.notchConcaveSize
            y: 0
            width: notchBody.width + barWin.notchConcaveSize * 2
            height: barWin.barH
        }

        Item {
            id: notchBody
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            height: barWin.barH
            width: barWin.notchMode ? barFrame.notchTargetW : barFrame.width

            Behavior on width {
                enabled: barWin.animReady
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                }
            }

            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: barWin.notchMode ? (parent.height + barWin.notchCornerR) : parent.height
                    radius: barWin.notchMode ? barWin.notchCornerR : 0
                    color: Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true
                visible: barWin.notchMode

                ShapePath {
                    strokeWidth: Theme.popoutBorderWidth
                    strokeColor: barWin.notchBorderColor
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: barWin.notchHalfB
                    startY: barWin.notchConcaveSize

                    PathLine {
                        x: barWin.notchHalfB
                        y: notchBody.height - barWin.notchCornerR
                    }
                    PathArc {
                        x: barWin.notchCornerR
                        y: notchBody.height - barWin.notchHalfB
                        radiusX: barWin.notchCornerR - barWin.notchHalfB
                        radiusY: barWin.notchCornerR - barWin.notchHalfB
                        direction: PathArc.Counterclockwise
                    }
                    PathLine {
                        x: notchBody.width - barWin.notchCornerR
                        y: notchBody.height - barWin.notchHalfB
                    }
                    PathArc {
                        x: notchBody.width - barWin.notchHalfB
                        y: notchBody.height - barWin.notchCornerR
                        radiusX: barWin.notchCornerR - barWin.notchHalfB
                        radiusY: barWin.notchCornerR - barWin.notchHalfB
                        direction: PathArc.Counterclockwise
                    }
                    PathLine {
                        x: notchBody.width - barWin.notchHalfB
                        y: barWin.notchConcaveSize
                    }
                }
            }
        }

        ConcaveCorner {
            position: "top-right"
            size: barWin.notchConcaveSize
            color: Theme.surface
            borderWidth: Theme.popoutBorderWidth
            borderColor: barWin.notchBorderColor
            anchors.top: parent.top
            anchors.right: notchBody.left
            z: 2
            visible: barWin.notchMode
        }

        ConcaveCorner {
            position: "top-left"
            size: barWin.notchConcaveSize
            color: Theme.surface
            borderWidth: Theme.popoutBorderWidth
            borderColor: barWin.notchBorderColor
            anchors.top: parent.top
            anchors.left: notchBody.right
            z: 2
            visible: barWin.notchMode
        }

        // Línea inferior sutil que se desvanece cuando un popout se acopla o en modo notch
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.outlineVariant
            opacity: (barWin.anyDockedOpen || barWin.hasPopupsHere || barWin.notchMode) ? 0.0 : 0.45

            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }

        // Borde sutil inferior en modo barra cuando hay notificaciones push acopladas (396 = NotificationPopups.cardWidth)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 18 + 396 + Theme.concaveRadius
            anchors.bottom: parent.bottom
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: (!barWin.notchMode && !barWin.anyDockedOpen && barWin.hasPopupsHere) ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Math.max(0, 18 - Theme.concaveRadius)
            height: Theme.popoutBorderWidth
            color: Theme.popoutBorder
            opacity: (!barWin.notchMode && !barWin.anyDockedOpen && barWin.hasPopupsHere) ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }

        // =====================================================================
        // ZONA IZQUIERDA: Workspaces
        // =====================================================================
        // Píldora de Workspaces con morphing elástico estilo Caelestia
        Rectangle {
            id: leftIsland
            z: 5
            visible: barWin.monitorWorkspaces.length > 0
            anchors.verticalCenter: parent.verticalCenter
            x: barWin.notchMode ? (barFrame.notchTargetX + barWin.notchInnerPad) : 12
            height: barWin.pillH
            width: wsRow.implicitWidth + 14
            radius: Theme.radiusFull
            color: Theme.surfaceContainer
            border.width: 0

            Behavior on x {
                enabled: barWin.animReady
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            Hyprland.dispatch("workspace m-1");
                        else if (wheel.angleDelta.y < 0)
                            Hyprland.dispatch("workspace m+1");
                    }
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 5

                    Repeater {
                        id: wsRepeater
                        model: barWin.monitorWorkspaces

                        Rectangle {
                            required property var modelData
                            readonly property bool isActive: Boolean(modelData.active)
                            readonly property bool isUrgent: Boolean(modelData.urgent)
                            readonly property bool hasWins: barWin.workspaceHasWindows(modelData.id)

                            height: barWin.pillH - 6
                            width: isActive
                                ? Math.max(36, wsLabel.implicitWidth + 18)
                                : (hasWins ? Math.max(24, wsLabel.implicitWidth + 12) : 20)
                            radius: height / 2
                            color: isUrgent
                                ? Theme.error
                                : (isActive
                                    ? Theme.primary
                                    : (wsM.containsMouse
                                        ? Theme.surfaceContainerHighest
                                        : (hasWins ? Theme.surfaceContainerHigh : Qt.alpha(Theme.surfaceContainerHighest, 0.0))))

                            Behavior on width {
                                NumberAnimation {
                                    duration: 280
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveDecel
                                }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                text: String(modelData.name)
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: isActive ? Font.Bold : (hasWins ? Font.DemiBold : Font.Normal)
                                color: (isActive || isUrgent)
                                    ? Theme.fgOnPrimary
                                    : (hasWins ? Theme.fg : Theme.fgSubtle)
                                opacity: (isActive || isUrgent || hasWins || wsM.containsMouse) ? 1.0 : 0.75
                            }

                            MouseArea {
                                id: wsM
                                anchors.fill: parent
                                anchors.topMargin: -12
                                anchors.bottomMargin: -12
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }
            }

        // =====================================================================
        // ZONA CENTRAL UNIFICADA (Notch): Apps / Overview | Reloj · Fecha (Dashboard)
        // =====================================================================
        Rectangle {
            id: centerIsland
            z: 5
            anchors.verticalCenter: parent.verticalCenter
            x: barWin.notchMode
                ? (barFrame.notchTargetX + barWin.notchInnerPad + (barFrame.leftW > 0 ? (barFrame.leftW + barWin.notchGroupGap) : 0))
                : Math.round((barFrame.width - width) / 2)
            height: barWin.pillH
            width: centerCluster.implicitWidth + 12
            radius: Theme.radiusFull
            color: barWin.isDashboardHere
                ? Theme.surfaceContainerHigh
                : Theme.surfaceContainer
            border.width: barWin.isDashboardHere ? 1 : 0
            border.color: Qt.alpha(Theme.primary, 0.35)

            Behavior on x {
                enabled: barWin.animReady
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                id: centerCluster
                anchors.centerIn: parent
                spacing: 5

                // Botón Apps / Overview
                Rectangle {
                    id: appsBtn
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: 34
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isNotchAppsHere && !barWin.overviewOpen && launcherM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primary
                        opacity: (barWin.isNotchAppsHere || barWin.overviewOpen) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰀻"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: (barWin.isNotchAppsHere || barWin.overviewOpen) ? Theme.fgOnPrimary : Theme.primary
                    }

                    MouseArea {
                        id: launcherM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                barWin.overviewRequested();
                            else
                                barWin.dashboardRequested(barWin.screen, 0);
                        }
                    }
                }

                // Botón Dev & IA (clic izq: pestaña IA · clic der: pregunta rápida · clic medio: OpenCode)
                Rectangle {
                    id: aiBtn
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: 34
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isNotchAiHere && !barWin.aiActive && aiM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.tertiaryContainer
                        border.width: 1
                        border.color: Qt.alpha(Theme.tertiary, 0.45)
                        opacity: (!barWin.isNotchAiHere && barWin.aiActive) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primary
                        opacity: barWin.isNotchAiHere ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰚩"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: barWin.isNotchAiHere
                            ? Theme.fgOnPrimary
                            : (barWin.aiActive ? Theme.tertiary : Theme.fgMuted)
                    }

                    MouseArea {
                        id: aiM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                barWin.runScript("ai.sh", ["ask"]);
                            else if (mouse.button === Qt.MiddleButton)
                                barWin.runScript("ai.sh", ["open"]);
                            else
                                barWin.dashboardRequested(barWin.screen, 1);
                        }
                    }
                }

                // Separador sutil de 1 px dentro de la isla unificada
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, barWin.pillH - 14)
                    color: Qt.alpha(Theme.outlineVariant, 0.45)
                }

                // Reloj / Dashboard / Media / Sistema
                Rectangle {
                    id: centerClock
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: clockRow.implicitWidth + 26
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isNotchDashHere && clkM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primaryContainer
                        opacity: barWin.isNotchDashHere ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Indicador sutil de grabación activa
                    Rectangle {
                        visible: Boolean(barWin.sysState && barWin.sysState.recordingActive)
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: barWin.formattedDate
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: barWin.isNotchDashHere ? Theme.fgOnPrimaryContainer : Theme.fgMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: barWin.isNotchDashHere ? Theme.primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: barWin.formattedTime
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: barWin.isNotchDashHere ? Theme.fgOnPrimaryContainer : Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Indicador discreto de reposo inhibido
                    Text {
                        visible: barWin.idleInhibited
                        text: "󰅶"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: barWin.isNotchDashHere ? Theme.fgOnPrimaryContainer : Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Alerta discreta: audio silenciado
                    Text {
                        visible: barWin.sinkMuted
                        text: "󰖁"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Alerta discreta: sin conexión de red
                    Text {
                        visible: Boolean(barWin.sysState && barWin.sysState.netReady && barWin.sysState.netKind === "disconnected")
                        text: "󰪎"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Alerta discreta: batería baja (solo laptops <= 20% sin cargar)
                    Row {
                        visible: barWin.batteryLow
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "󰂃"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: barWin.batteryPct + "%"
                            font.family: Theme.monoFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                    MouseArea {
                        id: clkM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                barWin.dashboardRequested(barWin.screen, 3);
                            else if (mouse.button === Qt.MiddleButton)
                                barWin.dashboardRequested(barWin.screen, 4);
                            else
                                barWin.dashboardRequested(barWin.screen, 2);
                        }
                    }
                }

                // Separador sutil de 1 px dentro de la isla unificada
                Rectangle {
                    visible: sysBtn.visible
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, barWin.pillH - 14)
                    color: Qt.alpha(Theme.outlineVariant, 0.45)
                }

                // Botón Sistema / Telemetría (temperatura CPU + % RAM)
                Rectangle {
                    id: sysBtn
                    visible: !barWin.sysState || barWin.sysState.showTelemetry
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: sysRow.implicitWidth + 18
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isNotchSysHere && sysM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primary
                        opacity: barWin.isNotchSysHere ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        id: sysRow
                        anchors.centerIn: parent
                        spacing: 7

                        Row {
                            visible: barWin.cpuTempC >= 0
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "󰔏"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: barWin.isNotchSysHere
                                    ? Theme.fgOnPrimary
                                    : (barWin.cpuTempC >= 80 ? Theme.error : Theme.primary)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: barWin.cpuTempC + "°"
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: barWin.isNotchSysHere
                                    ? Theme.fgOnPrimary
                                    : (barWin.cpuTempC >= 80 ? Theme.error : Theme.fg)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "󰍛"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: barWin.isNotchSysHere
                                    ? Theme.fgOnPrimary
                                    : (barWin.memPercent >= 88 ? Theme.error : Theme.secondary)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: barWin.memPercent + "%"
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: barWin.isNotchSysHere
                                    ? Theme.fgOnPrimary
                                    : (barWin.memPercent >= 88 ? Theme.error : Theme.fg)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    MouseArea {
                        id: sysM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barWin.dashboardRequested(barWin.screen, 4)
                    }
                }
            }
        }

        // =====================================================================
        // ZONA DERECHA UNIFICADA (Tray): Apariencia | Notificaciones | Off
        // =====================================================================
        Rectangle {
            id: rightIsland
            z: 5
            anchors.verticalCenter: parent.verticalCenter
            x: barWin.notchMode
                ? (barFrame.notchTargetX + barFrame.notchTargetW - barWin.notchInnerPad - width)
                : (barFrame.width - width - 12)
            height: barWin.pillH
            width: rightCluster.implicitWidth + 12
            radius: Theme.radiusFull
            color: (barWin.isAppearanceHere || barWin.isNotifCenterHere || barWin.isPowerHere)
                ? Theme.surfaceContainerHigh
                : Theme.surfaceContainer
            border.width: (barWin.isAppearanceHere || barWin.isNotifCenterHere || barWin.isPowerHere) ? 1 : 0
            border.color: barWin.isPowerHere
                ? Qt.alpha(Theme.error, 0.45)
                : Qt.alpha(Theme.primary, 0.35)

            Behavior on x {
                enabled: barWin.animReady
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveDecel
                }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                id: rightCluster
                anchors.centerIn: parent
                spacing: 5

                // Popout de Apariencia (clic izq) / Toggle inmediato Claro-Oscuro (clic der)
                Rectangle {
                    id: themeBtn
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: 34
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isAppearanceHere && themeM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primary
                        opacity: barWin.isAppearanceHere ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Theme.isDark ? "󰖔" : "󰖨"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: barWin.isAppearanceHere
                            ? Theme.fgOnPrimary
                            : Theme.primary
                    }

                    MouseArea {
                        id: themeM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                barWin.runScript("theme-switch.sh", ["toggle"]);
                            else
                                barWin.appearanceRequested(barWin.screen);
                        }
                    }
                }

                // Separador sutil de 1 px
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, barWin.pillH - 14)
                    color: Qt.alpha(Theme.outlineVariant, 0.45)
                }

                // Notificaciones (clic izq.: Centro · clic der.: No Molestar)
                Rectangle {
                    id: notifBtn
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: notifRow.implicitWidth + 20
                    radius: Theme.radiusFull
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.surfaceContainerHighest
                        opacity: (!barWin.anyDockedOpen && !barWin.isNotifCenterHere && !barWin.dndEnabled && notifM.containsMouse) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.errorContainer
                        opacity: (!barWin.isNotifCenterHere && barWin.dndEnabled) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusFull
                        color: Theme.primary
                        opacity: barWin.isNotifCenterHere ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        id: notifRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: barWin.dndEnabled
                                ? "󰂛"
                                : (barWin.notifCount > 0 ? "󰂚" : "󰂜")
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            color: barWin.isNotifCenterHere
                                ? Theme.fgOnPrimary
                                : (barWin.dndEnabled
                                    ? Theme.fgOnErrorContainer
                                    : (barWin.notifCount > 0 ? Theme.primary : Theme.fgMuted))
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: barWin.notifCount > 0 && !barWin.dndEnabled
                            text: String(barWin.notifCount)
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: barWin.isNotifCenterHere ? Theme.fgOnPrimary : Theme.fg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: notifM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                barWin.dndToggled();
                            else
                                barWin.notifCenterRequested();
                        }
                    }
                }

                // Separador sutil de 1 px
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, barWin.pillH - 14)
                    color: Qt.alpha(Theme.outlineVariant, 0.45)
                }

                // Botón Power / Cierre de sesión (tinte rojo + texto Off en modo barra; compacto en modo notch)
                Rectangle {
                    id: pwrBtn
                    Layout.preferredHeight: Math.max(22, barWin.pillH - 4)
                    Layout.preferredWidth: barWin.notchMode ? 34 : (pwrRow.implicitWidth + 20)
                    radius: Theme.radiusFull
                    color: barWin.isPowerHere
                        ? Theme.error
                        : (pwrM.containsMouse
                            ? Qt.alpha(Theme.error, Theme.isDark ? 0.34 : 0.24)
                            : Qt.alpha(Theme.error, Theme.isDark ? 0.16 : 0.12))
                    border.width: barWin.isPowerHere ? 0 : 1
                    border.color: Qt.alpha(Theme.error, pwrM.containsMouse ? 0.55 : 0.28)

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Row {
                        id: pwrRow
                        anchors.centerIn: parent
                        spacing: barWin.notchMode ? 0 : 5

                        Text {
                            text: "󰐥"
                            font.family: Theme.fontFamily
                            font.pixelSize: barWin.notchMode ? 15 : 14
                            color: barWin.isPowerHere ? Theme.fgOnError : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: !barWin.notchMode
                            text: "Off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: barWin.isPowerHere ? Theme.fgOnError : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: pwrM
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barWin.powerRequested(barWin.screen)
                    }
                }
            }
        }
    }
}
