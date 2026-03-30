import QtQuick
import QtQuick.Layouts

// ── Tile de toggle genérico (WiFi, Bluetooth, DND, etc.) ────────────────────
// Expõe: icon, label, badge, active, onToggled()
// Cores são todas injetadas pelo pai.
Item {
    id: root

    // ── Props de conteúdo ──────────────────────────────────────────────────
    property string icon:   ""
    property string label:  ""
    property string badge:  ""   // texto pequeno abaixo do label (ex.: SSID)
    property bool   active: false

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    signal toggled()

    // ── Visual ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 12

        color: root.active
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
            : Qt.rgba(1, 1, 1, 0.07)

        border.color: root.active ? root.colorAccent : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 10
            spacing: 3

            // ── Ícone ──────────────────────────────────────────────────
            Text {
                text:            root.icon
                color:           root.active ? root.colorAccent : root.colorText
                font.pixelSize:  13
                font.family:     "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // ── Label principal ────────────────────────────────────────
            Text {
                text:           root.label
                color:          root.active ? root.colorAccent : root.colorText
                font.pixelSize: 10
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // ── Badge de estado ────────────────────────────────────────
            Text {
                visible:        root.badge !== ""
                text:           root.badge
                color:          root.active ? root.colorAccent : root.colorTextDim
                font.pixelSize: 9
                elide:          Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item { Layout.fillHeight: true }
        }

        MouseArea {
            anchors.fill: parent
            onClicked:    root.toggled()
        }
    }
}
