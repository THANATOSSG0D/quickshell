import QtQuick
import QtQuick.Layouts
import '../../components' as C

GridLayout {
  id: root
  columns: 3
  rowSpacing: 6; columnSpacing: 6

  property int value: 4
  property color colorAccent
  property color colorTextDim
  signal selected(int index)

  readonly property var _labels: [
    "Superior esquerdo", "Superior centro", "Superior direito",
    "Centro esquerdo",   "Centro",          "Centro direito",
    "Inferior esquerdo", "Inferior centro", "Inferior direito",
  ]

  Repeater {
    model: 9
    delegate: C.CfgChip {
      required property int index
      Layout.fillWidth: true
      label:  root._labels[index]
      active: root.value === index
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onChipClicked: root.selected(index)
    }
  }
}
