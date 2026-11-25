import QtQuick
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
    id: barWin

    required property var sysState
    required property date currentDate
    required property int notifCount
    required property bool dndEnabled
    required property bool notifCenterOpen
    required property bool launcherOpen
    required property bool overviewOpen
    required property bool calendarOpen
    required property bool quickSettingsOpen
    required property bool powerOpen
    required property bool aiOpen
    required property bool popupsVisible
    required property var calendarScreen
    required property var quickSettingsScreen
    required property var notifCenterScreen
    required property var powerScreen
    required property var aiScreen
    required property var popupsScreen
    required property bool idleInhibited

    signal launcherRequested()
    signal overviewRequested()
    signal notifCenterRequested()
    signal dndToggled()
    signal calendarRequested(var scr)
    signal quickSettingsRequested(var scr)
    signal powerRequested(var scr)
    signal aiRequested(var scr)
    signal idleInhibitToggled()

    readonly property int barH: sysState ? sysState.barHeight : 38
    readonly property int pillH: Math.max(24, barH - 10)
    readonly property bool isCalendarHere: calendarOpen && (!calendarScreen || calendarScreen === screen)
    readonly property bool isQuickSettingsHere: quickSettingsOpen && (!quickSettingsScreen || quickSettingsScreen === screen)
    readonly property bool isNotifCenterHere: notifCenterOpen && (!notifCenterScreen || notifCenterScreen === screen)
    readonly property bool isPowerHere: powerOpen && (!powerScreen || powerScreen === screen)
    readonly property bool isAiHere: aiOpen && (!aiScreen || aiScreen === screen)
    readonly property bool hasPopupsHere: popupsVisible && (!popupsScreen || popupsScreen === screen)
    readonly property bool anyDockedOpen: isCalendarHere || isQuickSettingsHere || isNotifCenterHere || isPowerHere || isAiHere || hasPopupsHere
    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool isPrimaryOrFocused: Boolean(
        Hyprland.focusedMonitor && hyprMonitor && Hyprland.focusedMonitor.name === hyprMonitor.name
    )

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

    // Título de ventana activa en este monitor
    readonly property string activeWindowTitle: {
        void(Hyprland.toplevels.values);
        if (!hyprMonitor || !hyprMonitor.activeWorkspace)
            return "";
        const activeWsId = hyprMonitor.activeWorkspace.id;
        const vals = Hyprland.toplevels.values;
        if (!vals)
            return "";
        let fallback = "";
        for (let i = 0; i < vals.length; i++) {
            const t = vals[i];
            if (!t || !t.workspace || t.workspace.id !== activeWsId)
                continue;
            if (t.activated)
                return String(t.title || "");
            if (!fallback && t.title)
                fallback = String(t.title);
        }
        return fallback;
    }

    // Reproductor MPRIS activo (prioriza el que está reproduciendo)
    readonly property var activePlayer: {
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return list[i];
        }
        return list[0];
    }

    readonly property string mediaText: {
        if (!activePlayer)
            return "";
        const title = String(activePlayer.trackTitle || "").trim();
        const artist = String(activePlayer.trackArtist || "").trim();
        if (artist && title)
            return artist + " · " + title;
        return title || artist || "";
    }

    // Audio (PipeWire)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: Boolean(defaultSink && defaultSink.audio)
    readonly property int volumePct: sinkReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSink.audio.volume || 0)) * 100)
        : 0
    readonly property bool volumeMuted: sinkReady ? Boolean(defaultSink.audio.muted) : false

    // Batería (UPower)
    readonly property var batteryDev: UPower.displayDevice
    readonly property bool hasBattery: Boolean(batteryDev && batteryDev.isLaptopBattery && batteryDev.isPresent)
    readonly property int batteryPct: hasBattery ? Math.round((batteryDev.percentage || 0) * 100) : 0
    readonly property bool batteryCharging: hasBattery && (
        batteryDev.state === UPowerDeviceState.Charging ||
        batteryDev.state === UPowerDeviceState.PendingCharge
    )
    readonly property bool batteryFull: hasBattery && batteryDev.state === UPowerDeviceState.FullyCharged

    readonly property string batteryGlyph: {
        if (batteryCharging)
            return "󰂄";
        if (batteryFull)
            return "󰚥";
        const icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        const idx = Math.max(0, Math.min(icons.length - 1, Math.round(batteryPct / 10)));
        return icons[idx];
    }

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

    // Reloj en español
    readonly property var esDays: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    readonly property var esMonths: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property string formattedDate: {
        const d = currentDate;
        const wd = esDays[d.getDay()] || "";
        const day = String(d.getDate()).padStart(2, "0");
        const mon = esMonths[d.getMonth()] || "";
        return wd + " " + day + " " + mon;
    }
    readonly property string formattedTime: {
        const d = currentDate;
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return hh + ":" + mm;
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

    function runScript(relPath, args) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/" + relPath].concat(args || []));
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
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    // Superficie superior continua estilo Material 3 / Caelestia
    Rectangle {
        id: barFrame
        anchors.fill: parent
        color: Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        // Línea inferior sutil que se desvanece cuando un popout se acopla a esta barra
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.outlineVariant
            opacity: barWin.anyDockedOpen ? 0.0 : 0.45

            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }

        // =====================================================================
        // ZONA IZQUIERDA: Lanzador · Workspaces · Media · Ventana activa
        // =====================================================================
        RowLayout {
            id: leftCluster
            anchors.left: parent.left
            anchors.right: centerClock.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 14
            spacing: 6

            // Botón Lanzador / Overview
            Rectangle {
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: 32
                radius: Theme.radiusFull
                color: (barWin.launcherOpen || barWin.overviewOpen)
                    ? Theme.primary
                    : (launcherM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "󰀻"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: (barWin.launcherOpen || barWin.overviewOpen) ? Theme.fgOnPrimary : Theme.primary
                }

                MouseArea {
                    id: launcherM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            barWin.overviewRequested();
                        else
                            barWin.launcherRequested();
                    }
                }
            }

            // Píldora de Workspaces con morphing elástico estilo Caelestia
            Rectangle {
                visible: barWin.monitorWorkspaces.length > 0
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: wsRow.implicitWidth + 10
                radius: Theme.radiusFull
                color: Theme.surfaceContainer

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
                    spacing: 4

                    Repeater {
                        model: barWin.monitorWorkspaces

                        Rectangle {
                            required property var modelData
                            readonly property bool isActive: Boolean(modelData.active)
                            readonly property bool isUrgent: Boolean(modelData.urgent)
                            readonly property bool hasWins: barWin.workspaceHasWindows(modelData.id)

                            height: barWin.pillH - 8
                            width: isActive
                                ? Math.max(34, wsLabel.implicitWidth + 18)
                                : (hasWins ? Math.max(22, wsLabel.implicitWidth + 10) : 18)
                            radius: height / 2
                            color: isUrgent
                                ? Theme.error
                                : (isActive
                                    ? Theme.primary
                                    : (wsM.containsMouse
                                        ? Theme.surfaceContainerHighest
                                        : (hasWins ? Theme.surfaceContainerHigh : "transparent")))

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
                                font.pixelSize: 11
                                font.weight: isActive ? Font.Bold : (hasWins ? Font.DemiBold : Font.Normal)
                                color: (isActive || isUrgent)
                                    ? Theme.fgOnPrimary
                                    : (hasWins ? Theme.fg : Theme.fgSubtle)
                                opacity: (isActive || isUrgent || hasWins || wsM.containsMouse) ? 1.0 : 0.75
                            }

                            MouseArea {
                                id: wsM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }
            }

            // Chip Media (MPRIS, solo cuando hay pista)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.showMedia && barWin.mediaText.length > 0)
                Layout.preferredHeight: barWin.pillH
                Layout.maximumWidth: 210
                Layout.preferredWidth: Math.min(210, mediaRow.implicitWidth + 18)
                radius: Theme.radiusFull
                color: mediaM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                clip: true

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    id: mediaRow
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    Text {
                        text: (barWin.activePlayer && barWin.activePlayer.isPlaying) ? "󰎆" : "󰏤"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.primary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: barWin.mediaText
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.fgMuted
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: mediaM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (barWin.activePlayer && barWin.activePlayer.canTogglePlaying)
                            barWin.activePlayer.togglePlaying();
                    }
                    onWheel: wheel => {
                        if (!barWin.activePlayer)
                            return;
                        if (wheel.angleDelta.y > 0 && barWin.activePlayer.canGoNext)
                            barWin.activePlayer.next();
                        else if (wheel.angleDelta.y < 0 && barWin.activePlayer.canGoPrevious)
                            barWin.activePlayer.previous();
                    }
                }
            }

            // Título de ventana activa (elidido limpiamente antes del reloj central)
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: barWin.activeWindowTitle
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: barWin.isPrimaryOrFocused ? Theme.fgMuted : Theme.fgSubtle
                opacity: barWin.isPrimaryOrFocused ? 0.95 : 0.72
                elide: Text.ElideRight
            }
        }

        // =====================================================================
        // ZONA CENTRAL: Reloj + Fecha (ancla visual del CalendarPopup acoplado)
        // =====================================================================
        Rectangle {
            id: centerClock
            anchors.centerIn: parent
            height: barWin.pillH
            width: clockRow.implicitWidth + 24
            radius: Theme.radiusFull
            color: barWin.isCalendarHere
                ? Theme.primaryContainer
                : (clkM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: barWin.formattedDate
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: barWin.isCalendarHere ? Theme.fgOnPrimaryContainer : Theme.fgMuted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: barWin.isCalendarHere ? Theme.primary : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: barWin.formattedTime
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: barWin.isCalendarHere ? Theme.fgOnPrimaryContainer : Theme.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clkM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: barWin.calendarRequested(barWin.screen)
            }
        }

        // =====================================================================
        // ZONA DERECHA: REC · Telemetría · IA · Tray · QuickSettings · Notifs · Power
        // =====================================================================
        RowLayout {
            id: rightCluster
            anchors.left: centerClock.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 6

            Item { Layout.fillWidth: true }

            // Grabación de pantalla activa
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.recordingActive)
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: recRow.implicitWidth + 16
                radius: Theme.radiusFull
                color: Theme.error

                Row {
                    id: recRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.fgOnError
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "REC"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.fgOnError
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.runScript("screen-record.sh", [])
                }
            }

            // Telemetría compacta (CPU + RAM · clic abre btop)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.showTelemetry)
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: telRow.implicitWidth + 18
                radius: Theme.radiusFull
                color: telM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    id: telRow
                    anchors.centerIn: parent
                    spacing: 9

                    Text {
                        text: " " + (barWin.sysState ? barWin.sysState.cpuUsage : 0) + "%"
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: (barWin.sysState && barWin.sysState.cpuUsage >= 85) ? Theme.error : Theme.fgMuted
                    }

                    Text {
                        text: "󰍛 " + (barWin.sysState ? barWin.sysState.memUsedGiB.toFixed(1) : "0.0") + "G"
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.fgMuted
                    }
                }

                MouseArea {
                    id: telM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["foot", "-e", "btop"])
                }
            }

            // Servicio IA (OpenCode)
            Rectangle {
                id: aiPill
                readonly property bool aiOn: Boolean(barWin.sysState && barWin.sysState.aiActive)
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: aiTxt.implicitWidth + 16
                radius: Theme.radiusFull
                color: (barWin.isAiHere || aiOn)
                    ? ((barWin.isAiHere || aiM.containsMouse) ? Theme.tertiary : Theme.tertiaryContainer)
                    : (aiM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    id: aiTxt
                    anchors.centerIn: parent
                    text: "󰚩 IA"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: (barWin.isAiHere || aiPill.aiOn)
                        ? ((barWin.isAiHere || aiM.containsMouse) ? Theme.fgOnTertiary : Theme.fgOnTertiaryContainer)
                        : Theme.fgMuted
                }

                MouseArea {
                    id: aiM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            barWin.runScript("ai.sh", ["service", "toggle"]);
                        else
                            barWin.aiRequested(barWin.screen);
                    }
                }
            }

            // System Tray (StatusNotifierItem + DBusMenu nativo)
            Rectangle {
                visible: SystemTray.items.values.length > 0
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: trayRow.implicitWidth + 14
                radius: Theme.radiusFull
                color: Theme.surfaceContainer

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8

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
                                source: barWin.resolveTrayIcon(modelData.icon)
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
                                            modelData.display(barWin, Math.round(pt.x), Math.round(pt.y));
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

            // Píldora unificada de Estado / Quick Settings (Red · VPN · BT · Energía · Audio)
            Rectangle {
                readonly property color statusFg: barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.fg
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: statusRow.implicitWidth + 20
                radius: Theme.radiusFull
                color: barWin.isQuickSettingsHere
                    ? Theme.primaryContainer
                    : (statusM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 9

                    Text {
                        visible: Boolean(barWin.sysState && barWin.sysState.nightlightActive)
                        text: ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: barWin.idleInhibited
                        text: "󰅶"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        readonly property string kind: barWin.sysState ? barWin.sysState.netKind : "disconnected"
                        text: kind === "wifi" ? "" : (kind === "ethernet" ? "󰈀" : "󰪎")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: kind === "disconnected"
                            ? Theme.error
                            : (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.fg)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: Boolean(barWin.sysState && barWin.sysState.vpnName.length > 0)
                        text: "󰒃"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: barWin.hasBluetooth
                        text: !barWin.btEnabled ? "󰂲" : (barWin.btConnectedDevice ? "󰂱" : "󰂯")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: barWin.btConnectedDevice
                            ? (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.primary)
                            : (barWin.btEnabled
                                ? (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.fgMuted)
                                : Theme.fgSubtle)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: barWin.volumeMuted
                            ? "󰖁"
                            : ((barWin.volumePct <= 33 ? "󰕿 " : (barWin.volumePct <= 66 ? "󰖀 " : "󰕾 ")) + barWin.volumePct + "%")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: barWin.volumeMuted
                            ? Theme.error
                            : (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.fg)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: barWin.hasBattery
                        text: barWin.batteryGlyph + " " + barWin.batteryPct + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: (!barWin.batteryCharging && barWin.batteryPct <= 15)
                            ? Theme.error
                            : (barWin.batteryCharging
                                ? (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.secondary)
                                : (barWin.isQuickSettingsHere ? Theme.fgOnPrimaryContainer : Theme.fg))
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: statusM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            barWin.runScript("osd.sh", ["volume", "mute"]);
                        else
                            barWin.quickSettingsRequested(barWin.screen);
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            barWin.runScript("osd.sh", ["volume", "raise"]);
                        else if (wheel.angleDelta.y < 0)
                            barWin.runScript("osd.sh", ["volume", "lower"]);
                    }
                }
            }

            // Notificaciones (clic izq.: Centro · clic der.: No Molestar)
            Rectangle {
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: notifRow.implicitWidth + 18
                radius: Theme.radiusFull
                color: barWin.isNotifCenterHere
                    ? Theme.primary
                    : (barWin.dndEnabled
                        ? Theme.errorContainer
                        : (notifM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    id: notifRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: barWin.dndEnabled
                            ? "󰂛"
                            : (barWin.notifCount > 0 ? "󰂚" : "󰂜")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
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
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: barWin.isNotifCenterHere ? Theme.fgOnPrimary : Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: notifM
                    anchors.fill: parent
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

            // Botón Power
            Rectangle {
                Layout.preferredHeight: barWin.pillH
                Layout.preferredWidth: barWin.pillH
                radius: Theme.radiusFull
                color: barWin.isPowerHere
                    ? Theme.error
                    : (pwrM.containsMouse ? Theme.errorContainer : Theme.surfaceContainer)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: barWin.isPowerHere
                        ? Theme.fgOnError
                        : (pwrM.containsMouse ? Theme.fgOnErrorContainer : Theme.fgMuted)
                }

                MouseArea {
                    id: pwrM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.powerRequested(barWin.screen)
                }
            }
        }
    }
}
