import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── DmenuPanel ────────────────────────────────────────────────────────────────
// PanelWindow standalone (não depende do Bar).
// Suporta modos: drun, run, window, script.
//
// panelAnchor controla a posição no monitor:
//   "top-center"    (padrão) — centrado no topo, offset de 65px
//   "top-left"      — topo esquerda, com margem
//   "top-right"     — topo direita, com margem
//   "center"        — centro absoluto do monitor
//   "bottom-center" — rodapé centrado

PanelWindow {
  id: panel

  required property var screen

  // ── Posicionamento ────────────────────────────────────────────────────────
  // "top-center" | "top-left" | "top-right" | "center" | "bottom-center"
  property string panelAnchor: "top-center"
  property int    edgeMargin:  65   // distância da borda (top offset ou bottom offset)
  property int    sideMargin:  40   // margem lateral para top-left / top-right

  // ── Modo e conteúdo ───────────────────────────────────────────────────────
  property string mode:        "drun"
  property bool   showIcons:   true
  property int    maxVisible:  12

  // Props do modo script
  property var    scriptEntries:  []
  property string scriptPrompt:   ">"
  property string scriptLabel:    "SCRIPT"
  property string scriptSep:      ""
  property var    scriptCallback: null

  // ── Cores ─────────────────────────────────────────────────────────────────
  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  function open()  { panelOpen = true  }
  function close() { panelOpen = false }

  // ── Dimensões do painel flutuante ─────────────────────────────────────────
  readonly property int _itemH:  32
  readonly property int _inputH: 42
  readonly property int _padV:   12
  readonly property int _panelW: 720
  readonly property int _panelH: _inputH + 6 + (_itemH * maxVisible) + _padV * 2 + 28

  // ── Posicionamento layer-shell ────────────────────────────────────────────
  // Âncoras e margens variam conforme panelAnchor.
  // Usamos anchors.top+left+right para top-* (horizontal stretch + margin.top)
  // e anchors.bottom para bottom-center.
  // Para "center" usamos top+bottom para calcular posição vertical.

  readonly property bool _anchorTop:    panelAnchor !== "bottom-center"
  readonly property bool _anchorBottom: panelAnchor === "bottom-center" || panelAnchor === "center"
  readonly property bool _anchorLeft:   true   // sempre stretch horizontal para poder centralizar
  readonly property bool _anchorRight:  true

  screen: panel.screen
  color:  "transparent"
  exclusionMode: ExclusionMode.Ignore

  anchors.top:    _anchorTop
  anchors.bottom: _anchorBottom
  anchors.left:   _anchorLeft
  anchors.right:  _anchorRight

  implicitWidth:  1
  implicitHeight: {
    if (panelAnchor === "center") return _panelH
    return _panelH + edgeMargin
  }

  margins.top:    0
  margins.bottom: 0
  margins.left:   0
  margins.right:  0

  // ── Animação ──────────────────────────────────────────────────────────────
  property bool panelOpen: false
  property real slideProgress: 0.0
  visible: slideProgress > 0.0

  Behavior on slideProgress {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  onPanelOpenChanged: {
    slideProgress = panelOpen ? 1.0 : 0.0
    if (panelOpen) content.activate()
  }

  HyprlandFocusGrab {
    windows: [panel]
    active:  panel.panelOpen
    onCleared: {
      panel.panelOpen = false
      if (panel.mode === "script" && panel.scriptCallback)
        panel.scriptCallback(null)
    }
  }

  // ── Posição do container dentro da PanelWindow ────────────────────────────
  // A PanelWindow ocupa a largura toda do monitor (stretch horizontal).
  // O container é centralizado ou alinhado conforme panelAnchor.

  readonly property real _containerX: {
    if (panelAnchor === "top-left")   return sideMargin
    if (panelAnchor === "top-right")  return panel.width - _panelW - sideMargin
    // top-center, center, bottom-center: centralizado
    return Math.round((panel.width - _panelW) / 2)
  }

  readonly property real _containerY: {
    if (panelAnchor === "bottom-center") return 0
    if (panelAnchor === "center")
      return Math.round((panel.height - _panelH) / 2)
    // top-*: offset do topo
    return edgeMargin
  }

  // ── Slide direction ───────────────────────────────────────────────────────
  readonly property real _slideY: {
    if (panelAnchor === "bottom-center") return  14
    if (panelAnchor === "center")        return   0
    return -14  // top-*: slide de cima para baixo
  }

  // ── Container ─────────────────────────────────────────────────────────────
  Item {
    id: container
    clip: true
    x: panel._containerX
    y: panel._containerY
    width:  panel._panelW
    height: panel._panelH * panel.slideProgress

    opacity: Math.min(1.0, panel.slideProgress * 2.5)

    transform: Translate {
      y: panel._slideY * (1.0 - panel.slideProgress)
    }

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g,
                     panel.colorPanelBg.b, 0.92)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    DmenuContent {
      id: content
      anchors {
        fill:         parent
        topMargin:    panel._padV
        bottomMargin: panel._padV
        leftMargin:   12
        rightMargin:  12
      }

      mode:        panel.mode
      showIcons:   panel.showIcons
      maxVisible:  panel.maxVisible

      scriptEntries: panel.scriptEntries
      scriptPrompt:  panel.scriptPrompt
      scriptLabel:   panel.scriptLabel
      scriptSep:     panel.scriptSep

      colorPanelBg:  panel.colorPanelBg
      colorText:     panel.colorText
      colorTextDim:  panel.colorTextDim
      colorAccent:   panel.colorAccent
      colorSelected: panel.colorSelected
      colorDivider:  panel.colorDivider
      colorInputBg:  panel.colorInputBg

      onCloseRequested: (selected) => {
        panel.panelOpen = false
        if (panel.mode === "script" && panel.scriptCallback)
          panel.scriptCallback(selected)
      }
    }
  }
}
