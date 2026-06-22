import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsSystemStats ─────────────────────────────────────────────────────────────
// CPU e RAM em texto simples (sem anéis/gráficos, por decisão explícita).
// Lê /proc/stat (delta entre duas leituras) para % de CPU e /proc/meminfo
// para RAM. Atualiza a cada 3s enquanto a aba estiver visível.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorProgressBg: "#474747"

    property bool   active:      false   // pai liga/desliga o polling (ex.: só quando a aba está visível)
    property real   cpuPercent:  0
    property real   ramPercent:  0
    property string ramUsedLabel: ""
    property string ramTotalLabel: ""

    property var _lastCpu: null   // {total, idle} da leitura anterior, para delta

    function _poll() {
        if (pollProc.running) return
        pollProc.command = ["bash", "-c",
            "cat /proc/stat | head -1; echo '---'; cat /proc/meminfo | grep -E '^(MemTotal|MemAvailable):'"]
        pollProc.running = true
    }

    Process {
        id: pollProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => pollProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = pollProc._buf.split("---"); pollProc._buf = ""
            if (parts.length < 2) return

            // ── CPU: linha "cpu  user nice system idle iowait irq softirq ..." ──
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

            // ── RAM ──────────────────────────────────────────────────────────
            var memLines = parts[1].trim().split("\n")
            var memTotalKb = 0, memAvailKb = 0
            for (var i = 0; i < memLines.length; i++) {
                var m = memLines[i].match(/(\d+)/)
                if (!m) continue
                if (memLines[i].startsWith("MemTotal"))     memTotalKb = parseInt(m[1])
                if (memLines[i].startsWith("MemAvailable")) memAvailKb = parseInt(m[1])
            }
            if (memTotalKb > 0) {
                var usedKb = memTotalKb - memAvailKb
                root.ramPercent     = Math.max(0, Math.min(100, 100 * usedKb / memTotalKb))
                root.ramUsedLabel   = (usedKb  / 1024 / 1024).toFixed(1) + "G"
                root.ramTotalLabel  = (memTotalKb / 1024 / 1024).toFixed(1) + "G"
            }
        }
    }

    Timer {
        interval: 3000; repeat: true; running: root.active
        onTriggered: root._poll()
    }
    onActiveChanged: if (active) root._poll()

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        // ── CPU ────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "\uf2db"; color: root.colorAccent
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                Text { text: "CPU"; color: root.colorText; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: Math.round(root.cpuPercent) + "%"; color: root.colorTextDim; font.pixelSize: 10 }
            }
            Item {
                Layout.fillWidth: true; height: 5
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 2.5
                    color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 5; radius: 2.5
                    width: parent.width * root.cpuPercent / 100; color: root.colorAccent
                    Behavior on width { NumberAnimation { duration: 300 } } }
            }
        }

        // ── RAM ────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "\uf538"; color: root.colorAccent
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                Text { text: "RAM"; color: root.colorText; font.pixelSize: 10; Layout.fillWidth: true }
                Text {
                    text: (root.ramUsedLabel !== "" ? (root.ramUsedLabel + " / " + root.ramTotalLabel) : "—")
                    color: root.colorTextDim; font.pixelSize: 10
                }
            }
            Item {
                Layout.fillWidth: true; height: 5
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 2.5
                    color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 5; radius: 2.5
                    width: parent.width * root.ramPercent / 100; color: root.colorAccent
                    Behavior on width { NumberAnimation { duration: 300 } } }
            }
        }
    }
}
