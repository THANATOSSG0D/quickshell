import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsShaderStatus ────────────────────────────────────────────────────────────
// Mostra o shader ativo (hyprshade current) e o modo (auto/manual/off, lido
// de ~/.cache/hyprnight/shader-mode) e permite trocar entre os shaders
// disponíveis (hyprshade ls) ou voltar para automático/desligado.
//
// Toda a lógica de troca de modo (parar timers concorrentes, salvar estado,
// lembrar o último modo ativo) vive em ~/.config/hypr/scripts/hyprshade-selector
// — este componente só LÊ o estado e CHAMA o script, nunca escreve direto no
// cache ou chama hyprshade/systemctl por conta própria.
Item {
    id: root

    readonly property string scriptPath: "/home/antonio/.config/hypr/scripts/hyprshade-selector"

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property string currentShader: ""   // nome do shader ativo, "" se nenhum
    property string mode:           ""   // "auto" | "off" | "manual:<nome>"
    property var    available:      []
    property bool   loading:        false

    property int  gamma:        100   // 0-100, lido via hyprctl hyprsunset gamma
    property bool gammaDragging: false

    readonly property string modeLabel: {
        if (root.mode === "auto") return "Automático (ciclo dia/noite)"
        if (root.mode === "off")  return "Desligado"
        if (root.mode.startsWith("manual:")) return "Manual"
        return "—"
    }

    function refresh() {
        if (statusProc.running) return
        root.loading = true
        statusProc.command = ["bash", "-c",
            "hyprshade current 2>/dev/null; echo '---'; " +
            "cat ~/.cache/hyprnight/shader-mode 2>/dev/null; echo '---'; " +
            "hyprshade ls 2>/dev/null; echo '---'; " +
            "hyprctl hyprsunset gamma 2>/dev/null"]
        statusProc.running = true
    }

    function setAuto() {
        applyProc.command = [root.scriptPath, "auto"]
        applyProc.running = true
        refreshDelay.restart()
    }

    function setOff() {
        applyProc.command = [root.scriptPath, "off"]
        applyProc.running = true
        refreshDelay.restart()
    }

    function setManual(name) {
        applyProc.command = [root.scriptPath, "manual", name]
        applyProc.running = true
        refreshDelay.restart()
    }

    function setGamma(value) {
        root.gamma = Math.round(value)
        gammaApplyProc.command = ["bash", "-c", "hyprctl hyprsunset gamma " + root.gamma + " 2>/dev/null"]
        gammaApplyProc.running = true
    }

    Process {
        id: statusProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => statusProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = statusProc._buf.split("---"); statusProc._buf = ""
            root.loading = false
            if (parts.length < 4) return
            root.currentShader = parts[0].trim()
            root.mode          = parts[1].trim()
            var list = parts[2].trim().split("\n")
                .map(function(s) { return s.trim() })
                .filter(function(s) { return s !== "" })
            root.available = list
            var g = parseInt(parts[3].trim())
            if (!root.gammaDragging && !isNaN(g)) root.gamma = g
        }
    }

    Process { id: applyProc }
    Process { id: gammaApplyProc }
    Timer { id: refreshDelay; interval: 500; onTriggered: root.refresh() }

    Component.onCompleted: refresh()

    // Lista unificada: "Automático", "Desligado" e cada shader manual, todos
    // como itens de uma única lista (em vez de botões separados + sub-lista).
    readonly property var menuItems: {
        var items = [
            { kind: "auto", id: "auto", icon: "\uf017", label: "Automático (ciclo dia/noite)" },
            { kind: "off",  id: "off",  icon: "\uf28d", label: "Desligado" }
        ]
        for (var i = 0; i < root.available.length; i++) {
            items.push({ kind: "manual", id: root.available[i], icon: "\uf185", label: root.available[i] })
        }
        return items
    }

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        // ── Status atual (linha única e compacta) ───────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                width: 8; height: 8; radius: 4
                color: root.currentShader !== "" ? "#a6e3a1" : "#6c7086"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                text: root.currentShader !== "" ? root.currentShader : "Nenhum shader ativo"
                color: root.colorText; font.pixelSize: 11; font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: root.modeLabel
                color: root.colorTextDim; font.pixelSize: 9
            }
        }

        // ── Lista única de opções (Automático, Desligado, shaders manuais) ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(40, shCol.implicitHeight + 16)
            radius: 8; color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

            Column {
                id: shCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 3

                Repeater {
                    model: root.menuItems
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive:
                            modelData.kind === "manual" ? root.mode === "manual:" + modelData.id
                                                         : root.mode === modelData.id
                        width: parent.width; height: 30; radius: 6
                        color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                            : (itMA.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        scale: itMA.pressed ? 0.985 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Row {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8
                            Text { anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                color: isActive ? root.colorAccent : root.colorTextDim
                                font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label
                                color: isActive ? root.colorAccent : root.colorText
                                font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        MouseArea { id: itMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.kind === "auto")        root.setAuto()
                                else if (modelData.kind === "off")    root.setOff()
                                else                                  root.setManual(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // ── Slider de gamma (hyprctl hyprsunset gamma) ───────────────────────
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    implicitWidth: 22; implicitHeight: 22; radius: 11
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                    Text { anchors.centerIn: parent; text: "\uf042"; color: root.colorAccent
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                }
                Text { text: "Gamma"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                Text { text: root.gamma + "%"; color: root.colorAccent; font.pixelSize: 11; font.weight: Font.Light }
            }

            Item {
                Layout.fillWidth: true; implicitHeight: 18

                Rectangle {
                    id: gammaTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                }
                Rectangle {
                    anchors.verticalCenter: gammaTrack.verticalCenter
                    width: Math.max(gammaThumb.width / 2, (root.gamma / 100) * gammaTrack.width)
                    height: gammaTrack.height; radius: gammaTrack.radius
                    color: root.colorAccent
                    Behavior on width { NumberAnimation { duration: gammaMA.pressed ? 0 : 200 } }
                }
                Rectangle {
                    id: gammaThumb
                    anchors.verticalCenter: gammaTrack.verticalCenter
                    x: (root.gamma / 100) * (gammaTrack.width - width)
                    width: 12; height: 12; radius: 6
                    color: "white"
                    border.color: Qt.rgba(1, 1, 1, 0.3); border.width: 1
                    scale: gammaMA.pressed ? 1.2 : 1.0
                    Behavior on x     { NumberAnimation { duration: gammaMA.pressed ? 0 : 200 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }
                }

                MouseArea {
                    id: gammaMA
                    anchors { fill: gammaTrack; margins: -10 }
                    preventStealing: true
                    cursorShape: Qt.SizeHorCursor
                    onPressed:  (m) => { root.gammaDragging = true; _drag(m.x) }
                    onPositionChanged: (m) => { if (pressed) _drag(m.x) }
                    onReleased: (m) => { _drag(m.x); root.setGamma(root.gamma); root.gammaDragging = false }
                    function _drag(mx) {
                        var r = Math.max(0, Math.min(1, mx / gammaTrack.width))
                        root.gamma = Math.round(r * 100)
                    }
                }
            }
        }
    }
}
