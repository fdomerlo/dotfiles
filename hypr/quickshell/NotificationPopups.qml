import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popupWin

    required property var popups
    required property real nowMs

    signal dismissRequested(int uid)
    signal popupCloseRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal hoverChanged(bool hovered)

    property int hoverCount: 0

    anchors {
        top: true
        right: true
    }
    margins {
        top: 52
        right: 12
    }

    implicitWidth: 368
    implicitHeight: Math.max(1, stackCol.implicitHeight)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    visible: popups && popups.length > 0

    ColumnLayout {
        id: stackCol
        width: popupWin.implicitWidth
        spacing: 8

        Repeater {
            model: popupWin.popups

            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                entry: modelData
                nowMs: popupWin.nowMs
                compact: true

                onDismissRequested: uid => popupWin.dismissRequested(uid)
                onPopupCloseRequested: uid => popupWin.popupCloseRequested(uid)
                onActionInvoked: (uid, action) => popupWin.actionInvoked(uid, action)
                onHoverStateChanged: h => {
                    popupWin.hoverCount = Math.max(0, popupWin.hoverCount + (h ? 1 : -1));
                    popupWin.hoverChanged(popupWin.hoverCount > 0);
                }
            }
        }
    }
}
