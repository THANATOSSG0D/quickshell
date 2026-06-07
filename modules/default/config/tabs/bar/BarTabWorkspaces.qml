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

  // ── Visual ────────────────────────────────────────────────────────────
  required property real   wsBgOpacity
  required property real   wsBgOpacityActive
  required property real   wsBgBorderWidthActive
  required property real   wsBgPaddingH
  required property real   wsBgPaddingV
  required property real   wsBgPaddingHActive
  required property real   wsBgPaddingVActive
  required property real   wsBgRadiusActive

  // ── Cores (chave de paleta) ───────────────────────────────────────────
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

  // ── Tema / cores UI ───────────────────────────────────────────────────
  required property var    colors
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg
  required property color  colorSidebar
  required property color  colorDivider
  required property var    overlay

  signal changed(var opts)

  // ═══════════════════════════════════════════════
  // ESTILO
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "ESTILO"; colorTextDim: root.colorTextDim }

  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "dots",   label: "Pontos"   },
        { id: "icons",  label: "Ícones"   },
        { id: "hybrid", label: "Híbrido"  },
        { id: "number", label: "Número"   },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:        modelData.label
        active:       root.wsStyle === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ wsStyle: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ═══════════════════════════════════════════════
  // ÍCONES (só quando style = icons ou hybrid)
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "ÍCONES"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:        "Monocromático"
    checked:      root.wsIconMonochrome
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsIconMonochrome: !root.wsIconMonochrome })
  }

  C.CfgSlider {
    label:          "Espaçamento"
    value:          root.wsIconSpacing
    from: 0; to: 16; step: 1; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsIconSpacing: v })
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
        label:        modelData.label
        active:       root.wsIconsSort === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ wsIconsSort: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ═══════════════════════════════════════════════
  // FUNDO GLOBAL
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "FUNDO GLOBAL"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label:          "Opacidade"
    value:          Math.round(root.wsBgOpacity * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgOpacity: v / 100 })
  }

  C.CfgSlider {
    label:          "Padding H"
    value:          root.wsBgPaddingH
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingH: v })
  }

  C.CfgSlider {
    label:          "Padding V"
    value:          root.wsBgPaddingV
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingV: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ═══════════════════════════════════════════════
  // WORKSPACE ATIVA
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "ATIVA"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label:          "Opacidade fundo"
    value:          Math.round(root.wsBgOpacityActive * 100)
    from: 0; to: 100; step: 5; unit: "%"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgOpacityActive: v / 100 })
  }

  C.CfgSlider {
    label:          "Raio"
    value:          root.wsBgRadiusActive
    from: 0; to: 99; step: 1; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgRadiusActive: v })
  }

  C.CfgSlider {
    label:          "Padding H ativa"
    value:          root.wsBgPaddingHActive
    from: 0; to: 32; step: 2; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingHActive: v })
  }

  C.CfgSlider {
    label:          "Padding V ativa"
    value:          root.wsBgPaddingVActive
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgPaddingVActive: v })
  }

  C.CfgSlider {
    label:          "Borda ativa"
    value:          root.wsBgBorderWidthActive
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent:    root.colorAccent
    colorTextDim:   root.colorTextDim
    colorText:      root.colorText
    colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ wsBgBorderWidthActive: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ═══════════════════════════════════════════════
  // BOTÃO +
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "BOTÃO +"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:        "Mostrar botão +"
    checked:      root.wsShowAddButton
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ wsShowAddButton: !root.wsShowAddButton })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ═══════════════════════════════════════════════
  // CORES
  // ═══════════════════════════════════════════════
  C.CfgSection { title: "CORES — FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo global"; value: root.pkWsBgColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsBgColor →", v); root.changed({ pkWsBgColor: v }) }
  }
  C.CfgPalette {
    label: "Fundo ativa"; value: root.pkWsBgColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsBgColorActive →", v); root.changed({ pkWsBgColorActive: v }) }
  }
  C.CfgPalette {
    label: "Borda global"; value: root.pkWsBgBorderColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsBgBorderColor →", v); root.changed({ pkWsBgBorderColor: v }) }
  }
  C.CfgPalette {
    label: "Borda ativa"; value: root.pkWsBgBorderColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsBgBorderColorActive →", v); root.changed({ pkWsBgBorderColorActive: v }) }
  }

  C.CfgSection { title: "CORES — PONTOS"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Vazio"; value: root.pkWsDotColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsDotColor →", v); root.changed({ pkWsDotColor: v }) }
  }
  C.CfgPalette {
    label: "Ativo"; value: root.pkWsDotActiveColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsDotActiveColor →", v); root.changed({ pkWsDotActiveColor: v }) }
  }
  C.CfgPalette {
    label: "Ocupado"; value: root.pkWsDotOccupiedColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsDotOccupiedColor →", v); root.changed({ pkWsDotOccupiedColor: v }) }
  }
  C.CfgPalette {
    label: "Urgente"; value: root.pkWsDotUrgentColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsDotUrgentColor →", v); root.changed({ pkWsDotUrgentColor: v }) }
  }

  C.CfgSection { title: "CORES — ÍCONES MONO"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Ícone inativo"; value: root.pkWsIconMonoColor
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsIconMonoColor →", v); root.changed({ pkWsIconMonoColor: v }) }
  }
  C.CfgPalette {
    label: "Ícone ativo"; value: root.pkWsIconMonoColorActive
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabWs] pkWsIconMonoColorActive →", v); root.changed({ pkWsIconMonoColorActive: v }) }
  }
}
