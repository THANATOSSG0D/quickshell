import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Seção: Modo Noturno ───────────────────────────────────────────────────────
// Combina dois controles:
//   1. Hyprshade  — ativa/desativa o shader nightcycle (escurecimento de tela)
//   2. Hyprsunset — slider de temperatura de cor (2700K–6500K) via hyprctl
//
// O script ~/.config/hypr/scripts/hyprsunset.sh pode ser chamado manualmente
// para restaurar o modo automático baseado em horário solar.
Item {
    id: root

    property color colorAccent:     "#ffb4a9"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"
    property bool  panelOpen:       false

    onPanelOpenChanged: { if (panelOpen) shadeProc.running = true }

    height: col.implicitHeight

    // ── Hyprshade ─────────────────────────────────────────────────────────
    property bool shadeActive: false

    Process { id: shadeProc;       command: [ "hyprshade", "current" ] }
    Process { id: shadeToggleProc }

    readonly property bool shadeDetected: (shadeProc.stdout || "").trim() === "nightcycle"
    onShadeDetectedChanged: shadeActive = shadeDetected

    Component.onCompleted: shadeProc.running = true

    function _toggleShade() {
        shadeToggleProc.command = shadeActive
            ? [ "hyprshade", "off" ]
            : [ "hyprshade", "on", "nightcycle" ]
        shadeToggleProc.running = true
        shadeActive = !shadeActive
    }

    // ── Hyprsunset — temperatura de cor ───────────────────────────────────
    // Slider de 2700K (quente/noite) a 6500K (frio/dia)
    property int  sunsetTemp:  4000
    property bool sunsetManual: false   // true quando o usuário mexeu no slider

    Process { id: sunsetProc }

    function _applyTemp(k) {
        sunsetProc.command = [ "hyprctl", "hyprsunset", "temperature", String(k) ]
        sunsetProc.running = true
    }

    function _resetSunset() {
        // Restaura o modo automático baseado no horário solar
        sunsetProc.command = [
            "bash", "-c",
            "$HOME/.config/hypr/scripts/hyprsunset.sh"
        ]
        sunsetProc.running = true
        sunsetManual = false
        sunsetTemp   = 4000
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: 8

        // Título
        Text {
            text:                "Modo Noturno"
            color:               root.colorTextDim
            font.pixelSize:      9
            font.capitalization: Font.AllUppercase
        }

        // ── Toggle Hyprshade ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text:           "\uf186"   // fa-moon-o
                color:          root.shadeActive ? root.colorAccent : root.colorText
                font.pixelSize: 13
                font.family:    "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text:           "Shader Noturno"
                    color:          root.colorText
                    font.pixelSize: 10
                }
                Text {
                    text:           root.shadeActive ? "nightcycle ativado" : "desativado"
                    color:          root.colorTextDim
                    font.pixelSize: 9
                    opacity:        0.7
                }
            }

            // Toggle pill
            Rectangle {
                id: shadePill
                width: 38; height: 20; radius: 10
                color: root.shadeActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
                    : Qt.rgba(1, 1, 1, 0.1)
                Behavior on color { ColorAnimation { duration: 200 } }

                Rectangle {
                    x:      root.shadeActive ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width:  14; height: 14; radius: 7
                    color:  root.shadeActive ? root.colorAccent : root.colorTextDim
                    Behavior on x     { NumberAnimation  { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation   { duration: 200 } }
                }
                MouseArea { anchors.fill: parent; onClicked: root._toggleShade() }
            }
        }

        // ── Slider de temperatura ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:           "\uf2c9"   // fa-thermometer
                    color:          root.colorAccent
                    font.pixelSize: 13
                    font.family:    "JetBrainsMono Nerd Font"
                }
                Text {
                    text:           "Temperatura"
                    color:          root.colorText
                    font.pixelSize: 10
                    Layout.fillWidth: true
                }
                Text {
                    text:                root.sunsetTemp + "K"
                    color:               root.sunsetManual ? root.colorAccent : root.colorTextDim
                    font.pixelSize:      10
                    horizontalAlignment: Text.AlignRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Slider 2700K – 6500K
            Item {
                id: tempSliderItem
                Layout.fillWidth: true
                height: 18

                readonly property real minT: 2700
                readonly property real maxT: 6500
                readonly property real pct:  (root.sunsetTemp - minT) / (maxT - minT)

                // Gradiente de cor: quente (laranja) → frio (azul)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ff8c00" }
                        GradientStop { position: 0.5; color: root.colorAccent }
                        GradientStop { position: 1.0; color: "#88c0f8" }
                    }
                    opacity: 0.35
                }
                // Preenchimento atual
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4; radius: 2
                    width: parent.width * tempSliderItem.pct
                    color: {
                        var p = tempSliderItem.pct
                        if (p < 0.5) return Qt.rgba(1, 0.55 + p * 0.45, 0, 1)
                        return root.colorAccent
                    }
                }
                // Thumb
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.min(parent.width - width,
                         Math.max(0, tempSliderItem.pct * parent.width - width/2))
                    width: 12; height: 12; radius: 6
                    color:   root.colorAccent
                    visible: tempArea.containsMouse || tempArea.pressed
                    scale:   tempArea.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                }

                MouseArea {
                    id: tempArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked:         (m) => _set(m.x)
                    onPositionChanged: (m) => { if (pressed) _set(m.x) }
                    function _set(x) {
                        var p   = Math.max(0, Math.min(1, x / width))
                        var minT = tempSliderItem.minT; var maxT = tempSliderItem.maxT
                        // Arredonda para múltiplo de 100K
                        var raw = minT + p * (maxT - minT)
                        root.sunsetTemp  = Math.round(raw / 100) * 100
                        root.sunsetManual = true
                        root._applyTemp(root.sunsetTemp)
                    }
                }
            }

            // Linha inferior: labels + botão reset
            RowLayout {
                Layout.fillWidth: true
                Text { text: "2700K"; color: "#ff8c00"; font.pixelSize: 8; opacity: 0.7 }
                Item { Layout.fillWidth: true }
                // Botão "Auto" — restaura modo baseado em horário solar
                Text {
                    visible:        root.sunsetManual
                    text:           "\uf021  Auto"
                    color:          root.colorTextDim
                    font.pixelSize: 9
                    font.family:    "JetBrainsMono Nerd Font"
                    opacity:        0.8
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root._resetSunset() }
                }
                Item { Layout.fillWidth: true }
                Text { text: "6500K"; color: "#88c0f8"; font.pixelSize: 8; opacity: 0.7 }
            }
        }
    }
}
