import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsWifiList ────────────────────────────────────────────────────────────────
// Lista de redes Wi-Fi com scan, busca e connect/disconnect (com dialog de
// senha quando necessário). Extraído do antigo QsTabNetworks, que misturava
// Wi-Fi e Ethernet — agora Wi-Fi vive na sua própria sub-página.
//
// NÃO faz toggle de rádio Wi-Fi — isso é responsabilidade da página pai
// (QsSwitch conectado a root._toggleWifi()).
//
// Props de entrada:  wifiEnabled, wifiListRaw, wifiScanning
// Signals de saída:  requestScan, requestRefresh
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    property bool   wifiEnabled:  false
    property string wifiListRaw:  ""
    property bool   wifiScanning: false

    signal requestScan()
    signal requestRefresh()

    property string filterText:     ""
    property string feedback:       ""
    property string pendingSsid:    ""
    property bool   showPassDialog: false

    // ── Processos de connect/disconnect ────────────────────────────────────
    // Agora capturamos stdout E stderr: o network-ctl.sh corrigido devolve
    // motivo real de falha em stderr (ex.: agente do PolicyKit ausente),
    // em vez de a UI mostrar sempre "verifique a senha" pra qualquer erro.
    Process {
        id: connectProc
        property string _buf: ""
        property string _errBuf: ""
        stdout: SplitParser { onRead: (l) => connectProc._buf += l + "\n" }
        stderr: SplitParser { onRead: (l) => connectProc._errBuf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                var out  = connectProc._buf
                var err  = connectProc._errBuf
                var code = connectProc.exitCode !== undefined ? connectProc.exitCode : -1
                connectProc._buf = ""; connectProc._errBuf = ""
                if (out.indexOf("NEED_PASS") >= 0) {
                    root.feedback = ""
                    root.showPassDialog = true
                    Qt.callLater(function() { passInput.forceActiveFocus() })
                } else if (code === 0 || out.indexOf("successfully") >= 0 || out.indexOf("OK|") >= 0) {
                    root.feedback = "Conectado!"
                    feedbackTimer.restart()
                    root.requestRefresh()
                } else {
                    root.feedback = root._parseErr(err) || "Falha ao conectar"
                    feedbackTimer.restart()
                }
            }
        }
    }

    Process {
        id: passConnectProc
        property string _buf: ""
        property string _errBuf: ""
        stdout: SplitParser { onRead: (l) => passConnectProc._buf += l + "\n" }
        stderr: SplitParser { onRead: (l) => passConnectProc._errBuf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                var out = passConnectProc._buf
                var err = passConnectProc._errBuf
                var code = passConnectProc.exitCode !== undefined ? passConnectProc.exitCode : -1
                passConnectProc._buf = ""; passConnectProc._errBuf = ""
                if (code === 0 && out.indexOf("OK|") >= 0) {
                    root.feedback = "Conectado!"
                } else {
                    root.feedback = root._parseErr(err) || "Senha incorreta"
                }
                feedbackTimer.restart()
                root.requestRefresh()
            }
        }
    }

    // "ERR|mensagem" (em stderr) → só a mensagem, pra mostrar no feedback.
    function _parseErr(raw) {
        var line = raw.trim().split("\n")[0] || ""
        var i = line.indexOf("ERR|")
        return i >= 0 ? line.substring(i + 4) : ""
    }

    Process {
        id: disconnectProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => disconnectProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) { disconnectProc._buf = ""; root.requestRefresh() }
        }
    }

    Process {
        id: editProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => editProc._buf += l + "\n" }
        onRunningChanged: { if (!running) editProc._buf = "" }
    }

    Timer { id: feedbackTimer; interval: 4000; onTriggered: root.feedback = "" }

    // ── Animação de scan ───────────────────────────────────────────────────
    property int scanDot: 0
    Timer {
        id: dotTimer; interval: 300; repeat: true; running: root.wifiScanning
        onTriggered: root.scanDot = (root.scanDot + 1) % 4
    }
    readonly property string scanLabel:
        "Procurando" + ["   ", ".  ", ".. ", "..."][root.scanDot]

    // ── Parsing ─────────────────────────────────────────────────────────────
    // Formato network-ctl.sh wifi list: "<*ou ' '>|SSID|SIGNAL|SECURITY"
    readonly property var wifiNetworks: {
        var lines = root.wifiListRaw.split("\n")
        var result = []; var seen = {}
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln === "") continue
            var p = ln.split("|")
            if (p.length < 4) continue
            var inUse    = p[0].trim() === "*"
            var ssid     = p[1].trim()
            var signal   = parseInt(p[2]) || 0
            var security = p[3].trim()
            if (ssid === "" || ssid === "--" || seen[ssid]) continue
            seen[ssid] = true
            result.push({ ssid: ssid, signal: signal, active: inUse,
                          secured: security !== "" })
        }
        result.sort(function(a, b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            return (b.signal || 0) - (a.signal || 0)
        })
        return result
    }

    readonly property var wifiFiltered: {
        var f = root.filterText.toLowerCase().trim()
        if (f === "") return root.wifiNetworks
        return root.wifiNetworks.filter(function(n) {
            return n.ssid.toLowerCase().indexOf(f) >= 0
        })
    }

    function passDialogConnect() {
        var ssid = root.pendingSsid
        var pass = passInput.text.trim()
        if (ssid === "" || pass === "") return
        root.feedback = "Conectando…"
        feedbackTimer.restart()
        passConnectProc.command = [
            "bash", Quickshell.shellDir + "/scripts/network-ctl.sh",
            "wifi", "connect", ssid, pass
        ]
        passConnectProc.running = true
        root.showPassDialog = false
        passInput.text = ""
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 4

        // Cabeçalho: status do scan + botão scan
        RowLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
                Layout.fillWidth: true
                visible: root.feedback !== "" || root.wifiScanning
                text:    root.wifiScanning ? root.scanLabel : root.feedback
                color:   root.feedback === "Conectado!" ? root.colorAccent
                       : root.feedback !== ""           ? root.colorMuted
                       : root.colorTextDim
                font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }

            Rectangle {
                width: 22; height: 22; radius: 11
                color: root.wifiScanning
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                    : Qt.rgba(1,1,1,0.07)
                border.color: root.wifiScanning ? root.colorAccent : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: 200 } }
                Text {
                    id: scanIcon; anchors.centerIn: parent; text: "\uf021"
                    color: root.wifiScanning ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                    property real spinA: 0
                    Timer { interval: 80; repeat: true; running: root.wifiScanning
                        onTriggered: scanIcon.spinA = (scanIcon.spinA + 15) % 360 }
                    transform: Rotation { angle: scanIcon.spinA
                        origin.x: scanIcon.width/2; origin.y: scanIcon.height/2 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { if (!root.wifiScanning) root.requestScan() }
                }
            }
        }

        // Campo de busca
        Rectangle {
            Layout.fillWidth: true; height: 22; radius: 11
            color: Qt.rgba(1,1,1,0.06)
            border.color: searchInput.activeFocus
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.5)
                : "transparent"
            border.width: 1
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 5
                Text { text: "\uf002"; color: root.colorTextDim; font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                TextInput {
                    id: searchInput; Layout.fillWidth: true
                    color: root.colorText; font.pixelSize: 9
                    selectionColor: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
                    onTextChanged: root.filterText = text
                    Text { anchors.fill: parent; text: "Buscar rede…"; color: root.colorTextDim
                        font.pixelSize: 9; visible: searchInput.text === ""; opacity: 0.45 }
                }
                Text { visible: root.filterText !== ""; text: "\uf00d"
                    color: root.colorTextDim; font.pixelSize: 8
                    font.family: "JetBrainsMono Nerd Font"
                    MouseArea { anchors.fill: parent
                        onClicked: { root.filterText = ""; searchInput.text = "" } } }
            }
        }

        // Lista
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; boundsMovement: Flickable.StopAtBounds
            model: root.wifiFiltered
            spacing: 3

            delegate: Item {
                id: netItem
                required property var modelData
                required property int index
                width: ListView.view.width; height: 34

                readonly property bool isActive: netItem.modelData.active === true
                readonly property real strength: Math.max(0, Math.min(1, (netItem.modelData.signal || 0) / 100))
                readonly property int  sigPct:   Math.round(netItem.modelData.signal || 0)

                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: netItem.isActive
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.13)
                        : itemMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.color: netItem.isActive ? root.colorAccent : "transparent"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    scale: itemMA.pressed ? 0.985 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8

                        Text {
                            text: "\uf1eb"
                            font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.15 + 0.85 * netItem.strength
                            color:   netItem.isActive ? root.colorAccent : root.colorText
                        }
                        Text {
                            text: netItem.modelData.ssid || "(oculto)"
                            color: netItem.isActive ? root.colorAccent : root.colorText
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible: netItem.modelData.secured === true
                            text: "\uf023"; color: root.colorTextDim
                            font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            visible: netItem.isActive
                            text: "conectado"; color: root.colorAccent; font.pixelSize: 8
                        }
                        Text {
                            visible: !netItem.isActive && netItem.sigPct > 0
                            text: netItem.sigPct + "%"; color: root.colorTextDim; font.pixelSize: 8
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
                                    var connName = netItem.modelData.ssid
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
                            if (netItem.modelData.active) {
                                disconnectProc.command = [ "bash", script, "wifi", "disconnect" ]
                                disconnectProc.running = true
                            } else {
                                var ssid = netItem.modelData.ssid
                                root.pendingSsid = ssid
                                root.feedback = "Conectando…"
                                feedbackTimer.restart()
                                // Sempre via network-ctl.sh, seguro ou não —
                                // é lá que mora a lógica de achar o perfil
                                // certo por SSID, registrar a última rede
                                // conectada (pro autoreconnect) e devolver
                                // o motivo real de uma falha (em vez do
                                // "nmcli connection up || echo NEED_PASS"
                                // antigo, que também nunca avisava sobre
                                // falta de agente do PolicyKit).
                                connectProc.command = [ "bash", script, "wifi", "connect", ssid ]
                                connectProc.running = true
                            }
                        }
                    }
                }
            }

            // Lista vazia
            Item {
                anchors.fill: parent
                visible: root.wifiFiltered.length === 0 && !root.wifiScanning
                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!root.wifiEnabled)      return "\uf1eb  Wi-Fi desligado"
                        if (root.filterText !== "") return "\uf002  Sem resultados para \"" +
                                                           root.filterText + "\""
                        return "\uf1eb  Sem redes — clique \uf021 para buscar"
                    }
                    color: root.colorTextDim; font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"; opacity: 0.6
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width - 20; wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ── Dialog de senha ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; visible: root.showPassDialog
        color: Qt.rgba(0, 0, 0, 0.78); radius: 12; z: 10
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.centerIn: parent; width: parent.width - 32; spacing: 10

            Text {
                Layout.fillWidth: true
                text: "\uf023  " + root.pendingSsid
                color: root.colorText; font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true; height: 26; radius: 8
                color: Qt.rgba(1,1,1,0.08)
                border.color: passInput.activeFocus
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.6)
                    : Qt.rgba(1,1,1,0.15)
                border.width: 1
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                    TextInput {
                        id: passInput; Layout.fillWidth: true
                        color: root.colorText; font.pixelSize: 10
                        echoMode: showPassBtn.show ? TextInput.Normal : TextInput.Password
                        selectionColor: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
                        Text { anchors.fill: parent; text: "Senha…"; color: root.colorTextDim
                            font.pixelSize: 10; visible: passInput.text === ""; opacity: 0.5 }
                        Keys.onReturnPressed: root.passDialogConnect()
                        Keys.onEscapePressed: { root.showPassDialog = false; passInput.text = "" }
                    }
                    Text {
                        id: showPassBtn; property bool show: false
                        text: show ? "\uf070" : "\uf06e"
                        color: root.colorTextDim; font.pixelSize: 9
                        font.family: "JetBrainsMono Nerd Font"
                        MouseArea { anchors.fill: parent; onClicked: showPassBtn.show = !showPassBtn.show }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 24; radius: 8
                    color: Qt.rgba(1,1,1,0.07)
                    Text { anchors.centerIn: parent; text: "Cancelar"
                        color: root.colorTextDim; font.pixelSize: 9 }
                    MouseArea { anchors.fill: parent
                        onClicked: { root.showPassDialog = false; passInput.text = "" } }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 24; radius: 8
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                    border.color: root.colorAccent; border.width: 1
                    Text { anchors.centerIn: parent; text: "Conectar"
                        color: root.colorAccent; font.pixelSize: 9 }
                    MouseArea { anchors.fill: parent; onClicked: root.passDialogConnect() }
                }
            }
        }
    }

    // Overlay quando WiFi está desligado
    Rectangle {
        anchors.fill: parent
        visible:      !root.wifiEnabled
        color:        Qt.rgba(0, 0, 0, 0.55)
        radius:       8; z: 99
        Column {
            anchors.centerIn: parent; spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf1eb"; color: root.colorTextDim
                font.pixelSize: 26; font.family: "JetBrainsMono Nerd Font"; opacity: 0.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi desligado"; color: root.colorTextDim
                font.pixelSize: 11; opacity: 0.7
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ative o Wi-Fi acima para ver redes"; color: root.colorTextDim
                font.pixelSize: 9; opacity: 0.45
            }
        }
    }
}
