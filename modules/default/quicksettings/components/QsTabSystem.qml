import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Sistema ──────────────────────────────────────────────────────────────
// Usa LC_ALL=C para forçar saída em inglês (nmcli etc. são sensíveis ao locale).
// Processo único coleta tudo; parsed reativo atualiza os delegates fixos.
// Correção: transform: Rotation usa id explícito (não parent) para o ângulo.
Item {
    id: root

    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorAccent:  "#ffb4a9"

    // Indicador de carregamento — rotação sem transform (usa NumberAnimation em x)
    property real spinAngle: 0
    property bool loading:   false

    Timer {
        id: spinTimer
        interval: 80; repeat: true; running: root.loading
        onTriggered: root.spinAngle = (root.spinAngle + 20) % 360
    }

    Process {
        id: sysProc
        command: [ "bash", "-c",
            "LC_ALL=C; " +
            "echo \"OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'\"' -f2)\"; " +
            "echo \"KERNEL=$(uname -r)\"; " +
            "echo \"HOST=$(hostname)\"; " +
            "echo \"CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //;s/(R)//g;s/(TM)//g;s/  */ /g' | cut -c1-40)\"; " +
            "echo \"RAM=$(free -h 2>/dev/null | awk '/^Mem:/{printf \"%s / %s\",$3,$2}')\"; " +
            "echo \"DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf \"%s / %s (%s)\",$3,$2,$5}')\"; " +
            "echo \"IP=$(LC_ALL=C ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i==\"src\"){print $(i+1); exit}}')\"; " +
            "echo \"UPTIME=$(LC_ALL=C uptime -p 2>/dev/null | sed 's/up //')\""
        ]
        property string _buf: ""
        stdout: SplitParser { onRead: (line) => sysProc._buf += line + "\n" }
        onRunningChanged: {
            root.loading = running
            if (!running) { root._sysOutput = sysProc._buf; sysProc._buf = "" }
        }
    }

    property string _sysOutput: ""

    function refresh() {
        if (!sysProc.running) {
            sysProc.running = true
        }
    }

    Component.onCompleted: Qt.callLater(function() { sysProc.running = true })

    // Parsing: KEY=value (sep = primeiro "=")
    readonly property var parsed: {
        var out = root._sysOutput
        var map = { OS:"–", KERNEL:"–", HOST:"–", CPU:"–", RAM:"–", DISK:"–", IP:"–", UPTIME:"–" }
        if (out.trim() === "") return map
        var lines = out.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var eq = lines[i].indexOf("=")
            if (eq < 0) continue
            var k = lines[i].substring(0, eq).trim()
            var v = lines[i].substring(eq + 1).trim()
            if (k !== "" && v !== "") map[k] = v
        }
        return map
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // Cabeçalho + spinner + botão refresh
        RowLayout {
            Layout.fillWidth: true; Layout.bottomMargin: 6

            Text {
                text: "Sistema"; color: root.colorTextDim
                font.pixelSize: 9; font.capitalization: Font.AllUppercase
                Layout.fillWidth: true
            }

            // Spinner de carregamento — sem transform, usa rotação por opacidade pulsante
            Rectangle {
                visible: root.loading
                width: 10; height: 10; radius: 5
                color: root.colorAccent; opacity: pulsTimer.on ? 0.9 : 0.3
                Timer { id: pulsTimer; property bool on: true; interval: 400; repeat: true; running: root.loading; onTriggered: on = !on }
            }

            Text {
                text: "\uf021"; color: root.colorTextDim
                font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                opacity: root.loading ? 0.3 : 0.7
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.refresh() }
            }
        }

        // Linhas de informação — delegates FIXOS com binding direto em root.parsed
        // (NÃO usar Repeater com array que captura valores — não atualiza)
        SysRow { icon:"\uf17c"; lbl:"Sistema";  val: root.parsed["OS"]     || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf013"; lbl:"Kernel";   val: root.parsed["KERNEL"] || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf108"; lbl:"Host";     val: root.parsed["HOST"]   || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf2db"; lbl:"CPU";      val: root.parsed["CPU"]    || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf538"; lbl:"RAM";      val: root.parsed["RAM"]    || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf0a0"; lbl:"Disco";    val: root.parsed["DISK"]   || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf1eb"; lbl:"IP";       val: root.parsed["IP"]     || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }
        SysRow { icon:"\uf017"; lbl:"Uptime";   val: root.parsed["UPTIME"] || "–"; c1:root.colorAccent; c2:root.colorTextDim; c3:root.colorText }

        Item { Layout.fillHeight: true }
    }

    // Componente inline reutilizável — propriedades simples sem conflito de nomes
    component SysRow: RowLayout {
        property string icon: ""
        property string lbl:  ""
        property string val:  "–"
        property color  c1:   "#ffb4a9"
        property color  c2:   "#c6c6c6"
        property color  c3:   "#e2e2e2"

        Layout.fillWidth: true; spacing: 8; Layout.topMargin: 5

        Text { text: icon; color: c1; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; opacity: 0.8; Layout.preferredWidth: 14 }
        Text { text: lbl;  color: c2; font.pixelSize: 9;  Layout.preferredWidth: 40 }
        Text { text: val;  color: c3; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
    }
}
