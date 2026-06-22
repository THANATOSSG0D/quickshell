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
    property bool   panelOpen:    false
    property var    parentWindow: null
    // Aba fixa no topo: "dashboard" | "media" | "performance" | "system"
    property string activeTab:    "dashboard"
    // Sub-tela com botão voltar, válida dentro da aba ativa:
    //   Dashboard:   "" | "wifi" | "ethernet" | "bluetooth"
    //   Mídia:       "" | "devices" | "easyeffects"
    //   Performance: "" | "power" | "shader"
    property string subPage:      ""
    // Verdadeiro enquanto um menu de tray estiver aberto — suspende FocusGrab
    readonly property bool trayMenuOpen: tabTray.menuOpen

    // ── Resumo leve do shader, só para exibir no QsNavRow da home ───────────
    // (a leitura completa — incluindo lista de shaders e gamma — vive dentro
    // do QsShaderStatus, instanciado só quando a sub-tela abre)
    property string shaderSummary: "Carregando…"

    Process {
        id: shaderSummaryProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => shaderSummaryProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = shaderSummaryProc._buf.split("---")
            shaderSummaryProc._buf = ""
            if (parts.length < 2) return
            var shader = parts[0].trim()
            var mode   = parts[1].trim()
            var modeLabel = mode === "auto" ? "Automático" : mode === "off" ? "Desligado" : "Manual"
            root.shaderSummary = (shader !== "" ? shader : "Nenhum shader") + " · " + modeLabel
        }
    }
    function _refreshShaderSummary() {
        if (shaderSummaryProc.running) return
        shaderSummaryProc.command = ["bash", "-c",
            "hyprshade current 2>/dev/null; echo '---'; cat ~/.cache/hyprnight/shader-mode 2>/dev/null"]
        shaderSummaryProc.running = true
    }

    // ── Resumo leve do perfil de energia ativo, só para exibir no QsNavRow ──
    property string powerProfileSummary: "Carregando…"

    readonly property var _powerProfileLabels: ({
        "performance":   "Performance",
        "gaming":        "Gaming",
        "balanced":      "Balanced",
        "balanced_cool": "Balanced Cool",
        "cool":          "Cool"
    })

    Process {
        id: powerProfileSummaryProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => powerProfileSummaryProc._buf += l }
        onRunningChanged: {
            if (running) return
            var out = powerProfileSummaryProc._buf.trim()
            powerProfileSummaryProc._buf = ""
            if (out === "") { root.powerProfileSummary = "Indisponível"; return }
            try {
                var data = JSON.parse(out)
                var id = (data.class || "").replace("-", "_")
                root.powerProfileSummary = root._powerProfileLabels[id] || id || "—"
            } catch (e) {
                root.powerProfileSummary = "Indisponível"
            }
        }
    }
    function _refreshPowerProfileSummary() {
        if (powerProfileSummaryProc.running) return
        powerProfileSummaryProc.command = ["bash", "-c", "thermal-profile waybar 2>/dev/null"]
        powerProfileSummaryProc.running = true
    }

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
        onRunningChanged: {
            if (!running) {
                btToggleProc._buf = ""
                btRefreshTimer.restart()   // confirma estado real após systemctl
            }
        }
    }
    Timer { id: btRefreshTimer; interval: 1800; onTriggered: _refreshBt() }

    function _refreshBt() { if (!btStatusProc.running) btStatusProc.running = true }
    function _toggleBluetooth() {
        btToggleProc.command = root.btEnabled
            ? ["bash", "-c", "systemctl stop bluetooth.service 2>/dev/null"]
            : ["bash", "-c", "systemctl start bluetooth.service 2>/dev/null"]
        btToggleProc.running = true
        root.btEnabled = !root.btEnabled   // optimistic
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
    // UI — abas fixas no topo + sub-telas (Wi-Fi/Bluetooth) dentro do Dashboard
    // ═══════════════════════════════════════════════════════════════════════
    // activeTab nunca usa botão de voltar — é navegação principal, sempre
    // visível. subPage é usado SOMENTE dentro da aba Dashboard, para abrir
    // detalhes de Wi-Fi/Ethernet/Bluetooth com um cabeçalho + botão voltar.
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Barra de abas fixa ──────────────────────────────────────────────
        Qs.QsTabBar {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.topMargin: 10
            Layout.bottomMargin: 0
            activeTab: root.activeTab
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            tabs: [
                { id: "dashboard",   label: "\uf2dc  Dashboard"   },
                { id: "media",       label: "\uf001  Mídia"       },
                { id: "performance", label: "\uf2db  Performance" },
                { id: "system",      label: "\uf108  Sistema"     }
            ]
            onTabClicked: (id) => { root.activeTab = id; root.subPage = "" }
        }

        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10
            height: 1; color: root.colorDivider; opacity: 0.4 }

        // ── Conteúdo das abas ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // ── ABA: Dashboard ──────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "dashboard"

                // ── Tela principal do Dashboard (tiles, tray, footer) ────────
                Flickable {
                    anchors.fill: parent; clip: true
                    visible: root.subPage === ""
                    contentWidth:  width
                    contentHeight: dashCol.implicitHeight + 24
                    boundsMovement: Flickable.StopAtBounds

                    ColumnLayout {
                        id: dashCol; x: 14; y: 10
                        width: parent.width - 28; spacing: 10

                        // ── Clima + Mídia (mesma linha) ─────────────────────────
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Qs.QsWeather {
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                compact: true
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                            Qs.QsMiniPlayer {
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                compact: true
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }

                        // ── Calendário (compacto, sem card de fundo) ────────────
                        Qs.QsCalendar {
                            Layout.fillWidth: true
                            compact: true
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        // ── Tiles ────────────────────────────────────────────────
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2; rowSpacing: 6; columnSpacing: 6

                            Qs.QsToggleTile {
                                Layout.fillWidth: true; Layout.preferredHeight: 50
                                icon: "\uf1eb"; label: "Wi-Fi"
                                badge: root.wifiEnabled ? (root.wifiBadge || "ligado") : "desligado"
                                active: root.wifiEnabled
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onClicked: root.subPage = "wifi"
                            }
                            Qs.QsToggleTile {
                                Layout.fillWidth: true; Layout.preferredHeight: 50
                                icon: "\uf6ff"; label: "Ethernet"
                                badge: root.ethConnected
                                    ? (root.ethDevice || "cabo")
                                    : (root.ethDevice ? "desconectado" : "indisponível")
                                active: root.ethConnected
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onClicked: root.subPage = "ethernet"
                            }
                            Qs.QsToggleTile {
                                Layout.fillWidth: true; Layout.preferredHeight: 50
                                icon: "\uf294"; label: "Bluetooth"
                                badge: root.btEnabled ? "ligado" : "desligado"
                                active: root.btEnabled
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onClicked: root.subPage = "bluetooth"
                            }
                            Qs.QsToggleTile {
                                Layout.fillWidth: true; Layout.preferredHeight: 50
                                icon: root.caffeineActive ? "\uf0f4" : "\uf017"
                                label: "Caffeine"
                                badge: root.caffeineActive ? "suspensão off" : ""
                                active: root.caffeineActive
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onClicked: root._toggleCaffeine()   // sem sub-página — alterna direto
                            }
                        }

                        // ── Tray inline (compacto, sem divisor próprio) ───────────
                        Qs.QsTabTray {
                            id: tabTray
                            Layout.fillWidth: true; Layout.preferredHeight: 36
                            colorText: root.colorText; colorTextDim: root.colorTextDim
                            parentWindow: root.parentWindow
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsFooter {
                            Layout.fillWidth: true
                            colorText: root.colorText; colorMuted: root.colorMuted
                        }

                        Item { height: 0 }
                    }
                }

                // ── Sub-tela: Wi-Fi ──────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "wifi"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Wi-Fi"; icon: "\uf1eb"
                            actionIcon: "\uf021"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked:   root.subPage = ""
                            onActionClicked: root._refreshWifiList()
                        }

                        // Toggle real do Wi-Fi — vive aqui, não no tile da home
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Wi-Fi"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.wifiEnabled
                                colorAccent: root.colorAccent
                                onToggled: root._toggleWifi()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsWifiList {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent:  root.colorAccent
                            colorText:    root.colorText
                            colorTextDim: root.colorTextDim
                            colorMuted:   root.colorMuted
                            wifiEnabled:  root.wifiEnabled
                            wifiListRaw:  root.wifiListRaw
                            wifiScanning: root.wifiScanning
                            onRequestScan:    root._requestWifiScan()
                            onRequestRefresh: root._refreshWifiList()
                        }
                    }
                }

                // ── Sub-tela: Ethernet ───────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "ethernet"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Ethernet"; icon: "\uf6ff"
                            actionIcon: "\uf021"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked:   root.subPage = ""
                            onActionClicked: root._refreshEthList()
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: root.ethDevice !== ""
                            Text { text: "Conexão principal"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.ethConnected
                                colorAccent: root.colorAccent
                                onToggled: root._toggleEth()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsEthernetList {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent:  root.colorAccent
                            colorText:    root.colorText
                            colorTextDim: root.colorTextDim
                            colorMuted:   root.colorMuted
                            ethConnected: root.ethConnected
                            ethDevice:    root.ethDevice
                            ethConnName:  root.ethConnName
                            ethListRaw:   root.ethListRaw
                            onRequestRefresh:  root._refreshEthList()
                        }
                    }
                }

                // ── Sub-tela: Bluetooth ──────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "bluetooth"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Bluetooth"; icon: "\uf294"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Bluetooth"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.btEnabled
                                colorAccent: root.colorAccent
                                onToggled: root._toggleBluetooth()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsTabBluetooth {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorMuted: root.colorMuted
                            btEnabled: root.btEnabled
                        }
                    }
                }
            }

            // ── ABA: Mídia ────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "media"

                // ── Tela principal (compacta, sempre cabe sem rolar) ────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === ""

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 12

                        Qs.QsMediaPlayerFull {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsVolumeSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                            colorMuted: root.colorMuted
                        }
                        Qs.QsMicSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                            colorMuted: root.colorMuted
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        // ── Navegação para sub-telas ───────────────────────────
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf2db"; label: "Dispositivos"
                            sub:  "Saída e entrada padrão"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "devices"
                        }
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf028"; label: "EasyEffects"
                            sub:  "Status, bypass e presets"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "easyeffects"
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ── Sub-tela: Dispositivos ────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "devices"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Dispositivos"; icon: "\uf2db"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: devCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsAudioDevices {
                                id: devCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }

                // ── Sub-tela: EasyEffects ──────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "easyeffects"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "EasyEffects"; icon: "\uf028"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: eeCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsEasyEffects {
                                id: eeCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }
            }

            // ── ABA: Performance ──────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "performance"

                // ── Tela principal (compacta) ───────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === ""

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 12

                        Qs.QsSystemStats {
                            Layout.fillWidth: true
                            active: root.activeTab === "performance" && root.subPage === ""
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsNightMode {
                            Layout.fillWidth: true; panelOpen: root.panelOpen && root.activeTab === "performance"
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }
                        Qs.QsBrightnessSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf2db"; label: "Perfil de energia"
                            sub:  root.powerProfileSummary
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "power"

                            Component.onCompleted: root._refreshPowerProfileSummary()
                        }
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf185"; label: "Shader"
                            sub:  root.shaderSummary
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "shader"

                            Component.onCompleted: root._refreshShaderSummary()
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ── Sub-tela: Perfil de energia ─────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "power"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Perfil de energia"; icon: "\uf2db"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: { root.subPage = ""; root._refreshPowerProfileSummary() }
                        }

                        Qs.QsPowerProfile {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                        }
                    }
                }

                // ── Sub-tela: Shader ─────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "shader"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Shader"; icon: "\uf185"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: { root.subPage = ""; root._refreshShaderSummary() }
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: shCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsShaderStatus {
                                id: shCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }
            }

            // ── ABA: Sistema ──────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "system"

                Qs.QsTabSystem {
                    anchors.fill: parent; anchors.margins: 14
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                }
            }
        }
    }
}
