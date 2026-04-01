import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Redes ────────────────────────────────────────────────────────────────
// LC_ALL=C em todos os nmcli para evitar locale PT que troca "connected" por "conectado"
// WiFi: scan + list; conexão: connection up (salvas) → device wifi connect
// Ethernet: lista todos os dispositivos ethernet via nmcli device status
// Correção: guard signal||0 e undefined check em todos os campos
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    property string netMode:  "wifi"
    property bool   scanning: false
    property string feedback: ""

    // ── Processos WiFi ─────────────────────────────────────────────────────
    Process {
        id: wifiListProc
        // LC_ALL=C força inglês; --rescan no usa cache
        command: [ "bash", "-c",
            "LC_ALL=C nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null" ]
    }

    Process {
        id: rescanProc
        command: [ "bash", "-c",
            "LC_ALL=C nmcli device wifi rescan 2>/dev/null; sleep 1; " +
            "LC_ALL=C nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null" ]
        onRunningChanged: {
            if (!running) {
                root.scanning   = false
                root.rescanData = rescanProc.stdout || ""
            }
        }
    }
    property string rescanData: ""
    readonly property string rawWifi: rescanData !== "" ? rescanData : (wifiListProc.stdout || "")

    Process {
        id: connectProc
        onRunningChanged: {
            if (!running) {
                var ok = (connectProc.stdout || "").indexOf("successfully") >= 0
                         || (connectProc.exitCode !== undefined && connectProc.exitCode === 0)
                root.feedback = ok ? "Conectado!" : "Falha — verifique a senha"
                feedbackTimer.restart()
                Qt.callLater(function() { if (!wifiListProc.running) wifiListProc.running = true })
            }
        }
    }
    Process {
        id: disconnectProc
        onRunningChanged: {
            if (!running) Qt.callLater(function() { if (!wifiListProc.running) wifiListProc.running = true })
        }
    }
    Timer { id: feedbackTimer; interval: 4000; onTriggered: root.feedback = "" }

    // ── Processos Ethernet ─────────────────────────────────────────────────
    Process {
        id: ethListProc
        // LC_ALL=C: estados ficam em inglês (connected, disconnected, unavailable...)
        command: [ "bash", "-c",
            "LC_ALL=C nmcli --escape no -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | grep ':ethernet:'" ]
    }
    Process { id: ethConnectProc }
    Process { id: ethDisconnectProc
        onRunningChanged: {
            if (!running) Qt.callLater(function() { if (!ethListProc.running) ethListProc.running = true })
        }
    }

    Component.onCompleted: Qt.callLater(function() {
        wifiListProc.running = true
        ethListProc.running  = true
    })

    // ── Parsing WiFi ───────────────────────────────────────────────────────
    // Linha: "INUSE:SSID:SIGNAL:SECURITY"  (INUSE = "*" ou " ")
    // Estratégia: divide da direita para não quebrar em SSIDs com ":"
    readonly property var wifiNetworks: {
        var lines  = root.rawWifi.split("\n")
        var result = []; var seen = {}
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.trim() === "") continue
            var inUse = ln.charAt(0) === "*"
            var rest  = ln.length > 2 ? ln.substring(2) : ""  // remove "X:"
            // Último campo: SECURITY
            var li3 = rest.lastIndexOf(":")
            if (li3 < 0) continue
            var security = rest.substring(li3 + 1).trim()
            rest = rest.substring(0, li3)
            // Penúltimo: SIGNAL
            var li2 = rest.lastIndexOf(":")
            if (li2 < 0) continue
            var signalStr = rest.substring(li2 + 1).trim()
            var signal    = signalStr !== "" ? (parseInt(signalStr) || 0) : 0
            var ssid      = rest.substring(0, li2).trim()
            if (ssid === "" || seen[ssid]) continue
            seen[ssid] = true
            result.push({ ssid: ssid, signal: signal, active: inUse,
                          secured: security !== "" && security !== "--" })
        }
        result.sort(function(a,b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            return (b.signal || 0) - (a.signal || 0)
        })
        return result
    }

    // ── Parsing Ethernet ───────────────────────────────────────────────────
    // Com LC_ALL=C: STATE é "connected", "disconnected", "unavailable", etc.
    readonly property var ethConnections: {
        var lines  = (ethListProc.stdout || "").split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln === "") continue
            var parts = ln.split(":")
            if (parts.length < 4) continue
            var dev   = parts[0]
            var state = parts[2]   // "connected", "disconnected", "unavailable"
            var conn  = parts[3] || dev
            result.push({
                device:     dev,
                connection: conn,
                connected:  state === "connected",
                state:      state
            })
        }
        return result
    }

    // ── Animação de scan ───────────────────────────────────────────────────
    property int scanDot: 0
    Timer { id: dotTimer; interval: 300; repeat: true; running: root.scanning
        onTriggered: root.scanDot = (root.scanDot + 1) % 4 }
    readonly property string scanLabel: {
        return "Procurando" + ["   ", ".  ", ".. ", "..."][root.scanDot]
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 5

        // Tabs WiFi / Cabo
        RowLayout {
            Layout.fillWidth: true; spacing: 4

            Repeater {
                model: [{ id: "wifi", label: "\uf1eb  WiFi" },
                        { id: "eth",  label: "\uf6ff  Cabo" }]
                delegate: Rectangle {
                    id: tabBtn; required property var modelData
                    readonly property bool active: root.netMode === tabBtn.modelData.id
                    Layout.preferredHeight: 22
                    Layout.preferredWidth:  tabLbl.implicitWidth + 16
                    radius: height/2
                    color: tabBtn.active
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                        : Qt.rgba(1,1,1,0.05)
                    border.color: tabBtn.active ? root.colorAccent : "transparent"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { id: tabLbl; anchors.centerIn: parent; text: tabBtn.modelData.label
                        color: tabBtn.active ? root.colorAccent : root.colorTextDim
                        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.netMode = tabBtn.modelData.id
                            if (root.netMode === "eth") { if (!ethListProc.running) ethListProc.running = true }
                            else                        { if (!wifiListProc.running) wifiListProc.running = true }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Status
            Text {
                visible:        root.feedback !== "" || root.scanning
                text:           root.scanning ? root.scanLabel : root.feedback
                color:          root.feedback === "Conectado!" ? root.colorAccent
                              : root.feedback !== ""            ? root.colorMuted
                              : root.colorTextDim
                font.pixelSize: 9
            }

            // Scan button (WiFi)
            Rectangle {
                visible: root.netMode === "wifi"
                width: 22; height: 22; radius: 11
                color: root.scanning
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                    : Qt.rgba(1,1,1,0.07)
                border.color: root.scanning ? root.colorAccent : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    id: scanIcon
                    anchors.centerIn: parent; text: "\uf021"
                    color: root.scanning ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"

                    property real spinA: 0
                    Timer { interval: 80; repeat: true; running: root.scanning
                        onTriggered: scanIcon.spinA = (scanIcon.spinA + 15) % 360 }
                    // Rotação usando id explícito (não parent) — corrige o erro de antes
                    transform: Rotation { angle: scanIcon.spinA; origin.x: scanIcon.width/2; origin.y: scanIcon.height/2 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!root.scanning && !rescanProc.running) {
                            root.scanning   = true
                            root.rescanData = ""
                            rescanProc.running = true
                        }
                    }
                }
            }
        }

        // Lista
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; boundsMovement: Flickable.StopAtBounds
            model: root.netMode === "wifi" ? root.wifiNetworks : root.ethConnections
            spacing: 3

            delegate: Item {
                id: netItem
                required property var modelData
                required property int index
                width: ListView.view.width; height: 34

                readonly property bool isWifi:   root.netMode === "wifi"
                readonly property bool isActive: netItem.isWifi
                    ? (netItem.modelData.active === true)
                    : (netItem.modelData.connected === true)
                // Guard contra undefined: signal pode não existir
                readonly property real strength: netItem.isWifi
                    ? Math.max(0, Math.min(1, ((netItem.modelData.signal !== undefined ? netItem.modelData.signal : 0)) / 100))
                    : 1.0
                readonly property int sigPct: netItem.isWifi
                    ? (netItem.modelData.signal !== undefined ? Math.round(netItem.modelData.signal) : 0)
                    : 0

                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: netItem.isActive
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.13)
                        : itemMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.color: netItem.isActive ? root.colorAccent : "transparent"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8

                        Text {
                            text:           netItem.isWifi ? "\uf1eb" : "\uf6ff"
                            font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            opacity:        netItem.isWifi ? 0.15 + 0.85 * netItem.strength : 1.0
                            color:          netItem.isActive ? root.colorAccent : root.colorText
                        }
                        Text {
                            text:  netItem.isWifi
                                   ? ((netItem.modelData.ssid && netItem.modelData.ssid !== "") ? netItem.modelData.ssid : "(oculto)")
                                   : (netItem.modelData.connection || netItem.modelData.device || "")
                            color: netItem.isActive ? root.colorAccent : root.colorText
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible:        netItem.isWifi && netItem.modelData.secured === true
                            text:           "\uf023"
                            color:          root.colorTextDim; font.pixelSize: 9
                            font.family:    "JetBrainsMono Nerd Font"
                        }
                        Text {
                            visible:        netItem.isActive
                            text:           "conectado"; color: root.colorAccent; font.pixelSize: 8
                        }
                        Text {
                            visible:        !netItem.isActive && netItem.isWifi && netItem.sigPct > 0
                            text:           netItem.sigPct + "%"
                            color:          root.colorTextDim; font.pixelSize: 8
                        }
                        // Estado da ethernet (disconnected, unavailable)
                        Text {
                            visible:        !netItem.isWifi && !netItem.isActive
                            text:           netItem.isWifi ? "" : (netItem.modelData.state || "")
                            color:          root.colorTextDim; font.pixelSize: 8; opacity: 0.6
                        }
                    }

                    MouseArea {
                        id: itemMA; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (netItem.isWifi) {
                                if (netItem.modelData.active) {
                                    // Desconectar: desativa o dispositivo wifi
                                    disconnectProc.command = [ "bash", "-c",
                                        "LC_ALL=C nmcli device disconnect $(LC_ALL=C nmcli -t -f DEVICE,TYPE d status | grep ':wifi' | head -1 | cut -d: -f1) 2>/dev/null" ]
                                    disconnectProc.running = true
                                } else {
                                    root.feedback = "Conectando\u2026"
                                    feedbackTimer.restart()
                                    var ssid = netItem.modelData.ssid
                                    // Tenta connection salva → connection por senha (sem senha = redes abertas)
                                    connectProc.command = [ "bash", "-c",
                                        "LC_ALL=C nmcli connection up \"" + ssid + "\" 2>/dev/null || " +
                                        "LC_ALL=C nmcli device wifi connect \"" + ssid + "\" 2>/dev/null" ]
                                    connectProc.running = true
                                }
                            } else {
                                // Ethernet: usa a connection salva para o device
                                var dev  = netItem.modelData.device
                                var conn = netItem.modelData.connection
                                if (netItem.modelData.connected) {
                                    ethDisconnectProc.command = [ "bash", "-c",
                                        "LC_ALL=C nmcli connection down \"" + conn + "\" 2>/dev/null" ]
                                    ethDisconnectProc.running = true
                                } else {
                                    ethConnectProc.command = [ "bash", "-c",
                                        "LC_ALL=C nmcli connection up \"" + conn + "\" 2>/dev/null || " +
                                        "LC_ALL=C nmcli device connect \"" + dev + "\" 2>/dev/null" ]
                                    ethConnectProc.running = true
                                    Qt.callLater(function() { if (!ethListProc.running) ethListProc.running = true })
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: (root.netMode === "wifi" ? root.wifiNetworks : root.ethConnections).length === 0
                          && !root.scanning
                Text {
                    anchors.centerIn: parent
                    text: root.netMode === "wifi"
                          ? "\uf1eb  Sem redes — clique \uf021 para buscar"
                          : "\uf6ff  Sem dispositivos Ethernet"
                    color: root.colorTextDim; font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"; opacity: 0.6
                    horizontalAlignment: Text.AlignHCenter; width: parent.width - 20
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
