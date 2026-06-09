import QtQuick
import QtQuick.Layouts
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

  // Estilo ativo — lido do config (reativo via _dep)
  readonly property string wsStyle:   config ? (config.get("workspaces","style") || "icons") : "icons"
  readonly property bool   _hasIcons: wsStyle === "icons" || wsStyle === "hybrid"
  readonly property bool   _hasDots:  wsStyle === "dots"  || wsStyle === "hybrid"

  // helper para props comuns (sem style)
  function getCommon(key) { return config ? config.get("workspaces", key) : undefined }
  // helper para props do estilo atual
  function getStyle(key) { return config ? config.get("workspaces", key, wsStyle) : undefined }

  // ════════════════════════════════════════
  C.CfgSection { title: "ESTILO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        {id:"dots",label:"Pontos"},{id:"icons",label:"Ícones"},
        {id:"hybrid",label:"Híbrido"},{id:"number",label:"Número"},
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label; active: root.wsStyle === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId:"workspaces", key:"style", value:modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── ÍCONES (icons + hybrid) ─────────────────────────────────
  C.CfgSection { visible:root._hasIcons; title:"ÍCONES"; colorTextDim:root.colorTextDim }
  C.CfgToggle {
    visible: root._hasIcons; label: "Monocromático"
    checked: root.getCommon("iconMonochrome") !== false
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId:"workspaces", key:"iconMonochrome", value:!(root.getCommon("iconMonochrome") !== false) })
  }
  C.CfgSlider {
    visible: root._hasIcons; label: "Espaçamento"; value: root.getCommon("iconSpacing") || 4
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"iconSpacing", value:v })
  }
  C.CfgSection { visible:root._hasIcons; title:"ORDENAÇÃO"; colorTextDim:root.colorTextDim }
  Row {
    visible: root._hasIcons; spacing: 6
    Repeater {
      model: [{id:"position",label:"Posição"},{id:"alphabetical",label:"Alfabética"}]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label; active: root.getCommon("iconsSort") === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId:"workspaces", key:"iconsSort", value:modelData.id })
      }
    }
  }
  C.CfgDiv { visible:root._hasIcons; colorDivider:root.colorDivider }

  // ── FUNDO (todos) ─────────────────────────────────────────────
  C.CfgSection { title:"FUNDO"; colorTextDim:root.colorTextDim }
  C.CfgSlider {
    label: "Opacidade"; value: Math.round((root.getStyle("bgOpacity") || 0) * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgOpacity", value:v/100, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Padding H"; value: root.getStyle("bgPaddingH") || 8
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgPaddingH", value:v, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Padding V"; value: root.getStyle("bgPaddingV") || 2
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgPaddingV", value:v, style:root.wsStyle })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title:"ATIVA"; colorTextDim:root.colorTextDim }
  C.CfgSlider {
    label: "Opacidade"; value: Math.round((root.getStyle("bgOpacityActive") || 0.85) * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgOpacityActive", value:v/100, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Raio"; value: root.getStyle("bgRadiusActive") || 99
    from: 0; to: 99; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgRadiusActive", value:v, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Padding H"; value: root.getStyle("bgPaddingHActive") || 6
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgPaddingHActive", value:v, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Padding V"; value: root.getStyle("bgPaddingVActive") || 2
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgPaddingVActive", value:v, style:root.wsStyle })
  }
  C.CfgSlider {
    label: "Borda"; value: root.getStyle("bgBorderWidthActive") || 0
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"workspaces", key:"bgBorderWidthActive", value:v, style:root.wsStyle })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title:"BOTÃO +"; colorTextDim:root.colorTextDim }
  C.CfgToggle {
    label: "Mostrar botão +"; checked: root.getCommon("showAddButton") !== false
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId:"workspaces", key:"showAddButton", value:!(root.getCommon("showAddButton") !== false) })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title:"CORES — FUNDO"; colorTextDim:root.colorTextDim }
  C.CfgPalette {
    label:"Fundo"; value:root.getStyle("bgColor") || "surface_variant"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"bgColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    label:"Fundo ativo"; value:root.getStyle("bgColorActive") || "primary_container"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"bgColorActive", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    label:"Borda"; value:root.getStyle("bgBorderColor") || "on_surface"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"bgBorderColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    label:"Borda ativa"; value:root.getStyle("bgBorderColorActive") || "primary"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"bgBorderColorActive", value:v, style:root.wsStyle })
  }

  C.CfgSection { visible:root._hasDots; title:"CORES — PONTOS"; colorTextDim:root.colorTextDim }
  C.CfgPalette {
    visible:root._hasDots; label:"Vazio"; value:root.getStyle("dotColor") || "on_surface_variant"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"dotColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    visible:root._hasDots; label:"Ativo"; value:root.getStyle("dotActiveColor") || "on_surface"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"dotActiveColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    visible:root._hasDots; label:"Ocupado"; value:root.getStyle("dotOccupiedColor") || "on_surface"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"dotOccupiedColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    visible:root._hasDots; label:"Urgente"; value:root.getStyle("dotUrgentColor") || "error"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"dotUrgentColor", value:v, style:root.wsStyle })
  }

  C.CfgSection { visible:root._hasIcons; title:"CORES — ÍCONES"; colorTextDim:root.colorTextDim }
  C.CfgPalette {
    visible:root._hasIcons; label:"Ícone"; value:root.getStyle("iconMonoColor") || "on_surface"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"iconMonoColor", value:v, style:root.wsStyle })
  }
  C.CfgPalette {
    visible:root._hasIcons; label:"Ícone ativo"; value:root.getStyle("iconMonoColorActive") || "primary"
    colors:root.colors; overlay:root.overlay
    colorAccent:root.colorAccent; colorTextDim:root.colorTextDim
    colorText:root.colorText; colorSidebar:root.colorSidebar; colorDivider:root.colorDivider
    onEdited:(v) => root.changed({ moduleId:"workspaces", key:"iconMonoColorActive", value:v, style:root.wsStyle })
  }
}
