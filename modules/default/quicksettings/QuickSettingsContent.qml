import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "./components" as Qs

// ── QuickSettingsContent ─────────────────────────────────────────────────────
// Toggles: WiFi (radio) | Ethernet (connection up/down) | Bluetooth | Caffeine
// Bluetooth: alinhado com toggle-bluetooth.sh (systemctl bluetooth.service)
// Thermal: sudo -n sem pkexec
// LC_ALL=C em todos os processos nmcli
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

    // ── WiFi: toggle do rádio (nmcli radio wifi) ───────────────────────────
    property bool   wifiEnabled: false
    property string wifiBadge:   ""

    Process { id: wifiRadioProc;  command: [ "bash", "-c", "LC_ALL=C nmcli radio wifi 2>/dev/null" ] }
    Process { id: wifiActiveProc; command: [ "bash", "-c",
        "LC_ALL=C nmcli --escape no -t -f NAME,TYPE,DEVICE conn show --active 2>/dev/null" ] }
    Process { id: wifiToggleProc }

    readonly property bool wifiOn: (wifiRadioProc.stdout || "").trim() === "enabled"
    onWifiOnChanged: wifiEnabled = wifiOn

    readonly property string wifiBadgeRaw: {
        var lines = (wifiActiveProc.stdout || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split(":")
            if (p.length >= 3 && p[1] === "802-11-wireless" && p[2].trim() !== "") return p[0]
        }
        return ""
    }
    onWifiBadgeRawChanged: wifiBadge = wifiBadgeRaw

    function _refreshWifi() {
        if (!wifiRadioProc.running)  wifiRadioProc.running  = true
        if (!wifiActiveProc.running) wifiActiveProc.running = true
    }
    function _toggleWifi() {
        wifiToggleProc.command = [ "bash", "-c",
            "LC_ALL=C nmcli radio wifi " + (root.wifiEnabled ? "off" : "on") ]
        wifiToggleProc.running = true
        root.wifiEnabled = !root.wifiEnabled
    }

    // ── Ethernet: connection up/down (LC_ALL=C para estados em inglês) ─────
    property bool   ethConnected: false
    property string ethConnName:  ""    // nome da connection (ex.: "Conexão cabeada 1")
    property string ethDevice:    ""

    Process { id: ethStatusProc; command: [ "bash", "-c",
        "LC_ALL=C nmcli --escape no -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | grep ':ethernet:' | head -1" ] }
    Process { id: ethToggleProc }

    readonly property string ethRaw: (ethStatusProc.stdout || "").trim()
    onEthRawChanged: {
        var p = ethRaw.split(":")
        if (p.length >= 4) {
            ethDevice    = p[0]
            ethConnected = p[2] === "connected"
            ethConnName  = p[3] || p[0]
        }
    }

    function _refreshEth() { if (!ethStatusProc.running) ethStatusProc.running = true }
    function _toggleEth() {
        if (ethDevice === "") return
        if (ethConnected) {
            // Down na connection — igual ao hábito do usuário
            ethToggleProc.command = [ "bash", "-c",
                "LC_ALL=C nmcli connection down \"" + root.ethConnName + "\" 2>/dev/null" ]
        } else {
            ethToggleProc.command = [ "bash", "-c",
                "LC_ALL=C nmcli connection up \"" + root.ethConnName + "\" 2>/dev/null || " +
                "LC_ALL=C nmcli device connect \"" + root.ethDevice + "\" 2>/dev/null" ]
        }
        ethToggleProc.running = true
        root.ethConnected = !root.ethConnected
        // Atualiza estado real após 1.5s
        ethRefreshTimer.restart()
    }
    Timer { id: ethRefreshTimer; interval: 1500; onTriggered: _refreshEth() }

    // ── Bluetooth: alinhado com toggle-bluetooth.sh ────────────────────────
    // Usa systemctl start/stop bluetooth.service (igual ao script)
    // bluetoothctl show ainda serve para ler o estado atual
    property bool btEnabled: false

    Process { id: btStatusProc; command: [ "bash", "-c",
        "systemctl is-active bluetooth.service 2>/dev/null" ] }
    Process { id: btToggleProc }

    readonly property bool btOn: (btStatusProc.stdout || "").trim() === "active"
    onBtOnChanged: btEnabled = btOn

    function _refreshBt() { if (!btStatusProc.running) btStatusProc.running = true }
    function _toggleBluetooth() {
        btToggleProc.command = root.btEnabled
            ? [ "bash", "-c", "systemctl stop bluetooth.service 2>/dev/null" ]
            : [ "bash", "-c", "systemctl start bluetooth.service 2>/dev/null" ]
        btToggleProc.running = true
        root.btEnabled = !root.btEnabled
    }

    // ── DND (local) ────────────────────────────────────────────────────────
    property bool dndEnabled: false

    // ── Caffeine ───────────────────────────────────────────────────────────
    property bool caffeineActive: false

    Process { id: caffeineStatusProc; command: [ "bash", "-c",
        "systemctl --user is-active hypridle 2>/dev/null" ] }
    Process { id: caffeineToggleProc }

    readonly property bool caffeineOn: (caffeineStatusProc.stdout || "").trim() === "active"
    // hypridle active = suspensão habilitada = caffeine OFF
    onCaffeineOnChanged: caffeineActive = !caffeineOn

    function _toggleCaffeine() {
        caffeineToggleProc.command = [ "bash", "-c",
            "$HOME/.config/hypr/scripts/caffeine-toggle.sh --quiet 2>/dev/null || " +
            (root.caffeineActive
                ? "systemctl --user start hypridle 2>/dev/null"
                : "systemctl --user stop hypridle 2>/dev/null") ]
        caffeineToggleProc.running = true
        root.caffeineActive = !root.caffeineActive
    }

    // ── Volume Pipewire ────────────────────────────────────────────────────
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
    readonly property var  sink:  Pipewire.defaultAudioSink
    readonly property real vol:   sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted  : false
    readonly property string volIcon: muted || vol <= 0 ? "\uf026" : vol <= 0.33 ? "\uf027" : "\uf028"

    // ── Inicialização ──────────────────────────────────────────────────────
    Component.onCompleted: Qt.callLater(function() {
        btStatusProc.running       = true
        caffeineStatusProc.running = true
        _refreshWifi()
        _refreshEth()
    })
    onPanelOpenChanged: {
        if (panelOpen) {
            if (!btStatusProc.running)       btStatusProc.running       = true
            if (!caffeineStatusProc.running) caffeineStatusProc.running = true
            _refreshWifi()
            _refreshEth()
        }
    }

    // ── Flickable ─────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent; clip: true
        contentWidth:  width
        contentHeight: mainCol.implicitHeight + 28
        boundsMovement: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol; x: 14; y: 14
            width: parent.width - 28; spacing: 10

            // ── Grade 2×2 ──────────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 8; columnSpacing: 8

                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: "\uf1eb"; label: "Wi-Fi"; badge: root.wifiBadge
                    active: root.wifiEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleWifi()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 60
                    icon: "\uf6ff"; label: "Ethernet"
                    badge: root.ethConnected ? root.ethDevice : "desconectado"
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

            // ── Volume inline ──────────────────────────────────────────
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
                    id: volThumb
                    anchors.verticalCenter: parent.verticalCenter
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

            // ── Modo Noturno ───────────────────────────────────────────
            Qs.QsNightMode {
                Layout.fillWidth: true; panelOpen: root.panelOpen
                colorAccent: root.colorAccent; colorText: root.colorText
                colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── Perfil Térmico ─────────────────────────────────────────
            Qs.QsThermalSection {
                Layout.fillWidth: true; panelOpen: root.panelOpen
                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── Abas ───────────────────────────────────────────────────
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
                Qs.QsTabNetworks  { anchors.fill: parent; visible: root.activeTab === "networks"
                    colorAccent: root.colorAccent; colorText: root.colorText
                    colorTextDim: root.colorTextDim; colorMuted: root.colorMuted }
                Qs.QsTabBluetooth { anchors.fill: parent; visible: root.activeTab === "bluetooth"
                    colorAccent: root.colorAccent; colorText: root.colorText
                    colorTextDim: root.colorTextDim; colorMuted: root.colorMuted }
                Qs.QsTabSystem    { anchors.fill: parent; visible: root.activeTab === "system"
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim }
                Qs.QsTabTray      { anchors.fill: parent; visible: root.activeTab === "tray"
                    colorText: root.colorText; colorTextDim: root.colorTextDim }
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
