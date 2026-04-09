import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "./components" as Qs

// ── QuickSettingsContent ─────────────────────────────────────────────────────
// API CORRETA do Quickshell para ler stdout de processos:
//   Process.stdout NÃO é uma string — é um DataStream.
//   Para ler o output, OBRIGATORIAMENTE anexe um SplitParser:
//
//   Process {
//       property string _buf: ""
//       stdout: SplitParser {
//           onRead: (line) => parent._buf += line + "\n"
//       }
//       onRunningChanged: if (!running) { var txt = _buf; _buf = ""; /* usa txt */ }
//   }
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property color colorPanelBg:    "#1f1f1f"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    signal closeRequested()
    property bool   panelOpen: false
    property string activeTab: "networks"

    readonly property string ctl: Quickshell.shellDir + "/scripts/network-ctl.sh"

    // ═══════════════════════════════════════════════════════════════════════
    // Estado de rede — lido via "network-ctl.sh status"
    // ═══════════════════════════════════════════════════════════════════════
    property bool   wifiEnabled:  false
    property string wifiBadge:    ""
    property bool   ethConnected: false
    property string ethDevice:    ""
    property string ethConnName:  ""

    Process {
        id: statusProc
        command: ["bash", root.ctl, "status"]
        property string _buf: ""

        stdout: SplitParser {
            onRead: (line) => statusProc._buf += line + "\n"
        }

        onRunningChanged: {
            if (!running) {
                var text = statusProc._buf
                statusProc._buf = ""
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim()
                    if (ln === "") continue
                    var eq = ln.indexOf("=")
                    if (eq < 0) continue
                    var key = ln.slice(0, eq).trim()
                    var val = ln.slice(eq + 1).trim()
                    if      (key === "WIFI_RADIO")    root.wifiEnabled  = (val === "on")
                    else if (key === "WIFI_SSID")     root.wifiBadge    = val
                    else if (key === "ETH_CONNECTED") root.ethConnected = (val === "true")
                    else if (key === "ETH_DEV")       root.ethDevice    = val
                    else if (key === "ETH_CONN")      root.ethConnName  = val
                }
            }
        }
    }

    function _refreshStatus() {
        if (!statusProc.running) statusProc.running = true
    }

    // ── WiFi toggle ────────────────────────────────────────────────────────
    Process {
        id: wifiToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) wifiToggleProc._buf = "" }
    }
    Timer { id: wifiRefreshTimer; interval: 1800; onTriggered: _refreshStatus() }

    function _toggleWifi() {
        wifiToggleProc.command = ["bash", root.ctl,
            "wifi", root.wifiEnabled ? "off" : "on"]
        wifiToggleProc.running = true
        root.wifiEnabled = !root.wifiEnabled
        wifiRefreshTimer.restart()
    }

    // ── Ethernet toggle ────────────────────────────────────────────────────
    Process {
        id: ethToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) ethToggleProc._buf = "" }
    }
    Timer { id: ethRefreshTimer; interval: 1800; onTriggered: _refreshStatus() }

    function _toggleEth() {
        if (root.ethDevice === "") return
        ethToggleProc.command = ["bash", root.ctl,
            "eth", root.ethConnected ? "off" : "on", root.ethDevice]
        ethToggleProc.running = true
        root.ethConnected = !root.ethConnected
        ethRefreshTimer.restart()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WiFi — lista de redes
    // ═══════════════════════════════════════════════════════════════════════
    property string wifiListRaw:  ""
    property bool   wifiScanning: false

    Process {
        id: wifiListProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiListProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.wifiListRaw  = wifiListProc._buf
                root.wifiScanning = false
                wifiListProc._buf = ""
            }
        }
    }

    Process {
        id: wifiScanProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiScanProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                wifiScanProc._buf = ""
                _refreshWifiList()
            }
        }
    }

    function _refreshWifiList() {
        wifiListProc.command = ["bash", root.ctl, "wifi", "list"]
        if (!wifiListProc.running) wifiListProc.running = true
    }

    function _requestWifiScan() {
        if (root.wifiScanning) return
        root.wifiScanning = true
        wifiScanProc.command = ["bash", root.ctl, "wifi", "scan"]
        if (!wifiScanProc.running) wifiScanProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Ethernet — lista (aba QsTabNetworks)
    // ═══════════════════════════════════════════════════════════════════════
    property string ethListRaw: ""

    Process {
        id: ethListProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethListProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.ethListRaw  = ethListProc._buf
                ethListProc._buf = ""
            }
        }
    }

    function _refreshEthList() {
        ethListProc.command = ["bash", root.ctl, "eth", "list"]
        if (!ethListProc.running) ethListProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Bluetooth
    // ═══════════════════════════════════════════════════════════════════════
    property bool btEnabled: false

    Process {
        id: btStatusProc
        command: ["bash", "-c", "systemctl is-active bluetooth.service 2>/dev/null"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btStatusProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.btEnabled    = btStatusProc._buf.trim() === "active"
                btStatusProc._buf = ""
            }
        }
    }

    Process {
        id: btToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) btToggleProc._buf = "" }
    }

    function _refreshBt() { if (!btStatusProc.running) btStatusProc.running = true }
    function _toggleBluetooth() {
        btToggleProc.command = root.btEnabled
            ? ["bash", "-c", "systemctl stop bluetooth.service 2>/dev/null"]
            : ["bash", "-c", "systemctl start bluetooth.service 2>/dev/null"]
        btToggleProc.running = true
        root.btEnabled = !root.btEnabled
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Caffeine
    // ═══════════════════════════════════════════════════════════════════════
    property bool dndEnabled:     false
    property bool caffeineActive: false

    Process {
        id: caffeineStatusProc
        command: ["bash", "-c", "systemctl --user is-active hypridle 2>/dev/null"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => caffeineStatusProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.caffeineActive        = caffeineStatusProc._buf.trim() !== "active"
                caffeineStatusProc._buf    = ""
            }
        }
    }

    Process {
        id: caffeineToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => caffeineToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) caffeineToggleProc._buf = "" }
    }

    function _toggleCaffeine() {
        caffeineToggleProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/caffeine-toggle.sh --quiet 2>/dev/null || " +
            (root.caffeineActive
                ? "systemctl --user start hypridle 2>/dev/null"
                : "systemctl --user stop hypridle 2>/dev/null")]
        caffeineToggleProc.running = true
        root.caffeineActive = !root.caffeineActive
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Volume Pipewire
    // ═══════════════════════════════════════════════════════════════════════
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
    readonly property var  sink:  Pipewire.defaultAudioSink
    readonly property real vol:   sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted  : false
    readonly property string volIcon:
        muted || vol <= 0 ? "\uf026" : vol <= 0.33 ? "\uf027" : "\uf028"

    // ═══════════════════════════════════════════════════════════════════════
    // Inicialização
    // ═══════════════════════════════════════════════════════════════════════
    Component.onCompleted: Qt.callLater(function() {
        statusProc.running         = true
        btStatusProc.running       = true
        caffeineStatusProc.running = true
        _refreshWifiList()
        _refreshEthList()
    })

    onPanelOpenChanged: {
        if (panelOpen) {
            _refreshStatus()
            if (!btStatusProc.running)       btStatusProc.running       = true
            if (!caffeineStatusProc.running) caffeineStatusProc.running = true
            _refreshWifiList()
            _refreshEthList()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // UI
    // ═══════════════════════════════════════════════════════════════════════
    Flickable {
        anchors.fill: parent; clip: true
        contentWidth:  width
        contentHeight: mainCol.implicitHeight + 28
        boundsMovement: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol; x: 14; y: 14
            width: parent.width - 28; spacing: 10

            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 8; columnSpacing: 8

                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: "\uf1eb"; label: "Wi-Fi"
                    badge: root.wifiEnabled ? (root.wifiBadge || "ligado") : "desligado"
                    active: root.wifiEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleWifi()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: "\uf6ff"; label: "Ethernet"
                    badge: root.ethConnected
                        ? (root.ethDevice || "cabo")
                        : (root.ethDevice ? "desconectado" : "indisponível")
                    active: root.ethConnected
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleEth()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: "\uf294"; label: "Bluetooth"
                    badge: root.btEnabled ? "ligado" : "desligado"
                    active: root.btEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleBluetooth()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: root.caffeineActive ? "\uf0f4" : "\uf017"
                    label: "Caffeine"
                    badge: root.caffeineActive ? "suspensão off" : ""
                    active: root.caffeineActive
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleCaffeine()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: root.volIcon; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                    color: root.muted ? root.colorMuted : root.colorAccent
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { anchors.fill: parent
                        onClicked: { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted } }
                }
                Text { text: "Volume"; color: root.colorText; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: Math.round(root.vol * 100) + "%"; color: root.colorTextDim; font.pixelSize: 10 }
            }
            Item {
                Layout.fillWidth: true; height: 18
                readonly property real maxV: 1.5
                readonly property real pct:  Math.min(1.0, root.vol) / maxV
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2
                    color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2
                    width: parent.width * parent.pct; color: root.muted ? root.colorMuted : root.colorAccent
                    Behavior on color { ColorAnimation { duration: 150 } } }
                Rectangle { anchors.verticalCenter: parent.verticalCenter
                    x: parent.width*(1.0/parent.maxV)-1; width:1; height:6; radius:1; color:Qt.rgba(1,1,1,0.2) }
                Rectangle {
                    id: volThumb; anchors.verticalCenter: parent.verticalCenter
                    x: Math.min(parent.width-width, Math.max(0, (root.vol/parent.maxV)*parent.width - width/2))
                    width:12; height:12; radius:6
                    color: root.muted ? root.colorMuted : root.colorAccent
                    visible: volMA.containsMouse
                    scale: volMA.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } } }
                MouseArea { id: volMA; anchors.fill: parent; hoverEnabled: true; enabled: root.sink !== null
                    onClicked: (m) => _sv(m.x); onPositionChanged: (m) => { if (pressed) _sv(m.x) }
                    function _sv(x) {
                        var n = root.sink; if (!n || !n.audio) return
                        n.audio.volume = Math.max(0, Math.min(1.5, x/width*1.5))
                        if (n.audio.volume > 0) n.audio.muted = false } }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            Qs.QsNightMode {
                Layout.fillWidth: true; panelOpen: root.panelOpen
                colorAccent: root.colorAccent; colorText: root.colorText
                colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            Qs.QsThermalSection {
                Layout.fillWidth: true; panelOpen: root.panelOpen
                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            Qs.QsTabBar {
                Layout.fillWidth: true; activeTab: root.activeTab
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                tabs: [
                    { id: "networks",  label: "\uf1eb  Redes"   },
                    { id: "bluetooth", label: "\uf294  BT"       },
                    { id: "system",    label: "\uf108  Sistema"  },
                    { id: "tray",      label: "\uf0c9  Tray"     }
                ]
                onTabClicked: (id) => root.activeTab = id
            }

            Item {
                Layout.fillWidth: true; height: 165; clip: true

                Qs.QsTabNetworks {
                    anchors.fill: parent
                    visible: root.activeTab === "networks"
                    colorAccent:  root.colorAccent
                    colorText:    root.colorText
                    colorTextDim: root.colorTextDim
                    colorMuted:   root.colorMuted
                    wifiEnabled:  root.wifiEnabled
                    wifiListRaw:  root.wifiListRaw
                    wifiScanning: root.wifiScanning
                    ethListRaw:   root.ethListRaw
                    onRequestWifiScan:    root._requestWifiScan()
                    onRequestRefreshWifi: root._refreshWifiList()
                    onRequestRefreshEth:  root._refreshEthList()
                }
                Qs.QsTabBluetooth {
                    anchors.fill: parent; visible: root.activeTab === "bluetooth"
                    colorAccent: root.colorAccent; colorText: root.colorText
                    colorTextDim: root.colorTextDim; colorMuted: root.colorMuted
                }
                Qs.QsTabSystem {
                    anchors.fill: parent; visible: root.activeTab === "system"
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                }
                Qs.QsTabTray {
                    anchors.fill: parent; visible: root.activeTab === "tray"
                    colorText: root.colorText; colorTextDim: root.colorTextDim
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            Qs.QsFooter {
                Layout.fillWidth: true
                colorText: root.colorText; colorMuted: root.colorMuted
            }

            Item { height: 0 }
        }
    }
}
