import QtQuick
import QtQuick.Layouts

// ── Barra de abas estilo pill ────────────────────────────────────────────────
// Idêntica ao VolumeContent: Rectangle radius height/2, border accent quando ativo,
// fundo colorAccent alpha 0.2 ativo / Qt.rgba(1,1,1,0.05) inativo.
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

    implicitHeight: 22

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: tabPill
                required property var modelData

                readonly property bool active: root.activeTab === tabPill.modelData.id

                Layout.preferredHeight: 22
                Layout.preferredWidth:  tabLabel.implicitWidth + 14
                radius:       height / 2
                color: tabPill.active
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                    : Qt.rgba(1, 1, 1, 0.05)
                border.color: tabPill.active ? root.colorAccent : "transparent"
                border.width: 1

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text:           tabPill.modelData.label
                    color:          tabPill.active ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 10
                    font.family:    "JetBrainsMono Nerd Font"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    root.tabClicked(tabPill.modelData.id)
                }
            }
        }

        // Espaço flexível à direita
        Item { Layout.fillWidth: true }
    }
}
