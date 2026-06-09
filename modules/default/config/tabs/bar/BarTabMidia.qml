import QtQuick
import QtQuick.Layouts
import '../../components' as C

// BarTabMidia — lê e escreve via config.get/set("mediaplayer", key)
// Não tem estado local — cada controle lê do config diretamente.
// Isolamento por tema é automático: config.get() usa root.theme do BarConfig.

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

  // helper — lê do config e inclui _dep como dependência reativa
  function g(key) { return config ? config.get("mediaplayer", key) : undefined }

  // ════════════════════════════════════════
  C.CfgSection { title: "MODO DE TEXTO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: BarSchema.module("mediaplayer").props.find(function(p){ return p.key==="textMode" }).options
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("textMode") === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId:"mediaplayer", key:"textMode", value:modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "SCROLL"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Velocidade"; value: root.g("scrollSpeed") || 40
    from: 10; to: 200; step: 5; unit: "px/s"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"scrollSpeed", value:v })
  }
  C.CfgSlider {
    label: "Largura"; value: root.g("scrollWidth") || 140
    from: 60; to: 400; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"scrollWidth", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Fundo habilitado"; checked: root.g("bgEnabled") === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId:"mediaplayer", key:"bgEnabled", value:!(root.g("bgEnabled") === true) })
  }
  C.CfgSlider {
    label: "Opacidade"; value: Math.round((root.g("bgOpacity") || 0.5) * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"bgOpacity", value:v/100 })
  }
  C.CfgSlider {
    label: "Opacidade ativo"; value: Math.round((root.g("bgOpacityActive") || 0.8) * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"bgOpacityActive", value:v/100 })
  }
  C.CfgSlider {
    label: "Padding H"; value: root.g("bgPaddingH") || 8
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"bgPaddingH", value:v })
  }
  C.CfgSlider {
    label: "Padding V"; value: root.g("bgPaddingV") || 4
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"mediaplayer", key:"bgPaddingV", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo"; value: root.g("bgColor") || "surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"bgColor", value:v })
  }
  C.CfgPalette {
    label: "Fundo ativo"; value: root.g("bgColorActive") || "primary_container"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"bgColorActive", value:v })
  }
  C.CfgPalette {
    label: "Texto"; value: root.g("textColor") || "on_surface"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"textColor", value:v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"dimColor", value:v })
  }
  C.CfgPalette {
    label: "Texto ativo"; value: root.g("textColorActive") || "on_primary_container"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"textColorActive", value:v })
  }
  C.CfgPalette {
    label: "Dim ativo"; value: root.g("dimColorActive") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"mediaplayer", key:"dimColorActive", value:v })
  }
}
