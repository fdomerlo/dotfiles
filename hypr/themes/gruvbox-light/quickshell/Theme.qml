pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color backdrop: "#99101010"
    readonly property color panelBg: "#d1f5f5f5"
    readonly property color cardBg: "#e0fafafa"
    readonly property color cardHoverBg: "#f2e8e8e8"
    readonly property color border: "#d9d9d9"
    readonly property color activeBorder: "#4f5d6b"
    readonly property color accent: "#4f5d6b"
    readonly property color accentText: "#f5f5f5"
    readonly property color urgent: "#cc241d"
    readonly property color text: "#2f2f2f"
    readonly property color textBright: "#111111"
    readonly property color muted: "#7a7a7a"
    readonly property string fontFamily: "Inter"
    readonly property int radius: 14
    readonly property int cardRadius: 10
    readonly property int borderWidth: 1
}
