import QtQuick
import QtQuick.Layouts
import '../../components' as C

// BarTabGeral — Tema, Posição, Comportamento
// Dimensões de barra ficam em BarTabBar.qml
C.CfgScroll {
  id: root

  required property var   config
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorProgressBg
  required property color colorSidebar
  required property color colorDivider

  signal changed(var opts)

  function g(key, def) {
    if (!config) return def
    // Props estruturais (theme, position, autoHide, silenceMode, barSize…)
    // vivem como props diretas no BarConfig — não no sistema get(moduleId, key).
    var v = config[key]
    return (v !== undefined && v !== null) ? v : def
  }

  readonly property bool isH: {
    var p = g("position", 3)
    return p === 1 || p === 3
  }

  // ── Tema ─────────────────────────────────────────────────────────────
  C.CfgSection { title: "TEMA"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: ["Pill", "Default", "Minimal", "Slider"]
      delegate: C.CfgChip {
        required property string modelData
        label:        modelData
        active:       root.g("theme", "Pill") === modelData
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
        active:       root.g("position", 3) === modelData.id
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
    label:        "Auto-ocultar"
    checked:      root.g("autoHide", true) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ autoHide: !(root.g("autoHide", true) === true) })
  }
  C.CfgToggle {
    label:        "Silence (sem OSD/toasts)"
    checked:      root.g("silenceMode", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ silence: !(root.g("silenceMode", false) === true) })
  }
}
