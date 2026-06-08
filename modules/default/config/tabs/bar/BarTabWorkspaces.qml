import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  // ── Genérico ──────────────────────────────────────────────────────────
  required property string wsStyle
  required property string wsIconsSort
  required property bool   wsIconMonochrome
  required property int    wsIconSpacing
  required property bool   wsShowAddButton

  // ── Visual (lidos do estilo ativo via BarConfig._wsGet) ───────────────
  required property real   wsBgOpacity
  required property real   wsBgOpacityActive
  required property real   wsBgBorderWidthActive
  required property real   wsBgPaddingH
  required property real   wsBgPaddingV
  required property real   wsBgPaddingHActive
  required property real   wsBgPaddingVActive
  required property real   wsBgRadiusActive

  // ── Cores do estilo ativo ─────────────────────────────────────────────
  required property string pkWsBgColor
  required property string pkWsBgColorActive
  required property string pkWsBgBorderColor
  required property string pkWsBgBorderColorActive
  required property string pkWsDotColor
  required property string pkWsDotActiveColor
  required property string pkWsDotOccupiedColor
  required property string pkWsDotUrgentColor
  required property string pkWsIconMonoColor
  required property string pkWsIconMonoColorActive

  // ── UI ────────────────────────────────────────────────────────────────
  required property var    colors
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg
  required property color  colorSidebar
  required property color  colorDivider
  required property var    overlay

  signal changed(var opts)

  // helpers de visibilidade por estilo
  readonly property bool _hasIcons: wsStyle === "icons" || wsStyle === "hybrid"
  readonly property bool _hasDots:  wsStyle === "dots"  || wsStyle === "hybrid"

  // ════════════════════════════════════════════════
  // ESTILO
  // ════════════════════════════════════════════════
  C.CfgSection { title: "ESTILO"; colorTextDim: root.colorTextDim }

  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "dots",   label: "Pontos"  },
        { id: "icons",  label: "Ícones"  },
        { id: "hybrid", label: "Híbrido" },
        { id: "number", label: "Número"  },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:         modelData.label
        active:        root.wsStyle === modelData.id
        colorAccent:   root.colorAccent
        colorTextDim:  root.colorTextDim
        onChipClicked: root.changed({ wsStyle: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════
  // ÍCONES — só icons e hybrid
  // ════════════════════════════════════════════════
  C.CfgSection {
    visible: root._hasIcons
    title: "ÍCONES"; colorTextDim: root.colorTextDim
  }

  C.CfgToggle {
    visible:      root._hasIcons
    label:        "Monocromático"
    checked:      root.wsIconMonochrome
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsIconMonochrome: !root.wsIconMonochrome })
  }

  C.CfgSlider {
    visible:         root._hasIcons
    label:           "Espaçamento"
    value:           root.wsIconSpacing
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsIconSpacing: v })
  }

  C.CfgSection {
    visible: root._hasIcons
    title: "ORDENAÇÃO"; colorTextDim: root.colorTextDim
  }

  Row {
    visible: root._hasIcons
    spacing: 6
    Repeater {
      model: [
        { id: "position",     label: "Posição"    },
        { id: "alphabetical", label: "Alfabética" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:         modelData.label
        active:        root.wsIconsSort === modelData.id
        colorAccent:   root.colorAccent
        colorTextDim:  root.colorTextDim
        onChipClicked: root.changed({ wsIconsSort: modelData.id })
      }
    }
  }

  C.CfgDiv { visible: root._hasIcons; colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════
  // FUNDO — todos os estilos
  // ════════════════════════════════════════════════
  C.CfgSection { title: "FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label:           "Opacidade"
    value:           Math.round(root.wsBgOpacity * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgOpacity: v / 100 })
  }

  C.CfgSlider {
    label:           "Padding H"
    value:           root.wsBgPaddingH
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingH: v })
  }

  C.CfgSlider {
    label:           "Padding V"
    value:           root.wsBgPaddingV
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingV: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════
  // WORKSPACE ATIVA — todos os estilos
  // ════════════════════════════════════════════════
  C.CfgSection { title: "ATIVA"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label:           "Opacidade fundo"
    value:           Math.round(root.wsBgOpacityActive * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgOpacityActive: v / 100 })
  }

  C.CfgSlider {
    label:           "Raio"
    value:           root.wsBgRadiusActive
    from: 0; to: 99; step: 1; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgRadiusActive: v })
  }

  C.CfgSlider {
    label:           "Padding H"
    value:           root.wsBgPaddingHActive
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingHActive: v })
  }

  C.CfgSlider {
    label:           "Padding V"
    value:           root.wsBgPaddingVActive
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingVActive: v })
  }

  C.CfgSlider {
    label:           "Borda"
    value:           root.wsBgBorderWidthActive
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgBorderWidthActive: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════
  // BOTÃO + — comum a todos
  // ════════════════════════════════════════════════
  C.CfgSection { title: "BOTÃO +"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:        "Mostrar botão +"
    checked:      root.wsShowAddButton
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsShowAddButton: !root.wsShowAddButton })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════
  // CORES — FUNDO (todos os estilos)
  // ════════════════════════════════════════════════
  C.CfgSection { title: "CORES — FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo"; value: root.pkWsBgColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsBgColor: v })
  }
  C.CfgPalette {
    label: "Fundo ativa"; value: root.pkWsBgColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsBgColorActive: v })
  }
  C.CfgPalette {
    label: "Borda"; value: root.pkWsBgBorderColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsBgBorderColor: v })
  }
  C.CfgPalette {
    label: "Borda ativa"; value: root.pkWsBgBorderColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsBgBorderColorActive: v })
  }

  // ════════════════════════════════════════════════
  // CORES — PONTOS (dots e hybrid)
  // ════════════════════════════════════════════════
  C.CfgSection {
    visible: root._hasDots
    title: "CORES — PONTOS"; colorTextDim: root.colorTextDim
  }

  C.CfgPalette {
    visible: root._hasDots
    label: "Vazio"; value: root.pkWsDotColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsDotColor: v })
  }
  C.CfgPalette {
    visible: root._hasDots
    label: "Ativo"; value: root.pkWsDotActiveColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsDotActiveColor: v })
  }
  C.CfgPalette {
    visible: root._hasDots
    label: "Ocupado"; value: root.pkWsDotOccupiedColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsDotOccupiedColor: v })
  }
  C.CfgPalette {
    visible: root._hasDots
    label: "Urgente"; value: root.pkWsDotUrgentColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsDotUrgentColor: v })
  }

  // ════════════════════════════════════════════════
  // CORES — ÍCONES MONO (icons e hybrid)
  // ════════════════════════════════════════════════
  C.CfgSection {
    visible: root._hasIcons
    title: "CORES — ÍCONES"; colorTextDim: root.colorTextDim
  }

  C.CfgPalette {
    visible: root._hasIcons
    label: "Ícone"; value: root.pkWsIconMonoColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsIconMonoColor: v })
  }
  C.CfgPalette {
    visible: root._hasIcons
    label: "Ícone ativo"; value: root.pkWsIconMonoColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ pkWsIconMonoColorActive: v })
  }
}
