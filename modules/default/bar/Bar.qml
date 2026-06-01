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
import '../wallpaper' as WallModule
import './themes' as BarThemes

Scope {
  id: barRoot

  BarState { id: barState }

  // ── Props do tema activo ───────────────────────────────────────────────
  property int  themeBarSize:    30
  signal _onZoneSurfaceChanged()  // emitido quando a zona da superfície muda
  property int  themeBarMargin:  0
  property bool themePill:         false
  property int  themePillMinWidth:   400   // piso da pill
  property int  themePillMinSpacing: 20    // espaço mínimo entre centro e laterais
  property bool themeHasPanel:     false
  property int  themePanelWidth: 400

  property var barMediaPlayerRef: null
  property var barClockRef:       null

  // Referência ao OsdService injetada pelo shell.qml
  property var osdService: null
  property var notifService: null

  // silenceMode — lido pelo shell.qml para propagar ao osd e notifService
  readonly property bool silenceMode: barState.silenceMode

  // Escrito pelo DmenuIpc.onPanelVisibleChanged para que cada instância de
  // bar (por monitor) possa incluir o dmenu no cálculo de anyPanelOpen.
  property bool dmenuPanelOpen: false

  // ── Cores dos popups — expostas publicamente para que componentes externos
  // (ex: DmenuIpc no shell.qml) usem exatamente as mesmas cores que o bar,
  // incluindo atualizações automáticas quando o tema muda.
  readonly property color popupColorBg:      barState.config.palettePanelBg
  readonly property color popupColorText:    barState.config.paletteText
  readonly property color popupColorTextDim: barState.config.paletteTextDim
  readonly property color popupColorAccent:  barState.config.paletteAccent
  readonly property color popupColorDivider: barState.config.paletteDivider

  // Referência ao ClockContent (dentro do clockPopup) — exposta para que
  // shell.qml possa injetar em osd.clockContent e conectar timerElapsed.
  property var clockContentRef: null

  // ── Conexão primária: timerElapsed → osdService ────────────────────────
  property var _barCcConnected: null

  function _barOnTimerElapsed(mode, phaseLabel) {
    if (!barRoot.osdService || !barRoot.clockContentRef) return
    var cc = barRoot.clockContentRef
    barRoot.osdService.timerOsd(phaseLabel, cc.barRemaining, mode === "pomodoro", cc.barRunning, cc.phaseDuration)
  }

  onClockContentRefChanged: {
    if (_barCcConnected) {
      try { _barCcConnected.timerElapsed.disconnect(barRoot._barOnTimerElapsed) } catch(e) {}
    }
    _barCcConnected = clockContentRef
    if (clockContentRef)
      clockContentRef.timerElapsed.connect(barRoot._barOnTimerElapsed)

    // Propaga para OsdService — garante que os botões do OSD timer funcionem
    if (barRoot.osdService)
      barRoot.osdService.clockContentRef = clockContentRef
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

  // Último bar que teve um painel aberto ou que está no monitor focado.
  // Usado como desempate quando nenhum monitor reporta focused=true (race condition).
  property var _lastActiveBar: null

  function _activeBar() {
    // Tenta pelo monitor focado (caminho normal)
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
    // Race condition: nenhum monitor está focused ainda — usa o último ativo
    // (evita abrir no monitor errado quando há múltiplos monitores)
    if (_lastActiveBar) return _lastActiveBar
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
    function silenceOn()     { barState.silenceMode = true  }
    function silenceOff()    { barState.silenceMode = false }
    function silenceToggle() { barState.silenceMode = !barState.silenceMode }
    function toggleWallpaper() { barRoot.wallpaperWindowOpen = !barRoot.wallpaperWindowOpen }
  }

  // ── Janela de configuração de wallpaper ──────────────────────────────────
  property bool wallpaperWindowOpen: false

  WallModule.WallpaperWindow {
    id: wallpaperWin
    panelOpen:    barRoot.wallpaperWindowOpen
    colorBg:      barRoot.popupColorBg
    colorText:    barRoot.popupColorText
    colorTextDim: barRoot.popupColorTextDim
    colorAccent:  barRoot.popupColorAccent
    colorDivider: barRoot.popupColorDivider
    onCloseRequested: barRoot.wallpaperWindowOpen = false
  }

  // ── IPC do dmenu — movido para shell.qml (usa DmenuIpc.openNative) ──────

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
  readonly property int popupHDmenu:  460

  // ── Configuração do dmenu (valores fixos) ────────────────────────────────
  property string _dmenuLaunchCmd: "uwsm app -- {exec}"
  property bool   _dmenuShowIcons: false

  // ── Barra + Popups (um conjunto por tela) ─────────────────────────────
  Variants {
    model: Quickshell.screens

    // ── Superfície de zona (transparente, não se retrai) ──────────────────
    // Propósito exclusivo: reservar espaço para janelas normais.
    //
    // Por que superfície separada?
    //   A barra visual precisa mudar zone (0↔barSize) quando detecta fullscreen.
    //   Cada mudança de zone faz o Hyprland reposicionar TODAS as janelas do monitor,
    //   incluindo a janela fullscreen em background — causando o push.
    //
    // Solução:
    //   • Esta superfície (Top, zone=barSize): nunca muda por fullscreen.
    //     Hyprland ignora exclusiveZone de superfícies Top para janelas fullscreen.
    //     Zone só muda com barState.autoHide (ação explícita do usuário).
    //   • Barra visual (Overlay, zone=0): nunca afeta o layout de janelas.
    //     Aparece acima de fullscreen para peek. Anima normalmente.
    PanelWindow {
      required property var modelData
      screen: modelData
      color: "transparent"

      WlrLayershell.layer: WlrLayershell.Top
      focusable: false
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: barState.autoHide ? 0 : barRoot.themeBarSize
      aboveWindows:  false

      readonly property int _pos: barRoot.position

      // Mesmos anchors que a barra visual
      anchors.top:    _pos === 1 || _pos === 2 || _pos === 4
      anchors.bottom: _pos === 3 || _pos === 2 || _pos === 4
      anchors.left:   _pos === 1 || _pos === 3 || _pos === 4
      anchors.right:  _pos === 1 || _pos === 3 || _pos === 2

      // Tamanho mínimo — exclusiveZone é explícito, tamanho não importa para a zona
      implicitWidth:  (_pos === 2 || _pos === 4) ? barRoot.themeBarSize : 1
      implicitHeight: (_pos === 1 || _pos === 3) ? barRoot.themeBarSize : 1

      // Margem da borda (sem marginOffset — não se move nunca)
      margins.top:    _pos === 1 ? barRoot.themeBarMargin : 0
      margins.bottom: _pos === 3 ? barRoot.themeBarMargin : 0
      margins.left:   _pos === 4 ? barRoot.themeBarMargin : 0
      margins.right:  _pos === 2 ? barRoot.themeBarMargin : 0

      Component.onCompleted: {
        console.log("[ZoneBar] screen=" + screen.name
            + " pos=" + _pos
            + " zone=" + exclusiveZone
            + " barSize=" + barRoot.themeBarSize)
      }
      onExclusiveZoneChanged: {
        console.log("[ZoneBar] exclusiveZone →", exclusiveZone)
        barRoot._onZoneSurfaceChanged()
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      color:  "transparent"

      // ── Estado de painéis — isolado por monitor ────────────────────────
      property int activePanel: barRoot.panelNone

      // dmenuPanelOpen é escrito pelo DmenuIpc.onPanelVisibleChanged.
      readonly property bool anyPanelOpen:
          activePanel !== barRoot.panelNone || barRoot.dmenuPanelOpen

      function openPanel(panelId) {
        // Em silence: só editor e dmenu são permitidos
        if (barState.silenceMode) {
          var allowed = panelId === barRoot.panelEditor ||
                        panelId === barRoot.panelNone
          if (!allowed) {
            console.log("[Bar] openPanel bloqueado pelo silence mode — panelId:", panelId)
            return
          }
        }
        barRoot._lastActiveBar = bar
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
      property int  barSize:   barRoot.themeBarSize
      property int  barMargin: barRoot.themeBarMargin
      property bool pill:      barRoot.themePill
      property int  position:  barRoot.position

      readonly property bool isVertical: position === 2 || position === 4

      // ── Largura real da pill (sem deadlock de bootstrap) ───────────────
      // O PanelWindow não pode depender de loader.item para seu tamanho,
      // porque o loader vive DENTRO do PanelWindow (anchors.fill).
      // Solução: _pillContentWidth é uma var simples, atualizada pelo
      // Connections abaixo quando loader.item.implicitWidth muda.
      // No bootstrap: começa com themePillMinWidth → PanelWindow abre →
      // Loader carrega → Pill mede conteúdo → sinal → _pillContentWidth atualiza.
      property int _pillContentWidth: barRoot.themePillMinWidth

      readonly property int effectivePillWidth:
          Math.max(barRoot.themePillMinWidth, _pillContentWidth)

      // pillSideMargin: margem lateral calculada a partir da largura real.
      property int pillSideMargin: {
        if (!pill) return 0
        if (isVertical)
          return Math.max(0, Math.floor((screen.height - effectivePillWidth) / 2))
        return Math.max(0, Math.floor((screen.width - effectivePillWidth) / 2))
      }

      property bool themeLoaded: barRoot.themeBarSize > 0

      anchors.top:    themeLoaded ? (position === 1 || position === 2 || position === 4) : false
      anchors.bottom: themeLoaded ? (position === 3 || position === 2 || position === 4) : false
      anchors.left:   themeLoaded ? (position === 1 || position === 3 || position === 4) : false
      anchors.right:  themeLoaded ? (position === 1 || position === 3 || position === 2) : false

      implicitHeight: {
        if (!themeLoaded) return 0
        if (!isVertical) return barSize
        return pill ? effectivePillWidth : screen.height
      }
      implicitWidth: {
        if (!themeLoaded) return 0
        if (isVertical) return barSize
        return pill ? effectivePillWidth : screen.width
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

      // ── onBarShowChanged: controla marginOffset (estado físico) ──────────
      // POSIÇÃO INTENCIONAL: antes do bloco de auto-hide, pois _doShow()/_doHide()
      // escrevem barShow e precisam que este handler já exista.
      onBarShowChanged: {
        marginOffset = barShow ? 0 : barSize + barMargin + 1
      }

      // ── Layer e zona da barra visual ─────────────────────────────────────
      // zone=0: nunca afeta layout de janelas — a superfície de zona cuida disso.
      // Layer muda para Overlay quando autohide: barra aparece acima de fullscreen.
      WlrLayershell.layer: bar.effectiveAutoHide ? WlrLayershell.Overlay : WlrLayershell.Top

      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0

      // anchor.* removidos — popups agora usam PanelWindow com barRef: bar

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

          // Injecta a largura mínima e o espaçamento mínimo ao Pill.qml.
          var minW   = barState.config.pillWidth    > 0 ? barState.config.pillWidth    : 400
          var minGap = barState.config.pillMinSpacing >= 0 ? barState.config.pillMinSpacing : 20
          barRoot.themePillMinWidth   = minW
          barRoot.themePillMinSpacing = minGap
          if ("minPillWidth"   in item) item.minPillWidth   = minW
          if ("pillMinSpacing" in item) item.pillMinSpacing = minGap

          // Semente inicial de _pillContentWidth: usa o implicitWidth que o
          // Pill.qml já calculou (pode ser minPillWidth se o conteúdo ainda
          // não foi medido). O Connections onImplicitWidthChanged atualiza
          // conforme o layout estabiliza.
          Qt.callLater(function() {
            if (loader.item) {
              var iw = loader.item.implicitWidth
              if (iw > 0) bar._pillContentWidth = iw
            }
          })

          _applyConfig(item)

          // Reaplica o estado físico correto sem animação após troca de tema
          bar.animating    = false
          bar.marginOffset = bar.barShow ? 0 : bar.barSize + bar.barMargin + 1
          bar.animating    = true
        }
      }

      // ── Aplicação de config ao tema ────────────────────────────────────

      // Rastreia implicitWidth do Pill.qml → atualiza _pillContentWidth →
      // effectivePillWidth → PanelWindow redimensiona.
      // ignoreUnknownSignals: temas sem pill não emitem implicitWidthChanged.
      Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onImplicitWidthChanged() {
          var iw = loader.item ? loader.item.implicitWidth : 0
          if (iw > 0) bar._pillContentWidth = iw
        }
      }

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
        function onPillWidthChanged() {
          var minW = barState.config.pillWidth > 0 ? barState.config.pillWidth : 400
          barRoot.themePillMinWidth = minW
          if (loader.item && "minPillWidth" in loader.item) loader.item.minPillWidth = minW
        }
        function onPillMinSpacingChanged() {
          var gap = barState.config.pillMinSpacing >= 0 ? barState.config.pillMinSpacing : 20
          barRoot.themePillMinSpacing = gap
          if (loader.item && "pillMinSpacing" in loader.item) loader.item.pillMinSpacing = gap
        }
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
        // pillWidth: gerido pelo implicitWidth reactivo do Pill.qml —
        // não é necessário propagar manualmente.

      }

      Connections {
        target: barState
        ignoreUnknownSignals: true
        function onEditorRequested() {
          if (!editorCooldown.running) { bar.openPanel(barRoot.panelEditor); editorCooldown.restart() }
        }
        // onModulesUpdated — os Bindings declarativos cuidam da propagação.
        function onModulesUpdated() {}
        function onSilenceModeChanged() {
          // Ao ativar silence, fecha todos os painéis abertos
          // exceto editor e dmenu (são de configuração/controle, sempre permitidos).
          if (!barState.silenceMode) return
          var keep = bar.activePanel === barRoot.panelEditor
          if (!keep) bar.closeAllPanels()
        }
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
          // Sincroniza clockContentRef que pode ter chegado antes do osdService
          if (barRoot.osdService && barRoot.clockContentRef)
            barRoot.osdService.clockContentRef = barRoot.clockContentRef
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
          // Sem guard: ck.clockContent e clockContentRef precisam sempre apontar
          // para o mesmo ClockContent. Se houver guard aqui, após um reload do
          // tema clockContentRef fica apontando para uma instância destruída e
          // o IPC passa a chamar funções em um objeto morto silenciosamente.
          barRoot.clockContentRef = clockPopup.clockContentRef
        }
      }

      // ── Sinais do tema → abertura de painéis ───────────────────────────
      // panelCooldown: evita duplo-disparo de clicks rápidos vindos do TEMA.
      // Valor ≥ animDuration (200ms) para que o toggle não re-abra durante o fechamento.
      // NÃO é usado no IpcHandler — binds do Hyprland chamam openPanel() diretamente,
      // sem cooldown, para não ignorar acionamentos legítimos.
      Timer { id: panelCooldown;  interval: 220; repeat: false }
      Timer { id: editorCooldown; interval: 220; repeat: false }

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

      // ── Coordenadas globais do monitor via HyprlandMonitor ────────────────
      // screen.x/y NÃO existem no tipo Screen do Quickshell (só width/height/name).
      // Sem estas propriedades screen.x === undefined → NaN em comparações →
      // inScreen sempre false → detecção de cursor na borda nunca funciona.
      // Solução: usar hyprMonitor.x/y do IPC do Hyprland (coordenadas globais
      // corretas, incluindo monitores com posição negativa como eDP-1 em -1920,0).
      readonly property int _scrX: hyprMonitor ? hyprMonitor.x      : 0
      readonly property int _scrY: hyprMonitor ? hyprMonitor.y      : 0
      readonly property int _scrW: hyprMonitor ? hyprMonitor.width  : screen.width
      readonly property int _scrH: hyprMonitor ? hyprMonitor.height : screen.height

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
      property bool _verifyMode: false   // true quando _monProc está a verificar após troca de workspace
      property bool _zoneJustChanged: false  // true por 500ms após zone surface mudar

      Timer {
        id: _zoneChangedTimer
        interval: 500
        repeat: false
        onTriggered: bar._zoneJustChanged = false
      }

      Connections {
        target: barRoot
        function on_OnZoneSurfaceChanged() {
          bar._zoneJustChanged = true
          _zoneChangedTimer.restart()
        }
      }

      // ── fullscreenChanged: app entrou/saiu de fullscreen no workspace atual ────
      // Usa activewindow com delay de 150ms (estados transitórios durante a transição)
      // e debounce de 300ms no resultado false (Vivaldi/Chromium emite eventos extras).
      Timer {
        id: fsQueryTimer
        interval: 150
        repeat:   false
        onTriggered: {
          bar._verifyMode = false
          bar._monProc.running = true
        }
      }

      Timer {
        id: fsInitTimer
        interval: 600
        repeat:   false
        onTriggered: {
          bar._verifyMode = false
          bar._monProc.running = true
        }
      }

      Timer {
        id: fsDebounceTimer
        interval: 300
        repeat:   false
        onTriggered: {
          console.log("[FS] debounce FIRED → isFullscreen false")
          bar.isFullscreen = false
        }
      }

      // ── workspaceOrFocusChanged: usuário trocou de workspace ─────────────────
      // Fluxo "predict → verify":
      //  1. _wsProc roda hyprctl clients -j → filtra por workspace alvo + fullscreen & 2
      //     (hyprctl workspaces hasfullscreen é buggy para workspaces em background)
      //  2. Aplica isFullscreen imediatamente (sem debounce) → zone/autohide corretos
      //     antes de o Hyprland renderizar o workspace
      //  3. _wsVerifyTimer dispara após 500ms → _monProc verifica activewindow real
      //  4. Se a verificação discordar → corrige isFullscreen (evita falsos positivos)
      Timer {
        id: _wsVerifyTimer
        interval: 500
        repeat:   false
        onTriggered: {
          console.log("[FS] wsVerify → activewindow check")
          bar._verifyMode = true
          if (!bar._monProc.running) bar._monProc.running = true
        }
      }

      property string _wsBuf: ""
      property var _wsProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser {
          onRead: data => { bar._wsBuf += data }
        }
        onExited: {
          try {
            var clients = JSON.parse(bar._wsBuf)
            var wsId = bar.hyprMonitor ? bar.hyprMonitor.activeWorkspace.id : -1
            var found = false
            for (var i = 0; i < clients.length; i++) {
              var c = clients[i]
              if (c.workspace && c.workspace.id === wsId) {
                var isRealFs = c.fullscreen !== undefined && (c.fullscreen & 2) !== 0
                if (isRealFs) {
                  console.log("[FS] wsCheck HIT class=" + c.class
                      + " ws=" + wsId + " fs=" + c.fullscreen)
                  found = true; break
                }
              }
            }
            console.log("[FS] wsCheck ws=" + wsId + " hasFullscreen=" + found)
            // Aplica imediatamente — fullscreen de cliente é estável, não transitório
            fsDebounceTimer.stop()
            if (found !== bar.isFullscreen) {
              console.log("[FS] wsCheck → isFullscreen: " + bar.isFullscreen + " → " + found)
              bar.isFullscreen = found
            }
            // Agenda verificação de confirmação após 500ms
            _wsVerifyTimer.restart()
          } catch(e) {
            console.log("[FS] wsProc ERRO:", e.toString())
          }
          bar._wsBuf = ""
        }
      }

      property var _monProc: Process {
        command: ["hyprctl", "activewindow", "-j"]
        stdout: SplitParser {
          onRead: data => { bar._monBuf += data }
        }
        onExited: {
          try {
            var win = JSON.parse(bar._monBuf)
            var onThisMonitor = bar.hyprMonitor && (win.monitor === bar.hyprMonitor.id)
            var isRealFs = win.fullscreen !== undefined && (win.fullscreen & 2) !== 0
            var found = onThisMonitor && isRealFs
            console.log("[FS] activewindow"
                + (bar._verifyMode ? " [VERIFY]" : "")
                + " class=" + (win.class || "?")
                + " fs=" + win.fullscreen
                + " → found=" + found)
            if (bar._verifyMode) {
              // Modo verificação: ground-truth após 500ms — corrige se necessário
              if (found !== bar.isFullscreen) {
                console.log("[FS] VERIFY corrigiu isFullscreen: " + bar.isFullscreen + " → " + found)
                bar.isFullscreen = found
              }
            } else {
              // Modo normal (fullscreenChanged): debounce no false para Vivaldi/Chromium
              if (found) {
                fsDebounceTimer.stop()
                bar.isFullscreen = true
              } else {
                fsDebounceTimer.restart()
              }
            }
          } catch(e) {
            console.log("[FS] activewindow ERRO:", e.toString())
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
          // App entrou/saiu de fullscreen no workspace atual
          console.log("[FS] fullscreenChanged:", state, "→ delay 150ms")
          fsQueryTimer.restart()
        }
        function onWorkspaceOrFocusChanged() {
          // Filtra eventos auto-gerados pelo Hyprland em resposta às nossas mudanças de zona
          if (bar._zoneJustChanged) {
            console.log("[FS] workspaceFocus IGNORADO (zone mudou há <500ms)")
            return
          }
          console.log("[FS] workspaceFocus → wsCheck")
          bar._wsProc.running = true
        }
      }

      property bool effectiveAutoHide: {
        if (barState.autoHide) return true
        // silenceMode suprime o peek de fullscreen — barra fica escondida durante fullscreen
        if (!barState.silenceMode && barState.fullscreenPeekEnabled && isFullscreen) return true
        return false
      }

      onEffectiveAutoHideChanged: {
        console.log("[FS] [" + bar.screen.name + "] effectiveAutoHide:", effectiveAutoHide)
        updateBarVisibility()
      }

      onIsFullscreenChanged: {
        console.log("[FS] [" + bar.screen.name + "] isFullscreen →", isFullscreen)
      }

      property bool cursorNearBar: {
        var threshold = _showThreshold
        var cx = barState.cursorX
        var cy = barState.cursorY
        var inScreen = cx >= _scrX && cx <= _scrX + _scrW
                    && cy >= _scrY && cy <= _scrY + _scrH
        if (!inScreen) return false
        var lx = cx - _scrX
        var ly = cy - _scrY
        if (position === 1) return ly <= threshold
        if (position === 2) return lx >= _scrW - threshold
        if (position === 3) return ly >= _scrH - threshold
        if (position === 4) return lx <= threshold
        return false
      }

      property bool cursorAtEdge: {
        var threshold = _showThreshold
        var cx = barState.cursorX
        var cy = barState.cursorY
        var inScreen = cx >= _scrX && cx <= _scrX + _scrW
                    && cy >= _scrY && cy <= _scrY + _scrH
        if (!inScreen) return false
        var lx = cx - _scrX
        var ly = cy - _scrY
        var tolerance = barSize / 2
        if (position === 1 || position === 3) {
          var atV = position === 1 ? ly <= threshold : ly >= _scrH - threshold
          if (!atV) return false
          // pill: verifica extensão horizontal da pill (± barSize/2 de tolerância)
          if (pill) return lx >= pillSideMargin - tolerance && lx <= _scrW - pillSideMargin + tolerance
          return true   // não-pill: cobre toda a largura
        }
        if (position === 2 || position === 4) {
          var atH = position === 4 ? lx <= threshold : lx >= _scrW - threshold
          if (!atH) return false
          // pill vertical: extensão vertical da pill
          if (pill) return ly >= pillSideMargin - tolerance && ly <= _scrH - pillSideMargin + tolerance
          return true   // não-pill: cobre toda a altura
        }
        return false
      }

      // cursorOverBar: true quando o cursor está dentro da área física da barra
      // (não apenas na borda). Usado para não esconder a barra enquanto o cursor
      // ainda está sobre ela.
      // CORRECÇÃO: em modo pill, também verifica os limites laterais da pill —
      // sem isso a barra desaparecia quando o cursor chegava perto das extremidades
      // (dentro da pill mas fora da zona central), porque só a profundidade (Y)
      // era verificada.
      property bool cursorOverBar: {
        var cx = barState.cursorX
        var cy = barState.cursorY
        var inScreen = cx >= _scrX && cx <= _scrX + _scrW
                    && cy >= _scrY && cy <= _scrY + _scrH
        if (!inScreen) return false
        var lx = cx - _scrX
        var ly = cy - _scrY
        var size = barSize + barMargin + 4
        // Verifica primeiro a profundidade (distância à borda da tela)
        var inDepth = false
        if      (position === 1) inDepth = ly <= size
        else if (position === 2) inDepth = lx >= _scrW - size
        else if (position === 3) inDepth = ly >= _scrH - size
        else if (position === 4) inDepth = lx <= size
        if (!inDepth) return false
        // Em modo pill: também verifica se o cursor está dentro da extensão lateral
        // da pill.
        //
        // CORRECÇÃO: tolerância aumentada de 2px para barSize/2 (≈15px).
        //
        // Antes: margin = pillSideMargin - 2
        //   → cursorOverBar vai a false 2px além da borda visual da pill.
        //   → barra esconde quando o cursor está sobre os módulos das extremidades
        //     (ex: clock ou volume na base de uma barra vertical), porque qualquer
        //     micro-overshoot de 3px+ já desactiva cursorOverBar.
        //
        // Agora: margin = pillSideMargin - barSize/2 (≈ pillSideMargin - 15)
        //   → mesma tolerância que cursorAtEdge usa (tolerance = barSize/2).
        //   → o cursor pode ultrapassar a borda da pill em até ~15px antes da
        //     barra se esconder, dando espaço para interagir com módulos nas
        //     extremidades sem que a barra desapareça no caminho.
        //   → isométrico com cursorAtEdge: as duas zonas agora coincidem.
        if (pill) {
          var tolerance = Math.round(barSize / 2)
          var margin = pillSideMargin - tolerance
          if (position === 1 || position === 3)
            return lx >= margin && lx <= _scrW - margin
          if (position === 2 || position === 4)
            return ly >= margin && ly <= _scrH - margin
        }
        return true
      }

      // ══════════════════════════════════════════════════════════════════════
      // Auto-hide — Máquina de estado imperativa (sem binding loop)
      // ══════════════════════════════════════════════════════════════════════
      //
      // ARQUITETURA
      // ───────────
      // barVisible  (bool, simples) — estado LÓGICO. Sem binding derivado.
      //   Escrito exclusivamente por _doShow() e _doHide(). Nenhuma propriedade
      //   é lida dentro de um binding que também escreva barVisible.
      //
      // barShow     (bool, simples) — estado FÍSICO que controla marginOffset
      //   (via onBarShowChanged acima). Segue barVisible com delay no fechamento
      //   (hideTimer) para que a animação de saída possa terminar.
      //
      // updateBarVisibility() — único ponto de decisão. Lê todas as entradas e
      //   chama _doShow()/_doHide(). NÃO é chamada de dentro de onBarVisibleChanged
      //   nem de qualquer handler que barVisible dispare, evitando reentrada.
      //
      // POR QUÊ NÃO HÁ BINDING LOOP
      // ────────────────────────────
      // Bindings criam grafos de dependência estáticos: se A lê B, qualquer
      // escrita em B re-avalia A, potencialmente emitindo onAChanged, que escreve
      // B de volta — loop. Aqui:
      //   • barVisible NÃO é binding — é uma variável simples.
      //   • updateBarVisibility() é uma função JS: o motor QML não rastreia
      //     suas leituras como dependências. Ela pode ler barVisible à vontade
      //     sem criar dependência estática.
      //   • Escrever barVisible emite onBarVisibleChanged, mas esse handler
      //     não chama updateBarVisibility() nem escreve nenhuma propriedade
      //     que dispare os sinais conectados (onCursorNearBarChanged, etc.).
      //   • cursorOverBar/cursorNearBar/cursorAtEdge são bindings, mas NUNCA
      //     lêem barVisible — a dependência é estritamente unidirecional:
      //     cursor properties → updateBarVisibility → barVisible.
      //
      // ARMADILHA CONHECIDA: propriedades QML só emitem Changed quando o valor
      // REALMENTE MUDA. Atribuir `barVisible = true` quando já é true não emite
      // onBarVisibleChanged — comportamento esperado e necessário. _doShow() e
      // _doHide() podem ser chamados repetidamente sem efeito colateral extra.

      // Estado lógico: sem binding, escrito apenas por _doShow()/_doHide()
      property bool barVisible: false

      // Estado físico: delayed em relação a barVisible (via hideTimer)
      // Declarado separado de barVisible para deixar claro o papel de cada um.
      property bool barShow: true

      // ── Hover nativo (Wayland) para detecção precisa do cursor sobre a barra ──
      HoverHandler { id: barHover }
      property bool cursorOnBar: barHover.hovered

      // ── Timer de fechamento ──────────────────────────────────────────────
      // Só altera barShow (estado físico). barVisible já foi para false
      // antes do timer ser iniciado — garantindo que nenhuma condição de
      // manutenção em updateBarVisibility() leia um barVisible "stale".
      Timer {
        id: hideTimer
        interval: barState.hideDelayMs
        repeat:   false
        onTriggered: bar.barShow = false
      }

      // ── Timer de debounce de abertura (anti-falso-positivo) ──────────────
      // Evita abrir a barra quando o cursor roça a borda por < 80ms.
      // Ao disparar, re-verifica as condições: se o cursor já saiu, não abre.
      // 80ms é imperceptível para o usuário mas filtra movimentos rápidos.
      //
      // CORREÇÃO: adicionado `|| bar.cursorOverBar` à re-verificação.
      //
      // Cenário que este fix resolve (pill horizontal, barra no topo):
      //   1. cursor chega à borda superior (ly ≤ edgeThreshold=5px)
      //      → cursorAtEdge=true → P3 → showDebounceTimer.start()
      //   2. cursor move-se para o módulo clock/volume (ly=20px)
      //      ANTES dos 80ms expirarem
      //      → cursorAtEdge=false → onCursorAtEdgeChanged → updateBarVisibility()
      //      → P3 falha, P4 falha (barShow=false), nenhuma condição activa
      //      → _doHide NÃO é chamado (barVisible=false,barShow=false)
      //      → timer continua a correr
      //   3. 80ms depois o timer dispara:
      //      → SEM fix: near=false, condição=false → barra nunca abre
      //      → COM fix: near=false MAS cursorOverBar=true (cursor está sobre a
      //        barra, a ≤ barSize+barMargin+4 px da borda) → _doShow() ✓
      //
      // Segurança: showDebounceTimer SÓ é iniciado via P3, que exige
      // cursorAtEdge=true. Logo cursorOverBar=true aqui significa sempre
      // "cursor passou pela borda E está sobre a área da barra" — não é
      // um atalho para mostrar a barra a partir de posições arbitrárias.
      Timer {
        id: showDebounceTimer
        interval: 80
        repeat:   false
        onTriggered: {
          // Re-verificação: as condições ainda se aplicam?
          if (bar.cursorAtEdge || bar.anyPanelOpen || !bar.effectiveAutoHide || !bar.hasWindows) {
            bar._doShow()
          }
          // Se nenhuma condição persiste: falso positivo descartado silenciosamente.
        }
      }

      // ── _doShow: aplica o estado "visível" (lógico + físico imediatamente) ──
      // Seguro chamar múltiplas vezes: escritas sem mudança não emitem Changed.
      function _doShow() {
        hideTimer.stop()
        showDebounceTimer.stop()
        barVisible = true    // emite onBarVisibleChanged apenas se mudou de false
        barShow    = true    // emite onBarShowChanged → marginOffset = 0
      }

      // ── _doHide: aplica o estado "oculto"
      //   noDelay=true  → imediato: barShow=false agora (startup, sem janela)
      //   noDelay=false → lógico imediato, físico via hideTimer (comportamento normal).
      //     Durante o delay, barShow ainda é true — a animação de saída ocorre.
      //     Se o cursor voltar para a barra durante a animação (barShow=true,
      //     cursorOverBar=true), P4 em updateBarVisibility() cancela o hide.
      function _doHide(noDelay) {
        showDebounceTimer.stop()
        barVisible = false           // lógico: oculto agora (emite Changed se era true)
        if (noDelay) {
          hideTimer.stop()
          barShow = false            // físico: oculto imediatamente
        } else {
          // barShow permanece true durante a animação de saída.
          // hideTimer só é iniciado se não estiver rodando (evita reset do delay).
          if (!hideTimer.running) hideTimer.restart()
        }
      }

      // ── updateBarVisibility: ponto único de decisão ──────────────────────
      // Prioridades em ordem decrescente. A primeira condição verdadeira vence.
      // Chamada pelos onXChanged abaixo — nunca chamada de dentro de handlers
      // que barVisible ou barShow disparem.
      function updateBarVisibility() {

        // P1: painel aberto → visível imediatamente (independente de cursor)
        if (anyPanelOpen) { _doShow(); return }

        // P2: auto-hide desativado (barState.autoHide=false e não fullscreen
        //     com peek ativo) → sempre visível
        if (!effectiveAutoHide) { _doShow(); return }

        // P3: cursor na zona de ativação → abrir (com debounce anti-falso-positivo)
        //     cursorAtEdge cobre pill e não-pill com verificação lateral.
        if (cursorAtEdge) {
          hideTimer.stop()    // cancela fechamento pendente
          if (barVisible) {
            // Já estava visível: mantém sem debounce extra
            showDebounceTimer.stop()
            barShow = true
          } else if (!showDebounceTimer.running) {
            // Aguarda 80ms antes de abrir (anti-falso-positivo)
            showDebounceTimer.restart()
          }
          return
        }

        // P3.5: debounce pendente + cursor já sobre a área física da barra.
        //
        // Acontece quando:
        //   • O cursor cruzou a borda de activação (cursorAtEdge=true)
        //     → P3 iniciou showDebounceTimer
        //   • O cursor entrou no interior da barra (cursorAtEdge=false,
        //     cursorOverBar=true) ANTES de os 80ms expirarem
        //   • onCursorAtEdgeChanged chama updateBarVisibility():
        //     P3 falha, P4 falha (barShow=false), default não actua
        //     (barVisible=false e barShow=false → guarda não passa)
        //     → timer ainda corre, mas sem este P3.5 ficaria preso:
        //     ao disparar, near=false e a barra nunca abriria.
        //
        // P3.5 confirma a abertura imediatamente, sem esperar o timer,
        // sempre que o cursor esteja sobre a barra e o debounce ainda esteja
        // activo (garantia de que houve um cursorAtEdge=true recente).
        //
        // Diferença de P4: P4 exige barShow=true (barra já fisicamente visível).
        // P3.5 actua enquanto a barra ainda está oculta (barShow=false).
        // P3.5: debounce pendente + cursor já sobre a área física da barra.
        if (showDebounceTimer.running && cursorOverBar) {
            _doShow()
            return
        }

        // P4: cursor sobre a barra enquanto ela ainda está fisicamente presente.
        //     barShow pode ser true mesmo após barVisible ir a false (durante
        //     a animação de saída). Isso permite "resgatar" a barra com o cursor.
        // P4: cursor sobre a barra enquanto ela ainda está fisicamente presente (hover nativo)
        if (barShow && cursorOnBar) {
            _doShow()
            return
        }

        // P5: workspace sem janelas → sempre visível (barra de desktop vazio)
        if (!hasWindows) { _doShow(); return }

        // Padrão: nenhuma condição de manutenção → fechar
        if (barVisible || barShow) {
          _doHide(false)
        }
        // Se ambos já são false: estado já correto, nada a fazer.
      }

      // ── onBarVisibleChanged: apenas log e guarda defensiva ────────────────
      // barShow é gerenciado exclusivamente por _doShow(), _doHide() e hideTimer.
      // NUNCA chama updateBarVisibility() — evita reentrada.
      onBarVisibleChanged: {
        console.log("[Bar] [" + screen.name + "] barVisible →", barVisible)
        // Guarda defensiva: se barVisible foi para true mas barShow ainda é false
        // (situação que não deve ocorrer com _doShow, mas defensivamente):
        if (barVisible && !barShow) barShow = true
      }

      // ── Conexão de sinais → updateBarVisibility ───────────────────────────
      // Todos são onXChanged de property bool: disparam APENAS quando o valor
      // muda (false↔true), nunca por leituras ou a cada frame.
      // Nenhum desses sinais é emitido como consequência de barVisible mudar,
      // garantindo que não há ciclo.
      onAnyPanelOpenChanged:  updateBarVisibility()
      onCursorNearBarChanged: updateBarVisibility()
      onCursorAtEdgeChanged:  updateBarVisibility()
      onCursorOverBarChanged: updateBarVisibility()
      onCursorOnBarChanged: updateBarVisibility()
      onHasWindowsChanged:    updateBarVisibility()

      // ══════════════════════════════════════════════════════════════════════

      Component.onCompleted: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
          var m = Hyprland.monitors.values[i]
          if (m.name === bar.screen.name) { bar.hyprMonitor = m; break }
        }
        barRoot._barInstances = barRoot._barInstances.concat([bar])

        // ── Estado inicial sem animação ──────────────────────────────────
        // Determinamos o estado inicial diretamente, sem passar por
        // updateBarVisibility(), porque:
        //   1. cursorX/Y ainda não foram inicializados pelo Hyprland → não
        //      confiamos em cursorNearBar/cursorAtEdge neste momento.
        //   2. fsInitTimer ainda não rodou → isFullscreen pode estar desatualizado.
        //   3. Queremos ocultar imediatamente (sem delay de hideTimer) se necessário.
        //
        // A máquina de estado passa a ser totalmente reativa após este bloco:
        // fsInitTimer → _monProc → isFullscreen → effectiveAutoHide →
        // onEffectiveAutoHideChanged → updateBarVisibility().
        animating = false
        var startVisible = anyPanelOpen || !effectiveAutoHide || !hasWindows
        if (startVisible) {
          barVisible   = true
          barShow      = true
          marginOffset = 0
        } else {
          barVisible   = false
          barShow      = false
          marginOffset = barSize + barMargin + 1
        }
        animating = true

        // Dispara verificação de fullscreen após 600ms (aguarda Hyprland estabilizar)
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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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
        barRef: bar

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

      // ── Dmenu — gerenciado por DmenuIpc em shell.qml ──────────────────────

    } // PanelWindow bar
  } // Variants
}
