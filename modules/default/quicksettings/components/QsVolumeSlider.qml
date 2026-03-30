import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// ── Slider de volume (Pipewire defaultAudioSink) ─────────────────────────────
// Versão standalone extraída do VolumeContent para reutilização no QuickSettings.
// Suporta volume até 150% com indicador de over-gain.
Item {
    id: root

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorAccent:     "#ffb4a9"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"
    property color colorMuted:      "#cf6679"

    height: col.implicitHeight

    // ── Nó Pipewire ────────────────────────────────────────────────────────
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    readonly property var  node:    Pipewire.defaultAudioSink
    readonly property real vol:     node && node.audio ? node.audio.volume : 0
    readonly property bool muted:   node && node.audio ? node.audio.muted  : false
    readonly property real maxVol:  1.5
    readonly property real norm100: Math.min(1.0, vol) / maxVol
    readonly property real over100: Math.max(0, vol - 1.0) / maxVol

    // ── Ícone dinâmico de volume ───────────────────────────────────────────
    readonly property string volIcon: {
        if (muted || vol <= 0) return "\uf026"
        if (vol <= 0.33)       return "\uf027"
        return "\uf028"
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
                text:           root.volIcon
                color:          root.muted ? root.colorMuted : root.colorAccent
                font.pixelSize: 13
                font.family:    "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                text:           "Volume"
                color:          root.colorText
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text:                Math.round(root.vol * 100) + "%"
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
            // Marcador de 100%
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * (1.0 / root.maxVol) - 1
                width: 1; height: 6; radius: 1
                color: Qt.rgba(1, 1, 1, 0.2)
            }
            // Preenchimento normal (0–100%)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 4; radius: 2
                width: parent.width * root.norm100
                color: root.muted ? root.colorMuted : root.colorAccent
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            // Preenchimento over 100%
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x:      parent.width * (1.0 / root.maxVol)
                height: 4; radius: 2
                width:  parent.width * root.over100
                color:  root.muted ? root.colorMuted : Qt.rgba(1, 0.5, 0.2, 1.0)
                visible: root.over100 > 0
            }
            // Thumb (visível ao hover)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(parent.width - width,
                     Math.max(0, (root.vol / root.maxVol) * parent.width - width / 2))
                width: 12; height: 12; radius: 6
                color: root.muted          ? root.colorMuted
                     : root.vol > 1.0      ? Qt.rgba(1, 0.5, 0.2, 1.0)
                     : root.colorAccent
                visible: volArea.containsMouse
                scale:   volArea.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation  { duration: 150 } }
            }

            MouseArea {
                id: volArea
                anchors.fill:  parent
                hoverEnabled:  true
                enabled:       root.node !== null
                onClicked:         (m) => _set(m.x)
                onPositionChanged: (m) => { if (pressed) _set(m.x) }
                function _set(x) {
                    var n = root.node
                    if (!n || !n.audio) return
                    n.audio.volume = Math.max(0, Math.min(root.maxVol, x / width * root.maxVol))
                    if (n.audio.volume > 0) n.audio.muted = false
                }
            }
        }
    }
}
