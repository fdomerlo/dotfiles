pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color backdrop: "#99202a2f"
    readonly property color panelBg: "#fefbf8f0"
    readonly property color cardBg: "#fffffdf7"
    readonly property color cardHoverBg: "#ffefe8d8"
    readonly property color border: "#d8d2c4"
    readonly property color activeBorder: "#0f6b7a"
    readonly property color accent: "#0f6b7a"
    readonly property color accentText: "#fbf8f0"
    readonly property color urgent: "#b3403a"
    readonly property color text: "#1e2a30"
    readonly property color textBright: "#0b1f26"
    readonly property color muted: "#5a6a72"
    readonly property string fontFamily: "JetBrains Mono"
    readonly property int radius: 4
    readonly property int cardRadius: 3
    readonly property int borderWidth: 1
}
