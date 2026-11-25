import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calWin

    required property bool calendarOpen
    required property date currentDate
    property int barHeight: 38

    signal closeRequested()

    property bool revealed: false
    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth() // 0..11

    readonly property var monthNames: [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    readonly property var weekdayNames: [
        "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"
    ]
    readonly property var weekdayShort: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]

    readonly property string fullDateHeader: {
        const d = currentDate;
        const wd = weekdayNames[d.getDay()] || "";
        const mon = (monthNames[d.getMonth()] || "").toLowerCase();
        return wd + ", " + d.getDate() + " de " + mon;
    }

    readonly property var calendarCells: {
        const y = displayYear;
        const m = displayMonth;
        const first = new Date(y, m, 1);
        const startOffset = (first.getDay() + 6) % 7; // Lunes = 0
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const prevMonthDays = new Date(y, m, 0).getDate();
        const todayY = currentDate.getFullYear();
        const todayM = currentDate.getMonth();
        const todayD = currentDate.getDate();

        const cells = [];
        for (let i = startOffset - 1; i >= 0; i--) {
            cells.push({ day: prevMonthDays - i, inMonth: false, isToday: false });
        }
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                inMonth: true,
                isToday: (y === todayY && m === todayM && d === todayD)
            });
        }
        let nextDay = 1;
        while (cells.length % 7 !== 0 || cells.length < 35) {
            cells.push({ day: nextDay++, inMonth: false, isToday: false });
        }
        return cells;
    }

    function shiftMonth(delta) {
        let m = displayMonth + delta;
        let y = displayYear;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        displayYear = y;
        displayMonth = m;
    }

    function resetToToday() {
        displayYear = currentDate.getFullYear();
        displayMonth = currentDate.getMonth();
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (calWin.calendarOpen)
                calWin.revealed = true;
        }
    }

    Component.onCompleted: {
        resetToToday();
        calScope.forceActiveFocus();
        if (calendarOpen)
            revealTimer.restart();
    }

    onCalendarOpenChanged: {
        if (calendarOpen) {
            resetToToday();
            calScope.forceActiveFocus();
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
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    FocusScope {
        id: calScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: calWin.closeRequested()

        MouseArea {
            anchors.fill: parent
            enabled: calWin.calendarOpen
            onClicked: calWin.closeRequested()
        }

        // Popout acoplado al centro de la barra superior con esquinas cóncavas
        Item {
            id: calDock
            anchors.top: parent.top
            anchors.topMargin: calWin.barHeight
            anchors.horizontalCenter: parent.horizontalCenter
            width: 336
            height: calWin.revealed ? (calCol.implicitHeight + 28) : 0
            opacity: calWin.revealed ? 1.0 : 0.0

            Behavior on height {
                NumberAnimation {
                    duration: calWin.revealed ? Theme.animNormal : Theme.animClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: calWin.revealed ? Theme.curveDecel : Theme.curveAccel
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: calWin.revealed ? Theme.animFast : Theme.animClose
                    easing.type: Easing.OutCubic
                }
            }

            ConcaveCorner {
                position: "top-right"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.right: calSurface.left
                visible: calDock.height > 10
            }

            ConcaveCorner {
                position: "top-left"
                size: Theme.concaveRadius
                color: Theme.surface
                anchors.top: parent.top
                anchors.left: calSurface.right
                visible: calDock.height > 10
            }

            Item {
                id: calSurface
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
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            calWin.shiftMonth(-1);
                        else if (wheel.angleDelta.y < 0)
                            calWin.shiftMonth(1);
                    }
                }

                ColumnLayout {
                    id: calCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    y: calWin.revealed ? 12 : -10
                    spacing: 12

                    Behavior on y {
                        NumberAnimation {
                            duration: calWin.revealed ? Theme.animNormal : Theme.animClose
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calWin.revealed ? Theme.curveDecel : Theme.curveAccel
                        }
                    }

                    // Cabecera con fecha completa en español
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: calWin.fullDateHeader
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.fg
                        }

                        Text {
                            text: "Semana " + Math.ceil((Math.floor((calWin.currentDate - new Date(calWin.currentDate.getFullYear(), 0, 1)) / 86400000) + 1) / 7)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.fgSubtle
                        }
                    }

                    // Contenedor tonal del mes
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: monthInner.implicitHeight + 22
                        radius: Theme.radiusMedium
                        color: Theme.surfaceContainer

                        ColumnLayout {
                            id: monthInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 11
                            spacing: 10

                            // Navegación de mes
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: prevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "‹"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }

                                    MouseArea {
                                        id: prevM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calWin.shiftMonth(-1)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: calWin.monthNames[calWin.displayMonth] + " " + calWin.displayYear
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.fg

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calWin.resetToToday()
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: nextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "›"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }

                                    MouseArea {
                                        id: nextM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calWin.shiftMonth(1)
                                    }
                                }
                            }

                            // Grilla de días
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 7
                                columnSpacing: 4
                                rowSpacing: 4

                                Repeater {
                                    model: calWin.weekdayShort

                                    Text {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.fgSubtle
                                    }
                                }

                                Repeater {
                                    model: calWin.calendarCells

                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        color: modelData.isToday ? Theme.primary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(modelData.day)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: modelData.isToday ? Font.Bold : Font.Medium
                                            color: modelData.isToday
                                                ? Theme.fgOnPrimary
                                                : (modelData.inMonth ? Theme.fg : Theme.fgSubtle)
                                            opacity: modelData.inMonth ? 1.0 : 0.45
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Acción inferior: abrir GNOME Calendar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radiusFull
                        color: openCalM.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰃭  Abrir Calendario"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: openCalM.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                        }

                        MouseArea {
                            id: openCalM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calWin.closeRequested();
                                Quickshell.execDetached(["gnome-calendar"]);
                            }
                        }
                    }
                }
            }
        }
    }
}
