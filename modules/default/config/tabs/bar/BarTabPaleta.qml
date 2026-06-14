import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  required property var   config
  required property var   colors
  required property var   overlay
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorSidebar
  required property color colorDivider
  required property color colorProgressBg

  signal changed(var opts)

  function g(key, def) {
    if (!config) return def
    var v = config.get("palette", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Barra ─────────────────────────────────────────────────────────────
  C.CfgSection { title: "BARRA"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo barra"; value: root.g("barBg", "surface_container")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "barBg", value: v })
  }
  C.CfgPalette {
    label: "Fundo pill"; value: root.g("barBgPill", "surface_container_high")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "barBgPill", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "TEXTO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Texto"; value: root.g("text", "on_surface")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "text", value: v })
  }
  C.CfgPalette {
    label: "Texto dim"; value: root.g("textDim", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "textDim", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "ACCENT"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Accent"; value: root.g("accent", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accent", value: v })
  }
  C.CfgPalette {
    label: "Accent bg"; value: root.g("accentBg", "primary_container")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accentBg", value: v })
  }
  C.CfgPalette {
    label: "Accent text"; value: root.g("accentText", "on_primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accentText", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PAINÉIS"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo painel"; value: root.g("panelBg", "surface_container")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "panelBg", value: v })
  }
  C.CfgPalette {
    label: "Progress bg"; value: root.g("progressBg", "surface_container_high")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "progressBg", value: v })
  }
  C.CfgPalette {
    label: "Progress fg"; value: root.g("progressFg", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "progressFg", value: v })
  }
  C.CfgPalette {
    label: "Divisor"; value: root.g("divider", "outline_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "divider", value: v })
  }
}
