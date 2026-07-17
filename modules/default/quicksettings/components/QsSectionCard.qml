import QtQuick
import QtQuick.Layouts

// ── QsSectionCard ────────────────────────────────────────────────────────────
// Card estático só pra agrupamento visual — sem header clicável, sem
// expandir/colapsar (isso é o QsCollapsibleCard, pensado pra outra coisa:
// accordion de EasyEffects/etc.). Este aqui é só um "fundo com borda" que dá
// hierarquia visual pra um conjunto de widgets, tipo as seções do Dashboard.
//
// USO:
//   Qs.QsSectionCard {
//       Layout.fillWidth: true
//       title: "Hoje"; colorTextDim: root.colorTextDim
//
//       RowLayout { Layout.fillWidth: true; ... }
//       Qs.QsCalendar { Layout.fillWidth: true; ... }
//   }
//
// Qualquer item declarado dentro do bloco vira filho direto do ColumnLayout
// interno — pode usar Layout.fillWidth/Layout.preferredHeight normalmente,
// igual usaria dentro de qualquer outro ColumnLayout.
Rectangle {
    id: root

    property string title:       ""   // rótulo pequeno no topo; "" esconde
    property color  colorTextDim: "#c6c6c6"
    property int    contentSpacing: 8

    radius: 12
    color: Qt.rgba(1, 1, 1, 0.045)
    border.color: Qt.rgba(1, 1, 1, 0.07)
    border.width: 1

    implicitHeight: innerCol.implicitHeight + innerCol.anchors.topMargin + innerCol.anchors.bottomMargin

    // Filhos declarados pelo usuário do componente entram aqui, depois do
    // título (que já existe fixo dentro do ColumnLayout).
    default property alias content: innerCol.data

    ColumnLayout {
        id: innerCol
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: 10
        }
        spacing: root.contentSpacing

        Text {
            visible: root.title !== ""
            Layout.fillWidth: true
            text: root.title
            color: root.colorTextDim
            font.pixelSize: 9
            font.weight: Font.DemiBold
            opacity: 0.65
        }
    }
}
