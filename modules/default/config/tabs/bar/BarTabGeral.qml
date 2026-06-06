import QtQuick
import QtQuick.Layouts
import '../../components' as C

// BarTabGeral — Tema, Posição, Comportamento, Dimensões
C.CfgScroll {
  id: root

  required property string localTheme
  required property int    localPosition
  required property bool   localAutoHide
  required property bool   localSilence
  required property int    localBarSize
  required property int    localBarMargin
  required property int    localPillWidth
  required property int    localPillMinSpacing
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg

  readonly property bool isH: localPosition === 1 || localPosition === 3

  signal changed(var opts)

  // ── Tema ─────────────────────────────────────────────────────────────
  C.CfgSection { title: "TEMA"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: ["Pill", "Default", "Minimal"]
      delegate: C.CfgChip {
        required property string modelData
        label:       modelData
        active:      root.localTheme === modelData
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ theme: modelData })
      }
    }
  }

  // ── Posição ───────────────────────────────────────────────────────────
  C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: 1, icon: "\uf077", label: "Topo"     },
        { id: 3, icon: "\uf078", label: "Baixo"    },
        { id: 4, icon: "\uf053", label: "Esquerda" },
        { id: 2, icon: "\uf054", label: "Direita"  },
      ]
      delegate: C.CfgChip {
        required property var modelData
        icon:         modelData.icon
        label:        modelData.label
        active:       root.localPosition === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ position: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorTextDim }

  // ── Comportamento ─────────────────────────────────────────────────────
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:       "Auto-ocultar"
    checked:     root.localAutoHide
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ autoHide: !root.localAutoHide })
  }
  C.CfgToggle {
    label:       "Silence (sem OSD/toasts)"
    checked:     root.localSilence
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ silence: !root.localSilence })
  }

  C.CfgDiv { colorDivider: root.colorTextDim }

  // ── Dimensões ─────────────────────────────────────────────────────────
  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }
  C.CfgSlider {
    label: "Espessura"; value: root.localBarSize
    from: 20; to: 60; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barSize: v })
  }
  C.CfgSlider {
    label: "Margem"; value: root.localBarMargin
    from: 0; to: 30; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barMargin: v })
  }
  C.CfgSlider {
    visible: root.isH
    label: "Largura pill"; value: root.localPillWidth
    from: 400; to: 2000; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillWidth: v })
  }
  C.CfgSlider {
    visible: root.isH
    label: "Espaç. lateral"; value: root.localPillMinSpacing
    from: 0; to: 120; step: 4; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillMinSpacing: v })
  }
}
