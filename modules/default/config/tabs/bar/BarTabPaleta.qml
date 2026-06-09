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
  function g(key) { return config ? config.get("palette", key) : undefined }

  C.CfgSection { title: "BAR"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo do bar"; value: root.g("barBg") || "surface_container_lowest"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"barBg", value:v })
  }
  C.CfgPalette {
    label: "Fundo da pílula"; value: root.g("barBgPill") || "background"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"barBgPill", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "TEXTO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Texto"; value: root.g("text") || "on_surface"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"text", value:v })
  }
  C.CfgPalette {
    label: "Texto dim"; value: root.g("textDim") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"textDim", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "ACENTO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Acento"; value: root.g("accent") || "primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"accent", value:v })
  }
  C.CfgPalette {
    label: "Fundo acento"; value: root.g("accentBg") || "primary_container"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"accentBg", value:v })
  }
  C.CfgPalette {
    label: "Texto acento"; value: root.g("accentText") || "on_primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"accentText", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PAINEL"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo painel"; value: root.g("panelBg") || "surface_container"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"panelBg", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PROGRESSO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo progresso"; value: root.g("progressBg") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"progressBg", value:v })
  }
  C.CfgPalette {
    label: "Progresso"; value: root.g("progressFg") || "primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"progressFg", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "DIVISOR"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Divisor"; value: root.g("divider") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"palette", key:"divider", value:v })
  }
}
