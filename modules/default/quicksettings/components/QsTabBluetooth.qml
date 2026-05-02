import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Bluetooth ────────────────────────────────────────────────────────────
// REGRA: Process.stdout é DataStream — NUNCA lido como string diretamente.
//        Usa SplitParser para acumular linhas em _buf, lido em onRunningChanged.
//
// Tile toggle (bt on/off): controlado por QuickSettingsContent via systemctl.
// Esta aba: lista pareados, conecta/desconecta, faz scan de novos.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    // Injetado pelo QuickSettingsContent
    property bool btEnabled: true

    // ── Estado ─────────────────────────────────────────────────────────────
    property var  pairedList:    []
    property var  connectedMacs: ({})   // { "AA:BB:...": true }
    property bool scanning:      false

    // ── Parsing ────────────────────────────────────────────────────────────
    // Saída de `bluetoothctl devices [Paired|Connected]`:
    //   "Device AA:BB:CC:DD:EE:FF Nome do device"
    function parseDevices(text) {
        var lines  = (text || "").trim().split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].trim().match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
            if (m) result.push({ mac: m[1], name: m[2] })
        }
        return result
    }

    // ── Processo: lista pareados ───────────────────────────────────────────
    Process {
        id: pairedProc
        command: ["bluetoothctl", "devices", "Paired"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => pairedProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.pairedList  = root.parseDevices(pairedProc._buf)
                pairedProc._buf  = ""
            }
        }
    }

    // ── Processo: lista conectados ─────────────────────────────────────────
    Process {
        id: connectedProc
        command: ["bluetoothctl", "devices", "Connected"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => connectedProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                var devs = root.parseDevices(connectedProc._buf)
                connectedProc._buf = ""
                var macs = {}
                for (var i = 0; i < devs.length; i++) macs[devs[i].mac] = true
                root.connectedMacs = macs
            }
        }
    }

    // ── Processo: connect / disconnect ─────────────────────────────────────
    Process {
        id: btActionProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btActionProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                btActionProc._buf = ""
                btRefreshTimer.restart()
            }
        }
    }

    // ── Processo: scan on / off ────────────────────────────────────────────
    Process {
        id: btScanProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btScanProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) btScanProc._buf = ""
        }
    }

    // ── Timers ─────────────────────────────────────────────────────────────
    Timer { id: btRefreshTimer;  interval: 1500;  onTriggered: refresh() }
    Timer {
        id: scanTimer; interval: 10000
        onTriggered: {
            root.scanning = false
            btScanProc.command = ["bluetoothctl", "scan", "off"]
            if (!btScanProc.running) btScanProc.running = true
            refresh()
        }
    }

    // ── Funções públicas ───────────────────────────────────────────────────
    function refresh() {
        if (!root.btEnabled) return
        if (!pairedProc.running)    pairedProc.running    = true
        if (!connectedProc.running) connectedProc.running = true
    }

    function startScan() {
        if (!root.btEnabled || root.scanning) return
        root.scanning = true
        btScanProc.command = ["bluetoothctl", "scan", "on"]
        if (!btScanProc.running) btScanProc.running = true
        scanTimer.restart()
    }

    Component.onCompleted: refresh()
    onBtEnabledChanged: { if (btEnabled) refresh() }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Cabeçalho ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.scanning ? "\uf110  Procurando…" : "\uf294  Dispositivos Pareados"
                color: root.scanning ? root.colorAccent : root.colorTextDim
                font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                font.capitalization: Font.AllUppercase
                Layout.fillWidth: true
            }

            // Botão scan
            Rectangle {
                width: 20; height: 20; radius: 4
                color: root.scanning
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                    : Qt.rgba(1,1,1,0.07)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "\uf002"
                    color: root.scanning ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea { anchors.fill: parent; onClicked: root.startScan() }
            }

            // Botão atualizar
            Rectangle {
                width: 20; height: 20; radius: 4
                color: Qt.rgba(1,1,1,0.07)
                Text {
                    anchors.centerIn: parent; text: "\uf021"
                    color: root.colorTextDim
                    font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea { anchors.fill: parent; onClicked: root.refresh() }
            }
        }

        // ── Lista de dispositivos ──────────────────────────────────────
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; boundsMovement: Flickable.StopAtBounds
            model: root.pairedList
            spacing: 4

            delegate: Item {
                id: btItem
                required property var modelData
                required property int index

                readonly property bool connected: root.connectedMacs[btItem.modelData.mac] === true

                width: ListView.view.width; height: 36

                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: btItem.connected
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
                        : (itemMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8

                        Text {
                            text: "\uf294"
                            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                            color: btItem.connected ? root.colorAccent : root.colorTextDim
                        }
                        Text {
                            text: btItem.modelData.name
                            color: btItem.connected ? root.colorAccent : root.colorText
                            font.pixelSize: 10; elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: btItem.connected
                            text: "conectado"; color: root.colorAccent; font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        id: itemMA; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var mac = btItem.modelData.mac
                            btActionProc.command = btItem.connected
                                ? ["bluetoothctl", "disconnect", mac]
                                : ["bluetoothctl", "connect",    mac]
                            if (!btActionProc.running) btActionProc.running = true
                        }
                    }
                }
            }

            // Placeholder lista vazia
            Item {
                anchors.fill: parent
                visible: root.pairedList.length === 0 && !root.scanning && root.btEnabled
                Text {
                    anchors.centerIn: parent
                    text: "\uf294  Nenhum dispositivo pareado"
                    color: root.colorTextDim; font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"; opacity: 0.6
                }
            }
        }
    }

    // Overlay quando BT está desligado
    Rectangle {
        anchors.fill: parent
        visible:      !root.btEnabled
        color:        Qt.rgba(0, 0, 0, 0.55)
        radius:       8; z: 99
        Column {
            anchors.centerIn: parent; spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf294"; color: root.colorTextDim
                font.pixelSize: 26; font.family: "JetBrainsMono Nerd Font"; opacity: 0.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bluetooth desligado"; color: root.colorTextDim
                font.pixelSize: 11; opacity: 0.7
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ligue o tile para usar"; color: root.colorTextDim
                font.pixelSize: 9; opacity: 0.45
            }
        }
    }
}
