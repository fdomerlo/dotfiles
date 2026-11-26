import QtQuick
import Quickshell
import Quickshell.Wayland

// Capa compartida de oscurecimiento del escritorio bajo los popouts modales.
// Al residir fuera de cada Overlay individual, cambiar entre menú de sesión,
// notificaciones, apariencia y dashboard mantiene el fondo estable sin parpadeos.
PanelWindow {
    id: backdropWin

    required property bool active
    property int barHeight: 40
    property bool floatingMode: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-backdrop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: emptyMask

    Region {
        id: emptyMask
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: backdropWin.floatingMode ? 0 : backdropWin.barHeight
        color: Theme.dimAround
        opacity: backdropWin.active ? 1.0 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation {
                duration: backdropWin.active ? Theme.animFast : Theme.animClose
                easing.type: Easing.OutCubic
            }
        }
    }
}
