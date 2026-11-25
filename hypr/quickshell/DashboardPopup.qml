import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth

PanelWindow {
    id: dashWin

    required property bool panelOpen
    required property int activeTab
    required property var sysState
    required property date currentDate
    required property bool dndEnabled
    required property bool idleInhibited

    signal closeRequested()
    signal tabSelected(int tabIndex)
    signal toggleDndRequested()
    signal toggleIdleInhibitRequested()
    signal powerRequested()

    readonly property int barH: sysState ? sysState.barHeight : 40
    readonly property int panelWidth: Math.min(860, Math.max(680, (dashWin.screen ? dashWin.screen.width : 1280) - 64))
    readonly property int cornerSize: Theme.concaveRadius
    property bool revealed: false
    property int mediaTick: 0
    property int selectedPlayerIndex: 0
    property bool draggingBrightness: false

    // Navegación del calendario en Dashboard (Tab 0)
    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth()

    readonly property var tabMeta: [
        { id: "dashboard", label: "Dashboard", glyph: "󰕮" },
        { id: "media", label: "Media", glyph: "󰎆" },
        { id: "performance", label: "Rendimiento", glyph: "󰓅" },
        { id: "ai", label: "IA", glyph: "󰚩" }
    ]

    readonly property var monthNames: [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    readonly property var weekdayShort: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]

    readonly property var calendarCells: {
        const y = displayYear;
        const m = displayMonth;
        const first = new Date(y, m, 1);
        const startOffset = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const prevMonthDays = new Date(y, m, 0).getDate();
        const todayY = currentDate.getFullYear();
        const todayM = currentDate.getMonth();
        const todayD = currentDate.getDate();

        const cells = [];
        for (let i = startOffset - 1; i >= 0; i--)
            cells.push({ day: prevMonthDays - i, inMonth: false, isToday: false });
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                inMonth: true,
                isToday: (y === todayY && m === todayM && d === todayD)
            });
        }
        let nextDay = 1;
        while (cells.length % 7 !== 0 || cells.length < 42)
            cells.push({ day: nextDay++, inMonth: false, isToday: false });
        return cells;
    }

    // Audio (PipeWire)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: Boolean(defaultSink && defaultSink.audio)
    readonly property int sinkVolumePct: sinkReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSink.audio.volume || 0)) * 100)
        : 0
    readonly property bool sinkMuted: sinkReady ? Boolean(defaultSink.audio.muted) : false

    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property bool sourceReady: Boolean(defaultSource && defaultSource.audio)
    readonly property int sourceVolumePct: sourceReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSource.audio.volume || 0)) * 100)
        : 0
    readonly property bool sourceMuted: sourceReady ? Boolean(defaultSource.audio.muted) : false

    // Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool hasBluetooth: Boolean(btAdapter)
    readonly property bool btEnabled: Boolean(btAdapter && btAdapter.enabled)
    readonly property var btConnectedDevice: {
        if (!btAdapter || !btAdapter.enabled || !btAdapter.devices)
            return null;
        const devs = btAdapter.devices.values;
        if (!devs)
            return null;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].connected)
                return devs[i];
        }
        return null;
    }

    // Reproductores MPRIS
    readonly property var playersList: {
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i])
                out.push(list[i]);
        }
        return out;
    }

    readonly property var activePlayer: {
        if (!playersList || playersList.length === 0)
            return null;
        if (selectedPlayerIndex >= 0 && selectedPlayerIndex < playersList.length)
            return playersList[selectedPlayerIndex];
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].isPlaying)
                return playersList[i];
        }
        return playersList[0];
    }

    // Batería (solo laptops)
    readonly property var batteryDev: UPower.displayDevice
    readonly property bool hasBattery: Boolean(batteryDev && batteryDev.isLaptopBattery && batteryDev.isPresent)
    readonly property int batteryPct: hasBattery ? Math.round((batteryDev.percentage || 0) * 100) : 0
    readonly property bool batteryCharging: hasBattery && (
        batteryDev.state === UPowerDeviceState.Charging ||
        batteryDev.state === UPowerDeviceState.PendingCharge
    )

    // Acciones IA unificadas
    readonly property var aiQuickActions: [
        { cmd: "ask", glyph: "󰚩", title: "Preguntar", subtitle: "Consulta rápida", delay: false },
        { cmd: "open", glyph: "󰆍", title: "Abrir OpenCode", subtitle: "Super+Shift+I", delay: false },
        { cmd: "explain", glyph: "󰆧", title: "Explicar texto", subtitle: "Selección o clip", delay: false },
        { cmd: "error", glyph: "󰀪", title: "Explicar error", subtitle: "Desde portapapeles", delay: false }
    ]

    readonly property var aiContextActions: [
        { cmd: "window", glyph: "󰈈", title: "Ventana activa", subtitle: "Captura y análisis", delay: true },
        { cmd: "image", glyph: "󰋩", title: "Imagen clip", subtitle: "Analizar captura", delay: false },
        { cmd: "summarize", glyph: "󰊄", title: "Resumir", subtitle: "Viñetas clave", delay: false },
        { cmd: "translate", glyph: "󰗊", title: "Traducir", subtitle: "ES ↔ EN + copiar", delay: false },
        { cmd: "diff", glyph: "󰊢", title: "Revisar cambios", subtitle: "Diff del repo activo", delay: false },
        { cmd: "commit", glyph: "󰜘", title: "Mensaje commit", subtitle: "Conventional + copiar", delay: false }
    ]

    function shiftMonth(delta) {
        let m = displayMonth + delta;
        let y = displayYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        displayYear = y;
        displayMonth = m;
    }

    function resetToToday() {
        displayYear = currentDate.getFullYear();
        displayMonth = currentDate.getMonth();
    }

    function runScript(relPath, args) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/" + relPath].concat(args || []));
    }

    function runAiAction(cmd, delayForWindowCapture) {
        const script = (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ai.sh";
        dashWin.closeRequested();
        if (delayForWindowCapture)
            Quickshell.execDetached(["sh", "-c", "sleep 0.30 && exec \"$1\" \"$2\"", "_", script, cmd]);
        else
            Quickshell.execDetached([script, cmd]);
    }

    function cyclePowerProfile() {
        const cur = PowerProfiles.profile;
        if (cur === PowerProfile.PowerSaver) {
            PowerProfiles.profile = PowerProfile.Balanced;
        } else if (cur === PowerProfile.Balanced) {
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile
                ? PowerProfile.Performance
                : PowerProfile.PowerSaver;
        } else {
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }

    function powerProfileLabel() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "Rendimiento";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "Ahorro";
        return "Equilibrado";
    }

    function powerProfileGlyph() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "󰓅";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "󰌪";
        return "󰾅";
    }

    function formatTrackTime(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds) || 0));
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return m + ":" + String(rem).padStart(2, "0");
    }

    function resolveTrayIcon(rawIcon) {
        const s = String(rawIcon || "");
        if (!s)
            return "";
        if (s.startsWith("image://") || s.startsWith("file://") || s.startsWith("qrc:/"))
            return s;
        if (s.startsWith("/"))
            return "file://" + s;
        return Quickshell.iconPath(s, true);
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (dashWin.panelOpen)
                dashWin.revealed = true;
        }
    }

    Timer {
        id: mediaProgressTimer
        interval: 1000
        repeat: true
        running: dashWin.panelOpen && dashWin.activeTab === 1 && Boolean(dashWin.activePlayer && dashWin.activePlayer.isPlaying)
        onTriggered: dashWin.mediaTick += 1
    }

    Component.onCompleted: {
        resetToToday();
        dashScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            resetToToday();
            dashScope.forceActiveFocus();
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
    WlrLayershell.namespace: "quickshell-dashboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: panelOpen ? null : emptyMask

    color: "transparent"

    Region {
        id: emptyMask
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [dashWin]
        active: dashWin.panelOpen
        onCleared: dashWin.closeRequested()
    }

    FocusScope {
        id: dashScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: dashWin.closeRequested()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_1) {
                dashWin.tabSelected(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                dashWin.tabSelected(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                dashWin.tabSelected(2);
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                dashWin.tabSelected(3);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                dashWin.tabSelected((dashWin.activeTab + 1) % 4);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                dashWin.tabSelected((dashWin.activeTab + 3) % 4);
                event.accepted = true;
            }
        }

        // Oscurecimiento suave del fondo (equivalente a dim_around, sin blur)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: dashWin.barH
            color: Theme.dimAround
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: dashWin.panelOpen
            onClicked: dashWin.closeRequested()
        }

        // Borde cyan inferior de la barra superior a ambos lados del desplegable
        Rectangle {
            anchors.left: parent.left
            anchors.right: dashDock.left
            anchors.rightMargin: dashDock.height >= dashWin.cornerSize ? dashWin.cornerSize : 0
            y: dashWin.barH - 2
            height: 2
            color: Theme.activeBorder
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            anchors.left: dashDock.right
            anchors.leftMargin: dashDock.height >= dashWin.cornerSize ? dashWin.cornerSize : 0
            anchors.right: parent.right
            y: dashWin.barH - 2
            height: 2
            color: Theme.activeBorder
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Popout central grande acoplado a la barra superior con esquinas cóncavas
        Item {
            id: dashDock
            anchors.top: parent.top
            anchors.topMargin: dashWin.barH
            anchors.horizontalCenter: parent.horizontalCenter
            width: dashWin.panelWidth
            height: dashWin.revealed ? (dashBody.implicitHeight + 32) : 0
            opacity: dashWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animPop : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: dashWin.revealed ? Theme.curveExpressive : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: dashWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: dashWin.cornerSize
                color: Theme.surface
                borderWidth: 2
                borderColor: Theme.activeBorder
                anchors.top: parent.top
                anchors.right: dashSurface.left
                visible: dashDock.height >= dashWin.cornerSize
            }

            ConcaveCorner {
                position: "top-left"
                size: dashWin.cornerSize
                color: Theme.surface
                borderWidth: 2
                borderColor: Theme.activeBorder
                anchors.top: parent.top
                anchors.left: dashSurface.right
                visible: dashDock.height >= dashWin.cornerSize
            }

            Item {
                id: dashSurface
                anchors.fill: parent
                clip: true

                readonly property real cornerR: Math.max(2, Math.min(Theme.radiusLarge, height - Theme.concaveRadius))

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height + Theme.radiusLarge
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true
                    visible: dashDock.height >= Theme.concaveRadius

                    ShapePath {
                        strokeWidth: 2
                        strokeColor: Theme.activeBorder
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: 1
                        startY: Theme.concaveRadius

                        PathLine {
                            x: 1
                            y: dashSurface.height - dashSurface.cornerR
                        }
                        PathArc {
                            x: dashSurface.cornerR
                            y: dashSurface.height - 1
                            radiusX: dashSurface.cornerR - 1
                            radiusY: dashSurface.cornerR - 1
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: dashSurface.width - dashSurface.cornerR
                            y: dashSurface.height - 1
                        }
                        PathArc {
                            x: dashSurface.width - 1
                            y: dashSurface.height - dashSurface.cornerR
                            radiusX: dashSurface.cornerR - 1
                            radiusY: dashSurface.cornerR - 1
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: dashSurface.width - 1
                            y: Theme.concaveRadius
                        }
                    }
                }

                // Absorbe clics internos
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: dashBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    y: dashWin.revealed ? 14 : -14
                    spacing: 16

                    Behavior on y {
                        NumberAnimation {
                            duration: dashWin.revealed ? Theme.animPop : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: dashWin.revealed ? Theme.curveExpressive : Theme.curveAccel
                        }
                    }

                    // =========================================================
                    // CABECERA CON PESTAÑAS + INDICADOR DESLIZANTE + TRAY
                    // =========================================================
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Tabs estilo Caelestia con indicador deslizante Material 3
                        Item {
                            id: tabStrip
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42

                            readonly property int tabCount: dashWin.tabMeta.length
                            readonly property real tabW: width / Math.max(1, tabCount)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.outlineVariant
                                opacity: 0.55
                            }

                            Rectangle {
                                width: Math.min(76, Math.max(40, tabStrip.tabW * 0.48))
                                height: 3
                                radius: 2
                                color: Theme.primary
                                anchors.bottom: parent.bottom
                                x: dashWin.activeTab * tabStrip.tabW + (tabStrip.tabW - width) / 2

                                Behavior on x {
                                    NumberAnimation {
                                        duration: Theme.animTab
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.curveExpressive
                                    }
                                }
                            }

                            Row {
                                anchors.fill: parent

                                Repeater {
                                    model: dashWin.tabMeta

                                    Item {
                                        id: tabBtn
                                        required property var modelData
                                        required property int index
                                        readonly property bool isCurrent: dashWin.activeTab === index

                                        width: tabStrip.tabW
                                        height: tabStrip.height

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.topMargin: 2
                                            anchors.bottomMargin: 6
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            radius: Theme.radiusSmall
                                            color: tabBtn.isCurrent
                                                ? Theme.surfaceContainer
                                                : (tabMouse.containsMouse ? Theme.surfaceContainerLow : "transparent")

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -2
                                            spacing: 7

                                            Text {
                                                text: tabBtn.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: tabBtn.isCurrent
                                                    ? Theme.primary
                                                    : (tabMouse.containsMouse ? Theme.fg : Theme.fgSubtle)
                                                anchors.verticalCenter: parent.verticalCenter

                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            }

                                            Text {
                                                text: tabBtn.modelData.label
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: tabBtn.isCurrent ? Font.Bold : Font.Medium
                                                color: tabBtn.isCurrent
                                                    ? Theme.fg
                                                    : (tabMouse.containsMouse ? Theme.fgMuted : Theme.fgSubtle)
                                                anchors.verticalCenter: parent.verticalCenter

                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            }
                                        }

                                        MouseArea {
                                            id: tabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.tabSelected(tabBtn.index)
                                        }
                                    }
                                }
                            }
                        }

                        // Bandeja compacta rápida (visible solo si hay iconos de tray)
                        Rectangle {
                            visible: SystemTray.items.values.length > 0
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: headerTrayRow.implicitWidth + 14
                            radius: Theme.radiusFull
                            color: Theme.surfaceContainer

                            Row {
                                id: headerTrayRow
                                anchors.centerIn: parent
                                spacing: 7

                                Repeater {
                                    model: SystemTray.items

                                    Item {
                                        required property var modelData
                                        width: 18
                                        height: 18

                                        Image {
                                            anchors.centerIn: parent
                                            width: 15
                                            height: 15
                                            source: dashWin.resolveTrayIcon(modelData.icon)
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu)) {
                                                    if (modelData.hasMenu) {
                                                        const pt = mapToItem(null, width / 2, height);
                                                        modelData.display(dashWin, Math.round(pt.x), Math.round(pt.y));
                                                    } else {
                                                        modelData.secondaryActivate();
                                                    }
                                                } else if (mouse.button === Qt.MiddleButton) {
                                                    modelData.secondaryActivate();
                                                } else {
                                                    modelData.activate();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    // =========================================================
                    // CUERPO DE PESTAÑAS (altura y transición fluidas)
                    // =========================================================
                    Item {
                        id: tabContentHost
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            if (dashWin.activeTab === 0) return tabDashboard.implicitHeight;
                            if (dashWin.activeTab === 1) return tabMedia.implicitHeight;
                            if (dashWin.activeTab === 2) return tabPerf.implicitHeight;
                            return tabAi.implicitHeight;
                        }
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: Theme.animTab
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveExpressive
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 0: DASHBOARD (estilo Caelestia + Quick Controls)
                        // -----------------------------------------------------
                        RowLayout {
                            id: tabDashboard
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: dashWin.activeTab === 0 ? 0 : 10
                            opacity: dashWin.activeTab === 0 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 0
                            spacing: 12

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: Theme.animTab; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExpressive } }

                            // COLUMNA PRINCIPAL IZQUIERDA (Estado + Identidad arriba · Calendario + Sliders abajo)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 12

                                // Fila superior: Conectividad/Estado + Tarjeta OS/Hyprland/Uptime
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Tarjeta Resumen de Rendimiento (CPU / RAM / Temp · clic abre Tab 2)
                                    Rectangle {
                                        id: dashPerfSummaryCard
                                        readonly property int cpuPct: dashWin.sysState ? dashWin.sysState.cpuUsage : 0
                                        readonly property int memPct: (dashWin.sysState && dashWin.sysState.memTotalGiB > 0)
                                            ? Math.round((dashWin.sysState.memUsedGiB * 100) / dashWin.sysState.memTotalGiB)
                                            : 0
                                        readonly property int tempC: dashWin.sysState ? dashWin.sysState.cpuTempC : -1
                                        Layout.preferredWidth: 204
                                        Layout.preferredHeight: 106
                                        radius: Theme.radiusMedium
                                        color: perfSumM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: "󰓅"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    color: Theme.primary
                                                }

                                                Text {
                                                    text: "Rendimiento"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: Theme.fg
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    visible: dashPerfSummaryCard.tempC >= 0
                                                    height: 18
                                                    width: tempChipTxt.implicitWidth + 10
                                                    radius: Theme.radiusFull
                                                    color: dashPerfSummaryCard.tempC >= 80 ? Theme.errorContainer : Theme.surfaceContainerHighest

                                                    Text {
                                                        id: tempChipTxt
                                                        anchors.centerIn: parent
                                                        text: dashPerfSummaryCard.tempC + "°C"
                                                        font.family: Theme.monoFontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: dashPerfSummaryCard.tempC >= 80 ? Theme.fgOnErrorContainer : Theme.fgMuted
                                                    }
                                                }
                                            }

                                            // Barra compacta CPU
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.preferredWidth: 28
                                                    text: "CPU"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: Theme.fgSubtle
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 7
                                                    radius: 4
                                                    color: Theme.surfaceContainerHighest

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(dashPerfSummaryCard.cpuPct > 0 ? 7 : 0, parent.width * Math.min(1.0, dashPerfSummaryCard.cpuPct / 100.0))
                                                        radius: 4
                                                        color: dashPerfSummaryCard.cpuPct >= 85 ? Theme.error : Theme.primary
                                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }

                                                Text {
                                                    Layout.preferredWidth: 32
                                                    horizontalAlignment: Text.AlignRight
                                                    text: dashPerfSummaryCard.cpuPct + "%"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: dashPerfSummaryCard.cpuPct >= 85 ? Theme.error : Theme.fg
                                                }
                                            }

                                            // Barra compacta RAM
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.preferredWidth: 28
                                                    text: "RAM"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: Theme.fgSubtle
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 7
                                                    radius: 4
                                                    color: Theme.surfaceContainerHighest

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(dashPerfSummaryCard.memPct > 0 ? 7 : 0, parent.width * Math.min(1.0, dashPerfSummaryCard.memPct / 100.0))
                                                        radius: 4
                                                        color: dashPerfSummaryCard.memPct >= 90 ? Theme.error : Theme.secondary
                                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }

                                                Text {
                                                    Layout.preferredWidth: 32
                                                    horizontalAlignment: Text.AlignRight
                                                    text: dashPerfSummaryCard.memPct + "%"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: dashPerfSummaryCard.memPct >= 90 ? Theme.error : Theme.fg
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: perfSumM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.tabSelected(2)
                                        }
                                    }

                                    // Tarjeta Identidad (Debian / Hyprland / Uptime / Batería opcional)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredHeight: 106
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 50
                                                radius: 25
                                                color: Theme.primaryContainer

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 26
                                                    color: Theme.fgOnPrimaryContainer
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "  " + (dashWin.sysState ? dashWin.sysState.osLabel : "Debian Stable")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: Theme.fg
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "  Hyprland · " + (dashWin.sysState && dashWin.sysState.hostName
                                                        ? (dashWin.sysState.userName + "@" + dashWin.sysState.hostName)
                                                        : (dashWin.sysState ? dashWin.sysState.userName : "sesión"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: Theme.fgMuted
                                                    elide: Text.ElideRight
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Text {
                                                        text: "󰥔  activo " + (dashWin.sysState ? dashWin.sysState.uptimeText : "0m")
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 11
                                                        color: Theme.fgSubtle
                                                    }

                                                    Rectangle {
                                                        visible: dashWin.hasBattery
                                                        height: 18
                                                        width: batChipTxt.implicitWidth + 12
                                                        radius: Theme.radiusFull
                                                        color: dashWin.batteryCharging ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                                                        Text {
                                                            id: batChipTxt
                                                            anchors.centerIn: parent
                                                            text: (dashWin.batteryCharging ? "󰂄 " : "󰁹 ") + dashWin.batteryPct + "%"
                                                            font.family: Theme.monoFontFamily
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            color: dashWin.batteryCharging ? Theme.fgOnSecondaryContainer : Theme.fg
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Fila inferior estilo Caelestia: Calendario · Sliders verticales
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Calendario mensual interactivo
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 292
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            onWheel: wheel => {
                                                if (wheel.angleDelta.y > 0)
                                                    dashWin.shiftMonth(-1);
                                                else if (wheel.angleDelta.y < 0)
                                                    dashWin.shiftMonth(1);
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    color: cPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "‹"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 15
                                                        font.weight: Font.Bold
                                                        color: Theme.fg
                                                    }
                                                    MouseArea {
                                                        id: cPrevM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.shiftMonth(-1)
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: dashWin.monthNames[dashWin.displayMonth] + " " + dashWin.displayYear
                                                    elide: Text.ElideRight
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: Theme.fg
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.resetToToday()
                                                    }
                                                }

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    color: cNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "›"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 15
                                                        font.weight: Font.Bold
                                                        color: Theme.fg
                                                    }
                                                    MouseArea {
                                                        id: cNextM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: dashWin.shiftMonth(1)
                                                    }
                                                }
                                            }

                                            GridLayout {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                columns: 7
                                                columnSpacing: 2
                                                rowSpacing: 4

                                                Repeater {
                                                    model: dashWin.weekdayShort
                                                    Text {
                                                        required property string modelData
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: modelData
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        color: Theme.fgSubtle
                                                    }
                                                }

                                                Repeater {
                                                    model: dashWin.calendarCells
                                                    Rectangle {
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 31
                                                        radius: 15
                                                        color: modelData.isToday ? Theme.primary : "transparent"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: String(modelData.day)
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 12
                                                            font.weight: modelData.isToday ? Font.Bold : Font.Medium
                                                            color: modelData.isToday
                                                                ? Theme.fgOnPrimary
                                                                : (modelData.inMonth ? Theme.fg : Theme.fgSubtle)
                                                            opacity: modelData.inMonth ? 1.0 : 0.42
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Sliders verticales estilo Caelestia (Volumen · Mic · Brillo opcional)
                                    Rectangle {
                                        readonly property bool showBr: Boolean(dashWin.sysState && dashWin.sysState.hasBacklight)
                                        Layout.preferredWidth: showBr ? 132 : 96
                                        Layout.preferredHeight: 292
                                        radius: Theme.radiusMedium
                                        color: Theme.surfaceContainer

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 12

                                            // Slider Vertical 1: Volumen
                                            Column {
                                                spacing: 10

                                                Item {
                                                    width: 24
                                                    height: 224

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            height: dashWin.sinkMuted
                                                                ? 0
                                                                : Math.max(18, parent.height * Math.min(1.0, dashWin.sinkVolumePct / 100.0))
                                                            radius: 12
                                                            color: dashWin.sinkVolumePct > 100 ? Theme.error : Theme.primary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            if (!dashWin.sinkReady) return;
                                                            const frac = Math.max(0.0, Math.min(1.0, 1.0 - (my / Math.max(1, height))));
                                                            dashWin.defaultSink.audio.muted = false;
                                                            dashWin.defaultSink.audio.volume = frac;
                                                        }
                                                        onPressed: mouse => applyY(mouse.y)
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onWheel: wheel => {
                                                            if (!dashWin.sinkReady) return;
                                                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                                            dashWin.defaultSink.audio.muted = false;
                                                            dashWin.defaultSink.audio.volume = Math.max(0.0, Math.min(1.0, (dashWin.defaultSink.audio.volume || 0) + step));
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    radius: 12
                                                    color: dashWin.sinkMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: dashWin.sinkMuted ? "󰖁" : "󰕾"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 13
                                                        color: dashWin.sinkMuted ? Theme.fgOnErrorContainer : Theme.primary
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (dashWin.sinkReady)
                                                                dashWin.defaultSink.audio.muted = !dashWin.defaultSink.audio.muted;
                                                        }
                                                    }
                                                }
                                            }

                                            // Slider Vertical 2: Micrófono
                                            Column {
                                                spacing: 10

                                                Item {
                                                    width: 24
                                                    height: 224

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            height: dashWin.sourceMuted
                                                                ? 0
                                                                : Math.max(18, parent.height * Math.min(1.0, dashWin.sourceVolumePct / 100.0))
                                                            radius: 12
                                                            color: Theme.secondary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            if (!dashWin.sourceReady) return;
                                                            const frac = Math.max(0.0, Math.min(1.0, 1.0 - (my / Math.max(1, height))));
                                                            dashWin.defaultSource.audio.muted = false;
                                                            dashWin.defaultSource.audio.volume = frac;
                                                        }
                                                        onPressed: mouse => applyY(mouse.y)
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onWheel: wheel => {
                                                            if (!dashWin.sourceReady) return;
                                                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                                            dashWin.defaultSource.audio.muted = false;
                                                            dashWin.defaultSource.audio.volume = Math.max(0.0, Math.min(1.0, (dashWin.defaultSource.audio.volume || 0) + step));
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    radius: 12
                                                    color: dashWin.sourceMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: dashWin.sourceMuted ? "󰍭" : "󰍬"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 13
                                                        color: dashWin.sourceMuted ? Theme.fgOnErrorContainer : Theme.secondary
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (dashWin.sourceReady)
                                                                dashWin.defaultSource.audio.muted = !dashWin.defaultSource.audio.muted;
                                                        }
                                                    }
                                                }
                                            }

                                            // Slider Vertical 3: Brillo (solo equipos con backlight)
                                            Column {
                                                visible: Boolean(dashWin.sysState && dashWin.sysState.hasBacklight)
                                                spacing: 10

                                                Item {
                                                    width: 24
                                                    height: 224

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 12
                                                        color: Theme.surfaceContainerHighest

                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.bottom: parent.bottom
                                                            readonly property int pct: dashWin.sysState ? dashWin.sysState.brightnessPercent : 0
                                                            height: Math.max(18, parent.height * Math.min(1.0, pct / 100.0))
                                                            radius: 12
                                                            color: Theme.tertiary

                                                            Behavior on height {
                                                                NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        function applyY(my) {
                                                            const pct = Math.max(5, Math.min(100, Math.round((1.0 - (my / Math.max(1, height))) * 100)));
                                                            if (dashWin.sysState)
                                                                dashWin.sysState.brightnessPercent = pct;
                                                            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", pct + "%"]);
                                                        }
                                                        onPressed: mouse => {
                                                            dashWin.draggingBrightness = true;
                                                            applyY(mouse.y);
                                                        }
                                                        onPositionChanged: mouse => { if (pressed) applyY(mouse.y); }
                                                        onReleased: dashWin.draggingBrightness = false
                                                    }
                                                }

                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    radius: 12
                                                    color: Theme.surfaceContainerHigh
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰃠"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 13
                                                        color: Theme.tertiary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // COLUMNA DERECHA: Quick Toggles 2x3 + Media compacta estilo Caelestia
                            ColumnLayout {
                                Layout.preferredWidth: 264
                                Layout.minimumWidth: 264
                                Layout.maximumWidth: 264
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                                spacing: 12

                                // Grilla 2x3 de controles rápidos
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 8
                                    rowSpacing: 10

                                    // Red / VPN
                                    Rectangle {
                                        id: qNetTile
                                        readonly property bool active: Boolean(dashWin.sysState && dashWin.sysState.netKind !== "disconnected")
                                        readonly property bool hasVpn: Boolean(dashWin.sysState && dashWin.sysState.vpnName.length > 0)
                                        readonly property color tileFg: active
                                            ? (qNetM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qNetM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qNetM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                readonly property string kind: dashWin.sysState ? dashWin.sysState.netKind : "disconnected"
                                                text: qNetTile.hasVpn ? "󰒃" : (kind === "wifi" ? "" : (kind === "ethernet" ? "󰈀" : "󰪎"))
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: qNetTile.active ? qNetTile.tileFg : Theme.fgSubtle
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: qNetTile.hasVpn ? "VPN" : "Red"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qNetTile.tileFg
                                                }
                                                Text {
                                                    text: qNetTile.hasVpn
                                                        ? dashWin.sysState.vpnName
                                                        : (dashWin.sysState && dashWin.sysState.netLabel ? dashWin.sysState.netLabel : "Off")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: qNetTile.active ? qNetTile.tileFg : Theme.fgSubtle
                                                    opacity: qNetTile.active ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qNetM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.closeRequested();
                                                dashWin.runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"]);
                                            }
                                        }
                                    }

                                    // Bluetooth
                                    Rectangle {
                                        id: qBtTile
                                        readonly property bool active: dashWin.btEnabled
                                        readonly property color tileFg: active
                                            ? (qBtM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qBtM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qBtM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.btConnectedDevice ? "󰂱" : (dashWin.btEnabled ? "󰂯" : "󰂲")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: qBtTile.active ? qBtTile.tileFg : Theme.fgSubtle
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Bluetooth"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qBtTile.tileFg
                                                }
                                                Text {
                                                    text: !dashWin.hasBluetooth
                                                        ? "Ausente"
                                                        : (dashWin.btConnectedDevice
                                                            ? String(dashWin.btConnectedDevice.name || dashWin.btConnectedDevice.deviceName || "Conectado")
                                                            : (dashWin.btEnabled ? "Activo" : "Apagado"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: qBtTile.active ? qBtTile.tileFg : Theme.fgSubtle
                                                    opacity: qBtTile.active ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qBtM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.closeRequested();
                                                Quickshell.execDetached(["blueman-manager"]);
                                            }
                                        }
                                    }

                                    // No molestar
                                    Rectangle {
                                        id: qDndTile
                                        readonly property color tileFg: dashWin.dndEnabled
                                            ? (qDndM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: dashWin.dndEnabled
                                            ? (qDndM.containsMouse ? Theme.error : Theme.errorContainer)
                                            : (qDndM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.dndEnabled ? "󰂛" : "󰂚"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: dashWin.dndEnabled ? qDndTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "No molestar"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qDndTile.tileFg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: dashWin.dndEnabled ? "Silenciado" : "Normal"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: dashWin.dndEnabled ? qDndTile.tileFg : Theme.fgSubtle
                                                    opacity: dashWin.dndEnabled ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qDndM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.toggleDndRequested()
                                        }
                                    }

                                    // Luz nocturna
                                    Rectangle {
                                        id: qNlTile
                                        readonly property bool active: Boolean(dashWin.sysState && dashWin.sysState.nightlightActive)
                                        readonly property color tileFg: active
                                            ? (qNlM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: active
                                            ? (qNlM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                            : (qNlM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 14
                                                color: qNlTile.active ? qNlTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Luz nocturna"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qNlTile.tileFg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: qNlTile.active ? "4000K" : "Apagada"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: qNlTile.active ? qNlTile.tileFg : Theme.fgSubtle
                                                    opacity: qNlTile.active ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qNlM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dashWin.runScript("nightlight-toggle.sh", []);
                                                if (dashWin.sysState)
                                                    dashWin.sysState.refreshAll();
                                            }
                                        }
                                    }

                                    // Reposo (IdleInhibit)
                                    Rectangle {
                                        id: qIdleTile
                                        readonly property color tileFg: dashWin.idleInhibited
                                            ? (qIdleM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                            : Theme.fg
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: dashWin.idleInhibited
                                            ? (qIdleM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                            : (qIdleM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.idleInhibited ? "󰅶" : "󰾪"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: dashWin.idleInhibited ? qIdleTile.tileFg : Theme.fgMuted
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Reposo"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qIdleTile.tileFg
                                                }
                                                Text {
                                                    text: dashWin.idleInhibited ? "Inhibido" : "Auto"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: dashWin.idleInhibited ? qIdleTile.tileFg : Theme.fgSubtle
                                                    opacity: dashWin.idleInhibited ? 0.85 : 1.0
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qIdleM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.toggleIdleInhibitRequested()
                                        }
                                    }

                                    // Perfil de energía
                                    Rectangle {
                                        id: qPpTile
                                        readonly property bool isPerf: PowerProfiles.profile === PowerProfile.Performance
                                        readonly property bool isSaver: PowerProfiles.profile === PowerProfile.PowerSaver
                                        readonly property color tileFg: isPerf
                                            ? (qPpM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                            : (isSaver
                                                ? (qPpM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                                : Theme.fg)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 56
                                        radius: Theme.radiusMedium
                                        color: isPerf
                                            ? (qPpM.containsMouse ? Theme.error : Theme.errorContainer)
                                            : (isSaver
                                                ? (qPpM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                                : (qPpM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: dashWin.powerProfileGlyph()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: (qPpTile.isPerf || qPpTile.isSaver) ? qPpTile.tileFg : Theme.primary
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: "Energía"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: qPpTile.tileFg
                                                }
                                                Text {
                                                    text: dashWin.powerProfileLabel()
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: (qPpTile.isPerf || qPpTile.isSaver) ? qPpTile.tileFg : Theme.fgSubtle
                                                    opacity: (qPpTile.isPerf || qPpTile.isSaver) ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: qPpM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.cyclePowerProfile()
                                        }
                                    }
                                }

                                // Tarjeta Media estilo Caelestia (portada circular + pista + controles)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 210
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 78
                                            height: 78
                                            radius: 39
                                            color: Theme.primaryContainer
                                            border.width: 2
                                            border.color: (dashWin.activePlayer && dashWin.activePlayer.isPlaying)
                                                ? Theme.primary
                                                : Theme.outlineVariant
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: dashWin.activePlayer ? (dashWin.activePlayer.trackArtUrl || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !dashWin.activePlayer || !dashWin.activePlayer.trackArtUrl
                                                text: "󰎆"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 26
                                                color: Theme.fgOnPrimaryContainer
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: dashWin.tabSelected(1)
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackTitle || dashWin.activePlayer.identity || "Multimedia")
                                                    : "Sin reproducción"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackArtist || dashWin.activePlayer.identity || "Listo")
                                                    : ("Salida: " + (dashWin.sinkMuted ? "Mudo" : dashWin.sinkVolumePct + "%"))
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.fgSubtle
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 10

                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: 15
                                                color: dPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰒮"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    color: dashWin.activePlayer ? Theme.fg : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    id: dPrevM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoPrevious) dashWin.activePlayer.previous()
                                                }
                                            }

                                            Rectangle {
                                                width: 36
                                                height: 30
                                                radius: 15
                                                color: dashWin.activePlayer ? Theme.primary : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (dashWin.activePlayer && dashWin.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    color: dashWin.activePlayer ? Theme.fgOnPrimary : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (dashWin.activePlayer && dashWin.activePlayer.canTogglePlaying)
                                                            dashWin.activePlayer.togglePlaying();
                                                        else
                                                            dashWin.tabSelected(1);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: 15
                                                color: dNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰒭"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    color: dashWin.activePlayer ? Theme.fg : Theme.fgSubtle
                                                }
                                                MouseArea {
                                                    id: dNextM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoNext) dashWin.activePlayer.next()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 1: MEDIA & AUDIO EXPANDIDO
                        // -----------------------------------------------------
                        RowLayout {
                            id: tabMedia
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: dashWin.activeTab === 1 ? 0 : 10
                            opacity: dashWin.activeTab === 1 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 1
                            spacing: 12

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: Theme.animTab; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExpressive } }

                            // Tarjeta izquierda: Reproductor MPRIS completo
                            Rectangle {
                                Layout.preferredWidth: 360
                                Layout.preferredHeight: 356
                                radius: Theme.radiusMedium
                                color: Theme.surfaceContainer

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    // Selector de reproductor si hay >1
                                    RowLayout {
                                        visible: dashWin.playersList.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: dashWin.playersList

                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                readonly property bool isSel: dashWin.activePlayer === modelData
                                                height: 24
                                                width: Math.min(140, pPillTxt.implicitWidth + 18)
                                                radius: Theme.radiusFull
                                                color: isSel ? Theme.primaryContainer : Theme.surfaceContainerHigh

                                                Text {
                                                    id: pPillTxt
                                                    anchors.centerIn: parent
                                                    width: Math.min(implicitWidth, 122)
                                                    text: String(modelData.identity || "Player")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: isSel ? Font.Bold : Font.Medium
                                                    color: isSel ? Theme.fgOnPrimaryContainer : Theme.fgMuted
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: dashWin.selectedPlayerIndex = index
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    // Portada + info de pista
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 14

                                        Rectangle {
                                            Layout.preferredWidth: 124
                                            Layout.preferredHeight: 124
                                            radius: Theme.radiusMedium
                                            color: Theme.primaryContainer
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: dashWin.activePlayer ? (dashWin.activePlayer.trackArtUrl || "") : ""
                                                fillMode: Image.PreserveAspectCrop
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !dashWin.activePlayer || !dashWin.activePlayer.trackArtUrl
                                                text: "󰎆"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 42
                                                color: Theme.fgOnPrimaryContainer
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Text {
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackTitle || dashWin.activePlayer.identity || "Sin título")
                                                    : "Ningún reproductor activo"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: Theme.fg
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer
                                                    ? (dashWin.activePlayer.trackArtist || dashWin.activePlayer.identity || "")
                                                    : "Abrí un reproductor o navegador para controlar la reproducción"
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                color: Theme.fgMuted
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: Boolean(dashWin.activePlayer && dashWin.activePlayer.trackAlbum)
                                                Layout.fillWidth: true
                                                text: dashWin.activePlayer ? String(dashWin.activePlayer.trackAlbum || "") : ""
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgSubtle
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    // Barra de progreso + tiempos
                                    ColumnLayout {
                                        id: mediaSeekBox
                                        Layout.fillWidth: true
                                        spacing: 4

                                        readonly property real trackLen: (dashWin.activePlayer && Number(dashWin.activePlayer.length) > 0)
                                            ? Number(dashWin.activePlayer.length) : 0
                                        readonly property real trackPos: {
                                            void(dashWin.mediaTick);
                                            return dashWin.activePlayer ? Math.max(0, Number(dashWin.activePlayer.position) || 0) : 0;
                                        }
                                        readonly property real posFrac: trackLen > 0 ? Math.max(0, Math.min(1, trackPos / trackLen)) : 0

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 6
                                                radius: 3
                                                color: Theme.surfaceContainerHighest

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: Math.max(mediaSeekBox.posFrac > 0 ? 6 : 0, parent.width * mediaSeekBox.posFrac)
                                                    radius: 3
                                                    color: Theme.primary
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: Boolean(dashWin.activePlayer && dashWin.activePlayer.canSeek && mediaSeekBox.trackLen > 0)
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: mouse => {
                                                    const frac = Math.max(0.0, Math.min(1.0, mouse.x / Math.max(1, width)));
                                                    dashWin.activePlayer.position = frac * mediaSeekBox.trackLen;
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: dashWin.formatTrackTime(mediaSeekBox.trackPos)
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 10
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: mediaSeekBox.trackLen > 0 ? dashWin.formatTrackTime(mediaSeekBox.trackLen) : "--:--"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 10
                                                color: Theme.fgSubtle
                                            }
                                        }
                                    }

                                    // Controles grandes de transporte
                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 14

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: mPrevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒮"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                color: Theme.fg
                                            }
                                            MouseArea {
                                                id: mPrevM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoPrevious) dashWin.activePlayer.previous()
                                            }
                                        }

                                        Rectangle {
                                            width: 56
                                            height: 40
                                            radius: 20
                                            color: Theme.primary
                                            Text {
                                                anchors.centerIn: parent
                                                text: (dashWin.activePlayer && dashWin.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 20
                                                color: Theme.fgOnPrimary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canTogglePlaying) dashWin.activePlayer.togglePlaying()
                                            }
                                        }

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: mNextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒭"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                color: Theme.fg
                                            }
                                            MouseArea {
                                                id: mNextM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (dashWin.activePlayer && dashWin.activePlayer.canGoNext) dashWin.activePlayer.next()
                                            }
                                        }
                                    }
                                }
                            }

                            // Columna derecha: Mezclador PipeWire (Volumen · Micrófono · pavucontrol)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 356
                                spacing: 12

                                // Tarjeta Volumen de salida
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 114
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "SALIDA DE AUDIO"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.6
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: dashWin.sinkReady
                                                    ? String(dashWin.defaultSink.description || dashWin.defaultSink.nickname || "Predeterminada")
                                                    : "No disponible"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgMuted
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 230
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34
                                                radius: 17
                                                color: dashWin.sinkMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: dashWin.sinkMuted ? "󰖁" : (dashWin.sinkVolumePct <= 33 ? "󰕿" : (dashWin.sinkVolumePct <= 66 ? "󰖀" : "󰕾"))
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 16
                                                    color: dashWin.sinkMuted ? Theme.fgOnErrorContainer : Theme.primary
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.sinkReady) dashWin.defaultSink.audio.muted = !dashWin.defaultSink.audio.muted
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 14
                                                    radius: 7
                                                    color: Theme.surfaceContainerHighest
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: dashWin.sinkMuted ? 0 : Math.max(14, parent.width * Math.min(1.0, dashWin.sinkVolumePct / 100.0))
                                                        radius: 7
                                                        color: dashWin.sinkVolumePct > 100 ? Theme.error : Theme.primary
                                                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function applyX(mx) {
                                                        if (!dashWin.sinkReady) return;
                                                        const frac = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                                        dashWin.defaultSink.audio.muted = false;
                                                        dashWin.defaultSink.audio.volume = frac;
                                                    }
                                                    onPressed: mouse => applyX(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
                                                }
                                            }

                                            Text {
                                                Layout.preferredWidth: 44
                                                horizontalAlignment: Text.AlignRight
                                                text: dashWin.sinkMuted ? "Mudo" : (dashWin.sinkVolumePct + "%")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: dashWin.sinkMuted ? Theme.error : Theme.fg
                                            }
                                        }
                                    }
                                }

                                // Tarjeta Micrófono
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 114
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "MICRÓFONO"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.6
                                                color: Theme.fgSubtle
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: dashWin.sourceReady
                                                    ? String(dashWin.defaultSource.description || dashWin.defaultSource.nickname || "Entrada")
                                                    : "No disponible"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgMuted
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 230
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34
                                                radius: 17
                                                color: dashWin.sourceMuted ? Theme.errorContainer : Theme.surfaceContainerHigh
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: dashWin.sourceMuted ? "󰍭" : "󰍬"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 16
                                                    color: dashWin.sourceMuted ? Theme.fgOnErrorContainer : Theme.secondary
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (dashWin.sourceReady) dashWin.defaultSource.audio.muted = !dashWin.defaultSource.audio.muted
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 14
                                                    radius: 7
                                                    color: Theme.surfaceContainerHighest
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: dashWin.sourceMuted ? 0 : Math.max(14, parent.width * Math.min(1.0, dashWin.sourceVolumePct / 100.0))
                                                        radius: 7
                                                        color: Theme.secondary
                                                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel } }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function applyX(mx) {
                                                        if (!dashWin.sourceReady) return;
                                                        const frac = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                                        dashWin.defaultSource.audio.muted = false;
                                                        dashWin.defaultSource.audio.volume = frac;
                                                    }
                                                    onPressed: mouse => applyX(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) applyX(mouse.x); }
                                                }
                                            }

                                            Text {
                                                Layout.preferredWidth: 44
                                                horizontalAlignment: Text.AlignRight
                                                text: dashWin.sourceMuted ? "Mudo" : (dashWin.sourceVolumePct + "%")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: dashWin.sourceMuted ? Theme.error : Theme.fg
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Acción inferior: Mezclador pavucontrol
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: Theme.radiusFull
                                    color: pavuM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰓃  Abrir mezclador avanzado (pavucontrol)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: pavuM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                    }

                                    MouseArea {
                                        id: pavuM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dashWin.closeRequested();
                                            Quickshell.execDetached(["pavucontrol"]);
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 2: RENDIMIENTO, TELEMETRÍA Y BANDEJA DEL SISTEMA
                        // -----------------------------------------------------
                        ColumnLayout {
                            id: tabPerf
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: dashWin.activeTab === 2 ? 0 : 10
                            opacity: dashWin.activeTab === 2 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 2
                            spacing: 12

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: Theme.animTab; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExpressive } }

                            // 3 tarjetas métricas con sparklines en vivo
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                // CPU
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "  CPU"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                visible: dashWin.sysState && dashWin.sysState.cpuTempC >= 0
                                                text: (dashWin.sysState ? dashWin.sysState.cpuTempC : 0) + "°C"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                color: (dashWin.sysState && dashWin.sysState.cpuTempC >= 80) ? Theme.error : Theme.fgSubtle
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: (dashWin.sysState ? dashWin.sysState.cpuUsage : 0) + "%"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 26
                                                font.weight: Font.Bold
                                                color: (dashWin.sysState && dashWin.sysState.cpuUsage >= 85) ? Theme.error : Theme.fg
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "load " + (dashWin.sysState ? dashWin.sysState.loadAvg : "0.00")
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                color: Theme.fgSubtle
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (dashWin.sysState && dashWin.sysState.cpuModel) ? dashWin.sysState.cpuModel : "Procesador"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.fgMuted
                                            elide: Text.ElideRight
                                        }

                                        // Sparkline de CPU (24 muestras)
                                        Row {
                                            id: cpuSparkRow
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 68
                                            spacing: 3

                                            Repeater {
                                                model: 24
                                                Item {
                                                    required property int index
                                                    readonly property var hist: dashWin.sysState ? dashWin.sysState.cpuHistory : []
                                                    readonly property int offset: Math.max(0, 24 - hist.length)
                                                    readonly property int val: index >= offset ? (hist[index - offset] || 0) : 0
                                                    width: Math.max(4, Math.floor((cpuSparkRow.width - 23 * 3) / 24))
                                                    height: 68

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: Math.max(3, Math.round(68 * Math.max(0, Math.min(100, parent.val)) / 100.0))
                                                        radius: 2
                                                        color: parent.val >= 85 ? Theme.error : (parent.val > 0 ? Theme.primary : Theme.surfaceContainerHighest)
                                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Memoria + Swap/zRAM
                                Rectangle {
                                    id: memPerfCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    readonly property int memPct: (dashWin.sysState && dashWin.sysState.memTotalGiB > 0)
                                        ? Math.round((dashWin.sysState.memUsedGiB * 100) / dashWin.sysState.memTotalGiB)
                                        : 0

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "󰍛  MEMORIA"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.secondary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: memPerfCard.memPct + "%"
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: Theme.fgMuted
                                            }
                                        }

                                        Text {
                                            text: (dashWin.sysState ? dashWin.sysState.memUsedGiB.toFixed(1) : "0.0") + " / " +
                                                  (dashWin.sysState ? dashWin.sysState.memTotalGiB.toFixed(1) : "0.0") + " GiB"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 20
                                            font.weight: Font.Bold
                                            color: Theme.fg
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (dashWin.sysState && dashWin.sysState.swapTotalGiB > 0)
                                                ? ("Swap/zRAM: " + dashWin.sysState.swapUsedGiB.toFixed(1) + " / " + dashWin.sysState.swapTotalGiB.toFixed(1) + " GiB")
                                                : "Sin swap activo"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 10
                                            color: Theme.fgMuted
                                            elide: Text.ElideRight
                                        }

                                        // Sparkline de Memoria (24 muestras)
                                        Row {
                                            id: memSparkRow
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 68
                                            spacing: 3

                                            Repeater {
                                                model: 24
                                                Item {
                                                    required property int index
                                                    readonly property var hist: dashWin.sysState ? dashWin.sysState.memHistory : []
                                                    readonly property int offset: Math.max(0, 24 - hist.length)
                                                    readonly property int val: index >= offset ? (hist[index - offset] || 0) : 0
                                                    width: Math.max(4, Math.floor((memSparkRow.width - 23 * 3) / 24))
                                                    height: 68

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: Math.max(3, Math.round(68 * Math.max(0, Math.min(100, parent.val)) / 100.0))
                                                        radius: 2
                                                        color: parent.val >= 90 ? Theme.error : (parent.val > 0 ? Theme.secondary : Theme.surfaceContainerHighest)
                                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Disco + Grabación + Kernel
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 204
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "󰋊  SISTEMA"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.tertiary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: (dashWin.sysState && dashWin.sysState.kernelVersion) ? ("Linux " + dashWin.sysState.kernelVersion) : ""
                                                font.family: Theme.monoFontFamily
                                                font.pixelSize: 10
                                                color: Theme.fgSubtle
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Raíz /"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: Theme.fgMuted
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: (dashWin.sysState ? dashWin.sysState.diskUsed : "0G") + " / " +
                                                          (dashWin.sysState ? dashWin.sysState.diskTotal : "0G") + " (" +
                                                          (dashWin.sysState ? dashWin.sysState.diskPercent : 0) + "%)"
                                                    font.family: Theme.monoFontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    color: Theme.fg
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 8
                                                radius: 4
                                                color: Theme.surfaceContainerHighest
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    readonly property int pct: dashWin.sysState ? dashWin.sysState.diskPercent : 0
                                                    width: Math.max(8, parent.width * Math.min(1.0, pct / 100.0))
                                                    radius: 4
                                                    color: pct >= 90 ? Theme.error : Theme.tertiary
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Botón Grabación de pantalla
                                        Rectangle {
                                            id: perfRecBtn
                                            readonly property bool recOn: Boolean(dashWin.sysState && dashWin.sysState.recordingActive)
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: Theme.radiusFull
                                            color: recOn ? Theme.error : (recBtnM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow)
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: perfRecBtn.recOn ? "󰑊  Detener grabación (REC)" : "󰑋  Grabar pantalla"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: perfRecBtn.recOn ? Theme.fgOnError : Theme.fg
                                            }

                                            MouseArea {
                                                id: recBtnM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    dashWin.closeRequested();
                                                    dashWin.runScript("screen-record.sh", []);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bandeja del sistema + acceso rápido a btop
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 62
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceContainer

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 10

                                        Text {
                                            text: "BANDEJA"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.6
                                            color: Theme.fgSubtle
                                        }

                                        Text {
                                            visible: SystemTray.items.values.length === 0
                                            text: "Sin aplicaciones en segundo plano"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.fgSubtle
                                        }

                                        Flow {
                                            visible: SystemTray.items.values.length > 0
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: SystemTray.items

                                                Rectangle {
                                                    required property var modelData
                                                    height: 32
                                                    width: trayItemRow.implicitWidth + 16
                                                    radius: Theme.radiusFull
                                                    color: trayItemM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                    Row {
                                                        id: trayItemRow
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Image {
                                                            width: 16
                                                            height: 16
                                                            source: dashWin.resolveTrayIcon(modelData.icon)
                                                            sourceSize.width: 16
                                                            sourceSize.height: 16
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: String(modelData.title || modelData.id || "App")
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 11
                                                            color: Theme.fg
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: trayItemM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                                        onClicked: mouse => {
                                                            if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu)) {
                                                                if (modelData.hasMenu) {
                                                                    const pt = mapToItem(null, width / 2, height);
                                                                    modelData.display(dashWin, Math.round(pt.x), Math.round(pt.y));
                                                                } else {
                                                                    modelData.secondaryActivate();
                                                                }
                                                            } else if (mouse.button === Qt.MiddleButton) {
                                                                modelData.secondaryActivate();
                                                            } else {
                                                                modelData.activate();
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 180
                                    Layout.preferredHeight: 62
                                    radius: Theme.radiusMedium
                                    color: openBtopM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "󰄨"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: openBtopM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Abrir btop"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: openBtopM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: openBtopM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dashWin.closeRequested();
                                            Quickshell.execDetached(["foot", "-e", "btop"]);
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // TAB 3: ASISTENTE IA (OpenCode integrado)
                        // -----------------------------------------------------
                        ColumnLayout {
                            id: tabAi
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: dashWin.activeTab === 3 ? 0 : 10
                            opacity: dashWin.activeTab === 3 ? 1.0 : 0.0
                            visible: opacity > 0.01
                            enabled: dashWin.activeTab === 3
                            spacing: 14

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: Theme.animTab; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExpressive } }

                            readonly property bool aiOn: Boolean(dashWin.sysState && dashWin.sysState.aiActive)
                            readonly property string aiDet: dashWin.sysState ? String(dashWin.sysState.aiDetail || "") : ""

                            // Barra de servicio OpenCode
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    radius: Theme.radiusFull
                                    color: tabAi.aiOn ? Theme.tertiaryContainer : Theme.surfaceContainer
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 8

                                        Text {
                                            text: "󰚩"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            color: tabAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.tertiary
                                        }
                                        Text {
                                            text: "OpenCode · Asistente IA"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: tabAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.fg
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: tabAi.aiOn
                                                ? (tabAi.aiDet ? ("Servicio activo · " + tabAi.aiDet) : "Servicio activo")
                                                : "Modo standalone"
                                            font.family: Theme.monoFontFamily
                                            font.pixelSize: 11
                                            color: tabAi.aiOn ? Theme.fgOnTertiaryContainer : Theme.fgSubtle
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 44
                                    Layout.preferredWidth: aiSvcRow.implicitWidth + 24
                                    radius: Theme.radiusFull
                                    color: tabAi.aiOn
                                        ? (aiSvcM.containsMouse ? Theme.errorContainer : Theme.surfaceContainer)
                                        : (aiSvcM.containsMouse ? Theme.tertiaryContainer : Theme.surfaceContainer)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Row {
                                        id: aiSvcRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: tabAi.aiOn ? "󰐥" : "󰐊"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: tabAi.aiOn
                                                ? (aiSvcM.containsMouse ? Theme.fgOnErrorContainer : Theme.error)
                                                : (aiSvcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.tertiary)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: tabAi.aiOn ? "Detener servicio" : "Iniciar servicio"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: tabAi.aiOn
                                                ? (aiSvcM.containsMouse ? Theme.fgOnErrorContainer : Theme.fg)
                                                : (aiSvcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.fg)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: aiSvcM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dashWin.runScript("ai.sh", ["service", "toggle"])
                                    }
                                }
                            }

                            // 4 acciones principales en fila
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    model: dashWin.aiQuickActions

                                    Rectangle {
                                        id: aiQTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 68
                                        radius: Theme.radiusMedium
                                        color: aiQM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 30
                                                radius: 15
                                                color: aiQM.containsMouse ? Theme.primary : Theme.tertiaryContainer
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: aiQTile.modelData.glyph
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnTertiaryContainer
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: aiQTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: aiQTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: aiQM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                                    opacity: aiQM.containsMouse ? 0.85 : 1.0
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: aiQM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.runAiAction(aiQTile.modelData.cmd, aiQTile.modelData.delay)
                                        }
                                    }
                                }
                            }

                            // 6 acciones de contexto y Git (3 columnas x 2 filas)
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 8
                                rowSpacing: 10

                                Repeater {
                                    model: dashWin.aiContextActions

                                    Rectangle {
                                        id: aiCTile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        radius: Theme.radiusMedium
                                        color: aiCM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Text {
                                                text: aiCTile.modelData.glyph
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15
                                                color: aiCM.containsMouse ? Theme.primary : Theme.fgMuted
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: aiCTile.modelData.title
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: Theme.fg
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: aiCTile.modelData.subtitle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: aiCTile.modelData.cmd ? Theme.fgSubtle : Theme.fgSubtle
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: aiCM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashWin.runAiAction(aiCTile.modelData.cmd, aiCTile.modelData.delay)
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
}
