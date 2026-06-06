import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  required property string localWsStyle
  required property string localWsSort
  required property bool   localWsMono
  required property int    localWsSpacing
  required property bool   localWsAddBtn
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg

  signal changed(var opts)

  C.CfgSection { title: "ESTILO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "icons",  label: "Ícones" },
        { id: "dots",   label: "Dots"   },
        { id: "hybrid", label: "Hybrid" },
        { id: "number", label: "Número" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label; active: root.localWsStyle === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ wsStyle: modelData.id })
      }
    }
  }

  C.CfgSection { title: "ORDENAÇÃO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "position",     label: "Posição"    },
        { id: "alphabetical", label: "Alfabética" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label; active: root.localWsSort === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ wsIconsSort: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorTextDim }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Ícones monocromáticos"; checked: root.localWsMono
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsIconMonochrome: !root.localWsMono })
  }
  C.CfgToggle {
    label: "Botão + workspaces"; checked: root.localWsAddBtn
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsShowAddButton: !root.localWsAddBtn })
  }

  C.CfgDiv { colorDivider: root.colorTextDim }
  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Espaçamento ícones"; value: root.localWsSpacing
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsIconSpacing: v })
  }
}
