import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Slider de brilho via brightnessctl ──────────────────────────────────────
// Lê o valor atual e máximo ao iniciar; escreve via `brightnessctl set <N>`.
// currentVal e maxVal são bindings sobre (Process.stdout || "").
Item {
    id: root

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorAccent:     "#ffb4a9"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"

    height: col.implicitHeight

    // ── Processos de leitura ───────────────────────────────────────────────
    property real _rawCurrent: 0
    property real _rawMax:     100

    Process {
        id: getProc
        command: [ "brightnessctl", "get" ]
        property string _val: ""
        stdout: SplitParser { onRead: (l) => getProc._val = l.trim() }
        onRunningChanged: { if (!running) root._rawCurrent = parseFloat(getProc._val) || 0 }
    }
    Process {
        id: maxProc
        command: [ "brightnessctl", "max" ]
        property string _val: ""
        stdout: SplitParser { onRead: (l) => maxProc._val = l.trim() }
        onRunningChanged: { if (!running) root._rawMax = parseFloat(maxProc._val) || 100 }
    }
    Process { id: setProc }

    Component.onCompleted: { getProc.running = true; maxProc.running = true }

    property real currentVal: _rawCurrent
    readonly property real maxVal: _rawMax

    readonly property real pct: maxVal > 0 ? Math.max(0, Math.min(1, currentVal / maxVal)) : 0

    // ── Ícone dinâmico de brilho ───────────────────────────────────────────
    readonly property string brightIcon: {
        if (pct < 0.33) return "\uf0eb"   // nf-fa-lightbulb-o (dim)
        if (pct < 0.66) return "\uf185"   // nf-fa-sun-o (médio)
        return "\uf185"                    // nf-fa-sun (cheio)
    }

    ColumnLayout {
        id: col
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: 5

        // ── Cabeçalho: ícone + nome + valor % ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text:           root.brightIcon
                color:          root.colorAccent
                font.pixelSize: 13
                font.family:    "JetBrainsMono Nerd Font"
            }
            Text {
                text:           "Brilho"
                color:          root.colorText
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text:                Math.round(root.pct * 100) + "%"
                color:               root.colorTextDim
                font.pixelSize:      10
                horizontalAlignment: Text.AlignRight
            }
        }

        // ── Track do slider ────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: 18

            // Trilho de fundo
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g,
                               root.colorProgressBg.b, 0.5)
            }
            // Preenchimento
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 4; radius: 2
                width:  parent.width * root.pct
                color:  root.colorAccent
            }
            // Thumb
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(parent.width - width,
                     Math.max(0, root.pct * parent.width - width / 2))
                width: 12; height: 12; radius: 6
                color:   root.colorAccent
                visible: brightArea.containsMouse
                scale:   brightArea.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                id: brightArea
                anchors.fill:  parent
                hoverEnabled:  true
                onClicked:         (m) => _set(m.x)
                onPositionChanged: (m) => { if (pressed) _set(m.x) }
                function _set(x) {
                    var ratio  = Math.max(0, Math.min(1, x / width))
                    var newVal = Math.round(ratio * root.maxVal)
                    root.currentVal = newVal  // atualiza otimisticamente
                    setProc.command = [ "brightnessctl", "set", String(newVal) ]
                    setProc.running = true
                }
            }
        }
    }
}
