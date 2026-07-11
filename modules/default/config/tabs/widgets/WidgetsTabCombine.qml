import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabCombine.qml → modules/widgets/
import '../../../../widgets' as Shared

Item {
  id: root

  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  anchors.fill: parent

  Shared.WidgetLayoutConfig { id: layoutCfg }

  readonly property var _allWidgets: [
    { id: "clock",    label: "Relógio"         },
    { id: "todo",     label: "Lista de tarefas" },
    { id: "calendar", label: "Calendário"       },
    { id: "weather",  label: "Clima"            },
  ]

  C.CfgScroll {

    C.CfgSection { title: "MODO COMBINADO"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Junta os widgets marcados abaixo num único card, empilhados na ordem escolhida, " +
            "com divisores em vez de flutuar cada um separado. Widgets fora do grupo continuam " +
            "aparecendo do jeito de sempre, na posição individual deles."
    }

    C.CfgToggle {
      label: "Ativar modo combinado"
      checked: layoutCfg.groupEnabled
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: layoutCfg.groupEnabled = !layoutCfg.groupEnabled
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "POSIÇÃO DO GRUPO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: layoutCfg.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => layoutCfg.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: layoutCfg.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => layoutCfg.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "WIDGETS NO GRUPO"; colorTextDim: root.colorTextDim }

    ColumnLayout {
      width: parent.width
      spacing: 4

      Repeater {
        model: root._allWidgets
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 8

          readonly property int memberIndex: layoutCfg.members.indexOf(modelData.id)
          readonly property bool included: memberIndex !== -1

          Rectangle {
            width: 16; height: 16; radius: 4
            border.width: 1.5
            border.color: parent.included ? root.colorAccent : root.colorTextDim
            color: parent.included ? root.colorAccent : "transparent"
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: layoutCfg.toggleMember(modelData.id)
            }
          }

          Text {
            Layout.fillWidth: true
            text: modelData.label + (parent.included ? "  ·  posição " + (parent.memberIndex + 1) : "")
            color: root.colorText
            font.pixelSize: 12
          }

          Text {
            visible: parent.included
            text: "▲"
            color: root.colorTextDim
            font.pixelSize: 9
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: layoutCfg.moveMember(modelData.id, -1)
            }
          }
          Text {
            visible: parent.included
            text: "▼"
            color: root.colorTextDim
            font.pixelSize: 9
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: layoutCfg.moveMember(modelData.id, 1)
            }
          }
        }
      }

      Text {
        visible: layoutCfg.members.length === 0
        text: "Nenhum widget selecionado — marque acima pra montar o grupo."
        color: root.colorTextDim
        font.pixelSize: 11
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "desativar modo combinado"
      onClicked: {
        layoutCfg.groupEnabled = false
        layoutCfg.members = []
        layoutCfg.position = 4
        layoutCfg.edgeMargin = 48
      }
    }
  }
}
