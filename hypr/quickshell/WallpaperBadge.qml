import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: badgeWin

    required property string wallpaperName

    anchors {
        right: true
        bottom: true
    }

    margins {
        right: 16
        bottom: 14
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-wallpaper-badge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    color: "transparent"
    visible: wallpaperName.length > 0

    Rectangle {
        id: pill
        implicitWidth: Math.min(labelRow.implicitWidth + 18, 360)
        implicitHeight: labelRow.implicitHeight + 10
        radius: Theme.cardRadius > 0 ? Math.min(Theme.cardRadius, 6) : 0
        color: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g, Theme.panelBg.b, 0.72)
        border.width: Theme.borderWidth
        border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.75)

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 7

            Rectangle {
                width: 6
                height: 6
                radius: Theme.cardRadius > 0 ? 3 : 0
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.activeBorder
                opacity: 0.9
            }

            Text {
                text: badgeWin.wallpaperName
                width: Math.min(implicitWidth, 316)
                color: Theme.textBright
                opacity: 0.88
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideMiddle
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
