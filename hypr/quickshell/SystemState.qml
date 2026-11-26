import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: sys

    // Telemetría compartida entre todos los monitores (una sola sonda global).
    property int cpuUsage: 0
    property real memUsedGiB: 0.0
    property real memTotalGiB: 0.0
    property real swapUsedGiB: 0.0
    property real swapTotalGiB: 0.0
    property int cpuTempC: -1
    property string loadAvg: "0.00"
    property string uptimeText: "0m"

    property string diskUsed: "0G"
    property string diskTotal: "0G"
    property int diskPercent: 0

    property var cpuHistory: []
    property var memHistory: []

    property bool hasBacklight: false
    property int brightnessPercent: 0

    // Red: "wifi", "ethernet", "disconnected"
    property bool netReady: false
    property string netKind: "disconnected"
    property string netLabel: ""
    property string vpnName: ""

    property bool aiActive: false
    property string aiDetail: ""
    property bool nightlightActive: false
    property bool recordingActive: false

    property string hostName: ""
    property string osLabel: "Debian GNU/Linux"
    property string kernelVersion: ""
    property string cpuModel: ""
    readonly property string userName: Quickshell.env("USER") || "usuario"

    // Overrides locales opcionales (~/.config/quickshell/local.json)
    property int barHeight: 40
    property bool showTelemetry: true
    property bool showMedia: true
    property string barStyle: "bar" // "bar" | "islands" | "auto"

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

    Process {
        id: hostProbe
        command: [
            "sh", "-c",
            "h=$(hostname -s 2>/dev/null || true); " +
            "os=$(awk -F= '/^PRETTY_NAME=/{gsub(/\"/,\"\",$2); print $2; exit}' /etc/os-release 2>/dev/null || true); " +
            "kr=$(uname -r 2>/dev/null | cut -d- -f1 || true); " +
            "cpu=$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed -E 's/\\((R|TM)\\)//g; s/[[:space:]]+/ /g; s/ CPU @.*//' || true); " +
            "printf 'HOST|%s\\nOS|%s\\nKERNEL|%s\\nCPUMODEL|%s\\n' \"$h\" \"$os\" \"$kr\" \"$cpu\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("|");
                    if (p[0] === "HOST" && p.length >= 2)
                        sys.hostName = p[1] || "";
                    else if (p[0] === "OS" && p.length >= 2 && p[1])
                        sys.osLabel = p[1];
                    else if (p[0] === "KERNEL" && p.length >= 2)
                        sys.kernelVersion = p[1] || "";
                    else if (p[0] === "CPUMODEL" && p.length >= 2)
                        sys.cpuModel = p[1] || "";
                }
            }
        }
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
            if (cfg.barStyle === "bar" || cfg.barStyle === "islands" || cfg.barStyle === "auto")
                sys.barStyle = cfg.barStyle;
        } catch (e) {
            // Ignorar JSON inválido en override local
        }
    }

    function setBarStyle(mode) {
        const key = String(mode || "").trim().toLowerCase();
        const norm = (key === "islands" || key === "auto") ? key : "bar";
        sys.barStyle = norm;
        Quickshell.execDetached([
            "python3", "-c",
            "import json, os, sys; p, m = sys.argv[1], sys.argv[2]; os.makedirs(os.path.dirname(p), exist_ok=True)\ntry:\n with open(p, encoding='utf-8') as f: d = json.load(f)\n if not isinstance(d, dict): d = {}\nexcept Exception: d = {}\nd['barStyle'] = m\ntmp = p + '.tmp'\nwith open(tmp, 'w', encoding='utf-8') as f: json.dump(d, f, indent=2); f.write('\\n')\nos.replace(tmp, p)\n",
            sys.localConfigPath,
            norm
        ]);
    }

    function pushHistory(arr, value) {
        const next = (arr || []).slice(-23);
        next.push(Math.max(0, Math.min(100, Math.round(value))));
        return next;
    }

    function formatUptime(sec) {
        const s = Math.max(0, Math.floor(sec));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return Math.max(1, m) + "m";
    }

    // Sonda rápida (cada 2 s): /proc/stat + /proc/meminfo + uptime + load + temp + flags + backlight
    Process {
        id: fastProbe
        command: [
            "sh", "-c",
            "awk 'NR==1 {idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; printf \"CPU|%d|%d\\n\", total, idle}' /proc/stat; " +
            "awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2} END {printf \"MEM|%d|%d|%d|%d\\n\", t, (t-a), st, (st-sf)}' /proc/meminfo; " +
            "awk '{printf \"UP|%d\\n\", $1}' /proc/uptime; " +
            "awk '{printf \"LOAD|%s\\n\", $1}' /proc/loadavg; " +
            "temp=-1; for h in /sys/class/hwmon/hwmon*; do " +
            "  n=$(cat \"$h/name\" 2>/dev/null || true); " +
            "  case \"$n\" in k10temp|coretemp|zenpower|cpu_thermal) " +
            "    if [ -r \"$h/temp1_input\" ]; then v=$(cat \"$h/temp1_input\" 2>/dev/null || echo 0); [ \"$v\" -gt 0 ] 2>/dev/null && temp=$((v/1000)) && break; fi ;; " +
            "  esac; " +
            "done; " +
            "if [ \"$temp\" -lt 0 ]; then " +
            "  for z in /sys/class/thermal/thermal_zone*; do " +
            "    t=$(cat \"$z/type\" 2>/dev/null || true); " +
            "    case \"$t\" in x86_pkg_temp|cpu*|acpitz) " +
            "      v=$(cat \"$z/temp\" 2>/dev/null || echo 0); [ \"$v\" -gt 0 ] 2>/dev/null && temp=$((v/1000)) && break ;; " +
            "    esac; " +
            "  done; " +
            "fi; " +
            "nl=0; [ -f \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-nightlight.state\" ] && pgrep -x hyprsunset >/dev/null 2>&1 && nl=1; " +
            "rec=0; pgrep -x wf-recorder >/dev/null 2>&1 && rec=1; " +
            "br=''; if command -v brightnessctl >/dev/null 2>&1; then br=$(brightnessctl -c backlight -m 2>/dev/null | head -n1 | awk -F',' '{gsub(/%/,\"\",$4); print $4}'); fi; " +
            "printf 'FLAGS|%s|%s|%s|%s\\n' \"$nl\" \"$rec\" \"$br\" \"$temp\""
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
                        sys.cpuHistory = sys.pushHistory(sys.cpuHistory, sys.cpuUsage);
                    } else if (p[0] === "MEM" && p.length >= 5) {
                        const totalKb = Number(p[1]) || 0;
                        const usedKb = Number(p[2]) || 0;
                        const swapTotalKb = Number(p[3]) || 0;
                        const swapUsedKb = Number(p[4]) || 0;
                        sys.memTotalGiB = totalKb / (1024 * 1024);
                        sys.memUsedGiB = usedKb / (1024 * 1024);
                        sys.swapTotalGiB = swapTotalKb / (1024 * 1024);
                        sys.swapUsedGiB = Math.max(0, swapUsedKb / (1024 * 1024));
                        const memPct = totalKb > 0 ? (usedKb * 100 / totalKb) : 0;
                        sys.memHistory = sys.pushHistory(sys.memHistory, memPct);
                    } else if (p[0] === "UP" && p.length >= 2) {
                        sys.uptimeText = sys.formatUptime(Number(p[1]) || 0);
                    } else if (p[0] === "LOAD" && p.length >= 2) {
                        sys.loadAvg = p[1] || "0.00";
                    } else if (p[0] === "FLAGS" && p.length >= 5) {
                        sys.nightlightActive = (p[1] === "1");
                        sys.recordingActive = (p[2] === "1");
                        const br = parseInt(p[3], 10);
                        if (!isNaN(br)) {
                            sys.hasBacklight = true;
                            sys.brightnessPercent = Math.max(0, Math.min(100, br));
                        } else {
                            sys.hasBacklight = false;
                        }
                        const tp = parseInt(p[4], 10);
                        sys.cpuTempC = isNaN(tp) ? -1 : tp;
                    }
                }
            }
        }
    }

    // Sonda lenta (cada 4 s o bajo demanda vía IPC): Red (nmcli), VPN, Disco y Servicio IA (OpenCode)
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
            "dfline=$(df -h -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,\"\",$5); printf \"%s|%s|%s\", $5, $3, $2}'); " +
            "ai=0; aidet=''; " +
            "pid=$(pgrep -u \"$USER\" -f '(^|/)opencode[[:space:]]+serve[[:space:]]+--service([[:space:]]|$)' 2>/dev/null | head -n1 || true); " +
            "if [ -n \"$pid\" ]; then " +
            "  ai=1; " +
            "  rss=$(ps -o rss= -p \"$pid\" 2>/dev/null | tr -d ' ' || true); " +
            "  [ -n \"$rss\" ] && aidet=\"$(((rss + 512) / 1024)) MiB\"; " +
            "fi; " +
            "printf 'NET|%s|%s|%s\\nDISK|%s\\nAI|%s|%s\\n' \"$kind\" \"$label\" \"$vpn\" \"$dfline\" \"$ai\" \"$aidet\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("|");
                    if (p[0] === "NET" && p.length >= 4) {
                        sys.netReady = true;
                        sys.netKind = p[1] || "disconnected";
                        sys.netLabel = p[2] || "";
                        sys.vpnName = p[3] || "";
                    } else if (p[0] === "DISK" && p.length >= 4) {
                        sys.diskPercent = parseInt(p[1], 10) || 0;
                        sys.diskUsed = p[2] || "0G";
                        sys.diskTotal = p[3] || "0G";
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
