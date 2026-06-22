import QtQuick
import QtQuick.Layouts

// ── QsCollapsibleCard ─────────────────────────────────────────────────────────
// Card com cabeçalho clicável (ícone + título + chevron) que expande/colapsa
// o conteúdo. Pensado para uso em estilo "accordion": o pai controla qual
// card fica aberto setando `expanded` de cada um (só um true por vez).
//
// USO:
//   QsCollapsibleCard {
//       title: "EasyEffects"; icon: "\uf028"
//       expanded: root.openCard === "easyeffects"
//       onToggleRequested: root.openCard = (root.openCard === "easyeffects") ? "" : "easyeffects"
//       contentItem: Qs.QsEasyEffects { ... }
//   }
Item {
    id: root

    property string title:       ""
    property string icon:        ""
    property string subtitle:    ""   // texto pequeno ao lado do título, ex.: status resumido
    property bool   expanded:    false
    property color  colorAccent:  "#ffb4a9"
    property color  colorText:    "#e2e2e2"
    property color  colorTextDim: "#c6c6c6"

    // O conteúdo a ser mostrado quando expandido — definido pelo usuário do
    // componente via "default property alias".
    default property alias contentChildren: contentHolder.children

    signal toggleRequested()

    implicitHeight: bg.implicitHeight

    Rectangle {
        id: bg
        anchors.left: parent.left; anchors.right: parent.right
        implicitHeight: headerRow.implicitHeight + 20 + (root.expanded ? contentHolder.implicitHeight + 14 : 0)
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: root.expanded ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3) : "transparent"
        border.width: 1

        Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: root.expanded ? 14 : 0

            RowLayout {
                id: headerRow
                Layout.fillWidth: true; spacing: 8

                Text {
                    text: root.icon
                    color: root.expanded ? root.colorAccent : root.colorText
                    font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    text: root.title
                    color: root.expanded ? root.colorAccent : root.colorText
                    font.pixelSize: 11; font.weight: Font.Medium
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    visible: root.subtitle !== "" && !root.expanded
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: root.colorTextDim
                    font.pixelSize: 9; elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                }
                Item { Layout.fillWidth: true; visible: root.expanded || root.subtitle === "" }

                Text {
                    text: "\uf078"   // chevron-down
                    color: root.colorTextDim
                    font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 160 } }
                }
            }

            Item {
                id: contentHolder
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                visible: root.expanded
                clip: true

                // implicitHeight segue o filho único injetado via default alias
                implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            }
        }

        MouseArea {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: headerRow.implicitHeight + 20
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleRequested()
        }
    }
}
