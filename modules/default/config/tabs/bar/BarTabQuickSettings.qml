import QtQuick
import '../../components' as C

C.CfgScroll {
  id: root
  required property var   config
  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  signal changed(var opts)
  function g(key) { return config ? config.get("quicksettings", key) : undefined }

  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.g("textColor") || "on_surface"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"textColor", value:v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"dimColor", value:v })
  }
  C.CfgPalette {
    label: "Acento"; value: root.g("accentColor") || "primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"accentColor", value:v })
  }
  C.CfgPalette {
    label: "Erro/Mutado"; value: root.g("mutedColor") || "error"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"mutedColor", value:v })
  }
  C.CfgPalette {
    label: "Fundo slider"; value: root.g("progressBg") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"progressBg", value:v })
  }
  C.CfgPalette {
    label: "Divisor"; value: root.g("divider") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"quicksettings", key:"divider", value:v })
  }
}
