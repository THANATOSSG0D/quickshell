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

  // Emite mudanças estruturais (tema, posição, autoHide, etc.)
  signal structuralChange(var opts)

  function g(key) { return config ? config[key] : undefined }

  // ── TEMA ────────────────────────────────────────────────────────────────
  C.CfgSection { title: "TEMA"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: ["Pill", "Minimal"]
      delegate: C.CfgChip {
        required property string modelData
        label:  modelData
        active: root.g("theme") === modelData
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.structuralChange({ theme: modelData })
      }
    }
  }

  // ── POSIÇÃO ─────────────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: 1, label: "Topo"   },
        { id: 3, label: "Baixo"  },
        { id: 4, label: "Esquerda" },
        { id: 2, label: "Direita"  },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("position") === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.structuralChange({ position: modelData.id })
      }
    }
  }

  // ── DIMENSÕES ───────────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }
  C.CfgSlider {
    label: "Tamanho"; value: root.g("barSize") || 30
    from: 20; to: 60; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.structuralChange({ barSize: v })
  }
  C.CfgSlider {
    label: "Margem"; value: root.g("barMargin") || 3
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.structuralChange({ barMargin: v })
  }
  C.CfgSlider {
    label: "Largura pílula"; value: root.g("pillWidth") || 400
    from: 200; to: 1400; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.structuralChange({ pillWidth: v })
  }
  C.CfgSlider {
    label: "Espaçamento mín."; value: root.g("pillMinSpacing") || 20
    from: 0; to: 100; step: 5; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.structuralChange({ pillMinSpacing: v })
  }

  // ── COMPORTAMENTO ───────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label: "Auto-esconder"
    checked: root.g("autoHide") === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.structuralChange({ autoHide: !(root.g("autoHide") === true) })
  }
  C.CfgToggle {
    label: "Modo silencioso"
    checked: root.g("silenceMode") === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.structuralChange({ silence: !(root.g("silenceMode") === true) })
  }
}
