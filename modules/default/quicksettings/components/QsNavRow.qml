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
    property bool   loading:     false   // true → mostra shimmer no lugar do sub (ex.: "Carregando…")
    property color  colorAccent: "#ffb4a9"
    property color  colorText:   "#e2e2e2"
    property color  colorTextDim:"#c6c6c6"

    signal clicked()

    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: ma.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.06)
        Behavior on color { ColorAnimation { duration: 120 } }

        scale: ma.pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                implicitWidth: 26; implicitHeight: 26
                radius: 13
                color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    color: root.colorAccent
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    text: root.label; color: root.colorText
                    font.pixelSize: 11; font.weight: Font.Medium
                }
                Text {
                    visible: root.sub.length > 0 && !root.loading
                    text: root.sub; color: root.colorTextDim
                    font.pixelSize: 9; elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                QsSkeleton {
                    visible: root.loading
                    active:  root.loading
                    baseColor: root.colorTextDim
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 7
                    Layout.topMargin: 1
                }
            }

            Text {
                text: "\uf105"   // nf-fa-chevron_right
                color: root.colorTextDim
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                x: ma.containsMouse ? 2 : 0
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
