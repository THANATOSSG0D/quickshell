import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Redes ────────────────────────────────────────────────────────────────
// Modo WiFi: lista APs via `nmcli device wifi list`
// Modo Cabo: lista conexões Ethernet ativas via `nmcli device status`
// Botão de scan força um novo `nmcli device wifi rescan`
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    // ── Filtro de modo ─────────────────────────────────────────────────────
    property string netMode: "wifi"   // "wifi" | "eth"

    // ── WiFi ───────────────────────────────────────────────────────────────
    Process { id: wifiListProc; command: [ "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list" ] }
    Process { id: wifiRescanProc; command: [ "nmcli", "device", "wifi", "rescan" ] }
    Process { id: wifiConnectProc }


    readonly property var wifiNetworks: {
        var lines = (wifiListProc.stdout || "").split("\n")
        var result = []; var seen = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") continue
            var idx1 = line.indexOf(":")
            if (idx1 < 0) continue
            var inUse = line.substring(0, idx1)
            var rest  = line.substring(idx1 + 1)
            var idx2  = rest.indexOf(":")
            if (idx2 < 0) continue
            var ssid  = rest.substring(0, idx2)
            var rest2 = rest.substring(idx2 + 1)
            var idx3  = rest2.indexOf(":")
            if (idx3 < 0) continue
            var signal   = parseInt(rest2.substring(0, idx3)) || 0
            var security = rest2.substring(idx3 + 1).trim()
            if (ssid === "" || seen[ssid]) continue
            seen[ssid] = true
            result.push({ ssid: ssid, signal: signal,
                          active: inUse.trim() === "*",
                          secured: security !== "" && security !== "--" })
        }
        result.sort(function(a, b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            return b.signal - a.signal
        })
        return result
    }

    // ── Ethernet ───────────────────────────────────────────────────────────
    Process { id: ethListProc; command: [ "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status" ] }
    Component.onCompleted: {
        if (netMode === "wifi")
            wifiListProc.running = true
        else
            ethListProc.running = true
    }

    readonly property var ethConnections: {
        var lines = (ethListProc.stdout || "").split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") continue
            var parts = line.split(":")
            if (parts.length < 4) continue
            var dev = parts[0]; var type = parts[1]
            var state = parts[2]; var conn = parts[3]
            if (type !== "ethernet") continue
            result.push({
                device:     dev,
                connection: conn || dev,
                connected:  state === "connected"
            })
        }
        return result
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Filtro WiFi / Cabo ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { id: "wifi", label: "\uf1eb  WiFi"  },
                    { id: "eth",  label: "\uf6ff  Cabo"  }
                ]
                delegate: Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool active: root.netMode === modeBtn.modelData.id
                    Layout.preferredHeight: 20
                    Layout.preferredWidth:  modeLbl.implicitWidth + 12
                    radius: height / 2
                    color: modeBtn.active
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                        : Qt.rgba(1,1,1,0.05)
                    border.color: modeBtn.active ? root.colorAccent : "transparent"
                    border.width: 1
                    Text {
                        id: modeLbl
                        anchors.centerIn: parent
                        text:           modeBtn.modelData.label
                        color:          modeBtn.active ? root.colorAccent : root.colorTextDim
                        font.pixelSize: 9
                        font.family:    "JetBrainsMono Nerd Font"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.netMode = modeBtn.modelData.id
                            if (root.netMode === "wifi") wifiListProc.running = true
                            else ethListProc.running = true
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ── Botão scan (só WiFi) ───────────────────────────────────
            Text {
                visible:        root.netMode === "wifi"
                text:           "\uf021"
                color:          root.colorTextDim
                font.pixelSize: 11
                font.family:    "JetBrainsMono Nerd Font"
                MouseArea {
                    anchors.fill:    parent
                    anchors.margins: -4
                    onClicked: {
                        wifiRescanProc.running = true
                        // Atualiza lista 2s após o rescan
                        rescanTimer.restart()
                    }
                }
            }
        }

        Timer {
            id: rescanTimer
            interval: 2000
            onTriggered: wifiListProc.running = true
        }

        // ── Lista ──────────────────────────────────────────────────────
        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip:              true
            boundsMovement:    Flickable.StopAtBounds
            model:             root.netMode === "wifi" ? root.wifiNetworks : root.ethConnections
            spacing:           4

            delegate: Item {
                id: netItem
                required property var modelData
                required property int index
                width:  ListView.view.width
                height: 34

                // Distinção de modelo: wifi tem .ssid, eth tem .device
                readonly property bool isWifi: modelData.ssid !== undefined
                readonly property bool isActive: isWifi ? modelData.active : modelData.connected
                readonly property real strength: isWifi
                    ? Math.max(0, Math.min(1, (modelData.signal || 0) / 100))
                    : 1.0

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: netItem.isActive
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
                        : Qt.rgba(1, 1, 1, 0.05)

                    RowLayout {
                        anchors.fill:    parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text:           netItem.isWifi ? "\uf1eb" : "\uf6ff"
                            font.pixelSize: 13
                            font.family:    "JetBrainsMono Nerd Font"
                            opacity:        netItem.isWifi ? 0.25 + 0.75 * netItem.strength : 1.0
                            color:          netItem.isActive ? root.colorAccent : root.colorText
                        }
                        Text {
                            text:             netItem.isWifi
                                              ? (netItem.modelData.ssid || "(oculto)")
                                              : netItem.modelData.connection
                            color:            netItem.isActive ? root.colorAccent : root.colorText
                            font.pixelSize:   10
                            elide:            Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible:        netItem.isWifi && netItem.modelData.secured
                            text:           "\uf023"
                            color:          root.colorTextDim
                            font.pixelSize: 10
                            font.family:    "JetBrainsMono Nerd Font"
                        }
                        Text {
                            visible:        netItem.isActive
                            text:           "conectado"
                            color:          root.colorAccent
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (netItem.isWifi && !netItem.modelData.active) {
                                wifiConnectProc.command = [
                                    "nmcli", "device", "wifi", "connect",
                                    netItem.modelData.ssid
                                ]
                                wifiConnectProc.running = true
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: (root.netMode === "wifi" ? root.wifiNetworks : root.ethConnections).length === 0
                Text {
                    anchors.centerIn: parent
                    text:           root.netMode === "wifi"
                                    ? "\uf1eb  Buscando redes…"
                                    : "\uf6ff  Nenhuma conexão Ethernet"
                    color:          root.colorTextDim
                    font.pixelSize: 10
                    font.family:    "JetBrainsMono Nerd Font"
                }
            }
        }
    }
}
