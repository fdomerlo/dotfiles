import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property var entry
    property real nowMs: Date.now()
    property bool compact: false
    property bool keyboardSelected: false

    signal dismissRequested(int uid)
    signal popupCloseRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal replySent(int uid, string text)

    property bool entered: compact

    readonly property var notif: entry ? entry.notif : null
    readonly property int uid: entry ? entry.uid : -1
    readonly property int urgency: notif ? notif.urgency : NotificationUrgency.Normal
    readonly property bool isCritical: urgency === NotificationUrgency.Critical
    readonly property bool isLow: urgency === NotificationUrgency.Low

    Component.onCompleted: {
        if (!compact)
            enterTimer.restart();
    }

    Timer {
        id: enterTimer
        interval: 16
        repeat: false
        onTriggered: card.entered = true
    }

    readonly property string appNameText: {
        if (!notif)
            return "";
        return String(notif.appName || notif.desktopEntry || "Sistema");
    }

    readonly property string summaryText: notif ? String(notif.summary || "") : ""
    readonly property string bodyText: notif ? String(notif.body || "").trim() : ""

    readonly property string resolvedIcon: {
        if (!notif)
            return "";
        const icon = String(notif.appIcon || "");
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("image://"))
            return icon.startsWith("/") ? ("file://" + icon) : icon;
        return Quickshell.iconPath(icon, true);
    }

    readonly property string resolvedImage: {
        if (!notif)
            return "";
        const img = String(notif.image || "");
        if (!img)
            return "";
        if (img.startsWith("file://") || img.startsWith("image://"))
            return img;
        if (img.startsWith("/"))
            return "file://" + img;
        return Quickshell.iconPath(img, true);
    }

    readonly property string relativeTime: {
        void(nowMs);
        if (!entry || !entry.timestamp)
            return "";
        const diffSec = Math.max(0, Math.floor((nowMs - entry.timestamp) / 1000));
        if (diffSec < 45)
            return "ahora";
        const mins = Math.floor(diffSec / 60);
        if (mins < 60)
            return "hace " + mins + " min";
        const hrs = Math.floor(mins / 60);
        if (hrs < 24)
            return "hace " + hrs + " h";
        const days = Math.floor(hrs / 24);
        return "hace " + days + " d";
    }

    readonly property var visibleActions: {
        if (!notif || !notif.actions)
            return [];
        const list = [];
        for (let i = 0; i < notif.actions.length; i++) {
            const act = notif.actions[i];
            if (!act || act.identifier === "default")
                continue;
            if (String(act.text || "").trim().length === 0)
                continue;
            list.push(act);
        }
        return list;
    }

    readonly property var defaultAction: {
        if (!notif || !notif.actions)
            return null;
        for (let i = 0; i < notif.actions.length; i++) {
            if (notif.actions[i] && notif.actions[i].identifier === "default")
                return notif.actions[i];
        }
        return null;
    }

    implicitHeight: contentCol.implicitHeight + 22
    radius: Theme.radiusMedium
    color: (cardMouse.containsMouse || keyboardSelected) ? Theme.surfaceContainerHigh : Theme.surfaceContainer
    border.width: keyboardSelected ? 1 : 0
    border.color: isCritical ? Theme.error : Theme.primary
    clip: true

    opacity: compact ? 1.0 : (entered ? 1.0 : 0.0)
    scale: compact ? 1.0 : (entered ? (cardMouse.containsMouse ? 1.006 : 1.0) : 0.96)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    Behavior on opacity {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animCard
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveExpressive
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (card.compact)
                    card.popupCloseRequested(card.uid);
                else
                    card.dismissRequested(card.uid);
                return;
            }
            if (card.defaultAction) {
                card.actionInvoked(card.uid, card.defaultAction);
            } else if (card.compact) {
                card.popupCloseRequested(card.uid);
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        anchors.topMargin: 11
        spacing: 8

        // Fila superior: icono + nombre de app + tiempo + cerrar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icono de la app o badge tonal
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusSmall
                color: card.isCritical ? Theme.errorContainer : Theme.surfaceContainerHigh
                clip: true

                Image {
                    id: iconImg
                    anchors.fill: parent
                    anchors.margins: 4
                    source: card.resolvedIcon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: iconImg.status !== Image.Ready
                    text: card.isCritical ? "󰀪" : "󰂚"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: card.isCritical ? Theme.fgOnErrorContainer : Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: card.appNameText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: card.isCritical ? Theme.error : Theme.fgSubtle
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: card.relativeTime.length > 0
                        text: card.relativeTime
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.fgSubtle
                    }

                    // Botón cerrar
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: closeMouse.containsMouse ? Theme.errorContainer : Qt.alpha(Theme.errorContainer, 0.0)

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: closeMouse.containsMouse ? Theme.fgOnErrorContainer : Theme.fgSubtle
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                mouse.accepted = true;
                                card.dismissRequested(card.uid);
                            }
                        }
                    }
                }

                Text {
                    visible: card.summaryText.length > 0
                    Layout.fillWidth: true
                    text: card.summaryText
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.fg
                    wrapMode: Text.Wrap
                    maximumLineCount: card.compact ? 2 : 3
                    elide: Text.ElideRight
                }

                Text {
                    visible: card.bodyText.length > 0
                    Layout.fillWidth: true
                    text: card.bodyText
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.fgMuted
                    wrapMode: Text.Wrap
                    maximumLineCount: card.compact ? 4 : 8
                    elide: Text.ElideRight
                }
            }
        }

        // Imagen adjunta (si la notificación incluye preview)
        Rectangle {
            visible: bodyImg.status === Image.Ready
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(132, Math.max(64, bodyImg.implicitHeight)) : 0
            radius: Theme.radiusSmall
            color: Theme.surfaceContainerLow
            clip: true

            Image {
                id: bodyImg
                anchors.fill: parent
                source: card.resolvedImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        // Botones de acción
        Flow {
            visible: card.visibleActions.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: card.visibleActions

                Rectangle {
                    required property var modelData
                    height: 28
                    width: Math.min(card.width - 32, actLabel.implicitWidth + 20)
                    radius: Theme.radiusFull
                    color: actMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        text: String(modelData.text || "")
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: actMouse.containsMouse ? Theme.fgOnPrimaryContainer : Theme.fg
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width - 12)
                    }

                    MouseArea {
                        id: actMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            mouse.accepted = true;
                            card.actionInvoked(card.uid, modelData);
                        }
                    }
                }
            }
        }

        // Respuesta inline (solo en el centro de notificaciones, donde hay foco de teclado)
        RowLayout {
            visible: !card.compact && Boolean(card.notif && card.notif.hasInlineReply)
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.radiusSmall
                color: Theme.surfaceContainerLow
                border.width: replyInput.activeFocus ? 1 : 0
                border.color: Theme.primary

                TextInput {
                    id: replyInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.fgOnPrimary
                    clip: true

                    onAccepted: {
                        const msg = text.trim();
                        if (msg.length > 0) {
                            card.replySent(card.uid, msg);
                            text = "";
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: (card.notif && card.notif.inlineReplyPlaceholder)
                            ? card.notif.inlineReplyPlaceholder
                            : "Responder..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.fgSubtle
                        visible: replyInput.text.length === 0
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: sendMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒊"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: sendMouse.containsMouse ? Theme.fgOnPrimary : Theme.primary
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        const msg = replyInput.text.trim();
                        if (msg.length > 0) {
                            card.replySent(card.uid, msg);
                            replyInput.text = "";
                        }
                    }
                }
            }
        }
    }

}
