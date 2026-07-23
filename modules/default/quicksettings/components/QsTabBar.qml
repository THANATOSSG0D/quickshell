import QtQuick
import QtQuick.Layouts

// ── Barra de abas estilo segmented control ──────────────────────────────────
// Abas com largura igual, ocupando a linha inteira; a ativa vira um pill
// sólido preenchido de accent (não só um tint) — mais "seletor de central de
// controle" do que "menu de texto colorido".
// Uso: passe tabs como [{id, label}] e conecte onTabClicked(id).
Item {
    id: root

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorAccent:  "#ffb4a9"
    property color colorTextDim: "#c6c6c6"

    // ── Dados das abas ─────────────────────────────────────────────────────
    property var    tabs:      []   // [{id: string, label: string}]
    property string activeTab: ""

    signal tabClicked(string tabId)

    implicitHeight: 28

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: tabPill
                required property var modelData

                readonly property bool active: root.activeTab === tabPill.modelData.id

                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: height / 2
                color: tabPill.active ? root.colorAccent : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                scale: tabMa.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text:           tabPill.modelData.label
                    color:          tabPill.active ? "#1a1a1a" : root.colorTextDim
                    font.pixelSize: 10
                    font.weight:    tabPill.active ? Font.DemiBold : Font.Normal
                    font.family:    "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: tabMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked:   root.tabClicked(tabPill.modelData.id)
                }
            }
        }
    }
}
