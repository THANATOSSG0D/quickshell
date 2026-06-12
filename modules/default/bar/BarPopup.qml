import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs

// ── BarPopup ───────────────────────────────────────────────────────────────────
// Base de todos os popups da barra.
//
// ── API original (inalterada) ─────────────────────────────────────────────────
//   barRef          — referência ao PanelWindow da barra (obrigatório)
//   panelOpen       — abre/fecha o popup
//   popupW/popupH   — dimensões
//   popupXAlign     — "center"|"left"|"right"
//   popupYAnchor    — "bar"|"top"|"bottom"
//   popupXOffset    — deslocamento horizontal
//   popupYOffset    — deslocamento vertical
//   colorPanelBg    — cor de fundo (aceita cor direta)
//   animDuration    — duração da animação em ms
//   bgRadius        — raio de borda do Rectangle
//   bgOpacity       — opacidade do fundo 0.0–1.0
//   closeRequested  — sinal emitido ao clicar fora (focus grab cleared)
//   focusGrabActive — controla o HyprlandFocusGrab diretamente
//   content         — default property alias para conteúdo filho
//
// ── Cores de conteúdo (passadas pelo Bar.qml, usadas pelos filhos) ─────────────
//   colorText / colorTextDim / colorAccent / colorMuted
//   colorProgressBg / colorProgressFg / colorDivider / colorInputBg
//   Defaults baseados em Colors (matugen) — sobrescritos pelo tema ativo.
//
// ── Novas props (todas com defaults que preservam comportamento original) ───────
//   animationStyle  — "slide"(padrão)|"fade"|"scale"|"scale-slide"|"none"
//   shadowEnabled   — bool (padrão false)
//   shadowBlur      — px (padrão 16)
//   shadowOffsetX/Y — px (padrão 0/4)
//   shadowColor     — color (padrão Colors.shadow @ shadowOpacity)
//   shadowOpacity   — 0–1 (padrão 0.45)
//   borderWidth     — px (padrão 0)
//   borderColor     — color (padrão Colors.outline_variant)
//   popupTitle      — string; se não vazio, exibe header com título
//   popupIcon       — ícone Nerd Font para o header
//   layoutMode      — "single"(padrão)|"dual"
//   sidebarWidth    — largura da sidebar em dual (padrão 200)
//   sidebarItem     — alias para o Item da coluna esquerda (dual)
//   previewItem     — alias para o Item da coluna direita (dual)
//   configName      — chave para lookup em PopupConfig (padrão: objectName)

