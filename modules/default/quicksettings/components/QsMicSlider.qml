import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// ── QsMicSlider ───────────────────────────────────────────────────────────────
// Slider de volume do microfone (Pipewire defaultAudioSource). Espelha o
// QsVolumeSlider (saída), mas para entrada — sem suporte a over-100%, já que
// ganho de microfone acima de 100% raramente é desejado e adiciona ruído.
Item {
    id: root

    property color colorAccent:     "#ffb4a9"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"
    property color colorMuted:      "#cf6679"

    height: col.implicitHeight

    PwObjectTracker { objects: [ Pipewire.defaultAudioSource ] }

    readonly property var  node:  Pipewire.defaultAudioSource
    readonly property real vol:   node && node.audio ? node.audio.volume : 0
    readonly property bool muted: node && node.audio ? node.audio.muted  : false

    readonly property string micIcon: (muted || vol <= 0) ? "\uf131" : "\uf130"

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 5

        RowLayout {
            Layout.fillWidth: true; spacing: 6

            Rectangle {
                implicitWidth: 24; implicitHeight: 24; radius: 12
                color: root.muted ? root.colorMuted : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: micMuteMA.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text:           root.micIcon
                    color:          root.muted ? "#1a1a1a" : root.colorAccent
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: micMuteMA
                    anchors.fill: parent; anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.node !== null
                    onClicked: {
                        if (root.node && root.node.audio) root.node.audio.muted = !root.node.audio.muted
                    }
                }
            }
            Text { text: "Microfone"; color: root.colorText; font.pixelSize: 10; Layout.fillWidth: true }
            Text {
                text: Math.round(root.vol * 100) + "%"
                color: root.colorTextDim; font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            Layout.fillWidth: true; height: 18

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 4; radius: 2
                width: parent.width * Math.min(1.0, root.vol)
                color: root.muted ? root.colorMuted : root.colorAccent
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(parent.width - width, Math.max(0, root.vol * parent.width - width / 2))
                width: 12; height: 12; radius: 6
                color: root.muted ? root.colorMuted : root.colorAccent
                visible: micArea.containsMouse
                scale: micArea.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: micArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.node !== null
                onClicked:         (m) => _set(m.x)
                onPositionChanged: (m) => { if (pressed) _set(m.x) }
                function _set(x) {
                    var n = root.node
                    if (!n || !n.audio) return
                    n.audio.volume = Math.max(0, Math.min(1.0, x / width))
                    if (n.audio.volume > 0) n.audio.muted = false
                }
            }
        }
    }
}
