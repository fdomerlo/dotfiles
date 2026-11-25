pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // Polaridad activa (cambia en caliente por IPC sin reiniciar Quickshell)
    property bool isDark: true
    readonly property string modeName: isDark ? "dark" : "light"

    function setMode(mode) {
        isDark = (String(mode || "").trim().toLowerCase() !== "light");
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
    readonly property color surface: isDark ? "#f20d1317" : "#f2f2f7f8"
    readonly property color surfaceSolid: isDark ? "#0d1317" : "#f2f7f8"
    readonly property color surfaceContainerLowest: isDark ? "#090e11" : "#ffffff"
    readonly property color surfaceContainerLow: isDark ? "#121a1f" : "#eaf1f3"
    readonly property color surfaceContainer: isDark ? "#182228" : "#e1ebee"
    readonly property color surfaceContainerHigh: isDark ? "#212f37" : "#d5e3e7"
    readonly property color surfaceContainerHighest: isDark ? "#2b3c46" : "#c7d9df"

    // Acento primario (Cyan-Teal en Dark · Petrol-Teal en Light)
    readonly property color primary: isDark ? "#22d3ee" : "#006d80"
    readonly property color fgOnPrimary: isDark ? "#041b21" : "#ffffff"
    readonly property color primaryContainer: isDark ? "#0f424e" : "#c3edf6"
    readonly property color fgOnPrimaryContainer: isDark ? "#dcf8fe" : "#002b34"

    // Acento secundario (Mint-Teal sobrio para estados activos/positivos)
    readonly property color secondary: isDark ? "#7dd3c8" : "#0f766e"
    readonly property color fgOnSecondary: isDark ? "#05201d" : "#ffffff"
    readonly property color secondaryContainer: isDark ? "#18423e" : "#cceee8"
    readonly property color fgOnSecondaryContainer: isDark ? "#dbf9f4" : "#052e2b"

    // Acento terciario (Azul hielo para IA / destacados secundarios)
    readonly property color tertiary: isDark ? "#89b4fa" : "#2563a8"
    readonly property color fgOnTertiary: isDark ? "#081930" : "#ffffff"
    readonly property color tertiaryContainer: isDark ? "#1e375c" : "#d6e6fb"
    readonly property color fgOnTertiaryContainer: isDark ? "#e3eeff" : "#0d2847"

    // Estado de error / alerta / grabación
    readonly property color error: isDark ? "#f38ba8" : "#c83755"
    readonly property color fgOnError: isDark ? "#300916" : "#ffffff"
    readonly property color errorContainer: isDark ? "#5f1d31" : "#ffd9e0"
    readonly property color fgOnErrorContainer: isDark ? "#ffe4ec" : "#4a0c1b"

    // Texto y contornos (alto contraste en ambos modos)
    readonly property color fg: isDark ? "#f0f6f8" : "#0f1c22"
    readonly property color fgMuted: isDark ? "#c6d6dc" : "#2a3f47"
    readonly property color fgSubtle: isDark ? "#91a8b0" : "#556b73"
    readonly property color outline: isDark ? "#3f535c" : "#8ba2aa"
    readonly property color outlineVariant: isDark ? "#27363d" : "#c5d5da"
    readonly property color scrim: isDark ? "#9905090c" : "#66101c22"

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
    // Tipografía, geometría y movimiento Material 3 (suave y expresivo)
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
    readonly property int animNormal: 340
    readonly property int animClose: 240
    readonly property int animSlow: 420

    // Curvas Material 3 para Easing.BezierSpline
    readonly property var curveDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var curveAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
}
