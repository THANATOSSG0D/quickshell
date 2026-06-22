import QtQuick
import QtQuick.Layouts

// ── QsNavRow ──────────────────────────────────────────────────────────────────
// Linha clicável simples que navega para uma página de detalhe — sem switch,
// sem estado ligado/desligado. Usada na home para itens como "Display" e
// "Sistema", que não têm um conceito de on/off.
//
// USO:
//   QsNavRow {
//       icon: "\uf185"; label: "Display"; sub: "Modo noturno · Brilho · Térmico"
//       colorAccent: ...; colorText: ...; colorTextDim: ...
//       onClicked: root.currentPage = "display"
//   }
Item {
    id: root

    property string icon:        ""
    property string label:       ""
    property string sub:         ""   // texto pequeno de apoio, ex.: resumo do que tem dentro
    property color  colorAccent: "#ffb4a9"
    property color  colorText:   "#e2e2e2"
    property color  colorTextDim:"#c6c6c6"

    signal clicked()

    implicitHeight: 46

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: ma.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.06)
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10

            Text {
                text: root.icon
                color: root.colorAccent
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    text: root.label; color: root.colorText
                    font.pixelSize: 11; font.weight: Font.Medium
                }
                Text {
                    visible: root.sub.length > 0
                    text: root.sub; color: root.colorTextDim
                    font.pixelSize: 9; elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                text: "\uf105"   // nf-fa-chevron_right
                color: root.colorTextDim
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
