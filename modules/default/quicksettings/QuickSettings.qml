import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// ── QuickSettings (trigger da barra) ─────────────────────────────────────────
Item {
    id: root

    property bool isHorizontal: true
    property int  barPosition:  1
    property color textColor:   "#e2e2e2"
    property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
    property color accentColor: "#ffb4a9"
    // Multiplicador global de escala (barState.config.moduleScale) — não
    // havia prop de tamanho aqui antes, só o valor fixo 13px do ícone.
    property real fontScale:    1.0

    signal panelRequested()

    implicitWidth:  isHorizontal ? row.implicitWidth  + Math.round(10 * root.fontScale) : Math.round(28 * root.fontScale)
    implicitHeight: isHorizontal ? row.implicitHeight + Math.round(4  * root.fontScale) : row.implicitHeight + Math.round(10 * root.fontScale)

    // ── Estado de rede ─────────────────────────────────────────────────────
    property bool hasNetwork: false

    Process {
        id: netCheckProc
        command: [ "bash", "-c", "nmcli networking 2>/dev/null" ]
        property string _buf: ""
        stdout: SplitParser {
            onRead: (line) => netCheckProc._buf += line + "\n"
        }
        onRunningChanged: {
            if (!running) {
                root.hasNetwork = netCheckProc._buf.trim() === "enabled"
                netCheckProc._buf = ""
            }
        }
    }

    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: { if (!netCheckProc.running) netCheckProc.running = true }
    }

    // ── Volume — via Pipewire, sempre reativo, sem custo de polling ────────
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
    readonly property var  sink: Pipewire.defaultAudioSink
    readonly property real vol:   sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted  : false

    readonly property string outputDeviceName:
        Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.nickname || "") : ""
    readonly property string inputDeviceName:
        Pipewire.defaultAudioSource ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.nickname || "") : ""

    // ── Estado detalhado de Wi-Fi/Ethernet/Bluetooth — buscado SOB DEMANDA,
    // apenas quando o mouse entra no ícone (evita polling em background).
    readonly property string ctl: Quickshell.shellDir + "/scripts/network-ctl.sh"

    property bool   tipWifiEnabled:  false
    property string tipWifiSsid:     ""
    property bool   tipEthConnected: false
    property string tipEthDevice:    ""
    property bool   tipBtEnabled:    false
    property bool   tipDataReady:    false   // true após a primeira busca completar

    Process {
        id: tipStatusProc
        command: ["bash", root.ctl, "status"]
        property string _buf: ""
        stdout: SplitParser { onRead: (line) => tipStatusProc._buf += line + "\n" }
        onRunningChanged: {
            if (!running) {
                var lines = tipStatusProc._buf.split("\n")
                tipStatusProc._buf = ""
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim(); if (ln === "") continue
                    var eq = ln.indexOf("="); if (eq < 0) continue
                    var key = ln.slice(0, eq).trim(), val = ln.slice(eq + 1).trim()
                    if      (key === "WIFI_RADIO")    root.tipWifiEnabled  = (val === "on")
                    else if (key === "WIFI_SSID")     root.tipWifiSsid     = val
                    else if (key === "ETH_CONNECTED") root.tipEthConnected = (val === "true")
                    else if (key === "ETH_DEV")        root.tipEthDevice    = val
                }
                root.tipDataReady = true
            }
        }
    }

    Process {
        id: tipBtProc
        command: ["bash", "-c", "systemctl is-active bluetooth.service 2>/dev/null"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => tipBtProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.tipBtEnabled = tipBtProc._buf.trim() === "active"
                tipBtProc._buf = ""
            }
        }
    }

    function _refreshTooltipData() {
        if (!tipStatusProc.running) tipStatusProc.running = true
        if (!tipBtProc.running)     tipBtProc.running     = true
        if (!tipExtraProc.running)  tipExtraProc.running  = true
        if (!tipWeatherProc.running && root.tipWeatherStale) tipWeatherProc.running = true
    }

    // ── EasyEffects / Power Profile / Shader / Temperatura — combinados num
    // único Process para reduzir forks (tudo sob demanda, no hover) ─────────
    property bool   tipEeRunning:     false
    property string tipEeOutputPreset: ""
    property string tipEeInputPreset:  ""
    property string tipPowerProfile:  ""
    property string tipShaderName:    ""
    property string tipShaderMode:    ""   // "auto" | "off" | "manual:<nome>"
    property int    tipTemp:          0
    property int    tipGamma:         0

    readonly property var _powerProfileLabels: ({
        "performance":   "Performance",
        "gaming":        "Gaming",
        "balanced":      "Balanced",
        "balanced_cool": "Balanced Cool",
        "cool":          "Cool"
    })

    Process {
        id: tipExtraProc
        command: ["bash", "-c",
            "easyeffects -s 2>/dev/null; echo '###POWER###'; " +
            "thermal-profile waybar 2>/dev/null; echo '###SHADER###'; " +
            "hyprshade current 2>/dev/null; echo '###MODE###'; " +
            "cat ~/.cache/hyprnight/shader-mode 2>/dev/null; echo '###TEMPLOG###'; " +
            "source ~/.config/hypr/noturne.config 2>/dev/null && grep '| phase=' \"$HYPRSUNSET_LOG\" 2>/dev/null | tail -1"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => tipExtraProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var raw = tipExtraProc._buf; tipExtraProc._buf = ""

            var eeOut     = raw.split("###POWER###")[0] || ""
            var powerOut  = (raw.split("###POWER###")[1] || "").split("###SHADER###")[0]
            var shaderOut = (raw.split("###SHADER###")[1] || "").split("###MODE###")[0]
            var modeOut   = (raw.split("###MODE###")[1] || "").split("###TEMPLOG###")[0]
            var tempLogOut = raw.split("###TEMPLOG###")[1] || ""

            root.tipEeRunning = eeOut.trim() !== "" && !eeOut.includes("not running")

            root.tipEeOutputPreset = ""
            root.tipEeInputPreset  = ""
            var eeLines = eeOut.split("\n")
            for (var i = 0; i < eeLines.length; i++) {
                var el = eeLines[i].trim()
                if (el.startsWith("output:")) root.tipEeOutputPreset = el.replace("output:", "").trim()
                if (el.startsWith("input:"))  root.tipEeInputPreset  = el.replace("input:",  "").trim()
            }

            try {
                var pdata = JSON.parse(powerOut.trim())
                var pid = (pdata.class || "").replace("-", "_")
                root.tipPowerProfile = root._powerProfileLabels[pid] || pid || ""
            } catch (e) { root.tipPowerProfile = "" }

            root.tipShaderName = shaderOut.trim()
            root.tipShaderMode = modeOut.trim()

            var mt = tempLogOut.match(/\btemp=(\d+)K\b/)
            var mg = tempLogOut.match(/\bgamma=(\d+)\b/)
            root.tipTemp  = mt ? parseInt(mt[1]) : 0
            root.tipGamma = mg ? parseInt(mg[1]) : 0
        }
    }

    // ── Clima — cache de 30min, igual QsWeather, mas independente (módulo
    // da barra não compartilha estado com o painel) ────────────────────────
    property string tipWeatherCondition: ""
    property string tipWeatherTemp:      ""
    property bool   tipWeatherStale:     true
    property string weatherCity:         "Belo Horizonte"

    Process {
        id: tipWeatherProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => tipWeatherProc._buf += l }
        onRunningChanged: {
            if (running) return
            var out = tipWeatherProc._buf.trim(); tipWeatherProc._buf = ""
            root.tipWeatherStale = false
            var parts = out.split("|")
            if (parts.length < 2 || out === "") return
            root.tipWeatherCondition = parts[0].trim()
            root.tipWeatherTemp      = parts[1].trim()
        }
    }
    Timer { interval: 30 * 60 * 1000; repeat: true; running: true
        onTriggered: root.tipWeatherStale = true }

    Component.onCompleted: {
        netCheckProc.running = true
        var encodedCity = root.weatherCity.replace(/ /g, "+")
        tipWeatherProc.command = ["bash", "-c",
            "curl -s --max-time 6 'wttr.in/" + encodedCity + "?m&format=%C|%t'"]
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text:           "\uf0c9"
            color:          root.textColor
            font.pixelSize: Math.round(13 * root.fontScale)
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill:    parent
        hoverEnabled:    true
        acceptedButtons: Qt.LeftButton
        onClicked:       root.panelRequested()
        onEntered: {
            root._refreshTooltipData()
            QsTooltip.show(root, root, root.barPosition)
        }
        onExited: QsTooltip.hide()
    }
}
