import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import '../mediaPlayer' as MediaPanel
import '../volume'      as VolumeModule
import '../clock'       as ClockModule
import '../quicksettings' as QsModule
import '../notifications' as NotifModule
import './themes' as BarThemes
import '../dmenu'  as DmenuModule
import '../dmenu'  as DmenuModule

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
  property var notifService: null

  // Referência ao ClockContent (dentro do clockPopup) — exposta para que
  // shell.qml possa injetar em osd.clockContent e conectar timerElapsed.
  property var clockContentRef: null

  // ── Conexão primária: timerElapsed → osdService ────────────────────────
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
  IpcHandler {
    target: "timer"
    function toggle()   { var cc = barRoot.clockContentRef; if (cc) cc.toggleRunning() }
    function start()    { var cc = barRoot.clockContentRef; if (cc) cc.startFree(cc.freeTimerDuration) }
    function reset()    { var cc = barRoot.clockContentRef; if (cc) cc.resetTimer() }
    function addMin()   { var cc = barRoot.clockContentRef; if (cc) cc.adjustTimer(60) }
    function subMin()   { var cc = barRoot.clockContentRef; if (cc) cc.adjustTimer(-60) }
    function setTimer(arg: double) {
      var cc = barRoot.clockContentRef
      if (cc) cc.startFree(Math.max(1, Math.round(arg)) * 60)
    }
    function pomodoro()     { var cc = barRoot.clockContentRef; if (cc) cc.startPomodoro() }
    function pomodoroNext() { var cc = barRoot.clockContentRef; if (cc) cc.pomodoroNext() }
    function dismiss() {
      var cc = barRoot.clockContentRef
      if (cc) { cc.stopSound(); cc.resetTimer() }
    }
  }

  // ── Lista de instâncias do PanelWindow (um por monitor) ──────────────────
  property var _barInstances: []

  function _activeBar() {
    for (var i = 0; i < Hyprland.monitors.values.length; i++) {
      if (Hyprland.monitors.values[i].focused) {
        var name = Hyprland.monitors.values[i].name
        for (var j = 0; j < _barInstances.length; j++) {
          if (_barInstances[j] && _barInstances[j].screen &&
              _barInstances[j].screen.name === name)
            return _barInstances[j]
        }
      }
    }
    return _barInstances.length > 0 ? _barInstances[0] : null
  }

  // ── IPC dos painéis ───────────────────────────────────────────────────────
  // Uso: qs ipc call bar toggleVolume | toggleSource | togglePlayer |
  //           toggleClock | toggleQs | toggleNotif | toggleEditor | closeAll
  IpcHandler {
    target: "bar"
    function toggleVolume()     { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelSink)   }
    function toggleSource()     { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelSource) }
    function toggleVolumeFull() { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelVolume) }
    function togglePlayer()  { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelPlayer) }
    function toggleClock()   { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelClock)  }
    function toggleQs()      { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelQs)     }
    function toggleNotif()   { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelNotif)  }
    function toggleEditor()  { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelEditor) }
    function closeAll() {
      for (var i = 0; i < barRoot._barInstances.length; i++) {
        if (barRoot._barInstances[i]) barRoot._barInstances[i].closeAllPanels()
      }
    }
    function disableFullscreenPeek() { barState.fullscreenPeekEnabled = false }
    function enableFullscreenPeek()  { barState.fullscreenPeekEnabled = true  }
    function toggleFullscreenPeek()  { barState.fullscreenPeekEnabled = !barState.fullscreenPeekEnabled }
  }

  // ── IPC do dmenu ─────────────────────────────────────────────────────────
  // qs ipc call dmenu drun | run | window
  IpcHandler {
    target: "dmenu"
    function drun() {
      var b = barRoot._activeBar()
      if (b) { b.dmenuMode = "drun"; b.openPanel(barRoot.panelDmenu) }
    }
    function run() {
      var b = barRoot._activeBar()
      if (b) { b.dmenuMode = "run"; b.openPanel(barRoot.panelDmenu) }
    }
    function window() {
      var b = barRoot._activeBar()
      if (b) { b.dmenuMode = "window"; b.openPanel(barRoot.panelDmenu) }
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
  readonly property int panelEditor: 6
  readonly property int panelNotif:  7
  readonly property int panelVolume: 8
  readonly property int panelDmenu:  9

  // ── Dimensões dos popups (fonte de verdade única) ──────────────────────
  readonly property int popupHVolume: 380
  readonly property int popupHPlayer: 420
  readonly property int popupHClock:  480
  readonly property int popupHQs:     540
  readonly property int popupWQs:     320
  readonly property int popupWEditor: 440
  readonly property int popupHEditor: 560
  readonly property int popupWNotif:  360
  readonly property int popupHNotif:  560
  readonly property int popupHDmenu:  420

  // ── Barra + Popups (um conjunto por tela) ─────────────────────────────
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

      function openPanel(panelId) {
        activePanel = (activePanel === panelId) ? barRoot.panelNone : panelId
      }
      function closeAllPanels() { activePanel = barRoot.panelNone }

      readonly property bool sinkPanelOpen:   activePanel === barRoot.panelSink
      readonly property bool sourcePanelOpen: activePanel === barRoot.panelSource
      readonly property bool playerPanelOpen: activePanel === barRoot.panelPlayer
      readonly property bool clockPanelOpen:  activePanel === barRoot.panelClock
      readonly property bool qsPanelOpen:     activePanel === barRoot.panelQs
      readonly property bool editorPanelOpen: activePanel === barRoot.panelEditor
      readonly property bool notifPanelOpen:  activePanel === barRoot.panelNotif
      readonly property bool volumePanelOpen: activePanel === barRoot.panelVolume
      readonly property bool dmenuPanelOpen:  activePanel === barRoot.panelDmenu
      property string dmenuMode: "drun"
   // atualizado pelo IpcHandler antes de openPanel

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

      // Valor estável de pillSideMargin para uso em cursorAtEdge.
      // Não depende do _computedPillWidth dinâmico do tema — quebra binding loop.
      readonly property int _frozenPillSideMargin: pillSideMargin

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

      // ── Thresholds de cursor ───────────────────────────────────────────
      // _showThreshold: pixels da borda para MOSTRAR a barra (fixo, pequeno).
      // _hideThreshold: pixels da borda para MANTER visível (maior, hysteresis).
      // Separados para evitar loop: cursorAtEdge → barVisible → barShow → threshold → cursorAtEdge.
      readonly property real _showThreshold: barState.edgeThreshold

      onBarShowChanged: {
        marginOffset = barShow ? 0 : barSize + barMargin + 1
      }

      WlrLayershell.layer: bar.effectiveAutoHide ? WlrLayershell.Overlay : WlrLayershell.Top

      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: bar.effectiveAutoHide ? 0 : barSize

      // ── Helpers de anchor compartilhados pelos popups ──────────────────
      readonly property int popupEdge: {
        if (position === 1) return Edges.Bottom
        if (position === 2) return Edges.Left
        if (position === 3) return Edges.Top
        return Edges.Right
      }

      function popupRectCentered(pw, ph) {
        if (!isVertical) {
          var sw = pill ? pillWidth : screen.width
          var rx = Math.max(0, Math.floor((sw - pw) / 2))
          return Qt.rect(rx, 0, pw, implicitHeight)
        }
        var sh = pill ? pillWidth : screen.height
        var ry = Math.max(0, Math.floor((sh - ph) / 2))
        var rxAdj = -screen.x
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

      // ── Paleta dos popups ──────────────────────────────────────────────
      readonly property color popupColorBg:         barState.config.palettePanelBg
      readonly property color popupColorText:       barState.config.paletteText
      readonly property color popupColorTextDim:    barState.config.paletteTextDim
      readonly property color popupColorAccent:     barState.config.paletteAccent
      readonly property color popupColorMuted:      barState.config.paletteWsDotUrgentColor
      readonly property color popupColorProgress:   barState.config.paletteProgressBg
      readonly property color popupColorProgressFg: barState.config.paletteProgressFg
      readonly property color popupColorDivider:    barState.config.paletteDivider

      // ── Loader do tema ─────────────────────────────────────────────────
      Loader {
        id: loader
        anchors.fill: parent
        source: barState.config.configLoaded
          ? (Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml")
          : ""

        // ── Bindings reativos de módulos ──────────────────────────────────
        // Usam barState.modulesLeft (propriedade direta) em vez de
        // barState.config.modulesLeft (property var chain não rastreável).
        // Atualizam automaticamente quando o JSON muda — startup, reload,
        // editor — sem timers, sem _set() imperativo.
        Binding { target: loader.item; property: "cfgModulesLeft";   value: barState.modulesLeft;   when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "cfgModulesCenter"; value: barState.modulesCenter; when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "cfgModulesRight";  value: barState.modulesRight;  when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "cfgModulesTop";    value: barState.modulesTop;    when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "cfgModulesMiddle"; value: barState.modulesMiddle; when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "cfgModulesBottom"; value: barState.modulesBottom; when: loader.item !== null; restoreMode: Binding.RestoreNone }

        onLoaded: {
          // Lê tamanho base do tema
          barRoot.themeBarSize    = item.barSize       !== undefined ? item.barSize       : 30
          barRoot.themeBarMargin  = item.barMargin     !== undefined ? item.barMargin     : 0
          // Sobrescreve com valores do editor (se configurados)
          if (barState.config.barSize   > 0)  barRoot.themeBarSize   = barState.config.barSize
          if (barState.config.barMargin >= 0)  barRoot.themeBarMargin = barState.config.barMargin

          barRoot.themePill       = item.pill          !== undefined ? item.pill          : false
          barRoot.themePillWidth  = item.pillWidth     !== undefined ? item.pillWidth     : 600
          barRoot.themeHasPanel   = item.hasMediaPanel !== undefined ? item.hasMediaPanel : false
          barRoot.themePanelWidth = item.panelWidth    !== undefined ? item.panelWidth    : 400

          if ("monitorName" in item) item.monitorName = bar.screen.name
          if ("barPosition" in item) item.barPosition = barRoot.position
          // Para temas estáticos (Pill antigo): mediaPlayer já existe no onLoaded
          if (item.mediaPlayer)      barRoot.barMediaPlayerRef = item.mediaPlayer

          // Clock
          if (item.clock) {
            barRoot.barClockRef = item.clock
            if ("clockContent" in item.clock)
              item.clock.clockContent = clockPopup.clockContentRef
            if (!barRoot.clockContentRef)
              barRoot.clockContentRef = clockPopup.clockContentRef
          }

          // osdService
          if (barRoot.osdService !== null) {
            if ("osdService" in item) item.osdService = barRoot.osdService
            var _vol = item.volumeWidget
            if (_vol && "osdService" in _vol) _vol.osdService = barRoot.osdService
            var _mp  = item.mediaPlayer
            if (_mp  && "osdService" in _mp)  _mp.osdService  = barRoot.osdService
          }

          // notifService
          if (barRoot.notifService !== null) {
            if ("notifService" in item) item.notifService = barRoot.notifService
            var _nf = item.notifWidget
            if (_nf && "service" in _nf) _nf.service = barRoot.notifService
          }

          // Módulos são gerenciados pelos Binding declarativos acima.

          // pillWidth configurado pelo editor
          if ("minPillWidth" in item) item.minPillWidth = barState.config.pillWidth

          _applyConfig(item)

          bar.animating    = false
          bar.marginOffset = bar.barShow ? 0 : bar.barSize + bar.barMargin + 1
          bar.animating    = true
        }
      }

      // ── Propaga pillWidth dinâmico do tema → PanelWindow ─────────────────
      // Pill.qml expõe pillWidth como _computedPillWidth (dinâmico).
      // Quando muda (ex: mais workspaces abertas), atualiza barRoot.themePillWidth.
      Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onPillWidthChanged() {
          if (loader.item && loader.item.pillWidth > 0)
            barRoot.themePillWidth = loader.item.pillWidth
        }
      }

      // ── Aplicação de config ao tema ────────────────────────────────────
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

        // barSize/barMargin — afetam o PanelWindow diretamente
        function onBarSizeChanged()   { barRoot.themeBarSize   = barState.config.barSize   }
        function onBarMarginChanged() { barRoot.themeBarMargin = barState.config.barMargin }
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
        // onModules*Changed — removidos. Os Binding declarativos
        // no Loader são reativos via barState.modules* e atualizam
        // automaticamente sem handlers explícitos.
        // pillWidth configurado pelo editor
        function onPillWidthChanged() {
          if ("minPillWidth" in loader.item) loader.item.minPillWidth = barState.config.pillWidth
        }

      }

      Connections {
        target: barState
        ignoreUnknownSignals: true
        function onEditorRequested() {
          if (!editorCooldown.running) { bar.openPanel(barRoot.panelEditor); editorCooldown.restart() }
        }
        // onModulesUpdated — os Bindings declarativos cuidam da propagação.
        function onModulesUpdated() {}
      }

      Connections {
        target: barRoot
        function onPositionChanged() {
          bar._set("barPosition", barRoot.position)
        }
        function onThemePillWidthChanged() {
          if (loader.item && "minPillWidth" in loader.item)
            loader.item.minPillWidth = barState.config.pillWidth
        }
        function onOsdServiceChanged() {
          if (!loader.item) return
          if ("osdService" in loader.item) loader.item.osdService = barRoot.osdService
          var vol = loader.item.volumeWidget
          if (vol && "osdService" in vol) vol.osdService = barRoot.osdService
          var mp  = loader.item.mediaPlayer
          if (mp  && "osdService" in mp)  mp.osdService  = barRoot.osdService
        }
        function onNotifServiceChanged() {
          if (!loader.item) return
          if ("notifService" in loader.item) loader.item.notifService = barRoot.notifService
          var nf = loader.item.notifWidget
          if (nf && "service" in nf) nf.service = barRoot.notifService
        }
        function onBarClockRefChanged() {
          var ck = barRoot.barClockRef
          if (ck && "clockContent" in ck)
            ck.clockContent = clockPopup.clockContentRef
          barRoot.clockContentRef = clockPopup.clockContentRef
        }
      }

      // ── Sinais do tema → abertura de painéis ───────────────────────────
      Timer { id: panelCooldown; interval: 100; repeat: false }
      Timer { id: editorCooldown; interval: 100; repeat: false }

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
        function onNotificationsPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelNotif);  panelCooldown.restart() }
        }
        // O tema também pode pedir o editor directamente
        function onEditorRequested() {
          if (!editorCooldown.running) { bar.openPanel(barRoot.panelEditor); editorCooldown.restart() }
        }
      }

      // ── Abertura do painel MediaPlayer ────────────────────────────────
      // Abordagem dupla para compatibilidade com temas estáticos e dinâmicos:
      //
      // 1. Temas dinâmicos (Pill novo): emitem mediaPlayerClicked() no root
      //    do tema — escutado aqui via ignoreUnknownSignals.
      //    Também emitem refsUpdated() quando mediaPlayer ref fica disponível.
      // 2. Temas estáticos (Pill antigo, Default, Minimal): expõem
      //    item.mediaPlayer com signal clicked() — escutado via target dinâmico.

      Connections {
        target: loader.item
        ignoreUnknownSignals: true
        // Temas dinâmicos: click bubblado do mpLoader via root.mediaPlayerClicked()
        function onMediaPlayerClicked() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelPlayer); panelCooldown.restart() }
        }
        // Temas dinâmicos: refs prontas — atualiza barMediaPlayerRef e barClockRef
        function onRefsUpdated() {
          if (!loader.item) return
          if (loader.item.mediaPlayer) barRoot.barMediaPlayerRef = loader.item.mediaPlayer
          if (loader.item.clock) {
            barRoot.barClockRef = loader.item.clock
            if ("clockContent" in loader.item.clock)
              loader.item.clock.clockContent = clockPopup.clockContentRef
            if (!barRoot.clockContentRef)
              barRoot.clockContentRef = clockPopup.clockContentRef
          }
          // osdService
          if (barRoot.osdService !== null) {
            var mp = loader.item.mediaPlayer
            if (mp && "osdService" in mp) mp.osdService = barRoot.osdService
          }
          // notifService
          if (barRoot.notifService !== null) {
            var nf = loader.item.notifWidget
            if (nf && "service" in nf) nf.service = barRoot.notifService
          }
        }
      }

      // Fallback: temas estáticos com mediaPlayer.clicked
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

      // ── Fullscreen detection por monitor ───────────────────────────────
      // Verifica se há janela fullscreen VISÍVEL (no workspace ativo do monitor).
      // Filtra por workspace ativo para não confundir abas de browser em background
      // (ex: aba do YouTube em fullscreen em outro workspace/aba inativa).
      // Usa activewindow para eventos (rápido) e clients filtrado para startup.
      property bool isFullscreen: false
      property string _monBuf: ""
      property int _activeWsId: hyprMonitor ? hyprMonitor.activeWorkspace.id : -1

      Timer {
        id: fsQueryTimer
        interval: 150
        repeat:   false
        onTriggered: bar._monProc.running = true
      }

      Timer {
        id: fsInitTimer
        interval: 600
        repeat:   false
        onTriggered: bar._monProc.running = true
      }

      property var _monProc: Process {
        command: ["hyprctl", "activewindow", "-j"]
        stdout: SplitParser {
          onRead: data => { bar._monBuf += data }
        }
        onExited: {
          try {
            var win = JSON.parse(bar._monBuf)
            // Janela ativa no monitor desta barra, com fullscreen real (bit cliente)
            var onThisMonitor = bar.hyprMonitor && (win.monitor === bar.hyprMonitor.id)
            var isRealFs = win.fullscreen !== undefined && (win.fullscreen & 2) !== 0
            var found = onThisMonitor && isRealFs
            if (found)
              console.log("[FS] activewindow fullscreen:", win.class, "fs:", win.fullscreen)
            console.log("[FS] [" + bar.screen.name + "] →", found)
            bar.isFullscreen = found
          } catch(e) {
            // activewindow pode retornar {} quando não há janela focada (startup)
            // nesse caso consulta clients filtrado pelo workspace ativo
            bar._monBuf = ""
            bar._fallbackProc.running = true
            return
          }
          bar._monBuf = ""
        }
      }

      // Fallback para startup/reload: sem janela ativa, varre clients pelo workspace ativo
      property string _fbBuf: ""
      property var _fallbackProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser {
          onRead: data => { bar._fbBuf += data }
        }
        onExited: {
          try {
            var clients = JSON.parse(bar._fbBuf)
            var wsId = bar.hyprMonitor ? bar.hyprMonitor.activeWorkspace.id : -1
            var found = false
            for (var i = 0; i < clients.length; i++) {
              var c = clients[i]
              var inActiveWs = (c.workspace && c.workspace.id === wsId)
              var isRealFs   = c.fullscreen !== undefined && (c.fullscreen & 2) !== 0
              if (inActiveWs && isRealFs) {
                console.log("[FS] fallback fullscreen:", c.class, "ws:", wsId)
                found = true; break
              }
            }
            console.log("[FS] [" + bar.screen.name + "] fallback →", found)
            bar.isFullscreen = found
          } catch(e) {
            console.log("[FS] fallback ERRO:", e.toString())
          }
          bar._fbBuf = ""
        }
      }

      Connections {
        target: barState
        function onFullscreenChanged(state) {
          console.log("[FS] fullscreenChanged:", state, "→ delay 150ms")
          fsQueryTimer.restart()
        }
        function onWorkspaceOrFocusChanged() {
          bar._monProc.running = true
        }
      }

      property bool effectiveAutoHide: {
        if (barState.autoHide) return true
        if (barState.fullscreenPeekEnabled && isFullscreen) return true
        return false
      }

      onEffectiveAutoHideChanged: {
        console.log("[FS] [" + bar.screen.name + "] effectiveAutoHide:", effectiveAutoHide)
      }

      onIsFullscreenChanged: {
        console.log("[FS] [" + bar.screen.name + "] isFullscreen →", isFullscreen)
      }

      property bool cursorNearBar: {
        var threshold = _showThreshold
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
        var threshold = _showThreshold
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
          if (pill) return lx >= _frozenPillSideMargin - tolerance && lx <= screen.width - _frozenPillSideMargin + tolerance
          return true
        }
        if (position === 2 || position === 4) {
          var atH = position === 4 ? lx <= threshold : lx >= screen.width - threshold
          if (!atH) return false
          if (pill) return ly >= _frozenPillSideMargin - tolerance && ly <= screen.height - _frozenPillSideMargin + tolerance
          return true
        }
        return false
      }

      // cursorOverBar: true quando o cursor está dentro da área física da barra
      // (não apenas na borda). Usado para não esconder a barra quando o cursor
      // já está sobre ela ao entrar em fullscreen.
      property bool cursorOverBar: {
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barState.cursorX / scaleX
        var cy = barState.cursorY / scaleY
        var inScreen = cx >= screen.x && cx <= screen.x + screen.width
                    && cy >= screen.y && cy <= screen.y + screen.height
        if (!inScreen) return false
        var lx = cx - screen.x
        var ly = cy - screen.y
        var size = barSize + barMargin + 4
        if (position === 1) return ly <= size
        if (position === 2) return lx >= screen.width  - size
        if (position === 3) return ly >= screen.height - size
        if (position === 4) return lx <= size
        return false
      }

      property bool barVisible: {
        if (anyPanelOpen) return true
        if (!bar.effectiveAutoHide) return true
        // Se o cursor já está sobre a barra, manter visível independente do threshold
        if (cursorOverBar) return true
        var near = pill ? cursorAtEdge : cursorNearBar
        return near || !hasWindows
      }
      property bool barShow:             true

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
        barRoot._barInstances = barRoot._barInstances.concat([bar])
        barShow = barVisible
        if (!barVisible) marginOffset = barSize + barMargin + 1
        fsInitTimer.start()
      }

      Component.onDestruction: {
        barRoot._barInstances = barRoot._barInstances.filter(function(b) { return b !== bar })
      }

      // ═══════════════════════════════════════════════════════════════════
      // Popups — filhos QML do PanelWindow
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

      // ── Volume — Saída + Microfone em abas (painel unificado) ─────────────
      VolumeModule.VolumePopupTabbed {
        id: volTabbedPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHVolume)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHVolume

        panelOpen:  bar.volumePanelOpen
        openSource: false                // sempre abre na aba Saída; muda clicando nas abas

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

      // ── Editor da Barra ────────────────────────────────────────────────
      BarThemes.BarEditorPopup {
        id: editorPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.popupWEditor, barRoot.popupHEditor)

        popupW: barRoot.popupWEditor
        popupH: barRoot.popupHEditor

        panelOpen: bar.editorPanelOpen
        config:    barState.config

        colorPanelBg:    bar.popupColorBg
        colorText:       bar.popupColorText
        colorTextDim:    bar.popupColorTextDim
        colorAccent:     bar.popupColorAccent
        colorProgressBg: bar.popupColorProgress
        colorDivider:    bar.popupColorDivider

        onCloseRequested: bar.closeAllPanels()

        Connections {
          target: editorPopup
          ignoreUnknownSignals: true
          function onSaveRequested(opts) { barState.config.saveAll(opts) }
        }
      }

      // ── Notificações ───────────────────────────────────────────────────
      NotifModule.NotificationsPopup {
        id: notifPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectRight(barRoot.popupWNotif, barRoot.popupHNotif)

        popupW:    barRoot.popupWNotif
        popupH:    barRoot.popupHNotif
        service:   barRoot.notifService
        panelOpen: bar.notifPanelOpen

        colorPanelBg:  bar.popupColorBg
        colorText:     bar.popupColorText
        colorTextDim:  bar.popupColorTextDim
        colorAccent:   bar.popupColorAccent
        colorMuted:    bar.popupColorMuted
        colorDivider:  bar.popupColorDivider

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Dmenu ──────────────────────────────────────────────────────────────
      // ── Dmenu ──────────────────────────────────────────────────────────────
      DmenuModule.DmenuPopup {
        id: dmenuPopup
        anchor.window:  bar
        anchor.edges:   bar.popupEdge
        anchor.gravity: bar.popupEdge
        anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHDmenu)

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHDmenu

        mode:      bar.dmenuMode
        panelOpen: bar.dmenuPanelOpen

        colorPanelBg:  bar.popupColorBg
        colorText:     bar.popupColorText
        colorTextDim:  bar.popupColorTextDim
        colorAccent:   bar.popupColorAccent
        colorDivider:  bar.popupColorDivider
        colorInputBg:  bar.popupColorBg

        onCloseRequested: bar.closeAllPanels()
      }

    } // PanelWindow bar
  } // Variants
}
