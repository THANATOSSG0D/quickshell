import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "." as Qs

// ── QsSystemGaugesRow ─────────────────────────────────────────────────────
// CPU / RAM / Disk / Temp em anéis, lado a lado — versão "gauge" do que o
// QsSystemStats já faz em barra. Mesma técnica de delta pra CPU
// (/proc/stat), + df pra disco e sensors/thermal_zone pra temperatura.
//
// Tenta `sensors` (pacote lm_sensors, comum em coretemp/k10temp) primeiro;
// se não existir, cai pro thermal_zone0 do kernel. Ajuste o grep abaixo se
// o rótulo do seu sensor de CPU for diferente ("Package id 0", "Tctl", etc.)
Item {
    id: root

    property color colorAccent:     "#ffb4a9"
    property color colorTemp:       "#a8c8ff"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"

    property bool active: false   // liga o polling só quando o dashboard está visível

    property real cpuPercent:  0
    property real ramPercent:  0
    property real diskPercent: 0
    property real tempC:       0

    property var _lastCpu: null

    function _poll() {
        if (pollProc.running) return
        pollProc.command = ["bash", "-c",
            "cat /proc/stat | head -1; echo '---';" +
            "cat /proc/meminfo | grep -E '^(MemTotal|MemAvailable):'; echo '---';" +
            "df -B1 / | tail -1; echo '---';" +
            "sensors 2>/dev/null | grep -m1 -E 'Package id 0|Tctl|Tdie|CPU' | grep -oE '[0-9]+\\.[0-9]+' | head -1 || " +
            "awk '{printf \"%.1f\", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
        pollProc.running = true
    }

    Process {
        id: pollProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => pollProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = pollProc._buf.split("---")
            pollProc._buf = ""
            if (parts.length < 4) return

            // ── CPU ──────────────────────────────────────────────────────
            var cpuLine = parts[0].trim().split(/\s+/)
            var nums = cpuLine.slice(1).map(Number)
            var idle = (nums[3] || 0) + (nums[4] || 0)
            var total = nums.reduce(function(a, b) { return a + b }, 0)
            if (root._lastCpu) {
                var dTotal = total - root._lastCpu.total
                var dIdle  = idle  - root._lastCpu.idle
                if (dTotal > 0) root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - dIdle / dTotal)))
            }
            root._lastCpu = { total: total, idle: idle }

            // ── RAM ──────────────────────────────────────────────────────
            var memLines = parts[1].trim().split("\n")
            var memTotalKb = 0, memAvailKb = 0
            for (var i = 0; i < memLines.length; i++) {
                var m = memLines[i].match(/(\d+)/)
                if (!m) continue
                if (memLines[i].startsWith("MemTotal"))     memTotalKb = parseInt(m[1])
                if (memLines[i].startsWith("MemAvailable")) memAvailKb = parseInt(m[1])
            }
            if (memTotalKb > 0)
                root.ramPercent = Math.max(0, Math.min(100, 100 * (memTotalKb - memAvailKb) / memTotalKb))

            // ── Disco (/ em bytes, via df -B1) ──────────────────────────
            var dfCols = parts[2].trim().split(/\s+/)
            var dTotalB = parseFloat(dfCols[1]), dUsedB = parseFloat(dfCols[2])
            if (dTotalB > 0)
                root.diskPercent = Math.max(0, Math.min(100, 100 * dUsedB / dTotalB))

            // ── Temperatura ──────────────────────────────────────────────
            var t = parseFloat(parts[3].trim())
            if (!isNaN(t)) root.tempC = t
        }
    }

    Timer { interval: 3000; repeat: true; running: root.active; onTriggered: root._poll() }
    onActiveChanged: if (active) root._poll()

    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        Qs.QsCircularGauge {
            Layout.fillWidth: true
            value: root.cpuPercent; valueLabel: Math.round(root.cpuPercent) + "%"; label: "CPU"
            colorAccent: root.colorAccent; colorText: root.colorText
            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
        }
        Qs.QsCircularGauge {
            Layout.fillWidth: true
            value: root.ramPercent; valueLabel: Math.round(root.ramPercent) + "%"; label: "RAM"
            colorAccent: root.colorAccent; colorText: root.colorText
            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
        }
        Qs.QsCircularGauge {
            Layout.fillWidth: true
            value: root.diskPercent; valueLabel: Math.round(root.diskPercent) + "%"; label: "Disk"
            colorAccent: root.colorAccent; colorText: root.colorText
            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
        }
        Qs.QsCircularGauge {
            Layout.fillWidth: true
            // temp em relação a uma faixa 0–100°C só pro anel; ajuste se quiser
            // outra escala (ex.: 30–90 pra usar mais o anel no dia a dia)
            value: root.tempC; valueLabel: Math.round(root.tempC) + "°"; label: "Temp"
            colorAccent: root.colorTemp; colorText: root.colorText
            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
        }
    }
}
