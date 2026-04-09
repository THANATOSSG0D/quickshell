import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import '../mediaPlayer' as MediaPanel
import '../volume'      as VolumeModule
import '../clock'       as ClockModule
import '../quicksettings' as QsModule

Scope {
  id: barRoot

  BarState { id: barState }

  // ── Props do tema activo ───────────────────────────────────────────────
  property int  themeBarSize:    30
  property int  themeBarMargin:  0
  property bool themePill:       false
  property int  themePillWidth:  600
  property bool themeHasPanel:   false
  property int  themePanelWidth: 400

  property var barMediaPlayerRef: null
  property var barClockRef:       null

  // Referência ao OsdService injetada pelo shell.qml
  property var osdService: null

  // Referência ao ClockContent (dentro do clockPopup) — exposta para que
  // shell.qml possa injetar em osd.clockContent e conectar timerElapsed.
  property var clockContentRef: null

  // ── Conexão primária: timerElapsed → osdService ────────────────────────
  // Esta conexão vive aqui no Scope porque Bar.qml tem acesso direto tanto
  // ao clockContentRef quanto ao osdService, sem depender do timing do shell.qml.
  // Mesmo que shell.qml também conecte via osd.clockContent, o OsdService é
  // idempotente — receber a mesma chamada duas vezes só gera um OSD.
  property var _barCcConnected: null

  function _barOnTimerElapsed(mode, phaseLabel) {
    if (!barRoot.osdService || !barRoot.clockContentRef) return
    var cc = barRoot.clockContentRef
    barRoot.osdService.timerOsd(phaseLabel, cc.barRemaining, mode === "pomodoro", cc.barRunning)
  }

  onClockContentRefChanged: {
    if (_barCcConnected) {
      try { _barCcConnected.timerElapsed.disconnect(barRoot._barOnTimerElapsed) } catch(e) {}
    }
    _barCcConnected = clockContentRef
    if (clockContentRef)
      clockContentRef.timerElapsed.connect(barRoot._barOnTimerElapsed)
  }

  // ── IPC do timer ──────────────────────────────────────────────────────
  // Uso: qs ipc call timer <comando> [arg]
  //
  //   toggle          → play/pause
  //   start           → inicia com a duração configurada
  //   reset           → para e reseta
  //   addMin          → +1 minuto
  //   subMin          → -1 minuto
  //   setTimer <min>  → define duração em minutos e inicia
  //   pomodoro        → inicia sessão Pomodoro
  //   pomodoroNext    → avança para a próxima fase do Pomodoro
  //   dismiss         → para o alerta sonoro e reseta
  IpcHandler {
    target: "timer"
    function toggle()   {
      var cc = barRoot.clockContentRef; if (cc) cc.toggleRunning()
    }
    function start()    {
      var cc = barRoot.clockContentRef; if (cc) cc.startFree(cc.freeTimerDuration)
    }
    function reset()    {
      var cc = barRoot.clockContentRef; if (cc) cc.resetTimer()
    }
    function addMin()   {
      var cc = barRoot.clockContentRef; if (cc) cc.adjustTimer(60)
    }
    function subMin()   {
      var cc = barRoot.clockContentRef; if (cc) cc.adjustTimer(-60)
    }
    function setTimer(arg: double) {
      var cc = barRoot.clockContentRef
      if (cc) cc.startFree(Math.max(1, Math.round(arg)) * 60)
    }
    function pomodoro() {
      var cc = barRoot.clockContentRef; if (cc) cc.startPomodoro()
    }
    function pomodoroNext() {
      var cc = barRoot.clockContentRef; if (cc) cc.pomodoroNext()
    }
    function dismiss()  {
      var cc = barRoot.clockContentRef
      if (cc) { cc.stopSound(); cc.resetTimer() }
    }
  }

  property int position: barState.position

  // ── IDs de painel — evita strings mágicas espalhadas pelo código ───────
  readonly property int panelNone:   0
  readonly property int panelSink:   1
  readonly property int panelSource: 2
  readonly property int panelPlayer: 3
  readonly property int panelClock:  4
  readonly property int panelQs:     5

  // ── Dimensões dos popups (fonte de verdade única) ──────────────────────
  // Todos os popups usam themePanelWidth como largura.
  // Alturas fixas por módulo — ajuste aqui para mudar todos de uma vez.
  readonly property int popupHVolume: 380
  readonly property int popupHPlayer: 420
  readonly property int popupHClock:  480
  readonly property int popupHQs:     540
  readonly property int popupWQs:     320   // QS tem largura própria (mais estreito)

  // ── Barra + Popups (um conjunto por tela) ─────────────────────────────
  //
  // IMPORTANTE — os popups devem ser filhos QML do PanelWindow:
  //
  // PopupWindow é um xdg_popup Wayland e precisa de um parentWindow.
  // Quando declarado como filho de um PanelWindow, o Quickshell usa aquele
  // PanelWindow automaticamente como superfície pai do popup.
  //
  // Popups em Variants separados não funcionam porque:
  //   • `screen` não pode ser setado (controlado pelo parentWindow)
  //   • `anchor.window: this` → "transient parent cannot be same as window"
  //   • Não há como referenciar o `bar` correto por tela
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      color:  "transparent"

      // ── Estado de painéis — isolado por monitor ────────────────────────
      property int activePanel: barRoot.panelNone

      readonly property bool anyPanelOpen: activePanel !== barRoot.panelNone

      // Toggle: abre o painel pedido ou fecha se já estava aberto
      function openPanel(panelId) {
        activePanel = (activePanel === panelId) ? barRoot.panelNone : panelId
      }
      function closeAllPanels() { activePanel = barRoot.panelNone }

      // Aliases booleanos para cada popup (lidos pelos popups abaixo)
      readonly property bool sinkPanelOpen:   activePanel === barRoot.panelSink
      readonly property bool sourcePanelOpen: activePanel === barRoot.panelSource
      readonly property bool playerPanelOpen: activePanel === barRoot.panelPlayer
      readonly property bool clockPanelOpen:  activePanel === barRoot.panelClock
      readonly property bool qsPanelOpen:     activePanel === barRoot.panelQs
      // ──────────────────────────────────────────────────────────────────

      property int  barSize:   barRoot.themeBarSize
      property int  barMargin: barRoot.themeBarMargin
      property bool pill:      barRoot.themePill
      property int  pillWidth: barRoot.themePillWidth
      property int  position:  barRoot.position

      readonly property bool isVertical: position === 2 || position === 4

      property int pillSideMargin: {
        if (!pill) return 0
        if (isVertical)
          return Math.max(0, Math.floor((screen.height - pillWidth) / 2))
        return Math.max(0, Math.floor((screen.width - pillWidth) / 2))
      }

      property bool themeLoaded: barRoot.themeBarSize > 0

      anchors.top:    themeLoaded ? (position === 1 || position === 2 || position === 4) : false
      anchors.bottom: themeLoaded ? (position === 3 || position === 2 || position === 4) : false
      anchors.left:   themeLoaded ? (position === 1 || position === 3 || position === 4) : false
      anchors.right:  themeLoaded ? (position === 1 || position === 3 || position === 2) : false

      implicitHeight: {
        if (!themeLoaded) return 0
        if (!isVertical) return barSize
        return pill ? pillWidth : screen.height
      }
      implicitWidth: {
        if (!themeLoaded) return 0
        if (isVertical) return barSize
        return pill ? pillWidth : screen.width
      }

      property bool animating:    true
      property real marginOffset: 0

      Behavior on marginOffset {
        enabled: bar.animating
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
      }

      margins.top: {
        if (position === 1) return barMargin - marginOffset
        if (isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.bottom: {
        if (position === 3) return barMargin - marginOffset
        if (isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.left: {
        if (position === 4) return barMargin - marginOffset
        if (!isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.right: {
        if (position === 2) return barMargin - marginOffset
        if (!isVertical && pill) return pillSideMargin
        return barMargin
      }

      property real _edgeThreshold: barState.edgeThreshold

      onBarShowChanged: {
        _edgeThreshold = barShow ? (barSize + barMargin + 4) : barState.edgeThreshold
        marginOffset   = barShow ? 0 : barSize + barMargin + 1
      }

      WlrLayershell.layer: WlrLayershell.Top

      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: barState.autoHide ? 0 : barSize

      // ── Helpers de anchor compartilhados pelos popups ──────────────────
      //
      // Todos os popups usam a mesma edge/gravity derivada da posição da barra.
      // Centraliza aqui para não repetir o mesmo bloco 5 vezes.
      readonly property int popupEdge: {
        if (position === 1) return Edges.Bottom
        if (position === 2) return Edges.Left
        if (position === 3) return Edges.Top
        return Edges.Right
      }

      // ── Cálculo de anchor.rect ─────────────────────────────────────────
      //
      // anchor.rect define o "objeto" dentro da superfície da barra ao qual
      // o popup se ancora. O Wayland então posiciona o popup fora dessa rect
      // na direção de anchor.edges/gravity.
      //
      // Barra HORIZONTAL:
      //   • A superfície cobre screen.width (ou pillWidth).
      //   • rx centraliza (ou alinha à direita) o popup horizontalmente.
      //   • height = implicitHeight (a barra inteira, na vertical).
      //
      // Barra VERTICAL:
      //   • A superfície cobre screen.height (ou pillWidth).
      //   • O rect deve ser a barra INTEIRA — sem offset ry.
      //   • O Wayland usa anchor.gravity para posicionar o popup
      //     verticalmente fora da barra; calcular ry manualmente faz o
      //     popup ancorar no meio da superfície e abrir no lugar errado.

      // rect centrado (volume, clock, media player)
      //
      // Barra HORIZONTAL: rx centra pw no eixo X da superfície.
      // Barra VERTICAL:   usamos rect de 1x1 no topo da superfície.
      //   O compositor (wlroots/Hyprland) parece ignorar o ry calculado
      //   quando a superfície tem anchors top+bottom simultaneamente,
      //   posicionando sempre pelo centro geométrico da janela.
      //   Com rect 1x1 no topo + gravity Right, o popup ancora no topo
      //   e cresce para baixo — menos errado que o centro.
      //   TODO: investigar se PopupWindow.anchor.rect funciona corretamente
      //   com PanelWindow full-height no Quickshell/wlroots.
      function popupRectCentered(pw, ph) {
        if (!isVertical) {
          var sw = pill ? pillWidth : screen.width
          var rx = Math.max(0, Math.floor((sw - pw) / 2))
          return Qt.rect(rx, 0, pw, implicitHeight)
        }
        // Barra vertical: o anchor.rect é interpretado em coordenadas
        // globais pelo Hyprland quando screen.x é negativo (monitor à
        // esquerda do principal). Compensamos subtraindo screen.x do rx
        // para que o rect fique dentro da superfície globalmente.
        // ry centra verticalmente o popup na superfície.
        var sh = pill ? pillWidth : screen.height
        var ry = Math.max(0, Math.floor((sh - ph) / 2))
        var rxAdj = -screen.x   // 0 quando screen.x=0, 1920 quando screen.x=-1920
        console.log("[BarPopup] screen=" + screen.name
          + " screenX=" + screen.x + " ry=" + ry + " rxAdj=" + rxAdj
          + " → rect(" + rxAdj + "," + ry + "," + implicitWidth + "," + ph + ")")
        return Qt.rect(rxAdj, ry, implicitWidth, ph)
      }

      function popupRectRight(pw, ph) {
        if (!isVertical) {
          var sw = pill ? pillWidth : screen.width
          return Qt.rect(Math.max(0, sw - pw - 8), 0, pw, implicitHeight)
        }
        var sh = pill ? pillWidth : screen.height
        var ry = Math.max(0, Math.floor((sh - ph) / 2))
        var rxAdj = -screen.x
        return Qt.rect(rxAdj, ry, implicitWidth, ph)
      }

      // ── Paleta dos popups — binding único, replicado para todos ────────
      //
      // Em vez de repetir 7 bindings de cor em cada popup, definimos aqui
      // e cada popup lê de `bar.popup*`. Quando a paleta mudar em runtime,
      // os popups atualizam automaticamente por binding.
      readonly property color popupColorBg:       barState.config.palettePanelBg
      readonly property color popupColorText:     barState.config.paletteText
      readonly property color popupColorTextDim:  barState.config.paletteTextDim
      readonly property color popupColorAccent:   barState.config.paletteAccent
      readonly property color popupColorMuted:    barState.config.paletteWsDotUrgentColor
      readonly property color popupColorProgress: barState.config.paletteProgressBg
      readonly property color popupColorProgressFg: barState.config.paletteProgressFg
      readonly property color popupColorDivider:  barState.config.paletteDivider

      // ── Loader do tema ─────────────────────────────────────────────────
      Loader {
        id: loader
        anchors.fill: parent
        source: Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml"

        onLoaded: {
          barRoot.themeBarSize    = item.barSize       !== undefined ? item.barSize       : 30
          barRoot.themeBarMargin  = item.barMargin     !== undefined ? item.barMargin     : 0
          barRoot.themePill       = item.pill          !== undefined ? item.pill          : false
          barRoot.themePillWidth  = item.pillWidth     !== undefined ? item.pillWidth     : 600
          barRoot.themeHasPanel   = item.hasMediaPanel !== undefined ? item.hasMediaPanel : false
          barRoot.themePanelWidth = item.panelWidth    !== undefined ? item.panelWidth    : 400

          if ("monitorName" in item) item.monitorName = bar.screen.name
          if ("barPosition" in item) item.barPosition = barRoot.position
          if (item.mediaPlayer)      barRoot.barMediaPlayerRef = item.mediaPlayer

          // Clock — injeção do clockContent e captura da referência
          if (item.clock) {
            barRoot.barClockRef = item.clock
            if ("clockContent" in item.clock)
              item.clock.clockContent = clockPopup.clockContentRef
            // Expõe para o shell.qml repassar ao Osd
            if (!barRoot.clockContentRef)
              barRoot.clockContentRef = clockPopup.clockContentRef
          }

          // osdService — injetado quando disponível
          if (barRoot.osdService !== null) {
            if ("osdService" in item) item.osdService = barRoot.osdService
            var _vol = item.volumeWidget
            if (_vol && "osdService" in _vol) _vol.osdService = barRoot.osdService
            var _mp  = item.mediaPlayer
            if (_mp  && "osdService" in _mp)  _mp.osdService  = barRoot.osdService
          }

          _applyConfig(item)

          bar.animating    = false
          bar.marginOffset = bar.barShow ? 0 : bar.barSize + bar.barMargin + 1
          bar.animating    = true
        }
      }

      // ── Aplicação de config ao tema ────────────────────────────────────
      // Centraliza o bloco de injeção de props para não duplicar entre
      // onLoaded e os Connections de runtime.
      function _set(prop, value) {
        if (loader.item && prop in loader.item) loader.item[prop] = value
      }

      function _applyConfig(item) {
        // workspaces
        _set("cfgWsStyle",          barState.config.wsStyle)
        _set("cfgWsIconsSort",      barState.config.wsIconsSort)
        _set("cfgWsIconMonochrome", barState.config.wsIconMonochrome)
        _set("cfgWsIconSpacing",    barState.config.wsIconSpacing)
        _set("cfgWsBgOpacity",      barState.config.wsBgOpacity)
        _set("cfgWsBgPaddingH",     barState.config.wsBgPaddingH)
        _set("cfgWsBgPaddingV",     barState.config.wsBgPaddingV)
        _set("cfgWsShowAddButton",  barState.config.wsShowAddButton)
        // workspace ativa
        _set("cfgWsBgColorActive",       barState.config.paletteWsBgColorActive)
        _set("cfgWsBgOpacityActive",     barState.config.wsBgOpacityActive)
        _set("cfgWsBgBorderColorActive", barState.config.paletteWsBgBorderColorActive)
        _set("cfgWsBgBorderWidthActive", barState.config.wsBgBorderWidthActive)
        _set("cfgWsBgPaddingHActive",    barState.config.wsBgPaddingHActive)
        _set("cfgWsBgPaddingVActive",    barState.config.wsBgPaddingVActive)
        _set("cfgWsBgRadiusActive",      barState.config.wsBgRadiusActive)
        _set("colWsBgActive",            barState.config.paletteWsBgColorActive)
        // mediaPlayer
        _set("cfgMpTextMode",        barState.config.mpTextMode)
        _set("cfgMpScrollSpeed",     barState.config.mpScrollSpeed)
        _set("cfgMpScrollPauseMs",   barState.config.mpScrollPauseMs)
        _set("cfgMpScrollWidth",     barState.config.mpScrollWidth)
        _set("cfgMpBgEnabled",       barState.config.mpBgEnabled)
        _set("cfgMpBgOpacity",       barState.config.mpBgOpacity)
        _set("cfgMpBgOpacityActive", barState.config.mpBgOpacityActive)
        _set("cfgMpBgPaddingH",      barState.config.mpBgPaddingH)
        _set("cfgMpBgPaddingV",      barState.config.mpBgPaddingV)
        _set("cfgMpBgColor",         barState.config.paletteMpBgColor)
        _set("cfgMpBgColorActive",   barState.config.paletteMpBgColorActive)
        _set("cfgMpTextColor",       barState.config.paletteMpTextColor)
        _set("cfgMpDimColor",        barState.config.paletteMpDimColor)
        _set("cfgMpTextColorActive", barState.config.paletteMpTextColorActive)
        _set("cfgMpDimColorActive",  barState.config.paletteMpDimColorActive)
        // volume
        _set("cfgVolShowSink",   barState.config.volShowSink   !== undefined ? barState.config.volShowSink   : true)
        _set("cfgVolShowSource", barState.config.volShowSource !== undefined ? barState.config.volShowSource : true)
        _set("cfgVolTextColor",  barState.config.paletteText)
        _set("cfgVolDimColor",   barState.config.paletteTextDim)
        _set("cfgVolAccent",     barState.config.paletteAccent)
        _set("cfgVolMuted",      barState.config.paletteWsDotUrgentColor)
        // clock
        _set("cfgClkTextColor",    barState.config.paletteClkTextColor)
        _set("cfgClkDimColor",     barState.config.paletteClkDimColor)
        _set("cfgClkAccent",       barState.config.paletteClkAccentColor)
        _set("cfgClkDismissDelay", barState.config.clkDismissDelayMs)
        // paleta
        _set("colBarBg",          barState.config.paletteBarBg)
        _set("colBarBgPill",      barState.config.paletteBarBgPill)
        _set("colText",           barState.config.paletteText)
        _set("colTextDim",        barState.config.paletteTextDim)
        _set("colAccent",         barState.config.paletteAccent)
        _set("colAccentBg",       barState.config.paletteAccentBg)
        _set("colAccentText",     barState.config.paletteAccentText)
        _set("colWsDot",          barState.config.paletteWsDotColor)
        _set("colWsDotActive",    barState.config.paletteWsDotActiveColor)
        _set("colWsDotOccupied",  barState.config.paletteWsDotOccupiedColor)
        _set("colWsDotUrgent",    barState.config.paletteWsDotUrgentColor)
        _set("colWsBg",           barState.config.paletteWsBgColor)
        _set("colWsBorder",       barState.config.paletteWsBgBorderColor)
        _set("colIconMono",       barState.config.paletteWsIconMonoColor)
        _set("colIconMonoActive", barState.config.paletteWsIconMonoColorActive)
      }

      // ── Propagação runtime → tema ──────────────────────────────────────
      Connections {
        target: barState.config

        // paleta
        function onPaletteBarBgChanged()                { bar._set("colBarBg",          barState.config.paletteBarBg)                 }
        function onPaletteBarBgPillChanged()            { bar._set("colBarBgPill",      barState.config.paletteBarBgPill)             }
        function onPaletteTextChanged()                 { bar._set("colText",           barState.config.paletteText)
                                                          bar._set("cfgVolTextColor",   barState.config.paletteText)                  }
        function onPaletteTextDimChanged()              { bar._set("colTextDim",        barState.config.paletteTextDim)
                                                          bar._set("cfgVolDimColor",    barState.config.paletteTextDim)               }
        function onPaletteAccentChanged()               { bar._set("colAccent",         barState.config.paletteAccent)
                                                          bar._set("cfgVolAccent",      barState.config.paletteAccent)                }
        function onPaletteAccentBgChanged()             { bar._set("colAccentBg",       barState.config.paletteAccentBg)              }
        function onPaletteAccentTextChanged()           { bar._set("colAccentText",     barState.config.paletteAccentText)            }
        function onPaletteWsBgColorChanged()            { bar._set("colWsBg",           barState.config.paletteWsBgColor)             }
        function onPaletteWsBgBorderColorChanged()      { bar._set("colWsBorder",       barState.config.paletteWsBgBorderColor)       }
        function onPaletteWsDotColorChanged()           { bar._set("colWsDot",          barState.config.paletteWsDotColor)            }
        function onPaletteWsDotActiveColorChanged()     { bar._set("colWsDotActive",    barState.config.paletteWsDotActiveColor)      }
        function onPaletteWsDotOccupiedColorChanged()   { bar._set("colWsDotOccupied",  barState.config.paletteWsDotOccupiedColor)    }
        function onPaletteWsDotUrgentColorChanged()     { bar._set("colWsDotUrgent",    barState.config.paletteWsDotUrgentColor)
                                                          bar._set("cfgVolMuted",       barState.config.paletteWsDotUrgentColor)      }
        function onPaletteWsIconMonoColorChanged()      { bar._set("colIconMono",       barState.config.paletteWsIconMonoColor)       }
        function onPaletteWsIconMonoColorActiveChanged(){ bar._set("colIconMonoActive", barState.config.paletteWsIconMonoColorActive) }
        // workspaces
        function onWsStyleChanged()          { bar._set("cfgWsStyle",          barState.config.wsStyle)          }
        function onWsIconsSortChanged()      { bar._set("cfgWsIconsSort",      barState.config.wsIconsSort)      }
        function onWsIconMonochromeChanged() { bar._set("cfgWsIconMonochrome", barState.config.wsIconMonochrome) }
        function onWsIconSpacingChanged()    { bar._set("cfgWsIconSpacing",    barState.config.wsIconSpacing)    }
        function onWsBgOpacityChanged()      { bar._set("cfgWsBgOpacity",      barState.config.wsBgOpacity)      }
        function onWsBgPaddingHChanged()     { bar._set("cfgWsBgPaddingH",     barState.config.wsBgPaddingH)     }
        function onWsBgPaddingVChanged()     { bar._set("cfgWsBgPaddingV",     barState.config.wsBgPaddingV)     }
        function onWsShowAddButtonChanged()  { bar._set("cfgWsShowAddButton",  barState.config.wsShowAddButton)  }
        // workspace ativa
        function onPaletteWsBgColorActiveChanged()       { bar._set("cfgWsBgColorActive",      barState.config.paletteWsBgColorActive)
                                                           bar._set("colWsBgActive",            barState.config.paletteWsBgColorActive)       }
        function onWsBgOpacityActiveChanged()            { bar._set("cfgWsBgOpacityActive",     barState.config.wsBgOpacityActive)            }
        function onPaletteWsBgBorderColorActiveChanged() { bar._set("cfgWsBgBorderColorActive", barState.config.paletteWsBgBorderColorActive) }
        function onWsBgBorderWidthActiveChanged()        { bar._set("cfgWsBgBorderWidthActive", barState.config.wsBgBorderWidthActive)        }
        function onWsBgPaddingHActiveChanged()           { bar._set("cfgWsBgPaddingHActive",    barState.config.wsBgPaddingHActive)           }
        function onWsBgPaddingVActiveChanged()           { bar._set("cfgWsBgPaddingVActive",    barState.config.wsBgPaddingVActive)           }
        function onWsBgRadiusActiveChanged()             { bar._set("cfgWsBgRadiusActive",      barState.config.wsBgRadiusActive)             }
        // mediaPlayer
        function onMpTextModeChanged()               { bar._set("cfgMpTextMode",        barState.config.mpTextMode)            }
        function onMpScrollSpeedChanged()            { bar._set("cfgMpScrollSpeed",     barState.config.mpScrollSpeed)         }
        function onMpScrollPauseMsChanged()          { bar._set("cfgMpScrollPauseMs",   barState.config.mpScrollPauseMs)       }
        function onMpScrollWidthChanged()            { bar._set("cfgMpScrollWidth",     barState.config.mpScrollWidth)         }
        function onMpBgEnabledChanged()              { bar._set("cfgMpBgEnabled",       barState.config.mpBgEnabled)           }
        function onMpBgOpacityChanged()              { bar._set("cfgMpBgOpacity",       barState.config.mpBgOpacity)           }
        function onMpBgOpacityActiveChanged()        { bar._set("cfgMpBgOpacityActive", barState.config.mpBgOpacityActive)     }
        function onMpBgPaddingHChanged()             { bar._set("cfgMpBgPaddingH",      barState.config.mpBgPaddingH)          }
        function onMpBgPaddingVChanged()             { bar._set("cfgMpBgPaddingV",      barState.config.mpBgPaddingV)          }
        function onPaletteMpBgColorChanged()         { bar._set("cfgMpBgColor",         barState.config.paletteMpBgColor)         }
        function onPaletteMpBgColorActiveChanged()   { bar._set("cfgMpBgColorActive",   barState.config.paletteMpBgColorActive)   }
        function onPaletteMpTextColorChanged()       { bar._set("cfgMpTextColor",       barState.config.paletteMpTextColor)       }
        function onPaletteMpDimColorChanged()        { bar._set("cfgMpDimColor",        barState.config.paletteMpDimColor)        }
        function onPaletteMpTextColorActiveChanged() { bar._set("cfgMpTextColorActive", barState.config.paletteMpTextColorActive) }
        function onPaletteMpDimColorActiveChanged()  { bar._set("cfgMpDimColorActive",  barState.config.paletteMpDimColorActive)  }
        // clock
        function onPaletteClkTextColorChanged()   { bar._set("cfgClkTextColor",    barState.config.paletteClkTextColor)   }
        function onPaletteClkDimColorChanged()     { bar._set("cfgClkDimColor",     barState.config.paletteClkDimColor)    }
        function onPaletteClkAccentColorChanged()  { bar._set("cfgClkAccent",       barState.config.paletteClkAccentColor) }
        function onClkDismissDelayMsChanged()      { bar._set("cfgClkDismissDelay", barState.config.clkDismissDelayMs)     }
      }

      Connections {
        target: barRoot
        function onPositionChanged() {
          bar._set("barPosition", barRoot.position)
        }
        function onOsdServiceChanged() {
          if (!loader.item) return
          if ("osdService" in loader.item) loader.item.osdService = barRoot.osdService
          var vol = loader.item.volumeWidget
          if (vol && "osdService" in vol) vol.osdService = barRoot.osdService
          var mp  = loader.item.mediaPlayer
          if (mp  && "osdService" in mp)  mp.osdService  = barRoot.osdService
        }
        // Re-injeta clockContent ao recarregar tema (hot-reload)
        function onBarClockRefChanged() {
          var ck = barRoot.barClockRef
          if (ck && "clockContent" in ck)
            ck.clockContent = clockPopup.clockContentRef
          // Mantém clockContentRef atualizado após hot-reload
          barRoot.clockContentRef = clockPopup.clockContentRef
        }
      }

      // ── Sinais do tema → abertura de painéis ───────────────────────────
      // Um único Timer de cooldown compartilhado — 100 ms é suficiente
      // para debounce de clique em qualquer painel.
      Timer { id: panelCooldown; interval: 100; repeat: false }

      Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onSinkPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelSink);   panelCooldown.restart() }
        }
        function onSourcePanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelSource); panelCooldown.restart() }
        }
        function onClockPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelClock);  panelCooldown.restart() }
        }
        function onQuickSettingsPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelQs);     panelCooldown.restart() }
        }
      }

      Connections {
        target: loader.item && loader.item.mediaPlayer ? loader.item.mediaPlayer : null
        ignoreUnknownSignals: true
        function onClicked() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelPlayer); panelCooldown.restart() }
        }
      }

      // ── Hot-reload do tema ─────────────────────────────────────────────
      FileView {
        path:         Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml"
        watchChanges: true
        onFileChanged: {
          var src = loader.source
          loader.source = ""
          loader.source = src
        }
      }

      // ── Auto-hide ──────────────────────────────────────────────────────
      property var hyprMonitor: null

      Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
          for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (m.name === bar.screen.name) { bar.hyprMonitor = m; return }
          }
          bar.hyprMonitor = null
        }
      }

      property bool hasWindows: {
        if (!hyprMonitor) return false
        var ws = hyprMonitor.activeWorkspace
        if (!ws) return false
        return ws.toplevels.values.length > 0
      }

      property bool cursorNearBar: {
        var threshold = _edgeThreshold
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barState.cursorX / scaleX
        var cy = barState.cursorY / scaleY
        var inScreen = cx >= screen.x && cx <= screen.x + screen.width
                    && cy >= screen.y && cy <= screen.y + screen.height
        if (!inScreen) return false
        var lx = cx - screen.x
        var ly = cy - screen.y
        if (position === 1) return ly <= threshold
        if (position === 2) return lx >= screen.width - threshold
        if (position === 3) return ly >= screen.height - threshold
        if (position === 4) return lx <= threshold
        return false
      }

      property bool cursorAtEdge: {
        var threshold = _edgeThreshold
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barState.cursorX / scaleX
        var cy = barState.cursorY / scaleY
        var inScreen = cx >= screen.x && cx <= screen.x + screen.width
                    && cy >= screen.y && cy <= screen.y + screen.height
        if (!inScreen) return false
        var lx = cx - screen.x
        var ly = cy - screen.y
        var tolerance = barSize / 2
        if (position === 1 || position === 3) {
          var atV = position === 1 ? ly <= threshold : ly >= screen.height - threshold
          if (!atV) return false
          if (pill) return lx >= pillSideMargin - tolerance && lx <= screen.width - pillSideMargin + tolerance
          return true
        }
        if (position === 2 || position === 4) {
          var atH = position === 4 ? lx <= threshold : lx >= screen.width - threshold
          if (!atH) return false
          if (pill) return ly >= pillSideMargin - tolerance && ly <= screen.height - pillSideMargin + tolerance
          return true
        }
        return false
      }

      property bool barVisible: {
        if (anyPanelOpen) return true
        if (!barState.autoHide) return true
        var near = pill ? cursorAtEdge : cursorNearBar
        return near || !hasWindows
      }
      property bool barShow: true

      onBarVisibleChanged: {
        if (barVisible) { hideTimer.stop(); barShow = true }
        else hideTimer.restart()
      }

      Timer {
        id: hideTimer
        interval: barState.hideDelayMs
        repeat:   false
        onTriggered: bar.barShow = false
      }

      Component.onCompleted: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
          var m = Hyprland.monitors.values[i]
          if (m.name === bar.screen.name) { bar.hyprMonitor = m; break }
        }
        barShow = barVisible
        if (!barVisible) marginOffset = barSize + barMargin + 1
      }

      // ═══════════════════════════════════════════════════════════════════
      // Popups — filhos QML do PanelWindow (ver comentário no topo)
      //
      // Padrão de anchor compartilhado:
      //   anchor.window:  bar
      //   anchor.edges:   bar.popupEdge        (derivado da posição)
      //   anchor.gravity: bar.popupEdge        (idem)
      //   anchor.rect:    bar.popupRectCentered(pw, ph)  ou  popupRectRight
      //
      // Paleta:           bar.popupColor*      (binding único, sem repetição)
      // Dimensões:        barRoot.popupH*      (fonte de verdade única)
      // ═══════════════════════════════════════════════════════════════════

      // ── Volume — Sink ──────────────────────────────────────────────────
      VolumeModule.VolumePopup {
        id: volSinkPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHVolume)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHVolume

        showOnlySink: true
        panelOpen:    bar.sinkPanelOpen

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorProgressBg: bar.popupColorProgress
        colorDivider:    bar.popupColorDivider
        colorMuted:      bar.popupColorMuted

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Volume — Source ────────────────────────────────────────────────
      VolumeModule.VolumePopup {
        id: volSourcePopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHVolume)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHVolume

        showOnlySource: true
        panelOpen:      bar.sourcePanelOpen

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorProgressBg: bar.popupColorProgress
        colorDivider:    bar.popupColorDivider
        colorMuted:      bar.popupColorMuted

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Media Player ───────────────────────────────────────────────────
      MediaPanel.MediaPlayerPopup {
        id: mediaPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHPlayer)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHPlayer

        panelOpen:      bar.playerPanelOpen && barRoot.themeHasPanel
        barMediaPlayer: barRoot.barMediaPlayerRef

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorProgressBg: bar.popupColorProgress
        colorProgressFg: bar.popupColorProgressFg

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Clock ──────────────────────────────────────────────────────────
      ClockModule.ClockPopup {
        id: clockPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHClock)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHClock

        panelOpen: bar.clockPanelOpen

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorProgressBg: bar.popupColorProgress
        colorDivider:    bar.popupColorDivider

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Quick Settings ─────────────────────────────────────────────────
      // Alinhado à direita — usa popupRectRight em vez de popupRectCentered
      QsModule.QuickSettingsPopup {
        id: qsPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectRight(barRoot.popupWQs, barRoot.popupHQs)

        popupW: barRoot.popupWQs
        popupH: barRoot.popupHQs

        panelOpen: bar.qsPanelOpen

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorMuted:      bar.popupColorMuted
        colorProgressBg: bar.popupColorProgress
        colorDivider:    bar.popupColorDivider

        onCloseRequested: bar.closeAllPanels()
      }

    } // PanelWindow bar
  } // Variants
}
