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
    var v = config.get("mediaplayer", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Mostrar texto ─────────────────────────────────────────────────────
  C.CfgSection { title: "GERAL"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:   "Mostrar texto"
    checked: root.g("showText", true) !== false
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "mediaplayer", key: "showText", value: !(root.g("showText", true) !== false) })
  }
  C.CfgToggle {
    label:   "Texto estático (sem carretel)"
    checked: root.g("textStatic", false) === true
    visible: root.g("showText", true) !== false
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "mediaplayer", key: "textStatic", value: !(root.g("textStatic", false) === true) })
  }

  // ── Modo de texto ─────────────────────────────────────────────────────
  C.CfgSection { title: "MODO DE TEXTO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "artistAndTitle", label: "Artista + Título" },
        { id: "title",          label: "Só título"        },
        { id: "artist",         label: "Só artista"       },
        { id: "album",          label: "Só álbum"         },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("textMode", "artistAndTitle") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "mediaplayer", key: "textMode", value: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CAPA"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Tamanho"; value: root.g("artworkSize", 22)
    from: 14; to: 48; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "artworkSize", value: v })
  }
  C.CfgSlider {
    label: "Arredondamento"; value: root.g("artworkRadius", 11)
    from: 0; to: 24; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "artworkRadius", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider; visible: root.g("textStatic", false) !== true }
  C.CfgSection { title: "SCROLL"; colorTextDim: root.colorTextDim; visible: root.g("textStatic", false) !== true }

  C.CfgSlider {
    label: "Velocidade"; value: root.g("scrollSpeed", 40)
    from: 10; to: 120; step: 5; unit: "px/s"
    visible: root.g("textStatic", false) !== true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "scrollSpeed", value: v })
  }
  C.CfgSlider {
    label: "Largura"; value: root.g("scrollWidth", 140)
    from: 60; to: 300; step: 10; unit: "px"
    visible: root.g("textStatic", false) !== true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "scrollWidth", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "VOLUME"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Passo do scroll"; value: Math.round(root.g("volumeStep", 0.05) * 100)
    from: 1; to: 20; step: 1; unit: "%"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "volumeStep", value: v / 100 })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:   "Fundo habilitado"
    checked: root.g("bgEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "mediaplayer", key: "bgEnabled", value: !(root.g("bgEnabled", false) === true) })
  }
  C.CfgSlider {
    label: "Opacidade (inativo)"; value: root.g("bgOpacity", 0.7)
    from: 0.1; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "bgOpacity", value: v })
  }
  C.CfgSlider {
    label: "Opacidade (ativo)"; value: root.g("bgOpacityActive", 0.9)
    from: 0.1; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "bgOpacityActive", value: v })
  }
  C.CfgSlider {
    label: "Padding horizontal"; value: root.g("bgPaddingH", 8)
    from: 0; to: 24; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "bgPaddingH", value: v })
  }
  C.CfgSlider {
    label: "Padding vertical"; value: root.g("bgPaddingV", 4)
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "mediaplayer", key: "bgPaddingV", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo"; value: root.g("bgColor", "surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "bgColor", value: v })
  }
  C.CfgPalette {
    label: "Fundo ativo"; value: root.g("bgColorActive", "primary_container")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "bgColorActive", value: v })
  }
  C.CfgPalette {
    label: "Texto"; value: root.g("textColor", "on_surface")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "textColor", value: v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "dimColor", value: v })
  }
  C.CfgPalette {
    label: "Texto ativo"; value: root.g("textColorActive", "on_primary_container")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "textColorActive", value: v })
  }
  C.CfgPalette {
    label: "Dim ativo"; value: root.g("dimColorActive", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "mediaplayer", key: "dimColorActive", value: v })
  }
}
