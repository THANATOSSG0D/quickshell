import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  required property string pkClkText
  required property string pkClkDim
  required property string pkClkAccent
  required property int    localClkDismiss
  required property var    colors
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg
  required property color  colorSidebar
  required property color  colorDivider
  required property var   overlay

  signal changed(var opts)

  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.pkClkText; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkClkTextColor: v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.pkClkDim; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkClkDimColor: v })
  }
  C.CfgPalette {
    label: "Accent"; value: root.pkClkAccent; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkClkAccentColor: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Dismiss delay"; value: root.localClkDismiss
    from: 1000; to: 30000; step: 500; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ clkDismissDelayMs: v })
  }
}
