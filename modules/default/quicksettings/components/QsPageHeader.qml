import QtQuick
import QtQuick.Layouts

// ── QsPageHeader ──────────────────────────────────────────────────────────────
// Cabeçalho fixo usado em todas as páginas de detalhe (Wi-Fi, Bluetooth,
// Sistema, Display, Mídia, etc.). Mostra um botão de voltar (seta) + título,
// e opcionalmente um botão de ação à direita (ex.: refresh).
//
// USO:
//   QsPageHeader {
//       Layout.fillWidth: true
//       title: "Wi-Fi"
//       icon:  "\uf1eb"
//       colorAccent: ...; colorText: ...; colorTextDim: ...
//       onBackClicked: root.currentPage = "home"
//   }
Item {
    id: root

    property string title:       ""
    property string icon:        ""
    property color  colorAccent: "#ffb4a9"
    property color  colorText:   "#e2e2e2"
    property color  colorTextDim:"#c6c6c6"

    // Botão de ação opcional à direita (ex.: refresh). Vazio = escondido.
    property string actionIcon:  ""
    signal backClicked()
    signal actionClicked()

    implicitHeight: 32

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // ── Botão voltar ────────────────────────────────────────────────
        Rectangle {
            id: backBtn
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 8
            color: backMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "\uf060"   // nf-fa-arrow_left
                color: root.colorText
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
            }
            MouseArea {
                id: backMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backClicked()
            }
        }

        // ── Ícone + título ──────────────────────────────────────────────
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.colorAccent
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
        }
        Text {
            text: root.title
            color: root.colorText
            font.pixelSize: 13
            font.weight: Font.Medium
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // ── Botão de ação opcional ──────────────────────────────────────
        Rectangle {
            visible: root.actionIcon.length > 0
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 8
            color: actionMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: root.actionIcon
                color: root.colorTextDim
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
            MouseArea {
                id: actionMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionClicked()
            }
        }
    }
}
