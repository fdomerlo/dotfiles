import QtQuick

// Intercepta puntero en la franja superior (0..barH) cuando un Overlay modal está activo,
// permitiendo hover-scrubbing y clic directo entre indicadores de la barra.
Item {
    id: bridge

    property int barH: 40
    property var screen: null
    property bool active: true
    property string currentTarget: ""
    property var barHitTester: null

    signal menuHovered(var scr, string target)
    signal menuClicked(var scr, string target, int button)
    signal workspaceClicked(int wsId)
    signal outsideClicked()

    property string pendingTarget: ""
    property string hoveredKind: "none"
    property real entryX: -1
    property real entryY: -1

    function evaluateHit(px, py) {
        if (!bridge.barHitTester)
            return { kind: "empty", target: "", wsId: -1 };
        const hit = bridge.barHitTester(bridge.screen, px, py);
        return hit ? hit : { kind: "empty", target: "", wsId: -1 };
    }

    Timer {
        id: hoverTimer
        interval: 55
        repeat: false
        onTriggered: {
            if (!bridge.active || !bridge.pendingTarget)
                return;
            if (bridge.pendingTarget !== bridge.currentTarget)
                bridge.menuHovered(bridge.screen, bridge.pendingTarget);
        }
    }

    MouseArea {
        id: barPointerArea
        anchors.fill: parent
        enabled: bridge.active
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: (bridge.hoveredKind === "menu" || bridge.hoveredKind === "workspace")
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor

        onEntered: {
            bridge.entryX = barPointerArea.mouseX;
            bridge.entryY = barPointerArea.mouseY;
            const hit = bridge.evaluateHit(barPointerArea.mouseX, barPointerArea.mouseY);
            bridge.hoveredKind = hit.kind || "none";
        }

        onPositionChanged: mouse => {
            const hit = bridge.evaluateHit(mouse.x, mouse.y);
            bridge.hoveredKind = hit.kind || "none";

            if (bridge.entryX >= 0) {
                if (Math.abs(mouse.x - bridge.entryX) + Math.abs(mouse.y - bridge.entryY) < 0.5)
                    return;
                bridge.entryX = -1;
                bridge.entryY = -1;
            }

            if (hit.kind === "menu" && hit.target && hit.target !== bridge.currentTarget) {
                if (bridge.pendingTarget !== hit.target) {
                    bridge.pendingTarget = hit.target;
                    hoverTimer.restart();
                }
            } else {
                bridge.pendingTarget = "";
                hoverTimer.stop();
            }
        }

        onExited: {
            bridge.entryX = -1;
            bridge.entryY = -1;
            bridge.hoveredKind = "none";
            bridge.pendingTarget = "";
            hoverTimer.stop();
        }

        onClicked: mouse => {
            hoverTimer.stop();
            bridge.pendingTarget = "";

            const hit = bridge.evaluateHit(mouse.x, mouse.y);
            if (hit.kind === "menu" && hit.target) {
                bridge.menuClicked(bridge.screen, hit.target, mouse.button);
            } else if (hit.kind === "workspace" && hit.wsId > 0) {
                bridge.workspaceClicked(hit.wsId);
            } else {
                bridge.outsideClicked();
            }
        }
    }
}
