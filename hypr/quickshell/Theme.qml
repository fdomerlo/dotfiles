pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // Polaridad activa (cambia en caliente por IPC sin reiniciar Quickshell)
    property bool isDark: true
    readonly property string modeName: isDark ? "dark" : "light"

    function setMode(mode) {
        const key = String(mode || "").trim().toLowerCase();
        isDark = !(key === "light" || key === "light-stone" || key === "stone" || key === "cyber-teal-light" || key === "mr-robot-light");
    }

    function toggleMode() {
        isDark = !isDark;
    }

    // =========================================================================
    // Sistema de diseño Material 3 — Evolución tonal Cyber-Teal
    // Nota QML: las propiedades de texto usan prefijo `fg*` (nunca `on*`) para
    // evitar colisiones con el espacio de nombres de signal handlers de Qt6.
    // =========================================================================

    // Superficie base de barra y paneles acoplados (alta solidez para uniones cóncavas limpias)
    readonly property color surface: isDark ? "#f20d1317" : "#f4e9edf1"
    readonly property color surfaceSolid: isDark ? "#0d1317" : "#e9edf1"
    readonly property color surfaceContainerLowest: isDark ? "#090e11" : "#ffffff"
    readonly property color surfaceContainerLow: isDark ? "#121a1f" : "#f6f8fa"
    readonly property color surfaceContainer: isDark ? "#182228" : "#ffffff"
    readonly property color surfaceContainerHigh: isDark ? "#212f37" : "#dfe5eb"
    readonly property color surfaceContainerHighest: isDark ? "#2b3c46" : "#cfd8e0"

    // Acento primario (Cyan-Teal en Dark · Petrol-Teal en Light)
    readonly property color primary: isDark ? "#22d3ee" : "#006c7f"
    readonly property color fgOnPrimary: isDark ? "#041b21" : "#ffffff"
    readonly property color primaryContainer: isDark ? "#0f424e" : "#c9ecf3"
    readonly property color fgOnPrimaryContainer: isDark ? "#dcf8fe" : "#00333d"

    // Acento secundario (Mint-Teal en Dark · Esmeralda en Light)
    readonly property color secondary: isDark ? "#7dd3c8" : "#0f7b5b"
    readonly property color fgOnSecondary: isDark ? "#05201d" : "#ffffff"
    readonly property color secondaryContainer: isDark ? "#18423e" : "#cdeee1"
    readonly property color fgOnSecondaryContainer: isDark ? "#dbf9f4" : "#063426"

    // Acento terciario (Azul hielo en Dark · Violeta pizarra en Light)
    readonly property color tertiary: isDark ? "#89b4fa" : "#5b4db2"
    readonly property color fgOnTertiary: isDark ? "#081930" : "#ffffff"
    readonly property color tertiaryContainer: isDark ? "#1e375c" : "#e4e0fb"
    readonly property color fgOnTertiaryContainer: isDark ? "#e3eeff" : "#241b59"

    // Estado de error / alerta / grabación
    readonly property color error: isDark ? "#f38ba8" : "#c4324f"
    readonly property color fgOnError: isDark ? "#300916" : "#ffffff"
    readonly property color errorContainer: isDark ? "#5f1d31" : "#fde0e6"
    readonly property color fgOnErrorContainer: isDark ? "#ffe4ec" : "#591021"

    // Texto y contornos (alto contraste en ambos modos)
    readonly property color fg: isDark ? "#f0f6f8" : "#171f26"
    readonly property color fgMuted: isDark ? "#c6d6dc" : "#3c4a56"
    readonly property color fgSubtle: isDark ? "#91a8b0" : "#60707e"
    readonly property color outline: isDark ? "#3f535c" : "#8c9aa7"
    readonly property color outlineVariant: isDark ? "#27363d" : "#cdd5dd"
    readonly property color scrim: isDark ? "#9905090c" : "#66121a22"
    // Oscurecimiento de fondo equivalente a decoration:dim_around (0.40) sin blur
    readonly property color dimAround: Qt.rgba(0, 0, 0, 0.40)

    // =========================================================================
    // Alias de compatibilidad semántica (todos los componentes Quickshell)
    // =========================================================================
    readonly property color backdrop: scrim
    readonly property color panelBg: surface
    readonly property color cardBg: surfaceContainer
    readonly property color cardHoverBg: surfaceContainerHigh
    readonly property color border: outlineVariant
    readonly property color activeBorder: primary
    readonly property color accent: primary
    readonly property color accentText: fgOnPrimary
    readonly property color urgent: error
    readonly property color text: fgMuted
    readonly property color textBright: fg
    readonly property color muted: fgSubtle

    // =========================================================================
    // Tipografía, geometría y movimiento Material 3 Expressive
    // =========================================================================
    readonly property string fontFamily: "Inter"
    readonly property string monoFontFamily: "JetBrains Mono"

    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 14
    readonly property int radiusLarge: 20
    readonly property int radiusFull: 999
    readonly property int concaveRadius: 16

    readonly property int radius: radiusLarge
    readonly property int cardRadius: radiusMedium
    readonly property int borderWidth: 1

    readonly property int animFast: 180
    readonly property int animTab: 260
    readonly property int animCard: 300
    readonly property int animNormal: 340
    readonly property int animPop: 380
    readonly property int animClose: 240
    readonly property int animSlow: 420

    // Curvas Material 3 para Easing.BezierSpline
    readonly property var curveDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var curveAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var curveExpressive: [0.16, 1.0, 0.24, 1.0, 1.0, 1.0]
}
