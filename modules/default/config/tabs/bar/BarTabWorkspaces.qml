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
  required property color colorProgressBg
  required property color colorSidebar
  required property color colorDivider

  signal changed(var opts)

  function g(key, def) {
    if (!config) return def
    var v = config.get("workspaces", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Estilo ────────────────────────────────────────────────────────────
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
        label:  modelData.label
        active: root.g("style", "icons") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "workspaces", key: "style", value: modelData.id })
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
        label:  modelData.label
        active: root.g("iconsSort", "position") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "workspaces", key: "iconsSort", value: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:   "Ícones monocromáticos"
    checked: root.g("iconMonochrome", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "iconMonochrome", value: !(root.g("iconMonochrome", false) === true) })
  }
  C.CfgToggle {
    label:   "Botão + workspaces"
    checked: root.g("showAddButton", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "showAddButton", value: !(root.g("showAddButton", false) === true) })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Espaçamento ícones"; value: root.g("iconSpacing", 4)
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "iconSpacing", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "FUNDO DOS ITENS"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Opacidade (inativo)"; value: root.g("bgOpacity", 0.0)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgOpacity", value: v })
  }
  C.CfgSlider {
    label: "Padding H (inativo)"; value: root.g("bgPaddingH", 6)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgPaddingH", value: v })
  }
  C.CfgSlider {
    label: "Padding V (inativo)"; value: root.g("bgPaddingV", 3)
    from: 0; to: 14; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgPaddingV", value: v })
  }

  C.CfgSlider {
    label: "Opacidade (ativo)"; value: root.g("bgOpacityActive", 0.18)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgOpacityActive", value: v })
  }
  C.CfgSlider {
    label: "Padding H (ativo)"; value: root.g("bgPaddingHActive", 8)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgPaddingHActive", value: v })
  }
  C.CfgSlider {
    label: "Padding V (ativo)"; value: root.g("bgPaddingVActive", 4)
    from: 0; to: 14; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgPaddingVActive", value: v })
  }
  C.CfgSlider {
    label: "Raio borda (ativo)"; value: root.g("bgRadiusActive", 6)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgRadiusActive", value: v })
  }
  C.CfgSlider {
    label: "Borda (ativo)"; value: root.g("bgBorderWidthActive", 0)
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "bgBorderWidthActive", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo (inativo)"; value: root.g("bgColor", "surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "bgColor", value: v })
  }
  C.CfgPalette {
    label: "Fundo (ativo)"; value: root.g("bgColorActive", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "bgColorActive", value: v })
  }
  C.CfgPalette {
    label: "Borda (ativo)"; value: root.g("bgBorderColor", "outline_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "bgBorderColor", value: v })
  }
  C.CfgPalette {
    label: "Borda ativa"; value: root.g("bgBorderColorActive", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "bgBorderColorActive", value: v })
  }
  C.CfgPalette {
    label: "Dot (inativo)"; value: root.g("dotColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "dotColor", value: v })
  }
  C.CfgPalette {
    label: "Dot (ativo)"; value: root.g("dotActiveColor", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "dotActiveColor", value: v })
  }
  C.CfgPalette {
    label: "Dot (ocupado)"; value: root.g("dotOccupiedColor", "secondary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "dotOccupiedColor", value: v })
  }
  C.CfgPalette {
    label: "Dot (urgente)"; value: root.g("dotUrgentColor", "error")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "dotUrgentColor", value: v })
  }
  C.CfgPalette {
    label: "Ícone mono (inativo)"; value: root.g("iconMonoColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "iconMonoColor", value: v })
  }
  C.CfgPalette {
    label: "Ícone mono (ativo)"; value: root.g("iconMonoColorActive", "on_primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "iconMonoColorActive", value: v })
  }
}
