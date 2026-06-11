import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// ── BarPopup ───────────────────────────────────────────────────────────────
// Base de todos os popups da barra.
//
// ANIMAÇÃO:
//   Um único _animProg (0.0 → 1.0) controla opacity + translate.
//   Sem scale → conteúdo nunca muda de tamanho durante a transição.
//
//   ENTRADA (OutCubic):  slide prominent logo no início → sensação de "pop in"
//   SAÍDA   (OutCubic):  slide prominent logo no início → sensação de "fly away"
//   Usar OutCubic nos dois sentidos garante que o translate é sempre
//   visível desde o primeiro quadro — sem o ghost fade do Hyprland layersOut.
//
//   opacity  = min(1, _animProg × 1.4)      — opacidade completa em ~70% do prog.
//   translate = slideX/Y × (1 − _animProg)  — decresce com o progresso
//
//   Interrupção suave: ao abrir durante o fechamento (ou vice-versa),
//   a animação retoma do valor atual de _animProg.
//
//   _unmapTimer: delay de 1 quadro entre opacity=0 e visible=false,
//   garantindo que o compositor já processou o frame transparente antes do
//   unmap — evita que o Hyprland layersOut capture um frame opaco.

PanelWindow {
  id: popup

  // Redireciona filhos declarados em Bar.BarPopup { ... } para dentro do bg,
  // garantindo que o opacity e o transform do bg se apliquem ao conteúdo.
  default property alias content: bg.data

  // ── API pública ───────────────────────────────────────────────────────
  property var barRef: null

  property int  popupW: 300
  property int  popupH: 400

  // ── Posicionamento override (usado pelo DmenuPanel, ignorado pelos demais) ─
  // popupXAlign:  "center" | "left" | "right"  — alinhamento horizontal na tela
  //               "center" = padrão original ((sw - popupW) / 2)
  // popupYAnchor: "bar" | "top" | "bottom"     — âncora vertical
  //               "bar" = padrão original (junto da barra)
  // popupXOffset: px adicionais a partir da borda (left/right) ou deslocamento do centro
  // popupYOffset: px do topo ou da base (quando popupYAnchor != "bar")
  property string popupXAlign:  "center"
  property string popupYAnchor: "bar"
  property int    popupXOffset: 0
  property int    popupYOffset: 0

  property bool panelOpen: false

  property color colorPanelBg: "#1f1f1f"
  property int   animDuration: 200
  property int   bgRadius:     12
  property real  bgOpacity:    0.95

  signal closeRequested()

  // ── Detecção da posição da barra ──────────────────────────────────────
  // Usa barRef.position (int estável: 1=top 2=right 3=bottom 4=left) em vez de
  // barRef.anchors.* — ler anchors de um PanelWindow irmão e depois setar os
  // próprios anchors com base nisso causava um binding loop (stack overflow).
  readonly property int  _barPos:     barRef ? barRef.position : 2
  readonly property bool _barLeft:    _barPos === 4
  readonly property bool _barRight:   _barPos === 2
  readonly property bool _barTop:     _barPos === 1
  readonly property bool _barBottom:  _barPos === 3
  readonly property bool _isVertical: _barPos === 2 || _barPos === 4

  // ── Slide: direção de onde o painel "vem" / "vai" ────────────────────
  readonly property real _slideAmt: 14

  readonly property real _slideX: {
    if (!_isVertical) return 0
    if ( _barLeft && !_barRight) return -_slideAmt
    if (!_barLeft &&  _barRight) return  _slideAmt
    return 0
  }
  readonly property real _slideY: {
    if (_isVertical) return 0
    // Override YAnchor altera direção do slide
    if (popupYAnchor === "top")    return -_slideAmt
    if (popupYAnchor === "bottom") return  _slideAmt
    if ( _barTop && !_barBottom)   return -_slideAmt
    if (!_barTop  &&  _barBottom)  return  _slideAmt
    return -_slideAmt
  }

  // ── Estado de animação ────────────────────────────────────────────────
  property real _animProg: 0.0
  property bool _alive:    false
  property bool _closing:  false

  visible: _alive

  onPanelOpenChanged: {
      if (panelOpen) {
          _closing = false
          _alive   = true
          _unmapTimer.stop()
          _safetyUnmapTimer.stop()
          closeAnim.stop()
          openAnim.from = _animProg
          openAnim.to   = 1.0
          openAnim.start()
      } else {
          _closing = true
          openAnim.stop()
          closeAnim.from = _animProg
          closeAnim.to   = 0.0
          closeAnim.start()
          _safetyUnmapTimer.restart()
      }
  }

  // ── Configuração da janela ────────────────────────────────────────────
  // FIX: era "undefined" quando barRef é null — undefined não é atribuível
  // ao tipo QuickshellScreenInfo*, causando o WARN "Unable to assign [undefined]".
  // null é o valor correto para "sem screen específica" em PanelWindow.
  screen:         barRef ? barRef.screen : null
  color:          "transparent"
  implicitWidth:  popupW
  implicitHeight: popupH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0

  anchors.top:    true
  anchors.bottom: false
  anchors.left:   _barLeft
  anchors.right:  _barRight

  margins.left: {
    if (!barRef) return 0
    // Barra vertical esquerda: encosta sempre na barra (sem override de XAlign)
    if (_isVertical && _barLeft)
      return barRef.implicitWidth + (barRef.margins.left || 0)
    var sw = barRef.screen ? barRef.screen.width : 1920
    if (popupXAlign === "left")
      return Math.max(0, popupXOffset)
    if (popupXAlign === "right")
      return Math.max(0, sw - popupW - popupXOffset)
    // "center" (padrão)
    return Math.max(0, Math.floor((sw - popupW) / 2) + popupXOffset)
  }
  margins.right: {
    if (!barRef) return 0
    if (_isVertical && _barRight)
      return barRef.implicitWidth + (barRef.margins.right || 0)
    return 0
  }
  margins.top: {
    if (!barRef) return 0
    var sh = barRef.screen ? barRef.screen.height : 1080

    // Override: flutuar no topo ou base do monitor
    if (popupYAnchor === "top")
      return Math.max(0, popupYOffset)
    if (popupYAnchor === "bottom")
      return Math.max(0, sh - popupH - popupYOffset)

    // "bar" (padrão): encosta na barra
    if (_barTop && !_barBottom)
      return (barRef.implicitHeight || 0) + (barRef.margins.top || 0)
    if (_barBottom && !_barTop)
      return Math.max(0, sh - (barRef.implicitHeight || 0) - (barRef.margins.bottom || 0) - popupH)
    var mt = barRef.margins.top    || 0
    var mb = barRef.margins.bottom || 0
    var usable = sh - mt - mb
    return Math.max(0, mt + Math.floor((usable - popupH) / 2))
  }
  margins.bottom: 0

  // ── Focus grab ────────────────────────────────────────────────────────
  HyprlandFocusGrab {
    id: focusGrab
    windows:   [popup]
    active:    popup.panelOpen
    onCleared: popup.closeRequested()
  }

  property alias focusGrabActive: focusGrab.active

  // ── Timer de unmap ────────────────────────────────────────────────────
  // Aguarda 1 quadro após opacity=0 antes de desmapar.
  // Garante que o Hyprland já processou o frame transparente antes do unmap,
  // evitando que layersOut capture um frame visível e sobreponha um fade.
  Timer {
    id: _unmapTimer
    interval: 17   // ~1 quadro a 60 fps
    repeat:   false
    onTriggered: {
      if (popup._closing) {
        popup._alive   = false
        popup._closing = false
      }
    }
  }

  Timer {
      id: _safetyUnmapTimer
      interval: popup.animDuration + 200   // animação (200ms) + folga
      repeat:   false
      onTriggered: {
          if (!popup.panelOpen) {
              popup._alive   = false
              popup._closing = false
              _unmapTimer.stop()
          }
      }
  }
  // ── Animação de abertura ──────────────────────────────────────────────
  NumberAnimation {
    id: openAnim
    target:      popup
    property:    "_animProg"
    duration:    popup.animDuration
    easing.type: Easing.OutCubic
  }

  // ── Animação de fechamento ────────────────────────────────────────────
  // OutCubic (não InCubic): slide visível desde o primeiro quadro.
  // InCubic concentrava 80% do movimento nos últimos 20% do tempo —
  // o olho não via o slide, só o fade do Hyprland layersOut depois.
  NumberAnimation {
    id: closeAnim
    target:      popup
    property:    "_animProg"
    duration:    popup.animDuration
    easing.type: Easing.OutCubic
    onStopped: {
      if (popup._closing) _unmapTimer.restart()
    }
  }

  // ── Painel visual ─────────────────────────────────────────────────────
  Rectangle {
    id: bg
    anchors.fill: parent
    radius:  popup.bgRadius
    clip:    true

    opacity: Math.min(1.0, popup._animProg * 1.4)

    transform: Translate {
      x: popup._slideX * (1.0 - popup._animProg)
      y: popup._slideY * (1.0 - popup._animProg)
    }

    color: Qt.rgba(
      popup.colorPanelBg.r,
      popup.colorPanelBg.g,
      popup.colorPanelBg.b,
      popup.bgOpacity
    )
  }
}
