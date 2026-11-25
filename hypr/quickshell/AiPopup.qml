import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: aiWin

    required property bool panelOpen
    required property var sysState

    signal closeRequested()

    readonly property int barH: sysState ? sysState.barHeight : 38
    readonly property bool aiActive: Boolean(sysState && sysState.aiActive)
    readonly property string aiDetail: sysState ? String(sysState.aiDetail || "") : ""
    property bool revealed: false

    readonly property var primaryActions: [
        {
            cmd: "ask",
            glyph: "󰚩",
            title: "Preguntar",
            subtitle: "Consulta rápida",
            delay: false
        },
        {
            cmd: "open",
            glyph: "󰆍",
            title: "Abrir OpenCode",
            subtitle: "Super+Shift+I",
            delay: false
        }
    ]

    readonly property var contextActions: [
        {
            cmd: "explain",
            glyph: "󰆧",
            title: "Explicar texto",
            subtitle: "Selección o clip",
            delay: false
        },
        {
            cmd: "error",
            glyph: "󰀪",
            title: "Explicar error",
            subtitle: "Desde portapapeles",
            delay: false
        },
        {
            cmd: "window",
            glyph: "󰈈",
            title: "Ventana activa",
            subtitle: "Captura y análisis",
            delay: true
        },
        {
            cmd: "image",
            glyph: "󰋩",
            title: "Imagen clip",
            subtitle: "Analizar captura",
            delay: false
        },
        {
            cmd: "summarize",
            glyph: "󰊄",
            title: "Resumir",
            subtitle: "Viñetas clave",
            delay: false
        },
        {
            cmd: "translate",
            glyph: "󰗊",
            title: "Traducir",
            subtitle: "ES ↔ EN + copiar",
            delay: false
        }
    ]

    readonly property var gitActions: [
        {
            cmd: "diff",
            glyph: "󰊢",
            title: "Revisar cambios",
            subtitle: "Diff del repo activo",
            delay: false
        },
        {
            cmd: "commit",
            glyph: "󰜘",
            title: "Mensaje commit",
            subtitle: "Conventional + copiar",
            delay: false
        }
    ]

    function runAiAction(cmd, delayForWindowCapture) {
        const script = (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ai.sh";
        aiWin.closeRequested();
        if (delayForWindowCapture) {
            // Esperar a que termine la animación de repliegue antes de capturar la ventana activa
            Quickshell.execDetached(["sh", "-c", "sleep 0.30 && exec \"$1\" \"$2\"", "_", script, cmd]);
        } else {
            Quickshell.execDetached([script, cmd]);
        }
    }

    function toggleService() {
        const script = (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ai.sh";
        Quickshell.execDetached([script, "service", "toggle"]);
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (aiWin.panelOpen)
                aiWin.revealed = true;
        }
    }

    Component.onCompleted: {
        aiScope.forceActiveFocus();
        if (panelOpen)
            revealTimer.restart();
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            aiScope.forceActiveFocus();
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
    WlrLayershell.namespace: "quickshell-ai"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    FocusScope {
        id: aiScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: aiWin.closeRequested()

        MouseArea {
            anchors.fill: parent
            enabled: aiWin.panelOpen
            onClicked: aiWin.closeRequested()
        }

        // Contenedor acoplado a la barra superior con esquinas cóncavas
        Item {
            id: aiDock
            anchors.top: parent.top
            anchors.topMargin: aiWin.barH
            anchors.right: parent.right
            anchors.rightMargin: 18
            width: 396
            height: aiWin.revealed ? (aiBody.implicitHeight + 28) : 0
            opacity: aiWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: aiWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: aiWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: aiWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.right: aiSurface.left
                visible: aiDock.height > 10
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.left: aiSurface.right
                visible: aiDock.height > 10
            }

            Item {
                id: aiSurface
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
                    id: aiBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    y: aiWin.revealed ? 12 : -10
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: aiWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: aiWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // Encabezado + estado y control del servicio OpenCode
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Theme.radiusFull
                            color: aiWin.aiActive ? Theme.tertiaryContainer : Theme.surfaceContainer

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "󰚩"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: aiWin.aiActive ? Theme.fgOnTertiaryContainer : Theme.tertiary
                                }

                                Text {
                                    text: "Asistente IA"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: aiWin.aiActive ? Theme.fgOnTertiaryContainer : Theme.fg
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: aiWin.aiActive
                                        ? (aiWin.aiDetail ? ("Activo · " + aiWin.aiDetail) : "Activo")
                                        : "Standalone"
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: aiWin.aiActive ? Theme.fgOnTertiaryContainer : Theme.fgSubtle
                                }
                            }
                        }

                        // Toggle del servicio OpenCode
                        Rectangle {
                            id: svcBtn
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: svcRow.implicitWidth + 20
                            radius: Theme.radiusFull
                            color: aiWin.aiActive
                                ? (svcM.containsMouse ? Theme.errorContainer : Theme.surfaceContainer)
                                : (svcM.containsMouse ? Theme.tertiaryContainer : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Row {
                                id: svcRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: aiWin.aiActive ? "󰐥" : "󰐊"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: aiWin.aiActive
                                        ? (svcM.containsMouse ? Theme.fgOnErrorContainer : Theme.error)
                                        : (svcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.tertiary)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: aiWin.aiActive ? "Apagar" : "Servicio"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: aiWin.aiActive
                                        ? (svcM.containsMouse ? Theme.fgOnErrorContainer : Theme.fg)
                                        : (svcM.containsMouse ? Theme.fgOnTertiaryContainer : Theme.fg)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: svcM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: aiWin.toggleService()
                            }
                        }
                    }

                    // Acciones principales (2 tiles destacados)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: aiWin.primaryActions

                            Rectangle {
                                id: priTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Theme.radiusMedium
                                color: priM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: priM.containsMouse ? Theme.primary : Theme.tertiaryContainer

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: priTile.modelData.glyph
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 15
                                            color: priM.containsMouse ? Theme.fgOnPrimary : Theme.fgOnTertiaryContainer
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: priTile.modelData.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: priM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: priTile.modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: priM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fgSubtle
                                            opacity: priM.containsMouse ? 0.85 : 1.0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: priM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: aiWin.runAiAction(priTile.modelData.cmd, priTile.modelData.delay)
                                }
                            }
                        }
                    }

                    // Sección Portapapeles y pantalla
                    Text {
                        text: "PORTAPAPELES Y PANTALLA"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                        color: Theme.fgSubtle
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: aiWin.contextActions

                            Rectangle {
                                id: ctxTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: Theme.radiusMedium
                                color: ctxM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 11
                                    spacing: 9

                                    Text {
                                        text: ctxTile.modelData.glyph
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        color: ctxM.containsMouse ? Theme.primary : Theme.fgMuted
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: ctxTile.modelData.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: Theme.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: ctxTile.modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.fgSubtle
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: ctxM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: aiWin.runAiAction(ctxTile.modelData.cmd, ctxTile.modelData.delay)
                                }
                            }
                        }
                    }

                    // Sección Git
                    Text {
                        text: "GIT · REPO ACTIVO"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                        color: Theme.fgSubtle
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: aiWin.gitActions

                            Rectangle {
                                id: gitTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: Theme.radiusMedium
                                color: gitM.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainer

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 11
                                    spacing: 9

                                    Text {
                                        text: gitTile.modelData.glyph
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        color: gitM.containsMouse ? Theme.fgOnSecondaryContainer : Theme.secondary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: gitTile.modelData.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: gitM.containsMouse ? Theme.fgOnSecondaryContainer : Theme.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: gitTile.modelData.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: gitM.containsMouse ? Theme.fgOnSecondaryContainer : Theme.fgSubtle
                                            opacity: gitM.containsMouse ? 0.85 : 1.0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: gitM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: aiWin.runAiAction(gitTile.modelData.cmd, gitTile.modelData.delay)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
