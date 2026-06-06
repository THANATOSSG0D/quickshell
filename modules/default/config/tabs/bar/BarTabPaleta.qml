import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  required property string pkBarBg
  required property string pkBarBgPill
  required property string pkText
  required property string pkTextDim
  required property string pkAccent
  required property string pkAccentBg
  required property string pkPanelBg
  required property string pkProgressBg
  required property string pkProgressFg
  required property string pkDivider
  required property var    colors
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorSidebar
  required property color  colorDivider
  required property var   overlay

  signal changed(var opts)

  C.CfgSection { title: "BARRA"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo barra"; value: root.pkBarBg; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkBarBg: v })
  }
  C.CfgPalette {
    label: "Fundo pill"; value: root.pkBarBgPill; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkBarBgPill: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "TEXTO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Texto"; value: root.pkText; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkText: v })
  }
  C.CfgPalette {
    label: "Texto dim"; value: root.pkTextDim; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkTextDim: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "ACCENT"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Accent"; value: root.pkAccent; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkAccent: v })
  }
  C.CfgPalette {
    label: "Accent bg"; value: root.pkAccentBg; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkAccentBg: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PAINÉIS"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo painel"; value: root.pkPanelBg; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkPanelBg: v })
  }
  C.CfgPalette {
    label: "Progress bg"; value: root.pkProgressBg; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkProgressBg: v })
  }
  C.CfgPalette {
    label: "Progress fg"; value: root.pkProgressFg; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkProgressFg: v })
  }
  C.CfgPalette {
    label: "Divisor"; value: root.pkDivider; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkDivider: v })
  }
}
