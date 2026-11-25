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
    required property bool idleInhibited

    signal launcherRequested()
    signal overviewRequested()
    signal notifCenterRequested()
    signal dndToggled()
    signal calendarRequested(var scr)
    signal idleInhibitToggled()

    readonly property bool isFloating: Theme.radius > 0
    readonly property int barH: sysState ? sysState.barHeight : 40
    readonly property int pillRadius: isFloating ? Math.min(Theme.cardRadius + 4, 12) : 0
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
            return artist + " - " + title;
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

    // Reloj en español (sin depender del locale del motor JS)
    readonly property var esDays: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    readonly property var esMonths: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property string formattedClock: {
        const d = currentDate;
        const wd = esDays[d.getDay()] || "";
        const day = String(d.getDate()).padStart(2, "0");
        const mon = esMonths[d.getMonth()] || "";
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return wd + ", " + day + " " + mon + " " + hh + ":" + mm;
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

    function powerProfileGlyph() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "󰓅";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "󰌪";
        return "󰾅";
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
        const full = home + "/.config/hypr/scripts/" + relPath;
        Quickshell.execDetached([full].concat(args || []));
    }

    // Inhibidor real de reposo Wayland (equivalente nativo al módulo idle_inhibitor de Waybar)
    IdleInhibitor {
        window: barWin
        enabled: barWin.idleInhibited
    }

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: isFloating ? 6 : 0
        left: isFloating ? 8 : 0
        right: isFloating ? 8 : 0
    }

    implicitHeight: barH
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    // Contenedor principal de la barra
    Rectangle {
        id: barFrame
        anchors.fill: parent
        radius: barWin.isFloating ? Math.min(Theme.radius, barWin.barH / 2) : 0
        color: Theme.panelBg
        border.width: barWin.isFloating ? Theme.borderWidth : 0
        border.color: Theme.border
        clip: true

        // Borde inferior limpio en temas arquitectónicos (radius === 0)
        Rectangle {
            visible: !barWin.isFloating
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: barWin.isFloating ? 8 : 6
            anchors.rightMargin: barWin.isFloating ? 8 : 6
            spacing: 6

            // =================================================================
            // ZONA IZQUIERDA: Lanzador · Workspaces · Media · Ventana activa
            // =================================================================

            // Botón Lanzador (clic izq.: Launcher, clic der.: Overview)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: launcherTxt.implicitWidth + 18
                radius: barWin.pillRadius
                color: (barWin.launcherOpen || barWin.overviewOpen)
                    ? Theme.accent
                    : (launcherM.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
                border.width: 1
                border.color: (barWin.launcherOpen || barWin.overviewOpen)
                    ? Theme.accent
                    : (launcherM.containsMouse ? Theme.activeBorder : Theme.border)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: launcherTxt
                    anchors.centerIn: parent
                    text: ">_"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: (barWin.launcherOpen || barWin.overviewOpen) ? Theme.accentText : Theme.accent
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

            // Píldora de Workspaces del monitor (morphing fluido estilo Caelestia)
            Rectangle {
                visible: barWin.monitorWorkspaces.length > 0
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: wsRow.implicitWidth + 10
                radius: barWin.pillRadius
                color: Theme.cardBg
                border.width: 1
                border.color: Theme.border

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

                            height: barWin.barH - 18
                            width: isActive
                                ? Math.max(barWin.isFloating ? 34 : 30, wsLabel.implicitWidth + 16)
                                : Math.max(24, wsLabel.implicitWidth + 12)
                            radius: barWin.isFloating ? height / 2 : 0
                            color: isUrgent
                                ? Theme.urgent
                                : (isActive
                                    ? Theme.accent
                                    : (wsM.containsMouse ? Theme.cardHoverBg : "transparent"))

                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                text: barWin.isFloating ? String(modelData.name) : ("[" + modelData.name + "]")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: isActive ? Font.Bold : (hasWins ? Font.DemiBold : Font.Normal)
                                color: (isActive || isUrgent)
                                    ? Theme.accentText
                                    : (hasWins ? Theme.textBright : Theme.muted)
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

            // Píldora Media (MPRIS, solo cuando hay reproducción/pista)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.showMedia && barWin.mediaText.length > 0)
                Layout.preferredHeight: barWin.barH - 12
                Layout.maximumWidth: 230
                Layout.preferredWidth: Math.min(230, mediaRow.implicitWidth + 16)
                radius: barWin.pillRadius
                color: mediaM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                border.width: 1
                border.color: mediaM.containsMouse ? Theme.activeBorder : Theme.border
                clip: true

                RowLayout {
                    id: mediaRow
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 6

                    Text {
                        text: (barWin.activePlayer && barWin.activePlayer.isPlaying) ? "󰎆" : "󰏤"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: barWin.mediaText
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.text
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

            // Título de ventana activa (absorbe el espacio central disponible)
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                text: barWin.activeWindowTitle
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: barWin.isPrimaryOrFocused ? Theme.text : Theme.muted
                elide: Text.ElideRight
            }

            // =================================================================
            // ZONA DERECHA: Telemetría · Hardware · Red · Sesión · Reloj · Tray
            // =================================================================

            // Grabación de pantalla (solo visible si wf-recorder está activo)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.recordingActive)
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: recRow.implicitWidth + 16
                radius: barWin.pillRadius
                color: Theme.urgent

                Row {
                    id: recRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.accentText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "REC"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.accentText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.runScript("screen-record.sh", [])
                }
            }

            // Telemetría CPU + RAM (clic abre btop)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.showTelemetry)
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: telRow.implicitWidth + 16
                radius: barWin.pillRadius
                color: telM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                border.width: 1
                border.color: telM.containsMouse ? Theme.activeBorder : Theme.border

                Row {
                    id: telRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: " " + (barWin.sysState ? barWin.sysState.cpuUsage : 0) + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: (barWin.sysState && barWin.sysState.cpuUsage >= 85) ? Theme.urgent : Theme.text
                    }

                    Text {
                        text: "󰍛 " + (barWin.sysState ? barWin.sysState.memUsedGiB.toFixed(1) : "0.0") + "G"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.text
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

            // Grupo de energía + hardware (Perfil · Idle · Brillo · Batería · Audio)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: hwRow.implicitWidth + 14
                radius: barWin.pillRadius
                color: Theme.cardBg
                border.width: 1
                border.color: Theme.border

                Row {
                    id: hwRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Perfil de energía
                    Item {
                        width: ppTxt.implicitWidth + 6
                        height: barWin.barH - 14

                        Text {
                            id: ppTxt
                            anchors.centerIn: parent
                            text: barWin.powerProfileGlyph()
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: PowerProfiles.profile === PowerProfile.Performance
                                ? Theme.urgent
                                : (PowerProfiles.profile === PowerProfile.PowerSaver ? Theme.accent : Theme.text)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWin.cyclePowerProfile()
                        }
                    }

                    // Inhibidor de reposo (Wayland IdleInhibitor)
                    Item {
                        width: idleTxt.implicitWidth + 6
                        height: barWin.barH - 14

                        Text {
                            id: idleTxt
                            anchors.centerIn: parent
                            text: barWin.idleInhibited ? "󰅶" : "󰾪"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: barWin.idleInhibited ? Theme.accent : Theme.muted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWin.idleInhibitToggled()
                        }
                    }

                    // Brillo (solo en equipos con backlight)
                    Item {
                        visible: Boolean(barWin.sysState && barWin.sysState.hasBacklight)
                        width: visible ? (brTxt.implicitWidth + 6) : 0
                        height: barWin.barH - 14

                        Text {
                            id: brTxt
                            anchors.centerIn: parent
                            readonly property int pct: barWin.sysState ? barWin.sysState.brightnessPercent : 0
                            text: (pct <= 33 ? "󰃞 " : (pct <= 66 ? "󰃟 " : "󰃠 ")) + pct + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0)
                                    barWin.runScript("osd.sh", ["brightness", "raise"]);
                                else if (wheel.angleDelta.y < 0)
                                    barWin.runScript("osd.sh", ["brightness", "lower"]);
                            }
                        }
                    }

                    // Batería (solo en laptops)
                    Item {
                        visible: barWin.hasBattery
                        width: visible ? (batTxt.implicitWidth + 6) : 0
                        height: barWin.barH - 14

                        Text {
                            id: batTxt
                            anchors.centerIn: parent
                            text: barWin.batteryGlyph + " " + barWin.batteryPct + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: (!barWin.batteryCharging && barWin.batteryPct <= 15)
                                ? Theme.urgent
                                : (barWin.batteryCharging ? Theme.accent : Theme.text)
                        }
                    }

                    // Audio (PipeWire nativo)
                    Item {
                        width: audTxt.implicitWidth + 6
                        height: barWin.barH - 14

                        Text {
                            id: audTxt
                            anchors.centerIn: parent
                            text: barWin.volumeMuted
                                ? "󰖁"
                                : ((barWin.volumePct <= 33 ? "󰕿 " : (barWin.volumePct <= 66 ? "󰖀 " : "󰕾 ")) + barWin.volumePct + "%")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: barWin.volumeMuted ? Theme.urgent : Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    barWin.runScript("osd.sh", ["volume", "mute"]);
                                else
                                    Quickshell.execDetached(["pavucontrol"]);
                            }
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0)
                                    barWin.runScript("osd.sh", ["volume", "raise"]);
                                else if (wheel.angleDelta.y < 0)
                                    barWin.runScript("osd.sh", ["volume", "lower"]);
                            }
                        }
                    }
                }
            }

            // Grupo de conectividad (Red · VPN · Bluetooth)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: netRow.implicitWidth + 14
                radius: barWin.pillRadius
                color: Theme.cardBg
                border.width: 1
                border.color: Theme.border

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Red
                    Item {
                        width: netTxt.implicitWidth + 6
                        height: barWin.barH - 14

                        Text {
                            id: netTxt
                            anchors.centerIn: parent
                            readonly property string kind: barWin.sysState ? barWin.sysState.netKind : "disconnected"
                            text: kind === "wifi" ? "" : (kind === "ethernet" ? "󰈀" : "󰪎")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: kind === "disconnected" ? Theme.urgent : Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    Quickshell.execDetached(["nm-connection-editor"]);
                                else
                                    barWin.runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"]);
                            }
                        }
                    }

                    // VPN activa
                    Item {
                        visible: Boolean(barWin.sysState && barWin.sysState.vpnName.length > 0)
                        width: visible ? (vpnTxt.implicitWidth + 6) : 0
                        height: barWin.barH - 14

                        Text {
                            id: vpnTxt
                            anchors.centerIn: parent
                            text: " " + (barWin.sysState ? barWin.sysState.vpnName : "")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWin.runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"])
                        }
                    }

                    // Bluetooth (solo si el equipo tiene adaptador)
                    Item {
                        visible: barWin.hasBluetooth
                        width: visible ? (btTxt.implicitWidth + 6) : 0
                        height: barWin.barH - 14

                        Text {
                            id: btTxt
                            anchors.centerIn: parent
                            text: !barWin.btEnabled
                                ? "󰂲"
                                : (barWin.btConnectedDevice
                                    ? ("󰂱 " + String(barWin.btConnectedDevice.name || barWin.btConnectedDevice.deviceName || ""))
                                    : "󰂯")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: barWin.btConnectedDevice ? Font.DemiBold : Font.Normal
                            color: barWin.btConnectedDevice ? Theme.accent : (barWin.btEnabled ? Theme.text : Theme.muted)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["blueman-manager"])
                        }
                    }
                }
            }

            // Luz nocturna (solo visible cuando está activa)
            Rectangle {
                visible: Boolean(barWin.sysState && barWin.sysState.nightlightActive)
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: 30
                radius: barWin.pillRadius
                color: nlM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                border.width: 1
                border.color: Theme.activeBorder

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.accent
                }

                MouseArea {
                    id: nlM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.runScript("nightlight-toggle.sh", [])
                }
            }

            // Servicio IA (OpenCode)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: aiTxt.implicitWidth + 16
                radius: barWin.pillRadius
                color: aiM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                border.width: 1
                border.color: (barWin.sysState && barWin.sysState.aiActive) ? Theme.activeBorder : Theme.border

                Text {
                    id: aiTxt
                    anchors.centerIn: parent
                    text: "󰚩 IA"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: (barWin.sysState && barWin.sysState.aiActive) ? Theme.accent : Theme.muted
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
                            barWin.runScript("ai.sh", ["menu"]);
                    }
                }
            }

            // Notificaciones (clic izq.: Centro · clic der.: No Molestar)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: notifRow.implicitWidth + 16
                radius: barWin.pillRadius
                color: barWin.notifCenterOpen
                    ? Theme.accent
                    : (notifM.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
                border.width: 1
                border.color: barWin.dndEnabled
                    ? Theme.urgent
                    : (barWin.notifCenterOpen || barWin.notifCount > 0 ? Theme.activeBorder : Theme.border)

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
                        color: barWin.notifCenterOpen
                            ? Theme.accentText
                            : (barWin.dndEnabled ? Theme.urgent : (barWin.notifCount > 0 ? Theme.accent : Theme.text))
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: barWin.notifCount > 0 && !barWin.dndEnabled
                        text: String(barWin.notifCount)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: barWin.notifCenterOpen ? Theme.accentText : Theme.textBright
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

            // Reloj (clic abre CalendarPopup)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: clkTxt.implicitWidth + 18
                radius: barWin.pillRadius
                color: barWin.calendarOpen
                    ? Theme.accent
                    : (clkM.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
                border.width: 1
                border.color: barWin.calendarOpen
                    ? Theme.accent
                    : (clkM.containsMouse ? Theme.activeBorder : Theme.border)

                Text {
                    id: clkTxt
                    anchors.centerIn: parent
                    text: "󰃭 " + barWin.formattedClock
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: barWin.calendarOpen ? Theme.accentText : Theme.textBright
                }

                MouseArea {
                    id: clkM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.calendarRequested(barWin.screen)
                }
            }

            // System Tray (StatusNotifierItem + DBusMenu nativo)
            Rectangle {
                visible: SystemTray.items.values.length > 0
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: trayRow.implicitWidth + 14
                radius: barWin.pillRadius
                color: Theme.cardBg
                border.width: 1
                border.color: Theme.border

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
                                width: 16
                                height: 16
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

            // Botón Power (menú del sistema)
            Rectangle {
                Layout.preferredHeight: barWin.barH - 12
                Layout.preferredWidth: 30
                radius: barWin.pillRadius
                color: pwrM.containsMouse ? Theme.urgent : Theme.cardBg
                border.width: 1
                border.color: pwrM.containsMouse ? Theme.urgent : Theme.border

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: pwrM.containsMouse ? Theme.accentText : Theme.textBright
                }

                MouseArea {
                    id: pwrM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWin.runScript("toggle-menu.sh", ["Sistema:", Quickshell.env("HOME") + "/.config/hypr/scripts/powermenu.sh"])
                }
            }
        }
    }
}
