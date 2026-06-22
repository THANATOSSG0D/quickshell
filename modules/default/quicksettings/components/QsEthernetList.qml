import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsEthernetList ───────────────────────────────────────────────────────────
// Lista de dispositivos Ethernet com connect/disconnect e editar. Extraído
// do antigo QsTabNetworks, que misturava Wi-Fi e Ethernet — agora Ethernet
// vive na sua própria sub-página.
//
// Props de entrada:  ethConnected, ethDevice, ethConnName, ethListRaw
// Signals de saída:  toggleRequested, requestRefresh
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    property bool   ethConnected: false
    property string ethDevice:    ""
    property string ethConnName:  ""
    property string ethListRaw:   ""

    signal requestRefresh()

    // ── Processos ───────────────────────────────────────────────────────────
    Process {
        id: ethConnectProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethConnectProc._buf += l + "\n" }
        onRunningChanged: { if (!running) { ethConnectProc._buf = ""; root.requestRefresh() } }
    }

    Process {
        id: ethDisconnectProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethDisconnectProc._buf += l + "\n" }
        onRunningChanged: { if (!running) { ethDisconnectProc._buf = ""; root.requestRefresh() } }
    }

    Process {
        id: editProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => editProc._buf += l + "\n" }
        onRunningChanged: { if (!running) editProc._buf = "" }
    }

    // ── Parsing ─────────────────────────────────────────────────────────────
    // Formato network-ctl.sh eth list: "DEVICE|CONNECTED|CONNECTION"
    readonly property var ethConnections: {
        var lines = root.ethListRaw.split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln === "") continue
            var p = ln.split("|")
            if (p.length < 3) continue
            var dev  = p[0].trim()
            var ok   = p[1].trim() === "true"
            var conn = p[2].trim()
            if (conn === "" || conn === "--") conn = dev
            result.push({ device: dev, connection: conn, connected: ok,
                          state: ok ? "connected" : "disconnected" })
        }
        return result
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 4

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; boundsMovement: Flickable.StopAtBounds
            model: root.ethConnections
            spacing: 3

            delegate: Item {
                id: netItem
                required property var modelData
                required property int index
                width: ListView.view.width; height: 34

                readonly property bool isActive: netItem.modelData.connected === true

                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: netItem.isActive
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.13)
                        : itemMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.color: netItem.isActive ? root.colorAccent : "transparent"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8

                        Text {
                            text: "\uf6ff"
                            font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            color: netItem.isActive ? root.colorAccent : root.colorText
                        }
                        Text {
                            text: netItem.modelData.connection || netItem.modelData.device || ""
                            color: netItem.isActive ? root.colorAccent : root.colorText
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible: netItem.isActive
                            text: "conectado"; color: root.colorAccent; font.pixelSize: 8
                        }
                        Text {
                            visible: !netItem.isActive
                            text: netItem.modelData.state || ""
                            color: root.colorTextDim; font.pixelSize: 8; opacity: 0.6
                        }

                        // Botão editar
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: editMA.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "\uf040"
                                font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font"
                                color: root.colorTextDim }
                            MouseArea {
                                id: editMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    var connName = netItem.modelData.connection || netItem.modelData.device
                                    editProc.command = [ "bash", "-c",
                                        "uuid=$(nmcli -g UUID,NAME conn show 2>/dev/null" +
                                        " | awk -F: -v n=" + JSON.stringify(connName) +
                                        " '$0 ~ \":\"n\"$\" { print $1; exit }');" +
                                        " if [ -n \"$uuid\" ]; then" +
                                        "   nm-connection-editor --edit \"$uuid\" 2>/dev/null &" +
                                        " else" +
                                        "   nm-connection-editor --edit " + JSON.stringify(connName) + " 2>/dev/null &" +
                                        " fi" ]
                                    editProc.running = true
                                }
                            }
                        }
                    }

                    // Clique na linha: connect/disconnect — rightMargin para não
                    // sobrepor o botão de editar
                    MouseArea {
                        id: itemMA; anchors.fill: parent; hoverEnabled: true
                        anchors.rightMargin: 26
                        onClicked: {
                            var script = Quickshell.shellDir + "/scripts/network-ctl.sh"
                            var dev = netItem.modelData.device
                            if (netItem.modelData.connected) {
                                ethDisconnectProc.command = [ "bash", script, "eth", "off", dev ]
                                ethDisconnectProc.running = true
                            } else {
                                ethConnectProc.command = [ "bash", script, "eth", "on", dev ]
                                ethConnectProc.running = true
                            }
                        }
                    }
                }
            }

            // Lista vazia
            Item {
                anchors.fill: parent
                visible: root.ethConnections.length === 0
                Text {
                    anchors.centerIn: parent
                    text: "\uf6ff  Sem dispositivos Ethernet"
                    color: root.colorTextDim; font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"; opacity: 0.6
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width - 20; wrapMode: Text.WordWrap
                }
            }
        }
    }
}