PanelWindow {
  id: popup

  // Redireciona filhos para dentro do bg, garantindo que opacity e transform
  // do bg se apliquem ao conteúdo. Compatível com todos os popups existentes.
  default property alias content: _singleSlot.data

  // ── API original ───────────────────────────────────────────────────────────
  property var    barRef:       null
  property int    popupW:       300
  property int    popupH:       400
  property string popupXAlign:  "center"
  property string popupYAnchor: "bar"
  property int    popupXOffset: 0
  property int    popupYOffset: 0
  property bool   panelOpen:    false
  property color  colorPanelBg: Colors.surface_container
  property int    animDuration: 280
  property int    bgRadius:     12
  property real   bgOpacity:    0.95
  signal closeRequested()

  // ── Cores de conteúdo — passadas pelo Bar.qml ──────────────────────────────
  property color colorText:       Colors.on_surface
  property color colorTextDim:    Colors.on_surface_variant
  property color colorAccent:     Colors.primary
  property color colorMuted:      Colors.error
  property color colorProgressBg: Colors.surface_container_high
  property color colorProgressFg: Colors.primary
  property color colorDivider:    Colors.outline_variant
  property color colorInputBg:    Colors.surface_container_low

  // ── Resolução de token de cor do PopupConfig ───────────────────────────────
  // Converte chave de paleta matugen (ex: "surface_container") para cor QML.
  // Aplicado reativamente via Binding — muda quando matugen atualiza Colors.
  function _resolveToken(token) {
    if (!token || token === "auto") return null
    // Mapa de tokens → propriedades do singleton Colors
    var map = {
      "background":                Colors.background,
      "error":                     Colors.error,
      "error_container":           Colors.error_container,
      "inverse_on_surface":        Colors.inverse_on_surface,
      "inverse_primary":           Colors.inverse_primary,
      "inverse_surface":           Colors.inverse_surface,
      "on_background":             Colors.on_background,
      "on_error":                  Colors.on_error,
      "on_primary":                Colors.on_primary,
      "on_primary_container":      Colors.on_primary_container,
      "on_secondary":              Colors.on_secondary,
      "on_secondary_container":    Colors.on_secondary_container,
      "on_surface":                Colors.on_surface,
      "on_surface_variant":        Colors.on_surface_variant,
      "on_tertiary":               Colors.on_tertiary,
      "on_tertiary_container":     Colors.on_tertiary_container,
      "outline":                   Colors.outline,
      "outline_variant":           Colors.outline_variant,
      "primary":                   Colors.primary,
      "primary_container":         Colors.primary_container,
      "scrim":                     Colors.scrim,
      "secondary":                 Colors.secondary,
      "secondary_container":       Colors.secondary_container,
      "shadow":                    Colors.shadow,
      "source_color":              Colors.source_color,
      "surface":                   Colors.surface,
      "surface_bright":            Colors.surface_bright,
      "surface_container":         Colors.surface_container,
      "surface_container_high":    Colors.surface_container_high,
      "surface_container_highest": Colors.surface_container_highest,
      "surface_container_low":     Colors.surface_container_low,
      "surface_container_lowest":  Colors.surface_container_lowest,
      "surface_dim":               Colors.surface_dim,
      "surface_variant":           Colors.surface_variant,
      "tertiary":                  Colors.tertiary,
      "tertiary_container":        Colors.tertiary_container,
    }
    var c = map[token]
    return c !== undefined ? c : null
  }

  // Aplica cores do PopupConfig reativamente (responde a mudanças no JSON e no matugen)
  readonly property string _cfgName: configName || objectName
  Binding on colorPanelBg {
    when: { var t = PopupConfig.get(popup._cfgName, "colorPanelBg", null)
            if (!t) t = PopupConfig.get(null, "colorPanelBg", null)
            return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorPanelBg", null)
      if (!t) t = PopupConfig.get(null, "colorPanelBg", null)
      return popup._resolveToken(t) || Colors.surface_container
    }
  }
  Binding on colorText {
    when: { var t = PopupConfig.get(popup._cfgName, "colorText", null)
            if (!t) t = PopupConfig.get(null, "colorText", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorText", null)
      if (!t) t = PopupConfig.get(null, "colorText", null)
      return popup._resolveToken(t) || Colors.on_surface
    }
  }
  Binding on colorTextDim {
    when: { var t = PopupConfig.get(popup._cfgName, "colorTextDim", null)
            if (!t) t = PopupConfig.get(null, "colorTextDim", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorTextDim", null)
      if (!t) t = PopupConfig.get(null, "colorTextDim", null)
      return popup._resolveToken(t) || Colors.on_surface_variant
    }
  }
  Binding on colorAccent {
    when: { var t = PopupConfig.get(popup._cfgName, "colorAccent", null)
            if (!t) t = PopupConfig.get(null, "colorAccent", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorAccent", null)
      if (!t) t = PopupConfig.get(null, "colorAccent", null)
      return popup._resolveToken(t) || Colors.primary
    }
  }
  Binding on colorProgressBg {
    when: { var t = PopupConfig.get(popup._cfgName, "colorProgressBg", null)
            if (!t) t = PopupConfig.get(null, "colorProgressBg", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorProgressBg", null)
      if (!t) t = PopupConfig.get(null, "colorProgressBg", null)
      return popup._resolveToken(t) || Colors.surface_container_high
    }
  }
  Binding on colorProgressFg {
    when: { var t = PopupConfig.get(popup._cfgName, "colorProgressFg", null)
            if (!t) t = PopupConfig.get(null, "colorProgressFg", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorProgressFg", null)
      if (!t) t = PopupConfig.get(null, "colorProgressFg", null)
      return popup._resolveToken(t) || Colors.primary
    }
  }
  Binding on colorDivider {
    when: { var t = PopupConfig.get(popup._cfgName, "colorDivider", null)
            if (!t) t = PopupConfig.get(null, "colorDivider", null); return !!t }
    value: {
      var t = PopupConfig.get(popup._cfgName, "colorDivider", null)
      if (!t) t = PopupConfig.get(null, "colorDivider", null)
      return popup._resolveToken(t) || Colors.outline_variant
    }
  }

  // ── Novas props — animação ─────────────────────────────────────────────────
  property string animationStyle: "scale-slide"  // "slide"|"fade"|"scale"|"scale-slide"|"none"

  // ── Novas props — sombra ───────────────────────────────────────────────────
  property bool  shadowEnabled:  false
  property real  shadowBlur:     16
  property int   shadowOffsetX:  0
  property int   shadowOffsetY:  4
  property color shadowColor:    Colors.shadow
  property real  shadowOpacity:  0.45

  // ── Novas props — borda ────────────────────────────────────────────────────
  property int   borderWidth: 0
  property color borderColor: Colors.outline_variant

  // ── Novas props — header opcional ─────────────────────────────────────────
  property string popupTitle: ""
  property string popupIcon:  ""

  // ── Novas props — layout dual ──────────────────────────────────────────────
  property string layoutMode:   "single"
  property int    sidebarWidth: 200
  property alias  sidebarItem:  _sidebarSlot
  property alias  previewItem:  _previewSlot

  // ── Config name para lookup em PopupConfig ─────────────────────────────────
  property string configName: objectName

  // ── Detecção da posição da barra (idêntica ao original) ───────────────────
  readonly property int  _barPos:     barRef ? barRef.position : 2
  readonly property bool _barLeft:    _barPos === 4
  readonly property bool _barRight:   _barPos === 2
  readonly property bool _barTop:     _barPos === 1
  readonly property bool _barBottom:  _barPos === 3
  readonly property bool _isVertical: _barPos === 2 || _barPos === 4

  // ── Slide: direção (idêntica ao original) ─────────────────────────────────
  readonly property real _slideAmt: 20

  readonly property real _slideX: {
    if (!_isVertical) return 0
    if ( _barLeft && !_barRight) return -_slideAmt
    if (!_barLeft &&  _barRight) return  _slideAmt
    return 0
  }
  readonly property real _slideY: {
    if (_isVertical) return 0
    if (popupYAnchor === "top")    return -_slideAmt
    if (popupYAnchor === "bottom") return  _slideAmt
    if ( _barTop && !_barBottom)   return -_slideAmt
    if (!_barTop  &&  _barBottom)  return  _slideAmt
    return -_slideAmt
  }

  // ── Estado de animação (idêntico ao original) ─────────────────────────────
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

  // ── Configuração da janela (idêntica ao original) ─────────────────────────
  screen:         barRef ? barRef.screen : null
  color:          "transparent"
  implicitWidth:  popupW + (shadowEnabled ? shadowBlur * 2 : 0)
  implicitHeight: popupH + (shadowEnabled ? shadowBlur * 2 : 0)

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0

  anchors.top:    true
  anchors.bottom: false
  anchors.left:   !_isVertical || _barLeft  // barra horizontal: sempre ancora à esquerda
  anchors.right:  _barRight

  // ── Margens (idênticas ao original, com padding de sombra) ────────────────
  // _shadowPad: usa Math.ceil seguro — shadowBlur é sempre um number inicializado
  readonly property int _shadowPad: (shadowEnabled && shadowBlur > 0) ? Math.ceil(shadowBlur) : 0

  margins.left: {
    if (!barRef || !barRef.screen) return 0
    var pad = popup._shadowPad
    var ml  = barRef.margins ? (barRef.margins.left  || 0) : 0
    var mr  = barRef.margins ? (barRef.margins.right || 0) : 0
    var biw = barRef.implicitWidth || 0
    if (_isVertical && _barLeft)
      return Math.max(0, biw + ml - pad)
    var sw = barRef.screen.width || 1920
    if (popupXAlign === "left")
      return Math.max(0, popupXOffset - pad)
    if (popupXAlign === "right")
      return Math.max(0, sw - popupW - popupXOffset - pad)
    return Math.max(0, Math.floor((sw - popupW) / 2) + popupXOffset - pad)
  }
  margins.right: {
    if (!barRef || !barRef.screen) return 0
    var pad = popup._shadowPad
    var mr  = barRef.margins ? (barRef.margins.right || 0) : 0
    var biw = barRef.implicitWidth || 0
    if (_isVertical && _barRight)
      return Math.max(0, biw + mr - pad)
    return 0
  }
  margins.top: {
    if (!barRef || !barRef.screen) return 0
    var sh  = barRef.screen.height || 1080
    var pad = popup._shadowPad
    var mt  = barRef.margins ? (barRef.margins.top    || 0) : 0
    var mb  = barRef.margins ? (barRef.margins.bottom || 0) : 0
    var bih = barRef.implicitHeight || 0
    if (popupYAnchor === "top")
      return Math.max(0, popupYOffset - pad)
    if (popupYAnchor === "bottom")
      return Math.max(0, sh - popupH - popupYOffset - pad)
    if (_barTop && !_barBottom)
      return Math.max(0, bih + mt - pad)
    if (_barBottom && !_barTop)
      return Math.max(0, sh - bih - mb - popupH - pad)
    var usable = sh - mt - mb
    return Math.max(0, mt + Math.floor((usable - popupH) / 2) - pad)
  }
  margins.bottom: 0

  // ── Focus grab ────────────────────────────────────────────────────────────
  HyprlandFocusGrab {
    id: focusGrab
    windows:   [popup]
    active:    popup.panelOpen
    onCleared: popup.closeRequested()
  }

  // focusGrabActive exposto para QuickSettingsPopup:
  //   focusGrabActive: panelOpen && !qsContent.trayMenuOpen
  property alias focusGrabActive: focusGrab.active

  // ── Timers (idênticos ao original) ────────────────────────────────────────
  Timer {
    id: _unmapTimer
    interval: 17
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
    interval: popup.animDuration + 200
    repeat:   false
    onTriggered: {
      if (!popup.panelOpen) {
        popup._alive   = false
        popup._closing = false
        _unmapTimer.stop()
      }
    }
  }

  // ── Animações (idênticas ao original) ─────────────────────────────────────
  NumberAnimation {
    id: openAnim
    target:           popup
    property:         "_animProg"
    duration:         popup.animDuration
    easing.type:      Easing.OutBack
    easing.overshoot: 0.5
  }

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

  // ── Cálculos de transform por animationStyle ──────────────────────────────
  // "slide"       — comportamento original: translate + fade
  // "fade"        — só opacity
  // "scale"       — scale + opacity, sem translate
  // "scale-slide" — scale + translate + opacity
  // "none"        — sem animação (aparece/desaparece instantâneo)

  readonly property real _bgOpacity: {
    switch (animationStyle) {
      case "none":        return _alive ? bgOpacity : 0
      case "fade":        return _animProg * bgOpacity
      case "scale":       return _animProg * bgOpacity
      case "scale-slide": return _animProg * bgOpacity
      default:            return Math.min(bgOpacity, _animProg * 1.4 * bgOpacity)  // slide original
    }
  }
  readonly property real _bgTransX: {
    switch (animationStyle) {
      case "slide":       return _slideX * (1.0 - _animProg)
      case "scale-slide": return _slideX * (1.0 - _animProg)
      default:            return 0
    }
  }
  readonly property real _bgTransY: {
    switch (animationStyle) {
      case "slide":       return _slideY * (1.0 - _animProg)
      case "scale-slide": return _slideY * (1.0 - _animProg)
      default:            return 0
    }
  }
  readonly property real _bgScale: {
    switch (animationStyle) {
      case "scale":       return 0.82 + 0.18 * _animProg
      case "scale-slide": return 0.87 + 0.13 * _animProg
      default:            return 1.0
    }
  }

  // ── Altura do header ───────────────────────────────────────────────────────
  readonly property int _headerH: (popupTitle.length > 0) ? 38 : 0

  // ── UI ─────────────────────────────────────────────────────────────────────
  // _shadowPadItem garante que a sombra não seja cortada pela bounding box.
  Item {
    id: _shadowPadItem
    x:      popup._shadowPad
    y:      popup._shadowPad
    width:  popup.popupW
    height: popup.popupH

    // Sombra via MultiEffect — Qt 6.5+
    MultiEffect {
      anchors.fill:           bg
      source:                 bg
      visible:                popup.shadowEnabled && popup._alive
      shadowEnabled:          popup.shadowEnabled
      shadowBlur:             popup.shadowBlur / 64
      shadowHorizontalOffset: popup.shadowOffsetX
      shadowVerticalOffset:   popup.shadowOffsetY
      shadowColor: Qt.rgba(
        popup.shadowColor.r,
        popup.shadowColor.g,
        popup.shadowColor.b,
        popup.shadowOpacity
      )
      opacity: popup._animProg
    }

    Rectangle {
      id: bg
      anchors.fill: parent
      radius: popup.bgRadius
      clip:   true

      opacity: popup._bgOpacity

      color: Qt.rgba(
        popup.colorPanelBg.r,
        popup.colorPanelBg.g,
        popup.colorPanelBg.b,
        popup.bgOpacity
      )

      border.width: popup.borderWidth
      border.color: Qt.rgba(
        popup.borderColor.r,
        popup.borderColor.g,
        popup.borderColor.b,
        popup.borderWidth > 0 ? 0.7 : 0
      )

      transform: [
        Translate { x: popup._bgTransX; y: popup._bgTransY },
        Scale {
          xScale: popup._bgScale; yScale: popup._bgScale
          origin.x: popup._barLeft  ? 0 :
                    popup._barRight ? bg.width : bg.width / 2
          origin.y: (popup._barTop && !popup._barBottom)  ? 0 :
                    (!popup._barTop && popup._barBottom)  ? bg.height :
                    popup.popupYAnchor === "bottom"       ? bg.height :
                    popup.popupYAnchor === "top"          ? 0 : bg.height / 2
        }
      ]

      // ── Header opcional ────────────────────────────────────────────────────
      Rectangle {
        id: _header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height:  popup._headerH
        visible: popup.popupTitle.length > 0
        color:   Qt.darker(popup.colorPanelBg, 1.12)
        radius:  popup.bgRadius

        Rectangle {
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: popup.bgRadius; color: parent.color
        }

        Row {
          anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
          spacing: 8
          Text {
            text:    popup.popupIcon
            visible: popup.popupIcon.length > 0
            color:   Colors.primary
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text:  popup.popupTitle
            color: Colors.on_surface
            font { pixelSize: 12; weight: 600 }
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 1
          color:  Qt.rgba(Colors.outline_variant.r, Colors.outline_variant.g,
                          Colors.outline_variant.b, 0.4)
        }
      }

      // ── Área de conteúdo ───────────────────────────────────────────────────
      Item {
        anchors {
          top:    _header.visible ? _header.bottom : parent.top
          left:   parent.left; right: parent.right; bottom: parent.bottom
        }

        // Single layout — default, todos os filhos do BarPopup vão aqui
        Item {
          id: _singleSlot
          anchors.fill: parent
          visible: popup.layoutMode === "single"
        }

        // Dual layout — sidebar esquerda + preview direita
        Row {
          anchors.fill: parent
          visible: popup.layoutMode === "dual"
          spacing: 0

          Item {
            id: _sidebarSlot
            width:  popup.sidebarWidth
            height: parent.height

            Rectangle {
              anchors.fill: parent
              color:  Qt.darker(popup.colorPanelBg, 1.10)
              radius: popup.bgRadius
              Rectangle {
                anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                width: popup.bgRadius; color: parent.color
              }
            }
          }

          Rectangle {
            width: 1; height: parent.height
            color: Qt.rgba(Colors.outline_variant.r, Colors.outline_variant.g,
                           Colors.outline_variant.b, 0.3)
          }

          Item {
            id: _previewSlot
            width:  parent.width - popup.sidebarWidth - 1
            height: parent.height
          }
        }
      }
    }
  }

  // ── Aplicação de PopupConfig ao completar ─────────────────────────────────
  Component.onCompleted: {
    var name = popup.configName || popup.objectName
    if (!name || name.length === 0) return

    function applyIfSet(key, setter) {
      var v = PopupConfig.get(name, key, undefined)
      if (v !== undefined) setter(v)
    }

    applyIfSet("animationStyle", function(v){ popup.animationStyle = v })
    applyIfSet("animDuration",   function(v){ popup.animDuration   = v })
    applyIfSet("borderWidth",    function(v){ popup.borderWidth    = v })
    applyIfSet("shadowEnabled",  function(v){ popup.shadowEnabled  = v })
    applyIfSet("shadowBlur",     function(v){ popup.shadowBlur     = v })
    applyIfSet("shadowOffsetX",  function(v){ popup.shadowOffsetX  = v })
    applyIfSet("shadowOffsetY",  function(v){ popup.shadowOffsetY  = v })
    applyIfSet("shadowOpacity",  function(v){ popup.shadowOpacity  = v })
    applyIfSet("bgOpacity",      function(v){ popup.bgOpacity      = v })
    applyIfSet("bgRadius",       function(v){ popup.bgRadius       = v })
    applyIfSet("layoutMode",     function(v){ popup.layoutMode     = v })
    applyIfSet("sidebarWidth",   function(v){ popup.sidebarWidth   = v })
    applyIfSet("popupW",         function(v){ popup.popupW         = v })
    applyIfSet("popupH",         function(v){ popup.popupH         = v })
    applyIfSet("popupTitle",     function(v){ popup.popupTitle     = v })
    applyIfSet("popupIcon",      function(v){ popup.popupIcon      = v })
  }
}
