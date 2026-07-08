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
//   animationStyle  — "slide"(padrão)|"fade"|"scale"|"scale-slide"|"reveal"|"none"
//     "reveal" — gaveta: máscara de clip cresce a partir da borda que toca a
//                barra, sem mover/escalar o conteúdo. Dá a sensação de que o
//                popup é "puxado para fora" da barra, em vez de aparecer
//                flutuando por cima dela.
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

  // ── Modo de cantos ────────────────────────────────────────────────────────
  // "all"    — todos os 4 cantos arredondados (padrão original)
  // "bar"    — o(s) canto(s) que tocam a barra ficam retos, os outros arredondados
  // "screen" — o(s) canto(s) que tocam a borda do monitor ficam retos
  property string cornerMode: "all"

  // Raios por canto calculados de acordo com cornerMode + posição da barra
  readonly property int _rTL: _cornerR(true,  false)  // top-left
  readonly property int _rTR: _cornerR(true,  true)   // top-right
  readonly property int _rBL: _cornerR(false, false)  // bottom-left
  readonly property int _rBR: _cornerR(false, true)   // bottom-right

  // _cornerR(isTop, isRight): retorna 0 se o canto toca o elemento de referência,
  // bgRadius caso contrário.
  function _cornerR(isTop, isRight) {
    if (cornerMode === "all") return bgRadius
    var r = bgRadius
    if (cornerMode === "bar") {
      // Zera o(s) canto(s) que tocam a barra
      if (_barTop    && isTop   ) r = 0
      if (_barBottom && !isTop  ) r = 0
      if (_barLeft   && !isRight) r = 0
      if (_barRight  && isRight ) r = 0
    } else if (cornerMode === "screen") {
      // Zera o(s) canto(s) que tocam a borda do monitor (como na screenshot)
      // Modo "bar" na borda esquerda: popup fica encostado na barra à esquerda,
      // então o canto esquerdo (top-left e bottom-left) toca a barra/borda.
      // No modo flutuante (top/bottom), os cantos que tocam a borda do monitor
      // são os que ficam na direção da âncora.
      if (!_floating) {
        if (_barTop    && isTop   ) r = 0
        if (_barBottom && !isTop  ) r = 0
        if (_barLeft   && !isRight) r = 0
        if (_barRight  && isRight ) r = 0
      } else {
        if (_floatTop    && isTop   ) r = 0
        if (_floatBottom && !isTop  ) r = 0
      }
    }
    return r
  }
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

  // ── PopupConfig da instância certa (bar ou dock) ───────────────────────────
  // Antes era um singleton global (PopupConfig.get(...) direto). Agora cada
  // instância (bar/dock) tem sua PRÓPRIA PopupConfig — o popup só enxerga
  // qual é através de barRef (a PanelWindow que o instanciou, que expõe
  // popupConfigRef). _pcGet nunca quebra se _pc ainda for null (ex: um
  // instante antes do barRef ser atribuído) — simplesmente cai no fallback,
  // exatamente como antes de o arquivo JSON carregar.
  readonly property var _pc: barRef ? barRef.popupConfigRef : null
  function _pcGet(name, key, fallback) {
    return popup._pc ? popup._pc.get(name, key, fallback) : fallback
  }

  // Aplica cores do PopupConfig reativamente (responde a mudanças no JSON e no matugen)
  readonly property string _cfgName: configName || objectName
  Binding on colorPanelBg {
    when: { var t = popup._pcGet(popup._cfgName, "colorPanelBg", null)
            if (!t) t = popup._pcGet(null, "colorPanelBg", null)
            return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorPanelBg", null)
      if (!t) t = popup._pcGet(null, "colorPanelBg", null)
      return popup._resolveToken(t) || Colors.surface_container
    }
  }
  Binding on colorText {
    when: { var t = popup._pcGet(popup._cfgName, "colorText", null)
            if (!t) t = popup._pcGet(null, "colorText", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorText", null)
      if (!t) t = popup._pcGet(null, "colorText", null)
      return popup._resolveToken(t) || Colors.on_surface
    }
  }
  Binding on colorTextDim {
    when: { var t = popup._pcGet(popup._cfgName, "colorTextDim", null)
            if (!t) t = popup._pcGet(null, "colorTextDim", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorTextDim", null)
      if (!t) t = popup._pcGet(null, "colorTextDim", null)
      return popup._resolveToken(t) || Colors.on_surface_variant
    }
  }
  Binding on colorAccent {
    when: { var t = popup._pcGet(popup._cfgName, "colorAccent", null)
            if (!t) t = popup._pcGet(null, "colorAccent", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorAccent", null)
      if (!t) t = popup._pcGet(null, "colorAccent", null)
      return popup._resolveToken(t) || Colors.primary
    }
  }
  Binding on colorProgressBg {
    when: { var t = popup._pcGet(popup._cfgName, "colorProgressBg", null)
            if (!t) t = popup._pcGet(null, "colorProgressBg", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorProgressBg", null)
      if (!t) t = popup._pcGet(null, "colorProgressBg", null)
      return popup._resolveToken(t) || Colors.surface_container_high
    }
  }
  Binding on colorProgressFg {
    when: { var t = popup._pcGet(popup._cfgName, "colorProgressFg", null)
            if (!t) t = popup._pcGet(null, "colorProgressFg", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorProgressFg", null)
      if (!t) t = popup._pcGet(null, "colorProgressFg", null)
      return popup._resolveToken(t) || Colors.primary
    }
  }
  Binding on colorDivider {
    when: { var t = popup._pcGet(popup._cfgName, "colorDivider", null)
            if (!t) t = popup._pcGet(null, "colorDivider", null); return !!t }
    value: {
      var t = popup._pcGet(popup._cfgName, "colorDivider", null)
      if (!t) t = popup._pcGet(null, "colorDivider", null)
      return popup._resolveToken(t) || Colors.outline_variant
    }
  }

  // ── Novas props — animação ─────────────────────────────────────────────────
  property string animationStyle: "scale-slide"  // "slide"|"fade"|"scale"|"scale-slide"|"reveal"|"none"

  // ── Conexão com a barra/tela ────────────────────────────────────────────────
  // attachOffset: gap extra (px) entre o popup e a barra/borda da tela, somado
  // por cima do encaixe "flush" (sem padding) quando o popup está "preso".
  // Default 0 = totalmente colado. Útil quando a barra NÃO é uma pill
  // (full-width) e ficar 100% colado parece estranho — um offset pequeno
  // (4-8px) dá a impressão de "perto, mas não conectado", se for o efeito
  // desejado. Não tem efeito nos modos "monitor" (use popupYOffset/
  // popupXOffset, que já servem esse propósito ali) ou "loose".
  property int attachOffset: 0

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

  // ── Detecção automática do modo de conexão ─────────────────────────────────
  // "bar"     → preso na barra: cresce a partir da borda dela (sem padding ali).
  // "monitor" → preso na borda do monitor (popupYAnchor "top"/"bottom"),
  //             usa popupXOffset/popupYOffset como gap configurável.
  // "loose"   → solto (sem barRef): padding/sombra simétricos nos 4 lados,
  //             como um diálogo flutuante de verdade, sem fingir conexão.
  readonly property string _attachMode: !barRef ? "loose" : (_floating ? "monitor" : "bar")

  // ── Slide: direção (idêntica ao original) ─────────────────────────────────
  readonly property real _slideAmt: 36   // era 20 — mais perceptível

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

  // ── Configuração da janela ─────────────────────────────────────────────────
  // screen nunca deve ser null — null faz o compositor Wayland ignorar as anchors
  // e posicionar a janela no output padrão sem margens corretas.
  // Fallback para Quickshell.screens[0] garante que sempre há um output válido.
  screen: barRef ? barRef.screen
                 : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
  color:          "transparent"

  // ── Padding de sombra assimétrico ───────────────────────────────────────────
  // PROBLEMA ORIGINAL: o padding da sombra (_shadowPad) era simétrico nos 4
  // lados. Isso fazia a *janela* (não o conteúdo visível) se estender alguns
  // pixels para dentro da área da barra no lado que toca nela — e como o
  // popup usa WlrLayershell.Overlay (acima da barra, que é Top), esses pixels
  // "extras" (incluindo o blur da sombra) renderizavam por cima da barra.
  // Era sutil com slide/fade, mas ficou óbvio com o "reveal".
  // FIX: zerar o padding exatamente no lado que toca a barra/tela — a
  // superfície da janela passa a nascer flush com a barra, então não há
  // como a sombra (ou qualquer outra coisa) vazar por cima dela.
  readonly property bool _touchTop:    _floatTop    || (!!barRef && _barTop    && !_floating)
  readonly property bool _touchBottom: _floatBottom || (!!barRef && _barBottom && !_floating)
  readonly property bool _touchLeft:   !!barRef && !_floating && _isVertical && _barLeft
  readonly property bool _touchRight:  !!barRef && !_floating && _isVertical && _barRight

  readonly property int _padTop:    _touchTop    ? 0 : popup._shadowPad
  readonly property int _padBottom: _touchBottom ? 0 : popup._shadowPad
  readonly property int _padLeft:   _touchLeft   ? 0 : popup._shadowPad
  readonly property int _padRight:  _touchRight  ? 0 : popup._shadowPad

  implicitWidth:  popupW + _padLeft + _padRight
  implicitHeight: popupH + _padTop  + _padBottom

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.namespace:     "qs-barpopup"

  // ── Anchors do layer shell ─────────────────────────────────────────────────
  // Modo "bar" (ancora na barra): comportamento original.
  // Modo "top":    âncora topo+esquerda  → margins.top = dist. do topo, margins.left = pos X.
  // Modo "bottom": âncora base+esquerda  → margins.bottom = dist. da base, margins.left = pos X.
  // No modo flutuante, ignoramos a posição da barra e sempre ancoramos à esquerda
  // para controlar a posição X via margins.left (centro, esquerda ou direita do monitor).
  readonly property bool _floating:    popupYAnchor === "top" || popupYAnchor === "bottom"
  readonly property bool _floatBottom: popupYAnchor === "bottom"
  readonly property bool _floatTop:    popupYAnchor === "top"

  anchors.top:    !_floatBottom
  anchors.bottom: _floatBottom
  anchors.left:   _floating ? true : (!_isVertical || _barLeft)
  anchors.right:  _floating ? false : _barRight

  // ── Margens (com padding de sombra) ──────────────────────────────────────
  // _shadowPad: usa Math.ceil seguro — shadowBlur é sempre um number inicializado
  readonly property int _shadowPad: (shadowEnabled && shadowBlur > 0) ? Math.ceil(shadowBlur) : 0

  // _screenW / _screenH lidos via `screen` do próprio PanelWindow (não via barRef.screen).
  // Isso garante que as margens sejam reativas e corretas mesmo quando barRef ainda não
  // tem a screen resolvida — eliminando o bug de canto esquerdo no modo flutuante.
  readonly property int _screenW: screen ? (screen.width  || 1920) : 1920
  readonly property int _screenH: screen ? (screen.height || 1080) : 1080

  margins.left: {
    var pad = popup._padLeft
    var sw  = popup._screenW
    // Modo flutuante: ignora posição da barra, calcula pelo alinhamento X do monitor
    // Modo barra vertical esquerda: popup gruda logo à direita da barra
    if (!popup._floating && _isVertical && _barLeft) {
      var ml  = barRef && barRef.margins ? (barRef.margins.left || 0) : 0
      var biw = barRef ? (barRef.implicitWidth || 0) : 0
      return Math.max(0, biw + ml - pad + popup.attachOffset)
    }
    if (popupXAlign === "left")
      return Math.max(0, popupXOffset - pad)
    if (popupXAlign === "right")
      return Math.max(0, sw - popupW - popupXOffset - pad)
    // center (padrão)
    return Math.max(0, Math.floor((sw - popupW) / 2) + popupXOffset - pad)
  }
  margins.right: {
    var pad = popup._padRight
    // Modo flutuante: não ancora à direita, margem direita ignorada
    if (!popup._floating && _isVertical && _barRight) {
      var mr  = barRef && barRef.margins ? (barRef.margins.right || 0) : 0
      var biw = barRef ? (barRef.implicitWidth || 0) : 0
      return Math.max(0, biw + mr - pad + popup.attachOffset)
    }
    return 0
  }
  margins.top: {
    var sh  = popup._screenH
    var pad = popup._padTop
    var mt  = barRef && barRef.margins ? (barRef.margins.top    || 0) : 0
    var mb  = barRef && barRef.margins ? (barRef.margins.bottom || 0) : 0
    var bih = barRef ? (barRef.implicitHeight || 0) : 0
    // Modo "bottom": âncora está na base, margins.bottom é usado — margins.top irrelevante.
    if (popup._floatBottom) return 0
    // Modo "top": âncora no topo, margins.top = distância do topo do output.
    if (popup._floatTop)
      return Math.max(0, popup.popupYOffset - pad)
    // Modo "bar": ancora na barra
    if (_barTop && !_barBottom)
      return Math.max(0, bih + mt - pad + popup.attachOffset)
    if (_barBottom && !_barTop)
      return Math.max(0, sh - bih - mb - popup.popupH - pad - popup.attachOffset)
    var usable = sh - mt - mb
    return Math.max(0, mt + Math.floor((usable - popup.popupH) / 2) - pad)
  }
  margins.bottom: {
    var pad = popup._padBottom
    // Modo "bottom": âncora na base, margins.bottom = distância da base do output.
    if (popup._floatBottom)
      return Math.max(0, popup.popupYOffset - pad)
    return 0
  }

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

  // ── Animações ──────────────────────────────────────────────────────────────
  // Sem overshoot/bounce em nenhum estilo — fluido e previsível tanto pra
  // abrir quanto pra fechar. O "reveal" já não usava bounce (não combinava
  // com a máscara de clip); agora o "slide"/"scale"/"scale-slide" seguem o
  // mesmo princípio.
  NumberAnimation {
    id: openAnim
    target:           popup
    property:         "_animProg"
    duration:         popup.animDuration
    easing.type:      Easing.OutCubic
    easing.overshoot: 0
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
      // "reveal": conteúdo já nasce opaco — quem "aparece" é a máscara de clip,
      // não a opacidade. Isso é o que vende a sensação de material sólido
      // saindo de dentro da barra, em vez de um painel translúcido surgindo.
      case "reveal":      return _alive ? bgOpacity : 0
      default:            return _animProg * bgOpacity  // slide — fade sincronizado com o translate
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

  // ── Máscara de clip do estilo "reveal" ──────────────────────────────────────
  // Em vez de mover/escalar o painel inteiro, uma janela de clipping cresce a
  // partir da borda que toca a barra (ou a borda de ancoragem, no modo
  // flutuante). O conteúdo (bg) permanece estático e em tamanho real; só a
  // "viewport" visível cresce — exatamente como uma gaveta sendo aberta a
  // partir da barra, em vez de um painel que aparece flutuando por cima dela.
  readonly property real _revealProg: Math.max(0, Math.min(1, _animProg))

  // Borda fixa = a que toca a barra/âncora. A borda oposta é a que "cresce".
  // Barra horizontal no topo (ou popup flutuante ancorado no topo da tela):
  // a borda de cima é a fixa → o popup cresce para baixo.
  readonly property bool _revealGrowDown: !_isVertical &&
    (_floatTop || (_barTop && !_floating))
  // Barra vertical à esquerda: a borda da esquerda é a fixa → cresce p/ direita.
  readonly property bool _revealGrowLeft: _isVertical && _barLeft

  // _revealW agora anima em AMBOS os casos (barra vertical E horizontal).
  // Antes, numa barra horizontal o popup já nascia com a largura cheia desde
  // o primeiro frame (só a altura crescia) — se a barra for uma pill mais
  // estreita que o popup, isso faz o reveal "estourar" mais largo que a
  // própria barra logo de cara, quebrando a ilusão de conexão. Agora a
  // largura também cresce, ancorada no mesmo ponto do popupXAlign usado pelo
  // "scale" (esquerda/direita/centro) — ou seja, "a partir da margem da
  // barra", não do meio do popup.
  readonly property int _revealW: (animationStyle === "reveal")
    ? Math.round(popupW * _revealProg) : popupW
  readonly property int _revealH: (animationStyle === "reveal" && !_isVertical)
    ? Math.round(popupH * _revealProg) : popupH

  readonly property int _clipX: {
    if (animationStyle !== "reveal") return 0
    if (_isVertical) return _revealGrowLeft ? 0 : (popupW - _revealW)
    // Barra horizontal (ou flutuante): ancora conforme popupXAlign, igual ao
    // origin.x do "scale" — left=0 (cresce p/ direita), right=full (cresce
    // p/ esquerda), center=meio (cresce pros 2 lados, caso correto quando
    // não há borda específica da barra pra se ancorar).
    if (popupXAlign === "left")  return 0
    if (popupXAlign === "right") return popupW - _revealW
    return Math.round((popupW - _revealW) / 2)
  }
  readonly property int _clipY: (animationStyle !== "reveal" || _isVertical) ? 0
    : (_revealGrowDown ? 0 : (popupH - _revealH))

  // ── Altura do header ───────────────────────────────────────────────────────
  readonly property int _headerH: (popupTitle.length > 0) ? 38 : 0

  // ── UI ─────────────────────────────────────────────────────────────────────
  // _shadowPadItem garante que a sombra não seja cortada pela bounding box.
  // x/y usam o padding assimétrico (_padLeft/_padTop) — 0 no lado que toca a
  // barra, então o conteúdo nasce flush nesse lado e a janela nunca se
  // estende para dentro da área da barra.
  Item {
    id: _shadowPadItem
    x:      popup._padLeft
    y:      popup._padTop
    width:  popup.popupW
    height: popup.popupH

    // Alvo fixo pra sombra — NÃO anima de tamanho nunca, mesmo durante "reveal".
    // Existe só pra dar ao MultiEffect um irmão de tamanho ESTÁVEL pra ancorar
    // (anchors só funciona com pai/irmão direto, e bg agora é filho de
    // _revealMask). Antes a sombra ancorava direto no _revealMask, que MUDA DE
    // TAMANHO A CADA FRAME durante o "reveal" — isso força o Qt a realocar o
    // framebuffer da sombra a cada frame da animação, e É ISSO que tava
    // pesando. Com um alvo de tamanho fixo, o buffer da sombra é alocado uma
    // vez só; ela simplesmente faz fade in/out via opacity, como antes do
    // "reveal" existir.
    Item {
      id: _shadowAnchor
      width:  popup.popupW
      height: popup.popupH
    }

    // Sombra via MultiEffect — Qt 6.5+
    MultiEffect {
      anchors.fill:           _shadowAnchor
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

    // ── Máscara de reveal ───────────────────────────────────────────────────
    // Para os demais estilos (slide/fade/scale/scale-slide/none) esta máscara
    // sempre tem o tamanho cheio do popup e clip desligado — ou seja, ela é
    // totalmente transparente ao comportamento original. Só quando
    // animationStyle === "reveal" ela de fato recorta o conteúdo.
    Item {
      id: _revealMask
      x:      popup._clipX
      y:      popup._clipY
      width:  popup._revealW
      height: popup._revealH
      clip:   popup.animationStyle === "reveal"

      Rectangle {
        id: bg
        // bg fica sempre no tamanho real do popup e em posição fixa relativa
        // ao _shadowPadItem — é a máscara (_revealMask) que se move/redimensiona
        // por cima dele, "revelando" progressivamente a partir da borda da barra.
        x:      -parent.x
        y:      -parent.y
        width:  popup.popupW
        height: popup.popupH
        // Raios por canto — controlados por cornerMode + posição da barra
        topLeftRadius:     popup._rTL
        topRightRadius:    popup._rTR
        bottomLeftRadius:  popup._rBL
        bottomRightRadius: popup._rBR
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
          // origin.x: pra barra vertical, ancora na borda que toca a barra.
          // Pra barra horizontal (ou flutuante), ancora conforme popupXAlign —
          // ANTES caía sempre em bg.width/2 (meio do popup) independente do
          // alinhamento configurado, fazendo o "scale" crescer a partir do
          // centro do popup em vez da borda onde ele deveria estar "preso".
          origin.x: popup._barLeft  ? 0 :
                    popup._barRight ? bg.width :
                    popup.popupXAlign === "left"  ? 0 :
                    popup.popupXAlign === "right" ? bg.width : bg.width / 2
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
        topLeftRadius:    popup._rTL
        topRightRadius:   popup._rTR
        bottomLeftRadius: 0
        bottomRightRadius: 0

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
              topLeftRadius:     popup._rTL
              topRightRadius:    0
              bottomLeftRadius:  popup._rBL
              bottomRightRadius: 0
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
    }   // fecha Rectangle bg
    }   // fecha Item _revealMask
  }

  // ── Aplicação de PopupConfig ao completar ─────────────────────────────────
  // ── Aplicação de config do PopupConfig ────────────────────────────────────
  // Roda no onCompleted E sempre que PopupConfig muda (_dep sobe).
  // Isso garante que mudar cornerMode/bgRadius/animação no ConfigWindow
  // reflete imediatamente no popup sem precisar fechar e reabrir.
  function _applyConfig() {
    var name = popup.configName || popup.objectName
    if (!name || name.length === 0) return

    function applyIfSet(key, setter) {
      var v = popup._pcGet(name, key, undefined)
      if (v !== undefined) setter(v)
    }

    applyIfSet("animationStyle", function(v){ popup.animationStyle = v })
    applyIfSet("animDuration",   function(v){ popup.animDuration   = v })
    applyIfSet("attachOffset",   function(v){ popup.attachOffset   = v })
    applyIfSet("borderWidth",    function(v){ popup.borderWidth    = v })
    applyIfSet("shadowEnabled",  function(v){ popup.shadowEnabled  = v })
    applyIfSet("shadowBlur",     function(v){ popup.shadowBlur     = v })
    applyIfSet("shadowOffsetX",  function(v){ popup.shadowOffsetX  = v })
    applyIfSet("shadowOffsetY",  function(v){ popup.shadowOffsetY  = v })
    applyIfSet("shadowOpacity",  function(v){ popup.shadowOpacity  = v })
    applyIfSet("bgOpacity",      function(v){ popup.bgOpacity      = v })
    applyIfSet("bgRadius",       function(v){ popup.bgRadius       = v })
    applyIfSet("cornerMode",     function(v){ popup.cornerMode     = v })
    applyIfSet("layoutMode",     function(v){ popup.layoutMode     = v })
    applyIfSet("sidebarWidth",   function(v){ popup.sidebarWidth   = v })
    applyIfSet("popupW",         function(v){ popup.popupW         = v })
    applyIfSet("popupH",         function(v){ popup.popupH         = v })
    applyIfSet("popupTitle",     function(v){ popup.popupTitle     = v })
    applyIfSet("popupIcon",      function(v){ popup.popupIcon      = v })
    // ── Posicionamento — antes só dava pra mudar editando o .qml de cada
    // popup na mão. Agora é por-popup configurável via PopupConfig, igual o
    // dmenu já permite (cada popup abre "em qualquer lugar").
    applyIfSet("popupYAnchor",   function(v){ popup.popupYAnchor   = v })
    applyIfSet("popupXAlign",    function(v){ popup.popupXAlign    = v })
    applyIfSet("popupXOffset",   function(v){ popup.popupXOffset   = v })
    applyIfSet("popupYOffset",   function(v){ popup.popupYOffset   = v })
  }

  Component.onCompleted: popup._applyConfig()

  // Reaplica sempre que _pc muda de instância (barRef trocou) OU quando o
  // _dep da PopupConfig ativa muda (save no ConfigWindow). O binding em
  // `target` acompanha popup._pc automaticamente — se o barRef for
  // reatribuído em runtime, a Connections migra pra nova instância sozinha.
  Connections {
    target: popup._pc
    function on_DepChanged() { popup._applyConfig() }
  }
  onBarRefChanged: popup._applyConfig()
}
