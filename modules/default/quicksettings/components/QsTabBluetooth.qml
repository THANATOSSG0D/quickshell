import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Bluetooth ────────────────────────────────────────────────────────────
// Lista dispositivos pareados via `bluetoothctl devices Paired`.
// Verifica quais estão conectados via `bluetoothctl devices Connected`.
// Conecta/desconecta ao clicar.
// Botão de scan inicia descoberta por 10s.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    // ── Processos ──────────────────────────────────────────────────────────
    Process { id: pairedProc;    command: [ "bluetoothctl", "devices", "Paired" ] }
    Process { id: connectedProc; command: [ "bluetoothctl", "devices", "Connected" ] }
    Process { id: btActionProc }
    Process { id: btScanProc }

    Component.onCompleted: { pairedProc.running = true; connectedProc.running = true }

    function refresh() {
        pairedProc.running   = true
        connectedProc.running = true
    }

    // ── Parsing ────────────────────────────────────────────────────────────
    // Saída de `bluetoothctl devices`: "Device AA:BB:CC:DD:EE:FF Nome do device"
    function parseDevices(stdout) {
        var lines = (stdout || "").trim().split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            var m = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
            if (m) result.push({ mac: m[1], name: m[2] })
        }
        return result
    }

    readonly property var pairedList:    parseDevices(pairedProc.stdout || "")
    readonly property var connectedList: parseDevices(connectedProc.stdout || "")

    readonly property var connectedMacs: {
        var macs = {}
        for (var i = 0; i < connectedList.length; i++)
            macs[connectedList[i].mac] = true
        return macs
    }

    // ── Scan state ─────────────────────────────────────────────────────────
    property bool scanning: false
    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: {
            root.scanning = false
            btScanProc.command = [ "bluetoothctl", "scan", "off" ]
            btScanProc.running = true
            root.refresh()
        }
    }

    function startScan() {
        scanning = true
        btScanProc.command = [ "bluetoothctl", "scan", "on" ]
        btScanProc.running = true
        scanTimer.restart()
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Cabeçalho: botão scan + contador ──────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text:           root.scanning ? "\uf110  Procurando…" : "\uf294  Dispositivos Pareados"
                color:          root.scanning ? root.colorAccent : root.colorTextDim
                font.pixelSize: 9
                font.family:    "JetBrainsMono Nerd Font"
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
                    anchors.centerIn: parent
                    text:           "\uf002"  // fa-search
                    color:          root.scanning ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 9
                    font.family:    "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.startScan()
                }
            }

            // Botão atualizar
            Rectangle {
                width: 20; height: 20; radius: 4
                color: Qt.rgba(1,1,1,0.07)
                Text {
                    anchors.centerIn: parent
                    text:           "\uf021"  // fa-refresh
                    color:          root.colorTextDim
                    font.pixelSize: 9
                    font.family:    "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.refresh()
                }
            }
        }

        // ── Lista de dispositivos ──────────────────────────────────────
        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip:              true
            boundsMovement:    Flickable.StopAtBounds
            model:             root.pairedList
            spacing:           4

            delegate: Item {
                id: btItem
                required property var modelData
                required property int index

                readonly property bool connected: root.connectedMacs[btItem.modelData.mac] === true

                width:  ListView.view.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: btItem.connected
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
                        : Qt.rgba(1, 1, 1, 0.05)

                    RowLayout {
                        anchors.fill:    parent
                        anchors.margins: 10
                        spacing: 8

                        // Ícone + indicator
                        Text {
                            text:           "\uf294"  // fa-bluetooth-b
                            font.pixelSize: 13
                            font.family:    "JetBrainsMono Nerd Font"
                            color:          btItem.connected ? root.colorAccent : root.colorTextDim
                        }

                        // Nome do dispositivo
                        Text {
                            text:             btItem.modelData.name
                            color:            btItem.connected ? root.colorAccent : root.colorText
                            font.pixelSize:   10
                            elide:            Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Badge conectado / botão desconectar
                        Text {
                            visible:        btItem.connected
                            text:           "conectado"
                            color:          root.colorAccent
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var mac = btItem.modelData.mac
                            if (btItem.connected) {
                                btActionProc.command = [ "bluetoothctl", "disconnect", mac ]
                            } else {
                                btActionProc.command = [ "bluetoothctl", "connect", mac ]
                            }
                            btActionProc.running = true
                            // Atualiza estado após 1.5s
                            btRefreshTimer.restart()
                        }
                    }
                }
            }

            // Placeholder
            Item {
                anchors.fill: parent
                visible:      root.pairedList.length === 0
                Text {
                    anchors.centerIn: parent
                    text:           "\uf294  Nenhum dispositivo pareado"
                    color:          root.colorTextDim
                    font.pixelSize: 10
                    font.family:    "JetBrainsMono Nerd Font"
                    opacity:        0.6
                }
            }
        }
    }

    Timer { id: btRefreshTimer; interval: 1500; onTriggered: root.refresh() }
}
