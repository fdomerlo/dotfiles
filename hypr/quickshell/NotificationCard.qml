import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property var entry
    property real nowMs: Date.now()
    property bool compact: false

    signal dismissRequested(int uid)
    signal popupCloseRequested(int uid)
    signal actionInvoked(int uid, var action)
    signal replySent(int uid, string text)
    signal hoverStateChanged(bool hovered)

    readonly property var notif: entry ? entry.notif : null
    readonly property int uid: entry ? entry.uid : -1
    readonly property int urgency: notif ? notif.urgency : NotificationUrgency.Normal
    readonly property bool isCritical: urgency === NotificationUrgency.Critical
    readonly property bool isLow: urgency === NotificationUrgency.Low

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
    radius: Theme.cardRadius
    color: cardMouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg
    border.width: Theme.borderWidth
    border.color: isCritical ? Theme.urgent : (cardMouse.containsMouse ? Theme.activeBorder : Theme.border)
    clip: true

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    // Indicador lateral de urgencia
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: card.isCritical ? Theme.urgent : (card.isLow ? Theme.muted : Theme.accent)
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: card.hoverStateChanged(containsMouse)
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
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        anchors.topMargin: 11
        spacing: 8

        // Fila superior: icono + nombre de app + tiempo + cerrar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icono de la app o imagen en miniatura
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: Theme.cardRadius > 0 ? Math.min(Theme.cardRadius, 8) : 0
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.border
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
                    color: card.isCritical ? Theme.urgent : Theme.accent
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
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: card.isCritical ? Theme.urgent : Theme.muted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: card.relativeTime.length > 0
                        text: card.relativeTime
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.muted
                    }

                    // Botón cerrar
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: Theme.cardRadius > 0 ? 6 : 0
                        color: closeMouse.containsMouse ? Theme.urgent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: closeMouse.containsMouse ? Theme.accentText : Theme.muted
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
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.textBright
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
                    font.pixelSize: 12
                    color: Theme.text
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
            radius: Theme.cardRadius > 0 ? Math.max(4, Theme.cardRadius - 2) : 0
            color: Theme.panelBg
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
                    height: 26
                    width: Math.min(card.width - 32, actLabel.implicitWidth + 20)
                    radius: Theme.cardRadius > 0 ? 6 : 0
                    color: actMouse.containsMouse ? Theme.accent : Theme.panelBg
                    border.width: 1
                    border.color: actMouse.containsMouse ? Theme.accent : Theme.border

                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        text: String(modelData.text || "")
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: actMouse.containsMouse ? Theme.accentText : Theme.textBright
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
                Layout.preferredHeight: 30
                radius: Theme.cardRadius > 0 ? 6 : 0
                color: Theme.panelBg
                border.width: 1
                border.color: replyInput.activeFocus ? Theme.activeBorder : Theme.border

                TextInput {
                    id: replyInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textBright
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
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
                        font.pixelSize: 12
                        color: Theme.muted
                        visible: replyInput.text.length === 0
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Theme.cardRadius > 0 ? 6 : 0
                color: sendMouse.containsMouse ? Theme.accent : Theme.panelBg
                border.width: 1
                border.color: sendMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "󰒊"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: sendMouse.containsMouse ? Theme.accentText : Theme.accent
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
