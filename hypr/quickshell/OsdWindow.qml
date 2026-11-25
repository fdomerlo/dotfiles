import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osdWin

    required property bool osdVisible
    required property string osdKind
    required property int osdValue
    required property bool osdMuted

    readonly property bool isMic: osdKind === "mic"
    readonly property bool isBrightness: osdKind === "brightness"
    readonly property bool isCaps: osdKind === "caps"
    readonly property bool isNum: osdKind === "num"
    readonly property bool isLock: isCaps || isNum
    readonly property bool isVolume: !isMic && !isBrightness && !isLock
    readonly property bool isBoosted: isVolume && !osdMuted && osdValue > 100
    readonly property bool lockActive: isLock && !osdMuted

    readonly property real barFraction: {
        if (isLock)
            return lockActive ? 1.0 : 0.0;
        if (isMic)
            return osdMuted ? 0.0 : 1.0;
        if (isVolume && osdMuted)
            return 0.0;
        const maxVal = isVolume && osdValue > 100 ? 150.0 : 100.0;
        return Math.max(0.0, Math.min(1.0, osdValue / maxVal));
    }

    readonly property string iconGlyph: {
        if (isCaps)
            return "󰪛";
        if (isNum)
            return "󰎠";
        if (isMic)
            return osdMuted ? "󰍭" : "󰍬";
        if (isBrightness) {
            if (osdValue <= 33)
                return "󰃞";
            if (osdValue <= 66)
                return "󰃟";
            return "󰃠";
        }
        if (osdMuted || osdValue <= 0)
            return "󰖁";
        if (osdValue <= 33)
            return "󰕿";
        if (osdValue <= 66)
            return "󰖀";
        return "󰕾";
    }

    readonly property string titleText: {
        if (isCaps)
            return "Bloq Mayús";
        if (isNum)
            return "Bloq Num";
        if (isMic)
            return "Micrófono";
        if (isBrightness)
            return "Brillo";
        return "Volumen";
    }

    readonly property string valueText: {
        if (isLock)
            return lockActive ? "Activado" : "Desactivado";
        if (isMic)
            return osdMuted ? "Silenciado" : "Activo";
        if (isVolume && osdMuted)
            return "Mudo";
        return osdValue + "%";
    }

    readonly property color stateAccent: {
        if (isLock)
            return lockActive ? Theme.accent : Theme.muted;
        if (osdMuted || isBoosted)
            return Theme.urgent;
        return Theme.accent;
    }

    anchors {
        bottom: true
    }
    margins {
        bottom: 64
    }

    implicitWidth: 276
    implicitHeight: 60

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    color: "transparent"
    visible: osdVisible

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radius > 0 ? Math.min(Theme.radius + 4, height / 2) : 0
        color: Theme.panelBg
        border.width: Theme.borderWidth
        border.color: (!osdWin.isLock && osdWin.osdMuted)
            ? Theme.urgent
            : (osdWin.isLock && !osdWin.lockActive ? Theme.border : Theme.activeBorder)
        clip: true

        Behavior on border.color {
            ColorAnimation { duration: 140 }
        }

        // Borde superior sutil de acento para temas arquitectónicos (radius 0).
        Rectangle {
            visible: Theme.radius === 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: osdWin.stateAccent
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.cardRadius > 0 ? Math.min(Theme.cardRadius + 2, 17) : 0
                color: Theme.cardBg
                border.width: Theme.borderWidth
                border.color: (!osdWin.isLock && osdWin.osdMuted) ? Theme.urgent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: osdWin.iconGlyph
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    color: osdWin.stateAccent
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: osdWin.titleText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: osdWin.valueText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: (!osdWin.isLock && (osdWin.osdMuted || osdWin.isBoosted))
                            ? Theme.urgent
                            : (osdWin.isLock && !osdWin.lockActive ? Theme.muted : Theme.textBright)
                    }
                }

                // Barra de progreso fluida (estilo Caelestia + tokens del tema)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6

                    Rectangle {
                        id: track
                        anchors.fill: parent
                        radius: Theme.radius > 0 ? 3 : 0
                        color: Theme.cardBg
                        border.width: 1
                        border.color: Theme.border
                    }

                    Rectangle {
                        id: fill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(osdWin.barFraction > 0 ? 4 : 0, track.width * osdWin.barFraction)
                        radius: track.radius
                        color: osdWin.stateAccent

                        Behavior on width {
                            NumberAnimation {
                                duration: 110
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }
                }
            }
        }
    }
}
