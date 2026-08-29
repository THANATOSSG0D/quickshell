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
      model: ["Pill", "Bento", "Aurora", "Notch", "Dock", "Default", "Minimal", "Slider"]
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
    enabled:      root.g("alwaysVisible", false) !== true && root.g("pinned", false) !== true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ autoHide: !(root.g("autoHide", true) === true) })
  }
  C.CfgToggle {
    label:        "Fixar barra (ignora auto-ocultar e fullscreen peek)"
    checked:      root.g("pinned", false) === true
    enabled:      root.g("alwaysVisible", false) !== true && root.g("floating", false) !== true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ pinned: !(root.g("pinned", false) === true) })
  }
  C.CfgToggle {
    label:        "Sempre visível (flutua por cima de tudo, sem reservar espaço, ignora fullscreen)"
    checked:      root.g("alwaysVisible", false) === true
    enabled:      root.g("floating", false) !== true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ alwaysVisible: !(root.g("alwaysVisible", false) === true) })
  }
  C.CfgToggle {
    label:        "Flutuante (overlay sem reservar espaço, mas oculta em fullscreen)"
    checked:      root.g("floating", false) === true
    enabled:      root.g("alwaysVisible", false) !== true && root.g("pinned", false) !== true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ floating: !(root.g("floating", false) === true) })
  }
  C.CfgToggle {
    label:        "Auto-ocultar em fullscreen (peek)"
    checked:      root.g("fullscreenPeekEnabled", true) === true
    enabled:      root.g("alwaysVisible", false) !== true && root.g("pinned", false) !== true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ fullscreenPeekEnabled: !(root.g("fullscreenPeekEnabled", true) === true) })
  }
  C.CfgToggle {
    label:        "Silence (sem OSD/toasts)"
    checked:      root.g("silenceMode", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ silence: !(root.g("silenceMode", false) === true) })
  }
  C.CfgToggle {
    label:        "Painel ativado (desligado = nenhuma janela é criada)"
    checked:      root.g("panelEnabled", true) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ panelEnabled: !(root.g("panelEnabled", true) === true) })
  }

  C.CfgDiv { colorDivider: root.colorTextDim }

  // ── Tooltips ──────────────────────────────────────────────────────────
  C.CfgSection { title: "TOOLTIPS"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:        "Mostrar tooltips ao passar o mouse"
    checked:      root.g("tooltipEnabled", true) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ tooltipEnabled: !(root.g("tooltipEnabled", true) === true) })
  }
  C.CfgSlider {
    label: "Distância da barra"; value: root.g("tooltipOffset", 0)
    from: 0; to: 40; step: 2; unit: "px"
    enabled:      root.g("tooltipEnabled", true) === true
    colorAccent:  root.colorAccent; colorTextDim: root.colorTextDim
    colorText:    root.colorText;   colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ tooltipOffset: v })
  }
  Row {
    spacing: 6
    enabled: root.g("tooltipEnabled", true) === true
    opacity: enabled ? 1 : 0.4
    Repeater {
      model: [
        { id: "auto",  label: "Ajustável" },
        { id: "fixed", label: "Fixo" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:        modelData.label
        active:       root.g("tooltipWidthMode", "auto") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ tooltipWidthMode: modelData.id })
      }
    }
  }
  C.CfgSlider {
    visible: root.g("tooltipWidthMode", "auto") === "auto"
    label: "Largura máxima"; value: root.g("tooltipMaxWidth", 320)
    from: 120; to: 480; step: 8; unit: "px"
    enabled:      root.g("tooltipEnabled", true) === true
    colorAccent:  root.colorAccent; colorTextDim: root.colorTextDim
    colorText:    root.colorText;   colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ tooltipMaxWidth: v })
  }
  C.CfgSlider {
    visible: root.g("tooltipWidthMode", "auto") === "fixed"
    label: "Largura"; value: root.g("tooltipFixedWidth", 220)
    from: 120; to: 480; step: 8; unit: "px"
    enabled:      root.g("tooltipEnabled", true) === true
    colorAccent:  root.colorAccent; colorTextDim: root.colorTextDim
    colorText:    root.colorText;   colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ tooltipFixedWidth: v })
  }
  Row {
    spacing: 6
    enabled: root.g("tooltipEnabled", true) === true
    opacity: enabled ? 1 : 0.4
    Repeater {
      model: [
        { id: "module",  label: "Junto ao item" },
        { id: "section", label: "Centralizado na seção" },
        { id: "bar",     label: "Centralizado na barra" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:        modelData.label
        active:       root.g("tooltipAlign", "module") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ tooltipAlign: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorTextDim }

  // ── Cantos da tela ───────────────────────────────────────────────────
  // Config global (Bar.json), independente de tema. Editar isso pela aba
  // "Dock" NÃO tem efeito — ScreenCorners.qml só lê de bar.configRef.
  C.CfgSection { title: "CANTOS DA TELA"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:        "Arredondar os 4 cantos do monitor"
    checked:      root.g("cornersEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ cornersEnabled: !(root.g("cornersEnabled", false) === true) })
  }
  C.CfgSlider {
    label: "Raio"; value: root.g("cornersRadius", 24)
    from: 4; to: 60; step: 2; unit: "px"
    enabled:      root.g("cornersEnabled", false) === true
    colorAccent:  root.colorAccent; colorTextDim: root.colorTextDim
    colorText:    root.colorText;   colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ cornersRadius: v })
  }
  C.CfgToggle {
    label:        "Manter visível sobre janelas em fullscreen"
    checked:      root.g("cornersOverFullscreen", false) === true
    enabled:      root.g("cornersEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ cornersOverFullscreen: !(root.g("cornersOverFullscreen", false) === true) })
  }
  Row {
    spacing: 6
    enabled: root.g("cornersEnabled", false) === true
    opacity: enabled ? 1 : 0.4
    Repeater {
      model: [
        { id: "edge", label: "Extremidade da tela" },
        { id: "bar",  label: "Abaixo da Barra" },
        { id: "dock", label: "Abaixo da Dock" },
        { id: "both", label: "Barra + Dock" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:        modelData.label
        active:       root.g("cornersMode", "edge") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ cornersMode: modelData.id })
      }
    }
  }
}
