import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: sys

    // Telemetría compartida entre todos los monitores (una sola sonda global).
    property int cpuUsage: 0
    property real memUsedGiB: 0.0
    property real memTotalGiB: 0.0

    property bool hasBacklight: false
    property int brightnessPercent: 0

    // Red: "wifi", "ethernet", "disconnected"
    property string netKind: "disconnected"
    property string netLabel: ""
    property string vpnName: ""

    property bool aiActive: false
    property string aiDetail: ""
    property bool nightlightActive: false
    property bool recordingActive: false

    // Overrides locales opcionales (~/.config/quickshell/local.json)
    property int barHeight: 40
    property bool showTelemetry: true
    property bool showMedia: true

    property real _prevCpuTotal: 0
    property real _prevCpuIdle: 0

    readonly property string localConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/local.json"

    FileView {
        id: localConfigFile
        path: sys.localConfigPath
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: sys.parseLocalConfig()
        onFileChanged: reload()
    }

    function parseLocalConfig() {
        const raw = String(localConfigFile.text() || "").trim();
        if (!raw)
            return;
        try {
            const cfg = JSON.parse(raw);
            if (typeof cfg.barHeight === "number" && cfg.barHeight >= 28 && cfg.barHeight <= 56)
                sys.barHeight = Math.round(cfg.barHeight);
            if (typeof cfg.showTelemetry === "boolean")
                sys.showTelemetry = cfg.showTelemetry;
            if (typeof cfg.showMedia === "boolean")
                sys.showMedia = cfg.showMedia;
        } catch (e) {
            // Ignorar JSON inválido en override local
        }
    }

    // Sonda rápida (cada 2 s): /proc/stat + /proc/meminfo + nightlight + wf-recorder + backlight
    Process {
        id: fastProbe
        command: [
            "sh", "-c",
            "awk 'NR==1 {idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; printf \"CPU|%d|%d\\n\", total, idle}' /proc/stat; " +
            "awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf \"MEM|%d|%d\\n\", t, (t-a)}' /proc/meminfo; " +
            "nl=0; [ -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-nightlight.state\" ] && pgrep -x hyprsunset >/dev/null 2>&1 && nl=1; " +
            "rec=0; pgrep -x wf-recorder >/dev/null 2>&1 && rec=1; " +
            "br=''; if command -v brightnessctl >/dev/null 2>&1; then br=$(brightnessctl -m 2>/dev/null | head -n1 | awk -F',' '{gsub(/%/,\"\",$4); print $4}'); fi; " +
            "printf 'FLAGS|%s|%s|%s\\n' \"$nl\" \"$rec\" \"$br\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("|");
                    if (p[0] === "CPU" && p.length >= 3) {
                        const total = Number(p[1]) || 0;
                        const idle = Number(p[2]) || 0;
                        if (sys._prevCpuTotal > 0 && total > sys._prevCpuTotal) {
                            const dt = total - sys._prevCpuTotal;
                            const di = idle - sys._prevCpuIdle;
                            sys.cpuUsage = Math.max(0, Math.min(100, Math.round(((dt - di) / dt) * 100)));
                        }
                        sys._prevCpuTotal = total;
                        sys._prevCpuIdle = idle;
                    } else if (p[0] === "MEM" && p.length >= 3) {
                        const totalKb = Number(p[1]) || 0;
                        const usedKb = Number(p[2]) || 0;
                        sys.memTotalGiB = totalKb / (1024 * 1024);
                        sys.memUsedGiB = usedKb / (1024 * 1024);
                    } else if (p[0] === "FLAGS" && p.length >= 4) {
                        sys.nightlightActive = (p[1] === "1");
                        sys.recordingActive = (p[2] === "1");
                        const br = parseInt(p[3], 10);
                        if (!isNaN(br)) {
                            sys.hasBacklight = true;
                            sys.brightnessPercent = Math.max(0, Math.min(100, br));
                        } else {
                            sys.hasBacklight = false;
                        }
                    }
                }
            }
        }
    }

    // Sonda lenta (cada 4 s o bajo demanda vía IPC): Red (nmcli), VPN y Servicio IA (OpenCode)
    Process {
        id: slowProbe
        command: [
            "sh", "-c",
            "kind='disconnected'; label=''; vpn=''; " +
            "if command -v nmcli >/dev/null 2>&1; then " +
            "  while IFS=: read -r name type dev; do " +
            "    [ -n \"$type\" ] || continue; " +
            "    case \"$type\" in " +
            "      vpn|wireguard) [ -z \"$vpn\" ] && vpn=\"$name\" ;; " +
            "      802-3-ethernet) kind='ethernet'; label=\"${dev:-$name}\" ;; " +
            "      802-11-wireless) if [ \"$kind\" != 'ethernet' ]; then kind='wifi'; label=\"$name\"; fi ;; " +
            "    esac; " +
            "  done <<EOF\n$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null || true)\nEOF\n" +
            "fi; " +
            "ai=0; aidet=''; " +
            "pid=$(pgrep -u \"$USER\" -f '(^|/)opencode[[:space:]]+serve[[:space:]]+--service([[:space:]]|$)' 2>/dev/null | head -n1 || true); " +
            "if [ -n \"$pid\" ]; then " +
            "  ai=1; " +
            "  rss=$(ps -o rss= -p \"$pid\" 2>/dev/null | tr -d ' ' || true); " +
            "  [ -n \"$rss\" ] && aidet=\"$(((rss + 512) / 1024)) MiB\"; " +
            "fi; " +
            "printf 'NET|%s|%s|%s\\nAI|%s|%s\\n' \"$kind\" \"$label\" \"$vpn\" \"$ai\" \"$aidet\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("|");
                    if (p[0] === "NET" && p.length >= 4) {
                        sys.netKind = p[1] || "disconnected";
                        sys.netLabel = p[2] || "";
                        sys.vpnName = p[3] || "";
                    } else if (p[0] === "AI" && p.length >= 3) {
                        sys.aiActive = (p[1] === "1");
                        sys.aiDetail = p[2] || "";
                    }
                }
            }
        }
    }

    Timer {
        id: fastTimer
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!fastProbe.running)
                fastProbe.running = true;
        }
    }

    Timer {
        id: slowTimer
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!slowProbe.running)
                slowProbe.running = true;
        }
    }

    function refreshAll() {
        if (!fastProbe.running)
            fastProbe.running = true;
        if (!slowProbe.running)
            slowProbe.running = true;
    }

    function refreshSlow() {
        if (!slowProbe.running)
            slowProbe.running = true;
    }
}
