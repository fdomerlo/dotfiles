import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

PanelWindow {
    id: centerWin

    required property bool panelOpen
    required property var notifications
    required property bool dndEnabled
    required property real nowMs

    signal closeRequested()
    signal toggleDndRequested()
    signal clearAllRequested()
    signal dismissRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal replySent(int uid, string text)

    property bool hasBacklight: false
    property int brightnessPercent: 0
    property bool draggingBrightness: false

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: Boolean(defaultSink && defaultSink.audio)
    readonly property int sinkVolumePct: sinkReady
        ? Math.round(Math.max(0, Math.min(1.5, defaultSink.audio.volume || 0)) * 100)
        : 0
    readonly property bool sinkMuted: sinkReady ? Boolean(defaultSink.audio.muted) : false

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

    Process {
        id: backlightProbe
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -n1 || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = String(text || "").trim();
                if (!raw) {
                    centerWin.hasBacklight = false;
                    return;
                }
                const parts = raw.split(",");
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3].replace("%", ""), 10);
                    if (!isNaN(pct)) {
                        centerWin.hasBacklight = true;
                        if (!centerWin.draggingBrightness)
                            centerWin.brightnessPercent = Math.max(0, Math.min(100, pct));
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        backlightProbe.running = true;
        escScope.forceActiveFocus();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            backlightProbe.running = true;
            escScope.forceActiveFocus();
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
    visible: panelOpen

    FocusScope {
        id: escScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: centerWin.closeRequested()

        // Clic fuera del panel lo cierra
        MouseArea {
            anchors.fill: parent
            onClicked: centerWin.closeRequested()
        }

        // Panel lateral derecho
        Rectangle {
            id: drawer
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: 50
            anchors.bottomMargin: 10
            anchors.rightMargin: 10
            width: 392
            radius: Theme.radius
            color: Theme.panelBg
            border.width: Theme.borderWidth
            border.color: Theme.border
            clip: true

            // Absorber clics dentro del panel para no disparar el backdrop
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Encabezado
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notificaciones"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Theme.textBright
                    }

                    Rectangle {
                        visible: centerWin.notifications.length > 0
                        height: 20
                        width: Math.max(22, countTxt.implicitWidth + 12)
                        radius: Theme.radius > 0 ? 10 : 0
                        color: Theme.accent

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: String(centerWin.notifications.length)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.accentText
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Botón Limpiar todo
                    Rectangle {
                        visible: centerWin.notifications.length > 0
                        height: 28
                        width: clearTxt.implicitWidth + 18
                        radius: Theme.cardRadius > 0 ? 7 : 0
                        color: clearMouse.containsMouse ? Theme.urgent : Theme.cardBg
                        border.width: 1
                        border.color: clearMouse.containsMouse ? Theme.urgent : Theme.border

                        Text {
                            id: clearTxt
                            anchors.centerIn: parent
                            text: "Limpiar todo"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: clearMouse.containsMouse ? Theme.accentText : Theme.text
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

                // Tarjeta de controles rápidos (DND + Volumen + Brillo)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: controlsCol.implicitHeight + 20
                    radius: Theme.cardRadius
                    color: Theme.cardBg
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        id: controlsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 10

                        // Toggle No Molestar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: centerWin.dndEnabled ? "󰂛" : "󰂚"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                color: centerWin.dndEnabled ? Theme.urgent : Theme.accent
                            }

                            Text {
                                text: "No molestar"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.textBright
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 42
                                height: 22
                                radius: Theme.radius > 0 ? 11 : 0
                                color: centerWin.dndEnabled ? Theme.urgent : Theme.panelBg
                                border.width: 1
                                border.color: centerWin.dndEnabled ? Theme.urgent : Theme.border
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: Theme.radius > 0 ? 8 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: centerWin.dndEnabled ? parent.width - width - 3 : 3
                                    color: centerWin.dndEnabled ? Theme.accentText : Theme.muted
                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: centerWin.toggleDndRequested()
                                }
                            }
                        }

                        // Control de Volumen (PipeWire nativo)
                        RowLayout {
                            visible: centerWin.sinkReady
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: Theme.cardRadius > 0 ? 6 : 0
                                color: volMuteMouse.containsMouse ? Theme.cardHoverBg : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: centerWin.sinkMuted || centerWin.sinkVolumePct === 0
                                        ? "󰖁"
                                        : (centerWin.sinkVolumePct <= 50 ? "󰖀" : "󰕾")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: centerWin.sinkMuted ? Theme.urgent : Theme.accent
                                }

                                MouseArea {
                                    id: volMuteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (centerWin.sinkReady)
                                            centerWin.defaultSink.audio.muted = !centerWin.defaultSink.audio.muted;
                                    }
                                }
                            }

                            Item {
                                id: volSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                readonly property real fraction: centerWin.sinkMuted
                                    ? 0
                                    : Math.max(0, Math.min(1, centerWin.sinkVolumePct / 100.0))

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 6
                                    radius: Theme.radius > 0 ? 3 : 0
                                    color: Theme.panelBg
                                    border.width: 1
                                    border.color: Theme.border

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * volSlider.fraction
                                        radius: parent.radius
                                        color: centerWin.sinkMuted ? Theme.urgent : Theme.accent
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function applyX(mx) {
                                        if (!centerWin.sinkReady || width <= 0)
                                            return;
                                        const ratio = Math.max(0, Math.min(1, mx / width));
                                        centerWin.defaultSink.audio.muted = false;
                                        centerWin.defaultSink.audio.volume = ratio;
                                    }
                                    onPressed: mouse => applyX(mouse.x)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            applyX(mouse.x);
                                    }
                                }
                            }

                            Text {
                                Layout.preferredWidth: 36
                                horizontalAlignment: Text.AlignRight
                                text: centerWin.sinkMuted ? "Mudo" : (centerWin.sinkVolumePct + "%")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: centerWin.sinkMuted ? Theme.urgent : Theme.muted
                            }
                        }

                        // Control de Brillo (solo visible si el equipo tiene backlight)
                        RowLayout {
                            visible: centerWin.hasBacklight
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26

                                Text {
                                    anchors.centerIn: parent
                                    text: centerWin.brightnessPercent <= 33 ? "󰃞" : (centerWin.brightnessPercent <= 66 ? "󰃟" : "󰃠")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: Theme.accent
                                }
                            }

                            Item {
                                id: brSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                readonly property real fraction: Math.max(0, Math.min(1, centerWin.brightnessPercent / 100.0))

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 6
                                    radius: Theme.radius > 0 ? 3 : 0
                                    color: Theme.panelBg
                                    border.width: 1
                                    border.color: Theme.border

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * brSlider.fraction
                                        radius: parent.radius
                                        color: Theme.accent
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function applyX(mx) {
                                        if (width <= 0)
                                            return;
                                        const pct = Math.max(5, Math.min(100, Math.round((mx / width) * 100)));
                                        centerWin.brightnessPercent = pct;
                                        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
                                    }
                                    onPressed: mouse => {
                                        centerWin.draggingBrightness = true;
                                        applyX(mouse.x);
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            applyX(mouse.x);
                                    }
                                    onReleased: centerWin.draggingBrightness = false
                                }
                            }

                            Text {
                                Layout.preferredWidth: 36
                                horizontalAlignment: Text.AlignRight
                                text: centerWin.brightnessPercent + "%"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.muted
                            }
                        }
                    }
                }

                // Widget MPRIS (solo si hay reproductor activo)
                Rectangle {
                    visible: centerWin.activePlayer !== null
                    Layout.fillWidth: true
                    implicitHeight: visible ? 82 : 0
                    radius: Theme.cardRadius
                    color: Theme.cardBg
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: Theme.cardRadius > 0 ? Math.max(4, Theme.cardRadius - 2) : 0
                            color: Theme.panelBg
                            border.width: 1
                            border.color: Theme.border
                            clip: true

                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: centerWin.activePlayer ? String(centerWin.activePlayer.trackArtUrl || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: artImg.status !== Image.Ready
                                text: "󰎆"
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                color: Theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: centerWin.activePlayer
                                    ? String(centerWin.activePlayer.trackTitle || centerWin.activePlayer.identity || "Reproductor")
                                    : ""
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.textBright
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: centerWin.activePlayer
                                    ? String(centerWin.activePlayer.trackArtist || centerWin.activePlayer.identity || "")
                                    : ""
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.muted
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.topMargin: 4
                                spacing: 6

                                Repeater {
                                    model: [
                                        { icon: "󰒮", action: "prev" },
                                        { icon: (centerWin.activePlayer && centerWin.activePlayer.isPlaying) ? "󰏤" : "󰐊", action: "toggle" },
                                        { icon: "󰒭", action: "next" }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        width: 28
                                        height: 24
                                        radius: Theme.cardRadius > 0 ? 6 : 0
                                        color: mMouse.containsMouse ? Theme.accent : Theme.panelBg
                                        border.width: 1
                                        border.color: mMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: mMouse.containsMouse ? Theme.accentText : Theme.textBright
                                        }

                                        MouseArea {
                                            id: mMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = centerWin.activePlayer;
                                                if (!p)
                                                    return;
                                                if (modelData.action === "prev" && p.canGoPrevious)
                                                    p.previous();
                                                else if (modelData.action === "next" && p.canGoNext)
                                                    p.next();
                                                else if (modelData.action === "toggle" && p.canTogglePlaying)
                                                    p.togglePlaying();
                                            }
                                        }
                                    }
                                }
                            }
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

                    // Estado vacío
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: centerWin.notifications.length === 0
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: centerWin.dndEnabled ? "󰂛" : "󰂜"
                            font.family: Theme.fontFamily
                            font.pixelSize: 34
                            color: Theme.muted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: centerWin.dndEnabled ? "No molestar activo" : "Sin notificaciones"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.muted
                        }
                    }
                }
            }
        }
    }
}
