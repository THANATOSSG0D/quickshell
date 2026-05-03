import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// ── BarPopup ────────────────────────────────────────────────────────────────
// Wrapper reutilizável para todos os popups da barra.
// Usa PanelWindow (layer-shell) — contorna bug do Hyprland com xdg-popup
// em monitores com offset negativo (ex: eDP-1 x=-1920).
//
// USO:
//   SomePopup {
//     barRef:    bar
//     popupW:    280; popupH: 480
//     panelOpen: bar.clockPanelOpen
//     onCloseRequested: bar.closeAllPanels()
//     ClockContent { anchors.fill: parent }
//   }

PanelWindow {
  id: popup

  property var barRef: null

  property int popupW: 300
  property int popupH: 400

  property bool panelOpen:     false
  property real slideProgress: 0.0

  property color colorPanelBg: "#1f1f1f"
  property int   animDuration: 280
  property int   bgRadius:     12
  property real  bgOpacity:    0.95

  signal closeRequested()

  // ── Helpers internos — evitam bindings circulares ─────────────────────
  // Lê barRef.anchors.* como bool diretamente para não criar referência
  // circular entre PanelWindow.anchors e barRef.anchors.
  readonly property bool _barLeft:   barRef ? barRef.anchors.left   : false
  readonly property bool _barRight:  barRef ? barRef.anchors.right  : false
  readonly property bool _barTop:    barRef ? barRef.anchors.top    : false
  readonly property bool _barBottom: barRef ? barRef.anchors.bottom : false
  readonly property bool _isVertical: _barLeft && _barTop && _barBottom ||
                                      _barRight && _barTop && _barBottom

  // ── PanelWindow config ────────────────────────────────────────────────
  screen:         barRef ? barRef.screen : undefined
  color:          "transparent"
  implicitWidth:  popupW
  implicitHeight: popupH
  visible:        slideProgress > 0.0

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0

  // Ancora apenas à borda da barra + top.
  // Nunca top+bottom juntos — evita o PanelWindow esticar pela tela toda.
  anchors.top:    true
  anchors.bottom: false
  anchors.left:   _barLeft
  anchors.right:  _barRight

  margins.left: {
    if (!barRef) return 0
    if (_isVertical && _barLeft)
      // Popup sai pela direita da barra: margem = largura da barra + margem da barra
      return barRef.implicitWidth + (barRef.margins.left || 0)
    // Barra horizontal: centraliza
    var sw = barRef.screen ? barRef.screen.width : 1920
    return Math.max(0, Math.floor((sw - popupW) / 2))
  }

  margins.right: {
    if (!barRef) return 0
    if (_isVertical && _barRight)
      // Popup sai pela esquerda da barra
      return barRef.implicitWidth + (barRef.margins.right || 0)
    return 0
  }

  margins.top: {
    if (!barRef) return 0
    var sh = barRef.screen ? barRef.screen.height : 1080
    // Barra horizontal em cima
    if (_barTop && !_barBottom)
      return (barRef.implicitHeight || 0) + (barRef.margins.top || 0)
    // Barra horizontal em baixo
    if (_barBottom && !_barTop)
      return Math.max(0, sh - (barRef.implicitHeight || 0) - (barRef.margins.bottom || 0) - popupH)
    // Barra vertical: centraliza verticalmente dentro da área útil da barra
    // (desconta pillSideMargin quando pill, barMargin senão)
    var mt = barRef.margins.top    || 0
    var mb = barRef.margins.bottom || 0
    var usable = sh - mt - mb
    return Math.max(0, mt + Math.floor((usable - popupH) / 2))
  }

  margins.bottom: 0

  HyprlandFocusGrab {
    id: focusGrab
    windows:   [popup]
    active:    popup.panelOpen
    onCleared: popup.closeRequested()
  }

  // Alias para subclasses controlarem o grab (ex: QuickSettings com tray)
  property alias focusGrabActive: focusGrab.active

  Behavior on slideProgress {
    NumberAnimation { duration: popup.animDuration; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  Rectangle {
    id: bg
    anchors.fill: parent
    radius:  popup.bgRadius
    opacity: Math.min(1.0, popup.slideProgress * 2)
    color:   Qt.rgba(
      popup.colorPanelBg.r,
      popup.colorPanelBg.g,
      popup.colorPanelBg.b,
      popup.bgOpacity
    )
    default property alias content: bg.data
  }
}
