import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calWin

    required property bool calendarOpen
    required property date currentDate

    signal closeRequested()

    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth() // 0..11

    readonly property var monthNames: [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    readonly property var weekdayShort: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]

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

    Component.onCompleted: {
        resetToToday();
        calScope.forceActiveFocus();
    }

    onCalendarOpenChanged: {
        if (calendarOpen) {
            resetToToday();
            calScope.forceActiveFocus();
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
    visible: calendarOpen

    FocusScope {
        id: calScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: calWin.closeRequested()

        MouseArea {
            anchors.fill: parent
            onClicked: calWin.closeRequested()
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 50
            anchors.rightMargin: 12
            width: 300
            height: calCol.implicitHeight + 28
            radius: Theme.radius
            color: Theme.panelBg
            border.width: Theme.borderWidth
            border.color: Theme.border

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
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10

                // Navegación de mes
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 26
                        height: 26
                        radius: Theme.cardRadius > 0 ? 6 : 0
                        color: prevM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.textBright
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
                        font.weight: Font.Bold
                        color: Theme.textBright

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calWin.resetToToday()
                        }
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: Theme.cardRadius > 0 ? 6 : 0
                        color: nextM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.textBright
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

                // Cabecera días de semana
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
                            color: Theme.muted
                        }
                    }

                    Repeater {
                        model: calWin.calendarCells

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: Theme.cardRadius > 0 ? 7 : 0
                            color: modelData.isToday ? Theme.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData.day)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                color: modelData.isToday
                                    ? Theme.accentText
                                    : (modelData.inMonth ? Theme.textBright : Theme.muted)
                                opacity: modelData.inMonth ? 1.0 : 0.45
                            }
                        }
                    }
                }

                // Acción inferior: abrir GNOME Calendar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.cardRadius > 0 ? 7 : 0
                    color: openCalM.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                    border.width: 1
                    border.color: openCalM.containsMouse ? Theme.activeBorder : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "󰃭  Abrir Calendario"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.textBright
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
