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

    property bool revealed: false

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

    readonly property bool isAlertState: (!isLock && (osdMuted || isBoosted))

    readonly property color stateAccent: {
        if (isLock)
            return lockActive ? Theme.primary : Theme.fgSubtle;
        if (isAlertState)
            return Theme.error;
        if (isBrightness)
            return Theme.secondary;
        return Theme.primary;
    }

    readonly property color badgeBg: {
        if (isLock)
            return lockActive ? Theme.primaryContainer : Theme.surfaceContainer;
        if (isAlertState)
            return Theme.errorContainer;
        if (isBrightness)
            return Theme.secondaryContainer;
        return Theme.primaryContainer;
    }

    readonly property color badgeFg: {
        if (isLock)
            return lockActive ? Theme.fgOnPrimaryContainer : Theme.fgSubtle;
        if (isAlertState)
            return Theme.fgOnErrorContainer;
        if (isBrightness)
            return Theme.fgOnSecondaryContainer;
        return Theme.fgOnPrimaryContainer;
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (osdWin.osdVisible)
                osdWin.revealed = true;
        }
    }

    Component.onCompleted: {
        if (osdVisible)
            revealTimer.restart();
    }

    onOsdVisibleChanged: {
        if (osdVisible) {
            revealTimer.restart();
        } else {
            revealTimer.stop();
            revealed = false;
        }
    }

    anchors {
        bottom: true
    }
    margins {
        bottom: 48
    }

    implicitWidth: 296
    implicitHeight: 74

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    color: "transparent"

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: 288
        height: 62
        y: osdWin.revealed ? 6 : 22
        opacity: osdWin.revealed ? 1.0 : 0.0
        scale: osdWin.revealed ? 1.0 : 0.94
        radius: height / 2
        color: Theme.surface
        border.width: 1
        border.color: osdWin.isAlertState ? Theme.error : Theme.outlineVariant
        clip: true

        Behavior on y {
            NumberAnimation {
                duration: osdWin.revealed ? Theme.animNormal : Theme.animClose
                easing.type: Easing.BezierSpline
                easing.bezierCurve: osdWin.revealed ? Theme.curveDecel : Theme.curveAccel
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: osdWin.revealed ? Theme.animFast : Theme.animClose
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: osdWin.revealed ? Theme.animNormal : Theme.animClose
                easing.type: Easing.BezierSpline
                easing.bezierCurve: osdWin.revealed ? Theme.curveDecel : Theme.curveAccel
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 18
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: osdWin.badgeBg

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: osdWin.iconGlyph
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    color: osdWin.badgeFg
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
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
                        color: Theme.fg
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: osdWin.valueText
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: osdWin.isAlertState
                            ? Theme.error
                            : (osdWin.isLock && !osdWin.lockActive ? Theme.fgSubtle : Theme.fgMuted)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8

                    Rectangle {
                        id: track
                        anchors.fill: parent
                        radius: 4
                        color: Theme.surfaceContainerHighest
                    }

                    Rectangle {
                        id: fill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(osdWin.barFraction > 0 ? 8 : 0, track.width * osdWin.barFraction)
                        radius: 4
                        color: osdWin.stateAccent

                        Behavior on width {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveDecel
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }
                    }
                }
            }
        }
    }
}
