import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

PanelWindow {
    id: qsWin

    required property bool panelOpen
    required property var sysState
    required property bool dndEnabled
    required property bool idleInhibited

    signal closeRequested()
    signal toggleDndRequested()
    signal toggleIdleInhibitRequested()
    signal powerRequested()
    signal aiRequested()

    readonly property int barH: sysState ? sysState.barHeight : 38
    property bool revealed: false
    property bool draggingBrightness: false

    // Audio (PipeWire)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: Boolean(defaultSink && defaultSink.audio)
    readonly property int sinkVolumePct: sinkReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSink.audio.volume || 0)) * 100)
        : 0
    readonly property bool sinkMuted: sinkReady ? Boolean(defaultSink.audio.muted) : false

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

    // Reproductor MPRIS activo
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

    // Batería (solo laptops)
    readonly property var batteryDev: UPower.displayDevice
    readonly property bool hasBattery: Boolean(batteryDev && batteryDev.isLaptopBattery && batteryDev.isPresent)
    readonly property int batteryPct: hasBattery ? Math.round((batteryDev.percentage || 0) * 100) : 0

    function runScript(relPath, args) {
        const home = Quickshell.env("HOME") || "";
        Quickshell.execDetached([home + "/.config/hypr/scripts/" + relPath].concat(args || []));
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

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (qsWin.panelOpen)
                qsWin.revealed = true;
        }
    }

    Component.onCompleted: {
        qsScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            qsScope.forceActiveFocus();
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
    WlrLayershell.namespace: "quickshell-quicksettings"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    FocusScope {
        id: qsScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: qsWin.closeRequested()

        MouseArea {
            anchors.fill: parent
            enabled: qsWin.panelOpen
            onClicked: qsWin.closeRequested()
        }

        // Contenedor acoplado a la barra superior con esquinas cóncavas
        Item {
            id: dockAnchor
            anchors.top: parent.top
            anchors.topMargin: qsWin.barH
            anchors.right: parent.right
            anchors.rightMargin: 18
            width: 380
            height: qsWin.revealed ? (panelBody.implicitHeight + 28) : 0
            clip: false
            opacity: qsWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: qsWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: qsWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: qsWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            // Unión cóncava izquierda con la barra superior
            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.right: panelBox.left
                visible: dockAnchor.height > 10
            }

            // Unión cóncava derecha con la barra superior
            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.left: panelBox.right
                visible: dockAnchor.height > 10
            }

            // Cuerpo principal (esquinas superiores fundidas con la barra, inferiores redondeadas)
            Item {
                id: panelBox
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
                    id: panelBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    y: qsWin.revealed ? 12 : -10
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: qsWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: qsWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // Encabezado: sesión + toggle Oscuro/Claro en caliente + energía
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.fillWidth: true
                            radius: Theme.radiusFull
                            color: Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "󰀄"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: Theme.primary
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsWin.sysState
                                        ? (qsWin.sysState.userName + (qsWin.sysState.hostName ? "@" + qsWin.sysState.hostName : ""))
                                        : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: qsWin.hasBattery
                                    text: qsWin.batteryPct + "%"
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.secondary
                                }
                            }
                        }

                        // Toggle instantáneo Modo Oscuro / Claro
                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: modeRow.implicitWidth + 20
                            radius: Theme.radiusFull
                            color: modeMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Theme.isDark ? "󰖔" : "󰖨"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    color: modeMouse.containsMouse ? Theme.fgOnPrimaryContainer : Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: Theme.isDark ? "Oscuro" : "Claro"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: modeMouse.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.runScript("theme-switch.sh", ["toggle"])
                            }
                        }

                        // Botón de menú de energía
                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: Theme.radiusFull
                            color: pwrMouse.containsMouse ? Theme.errorContainer : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐥"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                color: pwrMouse.containsMouse ? Theme.fgOnErrorContainer : Theme.fg
                            }

                            MouseArea {
                                id: pwrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.powerRequested()
                            }
                        }
                    }

                    // Grilla 2x3 de toggles Material 3
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        // Tile 1: Red / VPN
                        Rectangle {
                            id: netTile
                            readonly property bool active: Boolean(qsWin.sysState && qsWin.sysState.netKind !== "disconnected")
                            readonly property bool hasVpn: Boolean(qsWin.sysState && qsWin.sysState.vpnName.length > 0)
                            readonly property color tileFg: active
                                ? (netTileM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                : Theme.fg
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: active
                                ? (netTileM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                : (netTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    readonly property string kind: qsWin.sysState ? qsWin.sysState.netKind : "disconnected"
                                    text: netTile.hasVpn ? "󰒃" : (kind === "wifi" ? "" : (kind === "ethernet" ? "󰈀" : "󰪎"))
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    color: netTile.active ? netTile.tileFg : Theme.fgSubtle
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: netTile.hasVpn ? "VPN activa" : "Red"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: netTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: netTile.hasVpn
                                            ? qsWin.sysState.vpnName
                                            : (qsWin.sysState && qsWin.sysState.netLabel ? qsWin.sysState.netLabel : "Desconectado")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: netTile.active ? netTile.tileFg : Theme.fgSubtle
                                        opacity: netTile.active ? 0.88 : 1.0
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: netTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qsWin.closeRequested();
                                    qsWin.runScript("toggle-menu.sh", ["Red:", Quickshell.env("HOME") + "/.config/hypr/scripts/network-menu.sh"]);
                                }
                            }
                        }

                        // Tile 2: Bluetooth
                        Rectangle {
                            id: btTile
                            readonly property bool active: qsWin.btEnabled
                            readonly property color tileFg: active
                                ? (btTileM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                : Theme.fg
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: active
                                ? (btTileM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                : (btTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: qsWin.btConnectedDevice ? "󰂱" : (qsWin.btEnabled ? "󰂯" : "󰂲")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    color: btTile.active ? btTile.tileFg : Theme.fgSubtle
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Bluetooth"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: btTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: !qsWin.hasBluetooth
                                            ? "Sin adaptador"
                                            : (qsWin.btConnectedDevice
                                                ? String(qsWin.btConnectedDevice.name || qsWin.btConnectedDevice.deviceName || "Conectado")
                                                : (qsWin.btEnabled ? "Encendido" : "Apagado"))
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: btTile.active ? btTile.tileFg : Theme.fgSubtle
                                        opacity: btTile.active ? 0.88 : 1.0
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: btTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qsWin.closeRequested();
                                    Quickshell.execDetached(["blueman-manager"]);
                                }
                            }
                        }

                        // Tile 3: No Molestar
                        Rectangle {
                            id: dndTile
                            readonly property color tileFg: qsWin.dndEnabled
                                ? (dndTileM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                : Theme.fg
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: qsWin.dndEnabled
                                ? (dndTileM.containsMouse ? Theme.error : Theme.errorContainer)
                                : (dndTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: qsWin.dndEnabled ? "󰂛" : "󰂚"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    color: qsWin.dndEnabled ? dndTile.tileFg : Theme.fgMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "No molestar"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: dndTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: qsWin.dndEnabled ? "Silenciado" : "Normal"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: qsWin.dndEnabled ? dndTile.tileFg : Theme.fgSubtle
                                        opacity: qsWin.dndEnabled ? 0.88 : 1.0
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: dndTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.toggleDndRequested()
                            }
                        }

                        // Tile 4: Luz nocturna
                        Rectangle {
                            id: nlTile
                            readonly property bool active: Boolean(qsWin.sysState && qsWin.sysState.nightlightActive)
                            readonly property color tileFg: active
                                ? (nlTileM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnPrimaryContainer)
                                : Theme.fg
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: active
                                ? (nlTileM.containsMouse ? Theme.primary : Theme.primaryContainer)
                                : (nlTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: nlTile.active ? nlTile.tileFg : Theme.fgMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Luz nocturna"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: nlTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: nlTile.active ? "4000K activo" : "Desactivada"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: nlTile.active ? nlTile.tileFg : Theme.fgSubtle
                                        opacity: nlTile.active ? 0.88 : 1.0
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: nlTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qsWin.runScript("nightlight-toggle.sh", []);
                                    if (qsWin.sysState)
                                        qsWin.sysState.refreshAll();
                                }
                            }
                        }

                        // Tile 5: Inhibir reposo
                        Rectangle {
                            id: idleTile
                            readonly property color tileFg: qsWin.idleInhibited
                                ? (idleTileM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                : Theme.fg
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: qsWin.idleInhibited
                                ? (idleTileM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                : (idleTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: qsWin.idleInhibited ? "󰅶" : "󰾪"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    color: qsWin.idleInhibited ? idleTile.tileFg : Theme.fgMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Reposo"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: idleTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: qsWin.idleInhibited ? "Inhibido" : "Automático"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: qsWin.idleInhibited ? idleTile.tileFg : Theme.fgSubtle
                                        opacity: qsWin.idleInhibited ? 0.88 : 1.0
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: idleTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.toggleIdleInhibitRequested()
                            }
                        }

                        // Tile 6: Perfil de energía
                        Rectangle {
                            id: ppTile
                            readonly property bool isPerf: PowerProfiles.profile === PowerProfile.Performance
                            readonly property bool isSaver: PowerProfiles.profile === PowerProfile.PowerSaver
                            readonly property color tileFg: isPerf
                                ? (ppTileM.containsMouse ? Theme.fgOnError : Theme.fgOnErrorContainer)
                                : (isSaver
                                    ? (ppTileM.containsMouse ? Theme.fgOnSecondary : Theme.fgOnSecondaryContainer)
                                    : Theme.fg)
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: isPerf
                                ? (ppTileM.containsMouse ? Theme.error : Theme.errorContainer)
                                : (isSaver
                                    ? (ppTileM.containsMouse ? Theme.secondary : Theme.secondaryContainer)
                                    : (ppTileM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: qsWin.powerProfileGlyph()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    color: (ppTile.isPerf || ppTile.isSaver) ? ppTile.tileFg : Theme.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Energía"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: ppTile.tileFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: qsWin.powerProfileLabel()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: (ppTile.isPerf || ppTile.isSaver) ? ppTile.tileFg : Theme.fgSubtle
                                        opacity: (ppTile.isPerf || ppTile.isSaver) ? 0.88 : 1.0
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: ppTileM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.cyclePowerProfile()
                            }
                        }
                    }

                    // Sliders gruesos estilo Material 3 / Caelestia (Volumen + Brillo)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: slidersCol.implicitHeight + 20
                        radius: Theme.radiusMedium
                        color: Theme.surfaceContainer

                        ColumnLayout {
                            id: slidersCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10

                            // Slider de Volumen
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusFull
                                    color: qsWin.sinkMuted ? Theme.errorContainer : Theme.surfaceContainerHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsWin.sinkMuted
                                            ? "󰖁"
                                            : (qsWin.sinkVolumePct <= 33 ? "󰕿" : (qsWin.sinkVolumePct <= 66 ? "󰖀" : "󰕾"))
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        color: qsWin.sinkMuted ? Theme.fgOnErrorContainer : Theme.primary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (qsWin.sinkReady)
                                                qsWin.defaultSink.audio.muted = !qsWin.defaultSink.audio.muted;
                                        }
                                    }
                                }

                                Item {
                                    id: volTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 26

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 12
                                        radius: 6
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: qsWin.sinkMuted ? 0 : Math.max(12, parent.width * Math.min(1.0, qsWin.sinkVolumePct / 100.0))
                                            radius: 6
                                            color: qsWin.sinkVolumePct > 100 ? Theme.error : Theme.primary

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 140
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Theme.curveDecel
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function applyX(mx) {
                                            if (!qsWin.sinkReady)
                                                return;
                                            const frac = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)));
                                            qsWin.defaultSink.audio.muted = false;
                                            qsWin.defaultSink.audio.volume = frac;
                                        }
                                        onPressed: mouse => applyX(mouse.x)
                                        onPositionChanged: mouse => {
                                            if (pressed)
                                                applyX(mouse.x);
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 40
                                    horizontalAlignment: Text.AlignRight
                                    text: qsWin.sinkMuted ? "Mudo" : (qsWin.sinkVolumePct + "%")
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: qsWin.sinkMuted ? Theme.error : Theme.fgMuted
                                }
                            }

                            // Slider de Brillo (solo equipos con backlight real)
                            RowLayout {
                                visible: Boolean(qsWin.sysState && qsWin.sysState.hasBacklight)
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusFull
                                    color: Theme.surfaceContainerHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰃠"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        color: Theme.secondary
                                    }
                                }

                                Item {
                                    id: brTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 26

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 12
                                        radius: 6
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            readonly property int pct: qsWin.sysState ? qsWin.sysState.brightnessPercent : 0
                                            width: Math.max(12, parent.width * Math.min(1.0, pct / 100.0))
                                            radius: 6
                                            color: Theme.secondary

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 140
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Theme.curveDecel
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function applyX(mx) {
                                            const pct = Math.max(5, Math.min(100, Math.round((mx / Math.max(1, width)) * 100)));
                                            if (qsWin.sysState)
                                                qsWin.sysState.brightnessPercent = pct;
                                            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", pct + "%"]);
                                        }
                                        onPressed: mouse => {
                                            qsWin.draggingBrightness = true;
                                            applyX(mouse.x);
                                        }
                                        onPositionChanged: mouse => {
                                            if (pressed)
                                                applyX(mouse.x);
                                        }
                                        onReleased: qsWin.draggingBrightness = false
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 40
                                    horizontalAlignment: Text.AlignRight
                                    text: (qsWin.sysState ? qsWin.sysState.brightnessPercent : 0) + "%"
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.fgMuted
                                }
                            }
                        }
                    }

                    // Tarjeta compacta de Reproductor MPRIS (visible solo si hay media)
                    Rectangle {
                        visible: Boolean(qsWin.activePlayer)
                        Layout.fillWidth: true
                        implicitHeight: 68
                        radius: Theme.radiusMedium
                        color: Theme.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: Theme.radiusSmall
                                color: Theme.primaryContainer
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: qsWin.activePlayer ? (qsWin.activePlayer.trackArtUrl || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !qsWin.activePlayer || !qsWin.activePlayer.trackArtUrl
                                    text: "󰎆"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 20
                                    color: Theme.fgOnPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: qsWin.activePlayer ? (qsWin.activePlayer.trackTitle || qsWin.activePlayer.identity || "Multimedia") : ""
                                    textFormat: Text.PlainText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsWin.activePlayer ? (qsWin.activePlayer.trackArtist || qsWin.activePlayer.identity || "") : ""
                                    textFormat: Text.PlainText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.fgSubtle
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                spacing: 4

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: prevM.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒮"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        color: Theme.fg
                                    }
                                    MouseArea {
                                        id: prevM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (qsWin.activePlayer && qsWin.activePlayer.canGoPrevious) qsWin.activePlayer.previous()
                                    }
                                }

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.primary
                                    Text {
                                        anchors.centerIn: parent
                                        text: (qsWin.activePlayer && qsWin.activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        color: Theme.fgOnPrimary
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (qsWin.activePlayer && qsWin.activePlayer.canTogglePlaying) qsWin.activePlayer.togglePlaying()
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: nextM.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒭"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        color: Theme.fg
                                    }
                                    MouseArea {
                                        id: nextM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (qsWin.activePlayer && qsWin.activePlayer.canGoNext) qsWin.activePlayer.next()
                                    }
                                }
                            }
                        }
                    }

                    // Pie rápido: Telemetría + Mezclador + OpenCode IA
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Theme.radiusFull
                            color: btopM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: " " + (qsWin.sysState ? qsWin.sysState.cpuUsage : 0) + "%  ·  󰍛 " + (qsWin.sysState ? qsWin.sysState.memUsedGiB.toFixed(1) : "0.0") + "G"
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 11
                                color: Theme.fgMuted
                            }

                            MouseArea {
                                id: btopM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qsWin.closeRequested();
                                    Quickshell.execDetached(["foot", "-e", "btop"]);
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: mixTxt.implicitWidth + 20
                            radius: Theme.radiusFull
                            color: mixM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: mixTxt
                                anchors.centerIn: parent
                                text: "󰓃 Audio"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.fg
                            }

                            MouseArea {
                                id: mixM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qsWin.closeRequested();
                                    Quickshell.execDetached(["pavucontrol"]);
                                }
                            }
                        }

                        Rectangle {
                            id: aiFootBtn
                            readonly property bool aiOn: Boolean(qsWin.sysState && qsWin.sysState.aiActive)
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: aiFootTxt.implicitWidth + 20
                            radius: Theme.radiusFull
                            color: aiOn
                                ? (aiFootM.containsMouse ? Theme.tertiary : Theme.tertiaryContainer)
                                : (aiFootM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: aiFootTxt
                                anchors.centerIn: parent
                                text: "󰚩 IA"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: aiFootBtn.aiOn
                                    ? (aiFootM.containsMouse ? Theme.fgOnTertiary : Theme.fgOnTertiaryContainer)
                                    : Theme.fgMuted
                            }

                            MouseArea {
                                id: aiFootM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qsWin.aiRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
