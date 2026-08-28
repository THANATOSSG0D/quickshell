import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs
import '../mediaPlayer' as MediaPanel
import '../volume'      as VolumeModule
import '../clock'       as ClockModule
import '../tasks'       as TasksModule
import '../quicksettings' as QsModule
import '../notifications' as NotifModule
import '../wallpaper' as WallModule
import './themes' as BarThemes

Scope {
  id: barRoot

  // ── Parametrização de instância ──────────────────────────────────────
  // Defaults preservam EXATAMENTE o comportamento atual (a barra original,
  // instanciada sem passar nada, continua igual). Uma segunda instância
  // (ex: a Dock) passa instanceId/paths/tema/autoHide diferentes.
  property string instanceId:      "bar"
  property string barJsonPath:     Quickshell.shellDir + "/state/Bar.json"
  property string stateJsonPath:   Quickshell.shellDir + "/state/BarState.json"
  property string initialTheme:    "Pill"
  property bool   initialAutoHide: false
  property bool   initialPanelEnabled: true

  // Config de aparência/posição dos POPUPS (PopupConfig) — separada por
  // instância, igual barJsonPath/stateJsonPath acima. Por padrão a instância
  // "bar" usa o arquivo original (state/PopupConfig.json — preserva o que já
  // estava salvo); shell.qml passa um caminho próprio pra "dock"
  // (state/DockPopupConfig.json), então editar os popups da dock nunca mexe
  // nos da barra principal, e vice-versa.
  property string popupConfigJsonPath: Quickshell.shellDir + "/state/PopupConfig.json"

  property var popupConfig: PopupConfig {
    id: popupConfigInst
    path: barRoot.popupConfigJsonPath
    // Isola a config de aparência/posição dos popups POR TEMA — troca de
    // tema na barra (ou na dock) troca junto as cores/tamanhos dos painéis.
    // Ver PopupConfig.qml (cascata: themes[tema] → legado → defaults).
    theme: barState.currentTheme
  }

  // Referência pública — popups leem via barRef.popupConfigRef (ver
  // "readonly property var popupConfigRef" na PanelWindow "bar" abaixo, e
  // BarPopup.qml). ConfigWindow/PanelTab leem via bar.popupConfigRef /
  // dockBar.popupConfigRef (fiação em shell.qml).
  readonly property var popupConfigRef: popupConfig

  BarState {
    id: barState
    instanceId:          barRoot.instanceId
    barJsonPath:         barRoot.barJsonPath
    stateJsonPath:       barRoot.stateJsonPath
    initialTheme:        barRoot.initialTheme
    initialAutoHide:     barRoot.initialAutoHide
    initialPanelEnabled: barRoot.initialPanelEnabled
  }

  // (o bridge de tooltip foi movido pra dentro do Loader "barContentRoot"
  // abaixo — cada painel, bar ou dock, expõe sua PRÓPRIA config de tooltip
  // ali, em vez de escrever num singleton global compartilhado. Ver
  // comentário junto ao Loader.)

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
  property var barTasksRef:       null

  // Referência ao OsdService injetada pelo shell.qml
  property var osdService: null
  property var notifService: null

  // Referência à instância única de DmenuIpc (shell.qml) — usada pelo
  // módulo "dmenu" da barra (Dmenu.qml) pra abrir o launcher direto do
  // clique, sem depender do IpcHandler externo.
  property var dmenuIpcRef: null

  // silenceMode — lido pelo shell.qml para propagar ao osd e notifService
  readonly property bool silenceMode: barState.silenceMode

  // Escrito pelo DmenuIpc.onPanelVisibleChanged para que cada instância de
  // bar (por monitor) possa incluir o dmenu no cálculo de anyPanelOpen.
  property bool dmenuPanelOpen:  false
  property int  dmenuPanelWidth: 320  // sincronizado pelo DmenuIpc quando abre

  // ── Cores dos popups — expostas publicamente para que componentes externos
  // (ex: DmenuIpc no shell.qml) usem exatamente as mesmas cores que o bar,
  // incluindo atualizações automáticas quando o tema muda.
  // Referência pública ao BarConfig — usada pelo shell.qml para o ConfigWindow
  readonly property var configRef: barState.config

  // ── Exposição pro PanelRouter ────────────────────────────────────────────
  // Quais módulos este bar/dock mostra no layout ativo agora — usado pra
  // decidir onde os popups abrem por padrão (ver PanelRouter.resolveInstance).
  readonly property var modulesLeft:   barState.modulesLeft
  readonly property var modulesRight:  barState.modulesRight
  readonly property var modulesTop:    barState.modulesTop
  readonly property var modulesBottom: barState.modulesBottom
  readonly property var modulesMiddle: barState.modulesMiddle
  readonly property var modulesCenter: barState.modulesCenter

  // Registra esta instância (bar/dock/...) no PanelRouter assim que ela
  // termina de montar — não precisa de fiação manual no shell.qml.
  //
  // (Guard contra tela placeholder "FALLBACK" removido daqui: barRoot é
  // uma instância ÚNICA por shell — bar/dock — não uma por tela; quem é
  // por tela é o PanelWindow interno, mais abaixo. Um monitor
  // aparecendo/sumindo não recria barRoot, então esse registro só roda
  // uma vez de verdade, no boot do shell.)
  Component.onCompleted: PanelRouter.registerInstance(barRoot.instanceId, barRoot)

  // Desregistra ao morrer — defensivo, cobre qualquer cenário futuro em
  // que barRoot venha a ser destruído/recriado, pra não deixar lixo em
  // _instances/_order do PanelRouter.
  Component.onDestruction: PanelRouter.unregisterInstance(barRoot.instanceId, barRoot)

  // ── _openRouted: abre um painel na instância "certa" (a que tem o módulo
  // no layout ativo), ou onde o override manual da config UI mandar, ou —
  // se nada resolver — na instância que chamou (comportamento original). ──
  function _openRouted(moduleName, panelId) {
    var inst = PanelRouter.resolveInstance(moduleName, barRoot)
    var b = inst ? inst._activeBar() : barRoot._activeBar()
    if (!b) b = barRoot._activeBar()
    if (b) b.openPanel(panelId)
  }

  readonly property color popupColorBg:      barState.config.palettePanelBg
  readonly property color popupColorText:    barState.config.paletteText
  readonly property color popupColorTextDim: barState.config.paletteTextDim
  readonly property color popupColorAccent:  barState.config.paletteAccent
  readonly property color popupColorDivider: barState.config.paletteDivider

  // Referência ao ClockContent (dentro do clockPopup) — exposta para que
  // shell.qml possa injetar em osd.clockContent e conectar timerElapsed.
  property var clockContentRef: null

  // Referência ao TasksContent (dentro do tasksPopup) — mesmo esquema do
  // clockContentRef, mas sem OSD/timer (o módulo tasks não tem isso).
  property var tasksContentRef: null

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
    target: barState.instanceId === "bar" ? "timer" : "timer_" + barState.instanceId
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
    target: barState.instanceId === "bar" ? "bar" : "bar_" + barState.instanceId
    // ── Painéis roteados — abrem de preferência onde o módulo correspondente
    // está instanciado no layout ativo (bar ou dock), com override manual
    // possível via config UI (PanelRouter.set). Ver Bar._openRouted().
    function toggleVolume()     { barRoot._openRouted("volume",        barRoot.panelSink)   }
    function toggleSource()     { barRoot._openRouted("volume",        barRoot.panelSource) }
    function toggleVolumeFull() { barRoot._openRouted("volume",        barRoot.panelVolume) }
    function togglePlayer()     { barRoot._openRouted("mediaplayer",   barRoot.panelPlayer) }
    function toggleClock()      { barRoot._openRouted("clock",         barRoot.panelClock)  }
    function toggleTasks()      { barRoot._openRouted("tasks",         barRoot.panelTasks)  }
    function toggleQs()         { barRoot._openRouted("quicksettings", barRoot.panelQs)     }
    function toggleNotif()      { barRoot._openRouted("notifications", barRoot.panelNotif)  }
    // O editor NÃO é roteado — ele edita a config da instância que o abriu
    // (bar ou dock), então precisa sempre ficar preso a quem chamou.
    function toggleEditor()  { var b = barRoot._activeBar(); if (b) b.openPanel(barRoot.panelEditor) }
    function closeAll() {
      // Fecha em TODAS as instâncias registradas (bar, dock, ...) — não só
      // na que recebeu o IPC — já que um painel roteado pode ter aberto
      // numa instância diferente da que foi chamada para fechá-lo.
      var insts = PanelRouter.allInstances()
      if (insts.length === 0) insts = [barRoot]
      for (var k = 0; k < insts.length; k++) {
        var inst = insts[k]
        for (var i = 0; i < inst._barInstances.length; i++) {
          if (inst._barInstances[i]) inst._barInstances[i].closeAllPanels()
        }
      }
    }
    function disableFullscreenPeek() { barState.fullscreenPeekEnabled = false }
    function enableFullscreenPeek()  { barState.fullscreenPeekEnabled = true  }
    function toggleFullscreenPeek()  { barState.fullscreenPeekEnabled = !barState.fullscreenPeekEnabled }
    function silenceOn()     { barState.silenceMode = true  }
    function silenceOff()    { barState.silenceMode = false }
    function silenceToggle() { barState.silenceMode = !barState.silenceMode }
    function toggleWallpaper() { barRoot.wallpaperWindowOpen = !barRoot.wallpaperWindowOpen }
    // Liga/desliga o painel INTEIRO (ver BarState.panelEnabled) — ex:
    //   qs ipc call bar      disable   (desliga a barra)
    //   qs ipc call bar_dock disable   (desliga a dock)
    function enable()  { barState.panelEnabled = true  }
    function disable() { barState.panelEnabled = false }
    function toggleEnabled() { barState.panelEnabled = !barState.panelEnabled }

    // Reload "leve" — destrói e recria só as PanelWindow desta instância
    // (bar OU dock), sem afetar a outra e sem derrubar o processo qs
    // inteiro. Útil pra pegar mudanças de config sem o pkill -9/qs -d
    // manual. Uso: qs ipc call bar reload | qs ipc call bar_dock reload
    function reload() {
      barState.panelEnabled = false
      _reloadTimer.start()
    }
  }

  // Pequeno delay entre disable/enable para garantir que o
  // Repeater/Variants termine de destruir as PanelWindow antigas antes
  // de recriá-las (ver função reload() no IpcHandler "bar"/"bar_dock" acima).
  Timer {
    id: _reloadTimer
    interval: 50
    repeat: false
    onTriggered: barState.panelEnabled = true
  }

  // ── Janela de configuração de wallpaper ──────────────────────────────────
  // Só existe na instância principal ("bar") — uma Dock não precisa de uma
  // segunda janela de config de wallpaper.
  property bool wallpaperWindowOpen: false

  Loader {
    active: barState.instanceId === "bar"
    sourceComponent: Component {
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
    }
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
  readonly property int panelTasks:  9

  // ── Dimensões dos popups (fonte de verdade única) ──────────────────────
  readonly property int popupHVolume: 380
  readonly property int popupHPlayer: 420
  readonly property int popupHClock:  480
  readonly property int popupHQs:     540
  // popupWQs/popupWEditor/popupWNotif — NÃO podem ser literais fixos.
  // BarPopup._applyConfig() (rodado em cada popup individualmente) sobrescreve
  // popup.popupW com o valor de PopupConfig ("QuickSettingsPopup"/"BarEditorPopup"/
  // "NotificationsPopup" → popupW) sempre que existir override — isso quebra
  // silenciosamente qualquer binding estático aqui. Como a Pill lê estas props
  // pra calcular activePopupW (ver PanelWindow "bar" → activePopupW), um literal
  // desincronizado do PopupConfig faz a Pill esticar pro tamanho errado.
  // Lendo via popupConfigRef.get(...) — igual o que BarPopup usa internamente —
  // mantemos as duas fontes sempre iguais (get() é reativo a _dep).
  readonly property int popupWQs:
      popupConfigRef ? popupConfigRef.get("QuickSettingsPopup", "popupW", 320) : 320
  readonly property int popupWEditor:
      popupConfigRef ? popupConfigRef.get("BarEditorPopup", "popupW", 440) : 440
  readonly property int popupHEditor: 560
  readonly property int popupWNotif:
      popupConfigRef ? popupConfigRef.get("NotificationsPopup", "popupW", 360) : 360
  readonly property int popupHNotif:  560
  readonly property int popupWTasks:
      popupConfigRef ? popupConfigRef.get("TasksPopup", "popupW", 300) : 300
  readonly property int popupHTasks:  560
  readonly property int popupHDmenu:  460

  // ── Configuração do dmenu (valores fixos) ────────────────────────────────
  property string _dmenuLaunchCmd: "uwsm app -- {exec}"
  property bool   _dmenuShowIcons: false

  // ── Barra + Popups (um conjunto por tela) ─────────────────────────────
  // model vazio quando panelEnabled=false → nenhuma PanelWindow é criada
  // (nem a de zona, nem a visual): painel completamente desligado.
  Variants {
    model: barState.panelEnabled ? Quickshell.screens : []

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
      // mask vazio → zero área de input capturada por esta superfície.
      // exclusiveZone (layout/reserva de espaço) e input region (clique) são
      // coisas independentes no wlr-layer-shell — reservar espaço não exige
      // capturar clique. Sem isso, mesmo sendo transparente, essa PanelWindow
      // bloqueia todo clique que cai na área reservada (ex: janela em
      // fullscreen por baixo dela), já que por padrão uma PanelWindow captura
      // input em toda a superfície. A barra visual (mais abaixo, id: bar) NÃO
      // recebe esse mask — continua clicável normalmente, só o tema/módulos.
      mask: Region {}
      // pinned força a reserva de zona mesmo com autoHide ligado — mesmo
      // comportamento de ter desligado "Auto-ocultar" manualmente.
      // alwaysVisible NÃO reserva zona, em NENHUM caso (mesmo com autoHide
      // desligado): é uma barra em Overlay que fica por cima de tudo
      // (inclusive fullscreen) sem empurrar/reservar espaço para as
      // janelas — janelas podem ocupar a área por baixo dela livremente.
      exclusiveZone: {
          if (!barState._configReady)                     return 0
          if (barState.alwaysVisible)                      return 0
          if (barState.autoHide && !barState.pinned)        return 0
          if (barState.floating)                           return 0   // ← novo
          return barRoot.themeBarSize
      }
      aboveWindows:  false

      readonly property int _pos: barRoot.position
      readonly property bool _ready: barState._configReady

      // Mesmos anchors que a barra visual — aguarda _configReady para não
      // alocar espaço na posição padrão (3=bottom) antes do JSON carregar.
      anchors.top:    _ready && (_pos === 1 || _pos === 2 || _pos === 4)
      anchors.bottom: _ready && (_pos === 3 || _pos === 2 || _pos === 4)
      anchors.left:   _ready && (_pos === 1 || _pos === 3 || _pos === 4)
      anchors.right:  _ready && (_pos === 1 || _pos === 3 || _pos === 2)

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
    model: barState.panelEnabled ? Quickshell.screens : []

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      color:  "transparent"

      // ── Estado de painéis — isolado por monitor ────────────────────────
      property int activePanel: barRoot.panelNone

      // pillTargetPanel: atualiza no MESMO frame do clique (openPanel), mesmo
      // quando activePanel (que controla os popups de verdade) só é setado um
      // pouco depois — ver _panelOpenDelay abaixo. Isso existe pra resolver
      // o popup "revelando" (BarPopup animationStyle="reveal") ANTES da Pill
      // terminar de esticar: sem esse desacoplamento, activePopupW só mudava
      // no exato instante em que panelOpen virava true, e as duas animações
      // (Pill.Behavior on implicitWidth, 400ms / popup reveal, animDuration)
      // rodavam em paralelo com curvas diferentes — o reveal "estourava"
      // pra fora da Pill ainda estreita nos primeiros frames.
      property int pillTargetPanel: barRoot.panelNone

      // dmenuPanelOpen é escrito pelo DmenuIpc.onPanelVisibleChanged.
      readonly property bool anyPanelOpen:
          pillTargetPanel !== barRoot.panelNone || barRoot.dmenuPanelOpen

      // Largura do popup atualmente aberto — usada pela Pill para expandir.
      // A Pill adiciona popupPillPadding internamente para ficar maior que o popup.
      // Lê pillTargetPanel (não activePanel) — precisa refletir o alvo assim que
      // o clique acontece, não só quando o popup real abrir.
      readonly property int activePopupW: {
        if (barRoot.dmenuPanelOpen)                  return barRoot.dmenuPanelWidth
        if (pillTargetPanel === barRoot.panelNone)   return 0
        if (pillTargetPanel === barRoot.panelEditor) return barRoot.popupWEditor
        if (pillTargetPanel === barRoot.panelQs)     return barRoot.popupWQs
        if (pillTargetPanel === barRoot.panelNotif)  return barRoot.popupWNotif
        return barRoot.themePanelWidth
      }

      // ── Esticamento DIRECIONADO da pill ─────────────────────────────────
      // Por padrão o crescimento da pill é simétrico (as duas bordas se
      // afastam do centro igualmente — ver activePopupW/pillSideMargin).
      // Quando o popup que está abrindo pertence a um módulo que vive num
      // slot lateral (left/right na horizontal, top/bottom na vertical) E
      // esse popup está configurado como "preso à barra" (popupYAnchor:
      // "bar") alinhado PRO MESMO LADO do slot do módulo (popupXAlign ou
      // popupYAlign), o crescimento passa a ser direcionado: só a borda
      // daquele lado se move, o lado oposto fica travado no tamanho natural,
      // e o centro (workspaces) continua sempre centrado na pill inteira —
      // porque centerInnerRow/middleCol usam anchors.centerIn: parent, então
      // reagem sozinhos a qualquer largura/altura final do Item.

      // Mapeia o painel visado para o id do módulo (usado nas listas
      // cfgModulesLeft/Center/Right/Top/Middle/Bottom da Pill).
      function _pillTargetModuleId() {
        if (pillTargetPanel === barRoot.panelPlayer) return "mediaplayer"
        if (pillTargetPanel === barRoot.panelClock)  return "clock"
        if (pillTargetPanel === barRoot.panelQs)     return "quicksettings"
        if (pillTargetPanel === barRoot.panelNotif)  return "notifications"
        if (pillTargetPanel === barRoot.panelVolume) return "volume"
        if (pillTargetPanel === barRoot.panelSink)   return "volume"
        if (pillTargetPanel === barRoot.panelSource) return "volume"
        if (pillTargetPanel === barRoot.panelTasks)  return "tasks"
        return ""
      }

      // Referência à instância BarPopup do painel visado — usada só pra ler
      // popupXAlign/popupYAlign/popupYAnchor (config de alinhamento).
      function _pillTargetPopup() {
        if (pillTargetPanel === barRoot.panelPlayer) return mediaPopup
        if (pillTargetPanel === barRoot.panelClock)  return clockPopup
        if (pillTargetPanel === barRoot.panelQs)     return qsPopup
        if (pillTargetPanel === barRoot.panelNotif)  return notifPopup
        if (pillTargetPanel === barRoot.panelVolume) return volTabbedPopup
        if (pillTargetPanel === barRoot.panelSink)   return volSinkPopup
        if (pillTargetPanel === barRoot.panelSource) return volSourcePopup
        if (pillTargetPanel === barRoot.panelTasks)  return tasksPopup
        return null
      }

      // Slot onde o módulo do painel visado vive, segundo a config ATUAL
      // dos módulos da Pill ("" = módulo no slot central/meio, ou tema sem
      // Pill carregado ainda → sem direção, cai no fallback simétrico).
      readonly property string pillGrowSlot: {
        var modId = _pillTargetModuleId()
        var it = loader.item
        if (!modId || !it) return ""
        if (isVertical) {
          if ((it.cfgModulesTop    || []).indexOf(modId) !== -1) return "top"
          if ((it.cfgModulesBottom || []).indexOf(modId) !== -1) return "bottom"
          return ""
        }
        if ((it.cfgModulesLeft  || []).indexOf(modId) !== -1) return "left"
        if ((it.cfgModulesRight || []).indexOf(modId) !== -1) return "right"
        return ""
      }

      // true só quando o popup está preso à barra (não flutuante) E
      // alinhado exatamente pro mesmo lado do slot do módulo que o abriu.
      // NÃO depende de `pill` — isto é usado tanto pelo truque de margens
      // assimétricas (só faz sentido com pill:true, ver margins.* abaixo)
      // quanto por temas como o Dock, onde cada ilha cresce sozinha e a
      // PanelWindow nunca muda de tamanho.
      readonly property bool pillGrowDirected: {
        if (pillGrowSlot === "") return false
        var p = _pillTargetPopup()
        if (!p || p.popupYAnchor !== "bar") return false
        return isVertical ? (p.popupYAlign === pillGrowSlot)
                           : (p.popupXAlign === pillGrowSlot)
      }

      // Largura/altura "natural" da pill (sem popup aberto) — a âncora fixa
      // usada pelo lado que NÃO deve se mover quando pillGrowDirected.
      readonly property int naturalPillWidth:
          (pill && loader.item && loader.item._naturalW !== undefined)
              ? loader.item._naturalW : effectivePillWidth

      readonly property int naturalPillSideMargin: {
        if (!pill) return 0
        if (isVertical)
          return Math.max(0, Math.floor((screen.height - naturalPillWidth) / 2))
        return Math.max(0, Math.floor((screen.width - naturalPillWidth) / 2))
      }

      // Quanto a pill cresceu além do tamanho natural — é isso que o lado
      // ativo "absorve" sozinho quando o crescimento é direcionado.
      readonly property int _pillExtra: Math.max(0, effectivePillWidth - naturalPillWidth)

      // ── Âncoras de posição pro popupXAlign "group" / "module" ──────────
      // Só fazem sentido pra barra horizontal (top/bottom) — é onde
      // popupXAlign é de facto usado (ver guarda _isVertical no BarPopup).

      // Slot (left/right/center OU top/bottom/middle) onde um modId vive,
      // segundo a config ATUAL dos módulos — igual pillGrowSlot, mas
      // parametrizado por modId em vez de depender do painel visado no
      // momento (usado aqui pra popups individuais, não só o ativo).
      function _slotForModule(modId) {
        var it = loader.item
        if (!it || !modId) return ""
        if (isVertical) {
          if ((it.cfgModulesTop    || []).indexOf(modId) !== -1) return "top"
          if ((it.cfgModulesBottom || []).indexOf(modId) !== -1) return "bottom"
          return "middle"
        }
        if ((it.cfgModulesLeft  || []).indexOf(modId) !== -1) return "left"
        if ((it.cfgModulesRight || []).indexOf(modId) !== -1) return "right"
        return "center"
      }

      function _moduleRefFor(modId) {
        var it = loader.item
        if (!it) return null
        // Preferência: o próprio delegate posicionado pela Row/Column
        // (geometria 100% confiável — width real, x real). Só cai pros
        // refs antigos (widget interno) se o tema não implementar
        // moduleItemAt (retrocompatibilidade).
        if (it.moduleItemAt) {
          var m = it.moduleItemAt(modId)
          if (m) return m
        }
        if (modId === "mediaplayer")   return it.mediaPlayer
        if (modId === "clock")         return it.clock
        if (modId === "tasks")         return it.tasks
        if (modId === "notifications") return it.notifWidget
        if (modId === "quicksettings") return it.qsWidget
        if (modId === "volume")        return it.volumeWidget
        if (modId === "sink")          return it.sinkWidget
        if (modId === "source")        return it.sourceWidget
        return null
      }

      function _groupRefFor(slot) {
        var it = loader.item
        if (!it) return null
        if (slot === "left")   return it.leftGroupItem
        if (slot === "right")  return it.rightGroupItem
        if (slot === "top")    return it.topGroupItem
        if (slot === "bottom") return it.bottomGroupItem
        return null
      }

      // X (espaço de tela) e largura de um Item que vive dentro de
      // loader.item. `loader` preenche `bar` sem margens próprias, então
      // mapear pra loader dá coordenadas locais da janela; somando
      // bar.margins.left (distância real da borda esquerda da TELA até a
      // borda esquerda da JANELA) chegamos em coordenadas de tela — válido
      // pra barras horizontais, único caso onde isso é usado.
      function _screenRectOf(item) {
        if (!item) return { x: 0, w: 0 }
        var pt = item.mapToItem(loader, 0, 0)
        return { x: bar.margins.left + pt.x, w: item.width }
      }

      // Objeto completo de âncora. widgetModId decide qual widget vira o
      // alvo do modo "module" (default = modId) — necessário porque
      // "sink"/"source" não existem como entradas próprias em
      // cfgModulesLeft/Right (ambos vivem dentro do módulo "volume").
      //
      // IMPORTANTE: o lado ("left"/"right") é decidido pela GEOMETRIA REAL
      // do módulo na tela (centro do módulo vs. centro da barra) — não por
      // procurar o modId dentro de cfgModulesLeft/cfgModulesRight. As duas
      // fontes deveriam sempre concordar, mas a geometria é a verdade
      // definitiva: é o que a pessoa vê. Isso também evita qualquer
      // divergência de timing entre a config dos módulos e o layout.
      function _anchorFor(modId, widgetModId) {
        var m = _screenRectOf(_moduleRefFor(widgetModId || modId))
        var barCenterX = bar.margins.left + (bar.implicitWidth || screen.width) / 2
        var moduleCenterX = m.x + m.w / 2
        var side = (m.w > 0 && moduleCenterX >= barCenterX) ? "right" : "left"
        var g = _screenRectOf(_groupRefFor(side))
        return {
          side: side,
          gx: g.x, gw: g.w, mx: m.x, mw: m.w
        }
      }

      // Atraso entre a Pill começar a esticar e o popup realmente abrir
      // (activePanel muda → panelOpen=true → reveal começa). Só entra em
      // ação quando estamos abrindo A PARTIR de nenhum painel aberto — trocar
      // entre painéis já abertos (Pill já no tamanho certo) continua instantâneo.
      // O valor bate com a duração do Behavior on implicitWidth da Pill
      // (ver Pill.qml, 400ms) — depois desse tempo a Pill já terminou (ou
      // está bem perto de terminar) de esticar.
      readonly property int _pillGrowDelay: 260

      Timer {
        id: _panelOpenDelay
        interval: bar._pillGrowDelay
        repeat: false
        onTriggered: bar.activePanel = bar.pillTargetPanel
      }

      // activePopupCloseDuration: duração real da animação de fechamento do
      // popup atualmente visado por pillTargetPanel — lê animDuration direto
      // da instância do popup (cada uma pode ter o próprio valor via
      // PopupConfig), em vez de um número chutado. Usada por _pillShrinkDelay
      // logo abaixo pra saber quanto esperar antes de encolher a Pill/Notch/Dock.
      readonly property int activePopupCloseDuration: {
        if (pillTargetPanel === barRoot.panelSink)   return volSinkPopup.animDuration
        if (pillTargetPanel === barRoot.panelSource) return volSourcePopup.animDuration
        if (pillTargetPanel === barRoot.panelVolume) return volTabbedPopup.animDuration
        if (pillTargetPanel === barRoot.panelPlayer) return mediaPopup.animDuration
        if (pillTargetPanel === barRoot.panelClock)  return clockPopup.animDuration
        if (pillTargetPanel === barRoot.panelTasks)  return tasksPopup.animDuration
        if (pillTargetPanel === barRoot.panelQs)     return qsPopup.animDuration
        if (pillTargetPanel === barRoot.panelEditor) return editorPopup.animDuration
        if (pillTargetPanel === barRoot.panelNotif)  return notifPopup.animDuration
        return 220
      }

      // Atraso simétrico ao _pillGrowDelay, mas pro fechamento: a Pill/Notch/
      // Dock só volta ao tamanho natural DEPOIS que o popup termina de
      // desaparecer (activePopupCloseDuration), em vez de encolher junto —
      // sem isso, em temas com Behavior de largura mais curto que o
      // animDuration do popup (ex: Dock, 180ms vs 220ms padrão), a barra
      // encolhia antes do popup sumir de vista.
      Timer {
        id: _pillShrinkDelay
        repeat: false
        onTriggered: bar.pillTargetPanel = barRoot.panelNone
      }

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

        var wasClosed = (pillTargetPanel === barRoot.panelNone)
        var newPanel  = (pillTargetPanel === panelId) ? barRoot.panelNone : panelId

        if (newPanel === barRoot.panelNone) {
          // Fechando — o popup começa a fechar já (activePanel muda no mesmo
          // frame), mas a Pill/Notch/Dock só encolhe depois que a animação
          // de fechamento do popup termina (ver _pillShrinkDelay). Precisa
          // ler activePopupCloseDuration ANTES de mexer em activePanel —
          // depois disso pillTargetPanel ainda aponta pro painel que estava
          // aberto, então o lookup pega a duração certa.
          _panelOpenDelay.stop()
          _pillShrinkDelay.interval = bar.activePopupCloseDuration
          activePanel = barRoot.panelNone
          _pillShrinkDelay.restart()
        } else {
          pillTargetPanel = newPanel   // Pill reage já, no mesmo frame do clique
          _pillShrinkDelay.stop()      // cancela encolhimento pendente, se houver
          if (wasClosed) {
            // Abrindo do zero — espera a Pill esticar antes de revelar o popup.
            _panelOpenDelay.restart()
          } else {
            // Trocando entre painéis já abertos — Pill já está no tamanho
            // (ou bem perto), não precisa atrasar a troca do popup.
            _panelOpenDelay.stop()
            activePanel = newPanel
          }
        }
      }
      function closeAllPanels() {
        _panelOpenDelay.stop()
        _pillShrinkDelay.interval = bar.activePopupCloseDuration
        activePanel = barRoot.panelNone
        _pillShrinkDelay.restart()
      }

      readonly property bool sinkPanelOpen:   activePanel === barRoot.panelSink
      readonly property bool sourcePanelOpen: activePanel === barRoot.panelSource
      readonly property bool playerPanelOpen: activePanel === barRoot.panelPlayer
      readonly property bool clockPanelOpen:  activePanel === barRoot.panelClock
      readonly property bool tasksPanelOpen:  activePanel === barRoot.panelTasks
      readonly property bool qsPanelOpen:     activePanel === barRoot.panelQs
      readonly property bool editorPanelOpen: activePanel === barRoot.panelEditor
      readonly property bool notifPanelOpen:  activePanel === barRoot.panelNotif
      readonly property bool volumePanelOpen: activePanel === barRoot.panelVolume
      property int  barSize:   barRoot.themeBarSize
      property int  barMargin: barRoot.themeBarMargin
      property bool pill:      barRoot.themePill
      property int  position:  barRoot.position

      // Repassa a PopupConfig DESTA instância (bar ou dock) — os popups só
      // enxergam barRef (esta PanelWindow), então é por aqui que eles chegam
      // na config certa. Ver BarPopup.qml (property _pc).
      readonly property var popupConfigRef: barRoot.popupConfigRef

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

      property bool themeLoaded: barRoot.themeBarSize > 0 && barState._configReady

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

      // Suprime animação quando _configReady muda de false→true.
      // Nesse momento os anchors saltam da posição padrão (3=bottom)
      // para a posição real do JSON — sem este guard, o PanelWindow
      // animaria a transição de posição no startup.
      // Espelha _configReady numa propriedade sem underscore para garantir
      // que o signal Changed seja gerado corretamente pelo Qt.
      property bool cfgReady: barState._configReady
      onCfgReadyChanged: {
        if (cfgReady) {
          animating = false
          Qt.callLater(function() { animating = true })
        }
      }

      Behavior on marginOffset {
        enabled: bar.animating
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
      }

      margins.top: {
        if (position === 1) return barMargin - marginOffset
        if (isVertical && pill) {
          // Direcionado: lado oposto ao slot que cresceu fica travado no
          // valor natural; o lado do slot ativo absorve toda a diferença.
          if (pillGrowDirected && pillGrowSlot === "bottom") return naturalPillSideMargin
          if (pillGrowDirected && pillGrowSlot === "top")
            return Math.max(0, naturalPillSideMargin - _pillExtra)
          return pillSideMargin   // fallback simétrico (popup central/flutuante)
        }
        return barMargin
      }
      margins.bottom: {
        if (position === 3) return barMargin - marginOffset
        if (isVertical && pill) {
          if (pillGrowDirected && pillGrowSlot === "top") return naturalPillSideMargin
          if (pillGrowDirected && pillGrowSlot === "bottom")
            return Math.max(0, naturalPillSideMargin - _pillExtra)
          return pillSideMargin
        }
        return barMargin
      }
      margins.left: {
        if (position === 4) return barMargin - marginOffset
        if (!isVertical && pill) {
          if (pillGrowDirected && pillGrowSlot === "right") return naturalPillSideMargin
          if (pillGrowDirected && pillGrowSlot === "left")
            return Math.max(0, naturalPillSideMargin - _pillExtra)
          return pillSideMargin
        }
        return barMargin
      }
      margins.right: {
        if (position === 2) return barMargin - marginOffset
        if (!isVertical && pill) {
          if (pillGrowDirected && pillGrowSlot === "left") return naturalPillSideMargin
          if (pillGrowDirected && pillGrowSlot === "right")
            return Math.max(0, naturalPillSideMargin - _pillExtra)
          return pillSideMargin
        }
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
      // Layer muda para Overlay quando autohide: barra aparece acima de fullscreen
      // durante o peek. alwaysVisible TAMBÉM força Overlay permanentemente — é o
      // que garante que "sempre visível" realmente signifique sempre visível,
      // inclusive por cima de janelas fullscreen (Top layer é ocultada pelo
      // Hyprland atrás de fullscreen; Overlay não). "pinned" (antigo
      // alwaysVisible) NÃO força Overlay — só impede o auto-hide/peek, então
      // continua podendo ficar atrás de uma janela fullscreen.
      WlrLayershell.layer: (bar.effectiveAutoHide || barState.alwaysVisible || barState.floating) ? WlrLayershell.Overlay : WlrLayershell.Top

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
        // Tag usada pelos tooltips (TooltipSettings.align === "bar"/"section")
        // pra subir a árvore de pais a partir do item hoverado e ancorar
        // neste container — que ocupa a barra inteira deste monitor/painel
        // — em vez de no item específico sob o cursor.
        objectName: "barContentRoot"
        anchors.fill: parent
        source: barState.config.configLoaded
          ? (Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml")
          : ""

        // ── Config de tooltip DESTE painel ──────────────────────────────
        // Antes isso era escrito num singleton global (TooltipSettings)
        // só pela instância "bar" — a Dock (2ª instância de Bar.qml) nunca
        // conseguia impor a própria config, e os tooltips hoverados nela
        // sempre obedeciam à config da Barra. Agora cada painel expõe a
        // própria config aqui, direto no seu barContentRoot; os 7
        // tooltips (singletons globais) resolvem qual config usar subindo
        // a árvore de pais a partir do item hoverado até este Loader —
        // ou seja, cada painel passa a ter tooltip independente de verdade.
        // TooltipSettings.* continua existindo só como fallback (caso o
        // item hoverado não esteja dentro de nenhum barContentRoot).
        property bool   cfgTooltipEnabled:  barState.config.tooltipEnabled
        property int    cfgTooltipMinWidth: barState.config.tooltipMinWidth
        property int    cfgTooltipMaxWidth: barState.config.tooltipMaxWidth
        property string cfgTooltipAlign:    barState.config.tooltipAlign
        property int    cfgTooltipOffset:   barState.config.tooltipOffset

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

        // Expande/contrai a pill de acordo com o popup aberto
        Binding { target: loader.item; property: "activePopupW";  value: bar.activePopupW;  when: loader.item !== null; restoreMode: Binding.RestoreNone }
        Binding { target: loader.item; property: "anyPanelOpen";  value: bar.anyPanelOpen;  when: loader.item !== null; restoreMode: Binding.RestoreNone }

        // Direção do esticamento (slot + se está "attached" no mesmo lado
        // do módulo) — genérico, qualquer tema pode usar. Guardado por
        // "in (loader.item||{})" pra não quebrar temas que não declaram
        // essas props (ex: Default/Minimal/Notch sem esse conceito).
        Binding { target: loader.item; property: "activePopupSlot";     value: bar.pillGrowSlot;     when: loader.item !== null && "activePopupSlot" in (loader.item || {}) }
        Binding { target: loader.item; property: "activePopupDirected"; value: bar.pillGrowDirected; when: loader.item !== null && "activePopupDirected" in (loader.item || {}) }

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

          // Tasks
          if (item.tasks) {
            barRoot.barTasksRef = item.tasks
            if ("tasksContent" in item.tasks)
              item.tasks.tasksContent = tasksPopup.tasksContentRef
            if (!barRoot.tasksContentRef)
              barRoot.tasksContentRef = tasksPopup.tasksContentRef
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

      // ── Bindings reativos para props do Notch ──────────────────────────
      // _applyConfig roda só no onLoaded. Pra que o slider de raio/padding
      // do Notch funcione em tempo real, precisamos de Bindings vivos que
      // propagam barState.config.X → loader.item.X sempre que o config muda.
      // ignoreUnknownSignals/when: loader.item protege os outros temas.
      // SEM fallback "|| default": 0 é valor válido (zerar raio/inclinação).
      // barState.config.X já vem resolvido corretamente pela cascata do
      // BarConfig (override → tema → BarSchema default).
      Binding { target: loader.item; property: "notchRadius";   value: barState.config.notchRadius;   when: loader.item !== null && "notchRadius"   in (loader.item || {}) }
      Binding { target: loader.item; property: "concaveRadius"; value: barState.config.concaveRadius; when: loader.item !== null && "concaveRadius" in (loader.item || {}) }
      Binding { target: loader.item; property: "lobePadH";      value: barState.config.lobePadH;      when: loader.item !== null && "lobePadH"      in (loader.item || {}) }
      Binding { target: loader.item; property: "notchTaper";    value: barState.config.notchTaper;    when: loader.item !== null && "notchTaper"    in (loader.item || {}) }
      Binding { target: loader.item; property: "popupPillPadding"; value: barState.config.popupPillPadding; when: loader.item !== null && "popupPillPadding" in (loader.item || {}) }
      Binding { target: loader.item; property: "pillExpandForPopups"; value: barState.config.pillExpandForPopups; when: loader.item !== null && "pillExpandForPopups" in (loader.item || {}) }
      Binding { target: loader.item; property: "notchPopupPadding"; value: barState.config.notchPopupPadding; when: loader.item !== null && "notchPopupPadding" in (loader.item || {}) }
      Binding { target: loader.item; property: "notchExpandForPopups"; value: barState.config.notchExpandForPopups; when: loader.item !== null && "notchExpandForPopups" in (loader.item || {}) }

      // ── Bindings reativos de arredondamento ─────────────────────────────
      // Uma por tema — só a que existir de fato em loader.item (checagem
      // "in") é aplicada; as outras três simplesmente não casam com nenhuma
      // prop do item carregado e ficam inertes. Mesmo padrão/racional do
      // Notch acima: SEM fallback "|| default", 0 é valor válido (cantos
      // 100% quadrados).
      Binding { target: loader.item; property: "barRadius";    value: barState.config.barRadius;    when: loader.item !== null && "barRadius"    in (loader.item || {}) }
      Binding { target: loader.item; property: "chipRadius";   value: barState.config.chipRadius;   when: loader.item !== null && "chipRadius"   in (loader.item || {}) }
      Binding { target: loader.item; property: "islandRadius"; value: barState.config.islandRadius; when: loader.item !== null && "islandRadius" in (loader.item || {}) }
      Binding { target: loader.item; property: "handleRadius"; value: barState.config.handleRadius; when: loader.item !== null && "handleRadius" in (loader.item || {}) }

      // ── FIX-BARSIZE: barSize (e só barSize — barMargin não é lido por
      // nenhum tema internamente, só afeta a PanelWindow via themeBarMargin,
      // então esse aqui está OK) até então só alimentava
      // barRoot.themeBarSize (tamanho da PanelWindow) — nunca era escrito de
      // volta em loader.item.barSize. Cada tema declara sua PRÓPRIA prop
      // "barSize" (Bento/Dock/etc.) com um default hardcoded (ex.: 32 no
      // Bento) que, sem este Binding, nunca via o valor real configurado
      // pelo usuário — os chips/ilhas eram desenhados com o tamanho errado
      // (maior que a PanelWindow), causando corte/overflow que parecia
      // "canto não arredondado". Mesmo padrão dos Bindings de arredondamento
      // acima: SEM fallback "|| default", valor já vem resolvido pela
      // cascata do BarConfig, e "barSize" já está em _unscaledProps (não
      // deve ser multiplicado por moduleScale).
      Binding { target: loader.item; property: "barSize"; value: barState.config.barSize; when: loader.item !== null && "barSize" in (loader.item || {}) }

      // Props que NUNCA devem ser multiplicadas por moduleScale, mesmo que o
      // nome bata com o padrão abaixo (ex.: "concaveRadius"/"notchRadius"
      // terminam em "Radius"). Estas já têm Binding{} própria (linhas acima)
      // que lê barState.config.X sem passar por _set() nas atualizações ao
      // vivo — se _set() as escalasse, ficariam escaladas só no load inicial
      // (via _applyConfig) e SEM escala nas mudanças ao vivo do slider,
      // um comportamento inconsistente. Ficam de fora por completo.
      readonly property var _unscaledProps: [
        "notchRadius", "concaveRadius", "lobePadH", "notchTaper",
        "barRadius", "chipRadius", "islandRadius", "handleRadius",
        "barSize"
      ]

      // Reconhece props "de tamanho" dos módulos (ícones, fontes, dots,
      // artwork, paddings/spacing internos) para aplicar o multiplicador
      // global de escala (barState.config.moduleScale). Convenção: qualquer
      // prop cujo nome termine em Size/Radius/Spacing/PaddingH/PaddingV.
      function _isScalable(prop) {
        if (bar._unscaledProps.indexOf(prop) !== -1) return false
        return /Size$|Radius$|Spacing$|PaddingH$|PaddingV$/.test(prop)
      }

      function _set(prop, value) {
        if (!loader.item || !(prop in loader.item)) return
        // Guard: durante _recalcBar() no BarConfig, onModuleScaleChanged
        // (abaixo) dispara de forma REENTRANTE assim que moduleScale é
        // setado, e pode chamar _applyConfig() antes de alguma outra prop
        // do mesmo recalc ter sido atribuída ainda (ex: primeiríssimo boot).
        // Nesse instante value chega undefined — ignora e deixa a PRÓXIMA
        // chamada de _applyConfig (já com tudo assentado) escrever o valor
        // certo, em vez de propagar undefined pro item do tema.
        if (value === undefined) return
        var v = value
        if (typeof v === "number" && bar._isScalable(prop)) {
          v = Math.round(v * barState.config.moduleScale)
        }
        loader.item[prop] = v
      }

      function _applyConfig(item) {
        // Notch — seta diretamente as props de aparência do tema.
        // SEM fallback "|| default": 0 é valor válido.
        _set("notchRadius",   barState.config.notchRadius)
        _set("concaveRadius", barState.config.concaveRadius)
        _set("lobePadH",      barState.config.lobePadH)
        _set("notchTaper",    barState.config.notchTaper)
        _set("popupPillPadding", barState.config.popupPillPadding)
        _set("pillExpandForPopups", barState.config.pillExpandForPopups)
        _set("notchPopupPadding", barState.config.notchPopupPadding)
        _set("notchExpandForPopups", barState.config.notchExpandForPopups)

        // Arredondamento — idem: cada _set() só escreve se a prop existir
        // de fato em loader.item, então é seguro chamar as 4 sempre.
        _set("barRadius",    barState.config.barRadius)
        _set("chipRadius",   barState.config.chipRadius)
        _set("islandRadius", barState.config.islandRadius)
        _set("handleRadius", barState.config.handleRadius)

        // FIX-BARSIZE: ver comentário completo no Binding{} equivalente,
        // logo acima na declaração do loader. Sem isso, o tema ficava preso
        // no barSize hardcoded do próprio QML (ex.: 32 no Bento).
        _set("barSize", barState.config.barSize)

        // workspaces
        _set("cfgWsStyle",          barState.config.wsStyle)
        _set("cfgWsIconsSort",      barState.config.wsIconsSort)
        _set("cfgWsIconMonochrome", barState.config.wsIconMonochrome)
        _set("cfgWsIconSpacing",    barState.config.wsIconSpacing)
        _set("cfgWsIconSize",       barState.config.wsIconSize)
        _set("cfgWsShowNumber",     barState.config.wsShowNumber)
        _set("cfgWsNumberBgEnabled",   barState.config.wsNumberBgEnabled)
        _set("cfgWsNumberBgRadius",    barState.config.wsNumberBgRadius)
        _set("cfgWsNumberBgPaddingH",  barState.config.wsNumberBgPaddingH)
        _set("cfgWsNumberBgPaddingV",  barState.config.wsNumberBgPaddingV)
        _set("cfgWsNumberSpacing",     barState.config.wsNumberSpacing)
        _set("cfgWsBgOpacity",      barState.config.wsBgOpacity)
        _set("cfgWsBgPaddingH",     barState.config.wsBgPaddingH)
        _set("cfgWsBgPaddingV",     barState.config.wsBgPaddingV)
        _set("cfgWsBgBorderWidth",  barState.config.wsBgBorderWidth)
        _set("cfgWsDotSize",        barState.config.wsDotSize)
        _set("cfgWsFontSize",       barState.config.wsFontSize)
        _set("cfgWsShowAddButton",  barState.config.wsShowAddButton)
        _set("cfgWsShowTooltip",    barState.config.wsShowTooltip)
        _set("cfgWsSpacing",        barState.config.wsSpacing)

        // ── Workspaces — Focus (reveal) ──────────────────────────────────
        // Faltavam aqui: só existiam no Connections.onXxxChanged (linha ~950),
        // que só dispara numa MUDANÇA em tempo real. No cold-start o valor já
        // nasce correto (lido do JSON) e nunca "muda" — então o Connections
        // nunca dispara e o tema fica preso no default hardcoded do QML.
        _set("cfgWsRevealMode",           barState.config.wsRevealMode)
        _set("cfgWsHoverRevealDelayMs",   barState.config.wsHoverRevealDelayMs)
        _set("cfgWsClickCollapseMode",    barState.config.wsClickCollapseMode)
        _set("cfgWsClickRevealTimeoutMs", barState.config.wsClickRevealTimeoutMs)

        // ── Workspaces — Scroll ────────────────────────────────────────────
        // Mesmo bug do bloco acima (só existiam no Connections live).
        _set("cfgWsScrollEnabled", barState.config.wsScrollEnabled)
        _set("cfgWsScrollAction",  barState.config.wsScrollAction)
        _set("cfgWsScrollInvert",  barState.config.wsScrollInvert)
        // workspace ativa
        _set("cfgWsBgColorActive",       barState.config.paletteWsBgColorActive)
        _set("cfgWsBgOpacityActive",     barState.config.wsBgOpacityActive)
        _set("cfgWsBgBorderColorActive", barState.config.paletteWsBgBorderColorActive)
        _set("cfgWsBgBorderWidthActive", barState.config.wsBgBorderWidthActive)
        _set("cfgWsBgPaddingHActive",    barState.config.wsBgPaddingHActive)
        _set("cfgWsBgPaddingVActive",    barState.config.wsBgPaddingVActive)
        _set("cfgWsBgRadiusActive",      barState.config.wsBgRadiusActive)
        _set("colWsBgActive",            barState.config.paletteWsBgColorActive)

        // ── Workspaces — fundo do grupo / ativo(toggle) / inativo (novo) ────
        _set("cfgWsBgGroupEnabled",  barState.config.wsBgGroupEnabled)
        _set("cfgWsBgActiveEnabled", barState.config.wsBgActiveEnabled)
        _set("cfgWsBgInactiveEnabled",     barState.config.wsBgInactiveEnabled)
        _set("cfgWsBgColorInactive",       barState.config.paletteWsBgColorInactive)
        _set("cfgWsBgOpacityInactive",     barState.config.wsBgOpacityInactive)
        _set("cfgWsBgBorderColorInactive", barState.config.paletteWsBgBorderColorInactive)
        _set("cfgWsBgBorderWidthInactive", barState.config.wsBgBorderWidthInactive)
        _set("cfgWsBgPaddingHInactive",    barState.config.wsBgPaddingHInactive)
        _set("cfgWsBgPaddingVInactive",    barState.config.wsBgPaddingVInactive)
        _set("cfgWsBgRadiusInactive",      barState.config.wsBgRadiusInactive)

        // ── Workspaces — animação do indicador (dots/número/hybrid) ────────
        _set("cfgWsIndicatorAnimStyle",    barState.config.wsIndicatorAnimStyle)
        _set("cfgWsIndicatorAnimDuration", barState.config.wsIndicatorAnimDuration)

        // ── Workspaces — botão "+" ───────────────────────────────────────
        _set("cfgWsAddButtonBorderEnabled", barState.config.wsAddButtonBorderEnabled)
        _set("cfgWsAddButtonBgEnabled",     barState.config.wsAddButtonBgEnabled)
        _set("cfgWsAddButtonBgOpacity",     barState.config.wsAddButtonBgOpacity)
        // termina em "Size" -> passa por _isScalable() e é multiplicado pelo
        // moduleScale global automaticamente, igual wsIconSize/wsDotSize.
        _set("cfgWsAddButtonSize",          barState.config.wsAddButtonSize)
        _set("cfgWsAddButtonPaddingH",      barState.config.wsAddButtonPaddingH)
        _set("cfgWsAddButtonPaddingV",      barState.config.wsAddButtonPaddingV)
        _set("cfgWsAddButtonColor",         barState.config.paletteWsAddButtonColor)
        _set("cfgWsAddButtonBgColor",       barState.config.paletteWsAddButtonBgColor)

        // mediaPlayer
        _set("cfgMpShowText",       barState.config.mpShowText)
        _set("cfgMpTextStatic",      barState.config.mpTextStatic)
        _set("cfgMpTextMode",        barState.config.mpTextMode)
        _set("cfgMpScrollSpeed",     barState.config.mpScrollSpeed)
        _set("cfgMpScrollPauseMs",   barState.config.mpScrollPauseMs)
        _set("cfgMpScrollWidth",     barState.config.mpScrollWidth)
        _set("cfgMpVolumeStep",      barState.config.mpVolumeStep)
        _set("cfgMpArtworkSize",     barState.config.mpArtworkSize)
        _set("cfgMpArtworkRadius",   barState.config.mpArtworkRadius)
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
        _set("cfgMpPlayerPriority",  barState.config.mpPlayerPriority)
        _set("cfgMpIdleInhibit",     barState.config.mpIdleInhibit)
        // MediaPlayer.qml expõe fontScale (não termina em "Size", então
        // _isScalable() não a multiplica de novo — passa o moduleScale cru).
        _set("cfgMpFontScale",       barState.config.moduleScale)
        // volume
        _set("cfgVolShowSink",   barState.config.volShowSink   !== undefined ? barState.config.volShowSink   : true)
        _set("cfgVolShowSource", barState.config.volShowSource !== undefined ? barState.config.volShowSource : true)
        _set("cfgVolMaxVol",     barState.config.volMaxVol)
        _set("cfgVolTextColor",  barState.config.paletteVolText)
        _set("cfgVolDimColor",   barState.config.paletteVolDim)
        _set("cfgVolAccent",     barState.config.paletteVolAccent)
        _set("cfgVolMuted",      barState.config.paletteVolMuted)
        _set("cfgVolProgress",   barState.config.paletteVolProgress)
        _set("cfgVolFontScale",  barState.config.moduleScale)
        // quicksettings
        _set("cfgQsTextColor",   barState.config.paletteQsText)
        _set("cfgQsDimColor",    barState.config.paletteQsDim)
        _set("cfgQsAccent",      barState.config.paletteQsAccent)
        _set("cfgQsFontScale",   barState.config.moduleScale)
        // notifications
        _set("cfgNotifTextColor", barState.config.paletteNotifText)
        _set("cfgNotifDimColor",  barState.config.paletteNotifDim)
        _set("cfgNotifAccent",    barState.config.paletteNotifAccent)
        _set("cfgNotifMuted",     barState.config.paletteNotifMuted)
        _set("cfgNotifFontScale", barState.config.moduleScale)
        // clock
        _set("cfgClkTextColor",    barState.config.paletteClkTextColor)
        _set("cfgClkDimColor",     barState.config.paletteClkDimColor)
        _set("cfgClkAccent",       barState.config.paletteClkAccentColor)
        _set("cfgClkDismissDelay", barState.config.clkDismissDelayMs)
        _set("cfgClkFontScale",    barState.config.moduleScale)
        // dmenu
        _set("cfgDmenuTextColor",     barState.config.paletteDmenuText)
        _set("cfgDmenuDimColor",      barState.config.paletteDmenuDim)
        _set("cfgDmenuAccent",        barState.config.paletteDmenuAccent)
        _set("cfgDmenuDisplayMode",   barState.config.dmenuDisplayMode)
        _set("cfgDmenuIconGlyph",     barState.config.dmenuIconGlyph)
        _set("cfgDmenuEmptyText",     barState.config.dmenuEmptyText)
        _set("cfgDmenuTitleMaxWidth", barState.config.dmenuTitleMaxWidth)
        _set("cfgDmenuOpenMode",      barState.config.dmenuOpenMode)
        _set("cfgDmenuFontScale",     barState.config.moduleScale)
        _set("cfgDmenuWindowIconSize", barState.config.dmenuWindowIconSize)
        _set("cfgDmenuTextStatic",     barState.config.dmenuTextStatic)
        _set("cfgDmenuScrollSpeed",    barState.config.dmenuScrollSpeed)
        _set("cfgDmenuScrollPauseMs",  barState.config.dmenuScrollPauseMs)
        _set("cfgDmenuShowWorkspace",     barState.config.dmenuShowWorkspace)
        _set("cfgDmenuWorkspacePosition", barState.config.dmenuWorkspacePosition)
        _set("cfgDmenuWorkspaceFormat",   barState.config.dmenuWorkspaceFormat)
        _set("cfgDmenuWorkspaceChipWidth", barState.config.dmenuWorkspaceChipWidth)
        _set("cfgDmenuWorkspaceIconMap",   barState.config.dmenuWorkspaceIconMap)
        _set("cfgTasksTextColor",  barState.config.paletteTasksTextColor)
        _set("cfgTasksDimColor",   barState.config.paletteTasksDimColor)
        _set("cfgTasksAccent",     barState.config.paletteTasksAccentColor)
        _set("cfgTasksFontScale",  barState.config.moduleScale)
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
        _set("colWsNumber",         barState.config.paletteWsNumberColor)
        _set("colWsNumberActive",   barState.config.paletteWsNumberColorActive)
        _set("colWsNumberBg",       barState.config.paletteWsNumberBgColor)
        _set("colWsNumberBgActive", barState.config.paletteWsNumberBgColorActive)
      }

      // ── Propagação runtime → tema ──────────────────────────────────────
      Connections {
        target: barState.config

        // barSize/barMargin — afetam o PanelWindow diretamente
        function onBarSizeChanged()   { barRoot.themeBarSize   = barState.config.barSize   }
        function onBarMarginChanged() { barRoot.themeBarMargin = barState.config.barMargin }
        // moduleScale — multiplicador global (ícones/fontes/dots/artwork/
        // paddings dos módulos). Não tem Binding própria no tema: os
        // onXxxChanged individuais abaixo só reagem quando A PRÓPRIA prop
        // muda, então ao mexer no slider de escala precisamos reaplicar tudo
        // de uma vez para tudo ser multiplicado pelo novo valor.
        function onModuleScaleChanged() { bar._applyConfig(loader.item) }
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
        function onPaletteTextChanged()                 { bar._set("colText",           barState.config.paletteText)                  }
        function onPaletteTextDimChanged()              { bar._set("colTextDim",        barState.config.paletteTextDim)               }
        function onPaletteAccentChanged()               { bar._set("colAccent",         barState.config.paletteAccent)                }
        function onPaletteAccentBgChanged()             { bar._set("colAccentBg",       barState.config.paletteAccentBg)              }
        function onPaletteAccentTextChanged()           { bar._set("colAccentText",     barState.config.paletteAccentText)            }
        function onPaletteWsBgColorChanged()            { bar._set("colWsBg",           barState.config.paletteWsBgColor)             }
        function onPaletteWsBgBorderColorChanged()      { bar._set("colWsBorder",       barState.config.paletteWsBgBorderColor)       }
        function onPaletteWsDotColorChanged()           { bar._set("colWsDot",          barState.config.paletteWsDotColor)            }
        function onPaletteWsDotActiveColorChanged()     { bar._set("colWsDotActive",    barState.config.paletteWsDotActiveColor)      }
        function onPaletteWsDotOccupiedColorChanged()   { bar._set("colWsDotOccupied",  barState.config.paletteWsDotOccupiedColor)    }
        function onPaletteWsDotUrgentColorChanged()     { bar._set("colWsDotUrgent",    barState.config.paletteWsDotUrgentColor)      }
        function onPaletteWsIconMonoColorChanged()      { bar._set("colIconMono",       barState.config.paletteWsIconMonoColor)       }
        function onPaletteWsIconMonoColorActiveChanged(){ bar._set("colIconMonoActive", barState.config.paletteWsIconMonoColorActive) }
        function onPaletteWsNumberColorChanged()         { bar._set("colWsNumber",         barState.config.paletteWsNumberColor)         }
        function onPaletteWsNumberColorActiveChanged()   { bar._set("colWsNumberActive",   barState.config.paletteWsNumberColorActive)   }
        function onPaletteWsNumberBgColorChanged()       { bar._set("colWsNumberBg",       barState.config.paletteWsNumberBgColor)       }
        function onPaletteWsNumberBgColorActiveChanged() { bar._set("colWsNumberBgActive", barState.config.paletteWsNumberBgColorActive) }
        // ── Workspaces — Focus (reveal) ──────────────────────────────────
        function onWsRevealModeChanged() {
            bar._set("cfgWsRevealMode", barState.config.wsRevealMode)
        }
        function onWsHoverRevealDelayMsChanged() {
            bar._set("cfgWsHoverRevealDelayMs", barState.config.wsHoverRevealDelayMs)
        }
        function onWsClickCollapseModeChanged() {
            bar._set("cfgWsClickCollapseMode", barState.config.wsClickCollapseMode)
        }
        function onWsClickRevealTimeoutMsChanged() {
            bar._set("cfgWsClickRevealTimeoutMs", barState.config.wsClickRevealTimeoutMs)
        }

        // ── Workspaces — Scroll ────────────────────────────────────────────
        function onWsScrollEnabledChanged() {
            bar._set("cfgWsScrollEnabled", barState.config.wsScrollEnabled)
        }
        function onWsScrollActionChanged() {
            bar._set("cfgWsScrollAction", barState.config.wsScrollAction)
        }
        function onWsScrollInvertChanged() {
            bar._set("cfgWsScrollInvert", barState.config.wsScrollInvert)
        }
        // volume — per-module (override individual tem prioridade sobre paleta global)
        function onPaletteVolTextChanged()     { bar._set("cfgVolTextColor",   barState.config.paletteVolText)     }
        function onPaletteVolDimChanged()      { bar._set("cfgVolDimColor",    barState.config.paletteVolDim)      }
        function onPaletteVolAccentChanged()   { bar._set("cfgVolAccent",      barState.config.paletteVolAccent)   }
        function onPaletteVolMutedChanged()    { bar._set("cfgVolMuted",       barState.config.paletteVolMuted)    }
        function onPaletteVolProgressChanged() { bar._set("cfgVolProgress",    barState.config.paletteVolProgress) }
        function onVolShowSinkChanged()        { bar._set("cfgVolShowSink",    barState.config.volShowSink)        }
        function onVolShowSourceChanged()      { bar._set("cfgVolShowSource",  barState.config.volShowSource)      }
        function onVolMaxVolChanged()          { bar._set("cfgVolMaxVol",      barState.config.volMaxVol)          }
        // quicksettings — per-module
        function onPaletteQsTextChanged()      { bar._set("cfgQsTextColor",    barState.config.paletteQsText)     }
        function onPaletteQsDimChanged()       { bar._set("cfgQsDimColor",     barState.config.paletteQsDim)      }
        function onPaletteQsAccentChanged()    { bar._set("cfgQsAccent",       barState.config.paletteQsAccent)   }
        // notifications — per-module
        function onPaletteNotifTextChanged()   { bar._set("cfgNotifTextColor", barState.config.paletteNotifText)  }
        function onPaletteNotifDimChanged()    { bar._set("cfgNotifDimColor",  barState.config.paletteNotifDim)   }
        function onPaletteNotifAccentChanged() { bar._set("cfgNotifAccent",    barState.config.paletteNotifAccent) }
        function onPaletteNotifMutedChanged()  { bar._set("cfgNotifMuted",     barState.config.paletteNotifMuted)  }
        // workspaces
        function onWsStyleChanged()          { bar._set("cfgWsStyle",          barState.config.wsStyle)          }
        function onWsIconsSortChanged()      { bar._set("cfgWsIconsSort",      barState.config.wsIconsSort)      }
        function onWsIconMonochromeChanged() { bar._set("cfgWsIconMonochrome", barState.config.wsIconMonochrome) }
        function onWsIconSpacingChanged()    { bar._set("cfgWsIconSpacing",    barState.config.wsIconSpacing)    }
        function onWsIconSizeChanged()       { bar._set("cfgWsIconSize",       barState.config.wsIconSize)       }
        function onWsShowNumberChanged()     { bar._set("cfgWsShowNumber",     barState.config.wsShowNumber)     }
        function onWsNumberBgEnabledChanged()  { bar._set("cfgWsNumberBgEnabled",  barState.config.wsNumberBgEnabled)  }
        function onWsNumberBgRadiusChanged()   { bar._set("cfgWsNumberBgRadius",   barState.config.wsNumberBgRadius)   }
        function onWsNumberBgPaddingHChanged() { bar._set("cfgWsNumberBgPaddingH", barState.config.wsNumberBgPaddingH) }
        function onWsNumberBgPaddingVChanged() { bar._set("cfgWsNumberBgPaddingV", barState.config.wsNumberBgPaddingV) }
        function onWsNumberSpacingChanged()    { bar._set("cfgWsNumberSpacing",    barState.config.wsNumberSpacing)    }
        function onWsBgOpacityChanged()      { bar._set("cfgWsBgOpacity",      barState.config.wsBgOpacity)      }
        function onWsBgPaddingHChanged()     { bar._set("cfgWsBgPaddingH",     barState.config.wsBgPaddingH)     }
        function onWsBgPaddingVChanged()     { bar._set("cfgWsBgPaddingV",     barState.config.wsBgPaddingV)     }
        function onWsBgBorderWidthChanged()  { bar._set("cfgWsBgBorderWidth",  barState.config.wsBgBorderWidth)  }
        function onWsDotSizeChanged()        { bar._set("cfgWsDotSize",        barState.config.wsDotSize)        }
        function onWsFontSizeChanged()       { bar._set("cfgWsFontSize",       barState.config.wsFontSize)       }
        function onWsShowAddButtonChanged()  { bar._set("cfgWsShowAddButton",  barState.config.wsShowAddButton)  }
        function onWsShowTooltipChanged()    { bar._set("cfgWsShowTooltip",    barState.config.wsShowTooltip)    }
        function onWsSpacingChanged()        { bar._set("cfgWsSpacing",        barState.config.wsSpacing)        }
        // workspace ativa
        function onPaletteWsBgColorActiveChanged()       { bar._set("cfgWsBgColorActive",      barState.config.paletteWsBgColorActive)
                                                           bar._set("colWsBgActive",            barState.config.paletteWsBgColorActive)       }
        function onWsBgOpacityActiveChanged()            { bar._set("cfgWsBgOpacityActive",     barState.config.wsBgOpacityActive)            }
        function onPaletteWsBgBorderColorActiveChanged() { bar._set("cfgWsBgBorderColorActive", barState.config.paletteWsBgBorderColorActive) }
        function onWsBgBorderWidthActiveChanged()        { bar._set("cfgWsBgBorderWidthActive", barState.config.wsBgBorderWidthActive)        }
        function onWsBgPaddingHActiveChanged()           { bar._set("cfgWsBgPaddingHActive",    barState.config.wsBgPaddingHActive)           }
        function onWsBgPaddingVActiveChanged()           { bar._set("cfgWsBgPaddingVActive",    barState.config.wsBgPaddingVActive)           }
        function onWsBgRadiusActiveChanged()             { bar._set("cfgWsBgRadiusActive",      barState.config.wsBgRadiusActive)             }

        // fundo do grupo / ativo (toggle) / inativo (novo)
        function onWsBgGroupEnabledChanged()  { bar._set("cfgWsBgGroupEnabled",  barState.config.wsBgGroupEnabled)  }
        function onWsBgActiveEnabledChanged() { bar._set("cfgWsBgActiveEnabled", barState.config.wsBgActiveEnabled) }
        function onWsBgInactiveEnabledChanged()          { bar._set("cfgWsBgInactiveEnabled",     barState.config.wsBgInactiveEnabled)     }
        function onPaletteWsBgColorInactiveChanged()     { bar._set("cfgWsBgColorInactive",       barState.config.paletteWsBgColorInactive) }
        function onWsBgOpacityInactiveChanged()          { bar._set("cfgWsBgOpacityInactive",     barState.config.wsBgOpacityInactive)     }
        function onPaletteWsBgBorderColorInactiveChanged() { bar._set("cfgWsBgBorderColorInactive", barState.config.paletteWsBgBorderColorInactive) }
        function onWsBgBorderWidthInactiveChanged()      { bar._set("cfgWsBgBorderWidthInactive", barState.config.wsBgBorderWidthInactive) }
        function onWsBgPaddingHInactiveChanged()         { bar._set("cfgWsBgPaddingHInactive",    barState.config.wsBgPaddingHInactive)    }
        function onWsBgPaddingVInactiveChanged()         { bar._set("cfgWsBgPaddingVInactive",    barState.config.wsBgPaddingVInactive)    }
        function onWsBgRadiusInactiveChanged()           { bar._set("cfgWsBgRadiusInactive",      barState.config.wsBgRadiusInactive)      }

        // animação do indicador
        function onWsIndicatorAnimStyleChanged()    { bar._set("cfgWsIndicatorAnimStyle",    barState.config.wsIndicatorAnimStyle)    }
        function onWsIndicatorAnimDurationChanged() { bar._set("cfgWsIndicatorAnimDuration", barState.config.wsIndicatorAnimDuration) }

        // botão "+"
        function onWsAddButtonBorderEnabledChanged()  { bar._set("cfgWsAddButtonBorderEnabled", barState.config.wsAddButtonBorderEnabled) }
        function onWsAddButtonBgEnabledChanged()      { bar._set("cfgWsAddButtonBgEnabled",     barState.config.wsAddButtonBgEnabled)     }
        function onWsAddButtonBgOpacityChanged()      { bar._set("cfgWsAddButtonBgOpacity",     barState.config.wsAddButtonBgOpacity)     }
        function onWsAddButtonSizeChanged()           { bar._set("cfgWsAddButtonSize",          barState.config.wsAddButtonSize)          }
        function onWsAddButtonPaddingHChanged()       { bar._set("cfgWsAddButtonPaddingH",      barState.config.wsAddButtonPaddingH)      }
        function onWsAddButtonPaddingVChanged()       { bar._set("cfgWsAddButtonPaddingV",      barState.config.wsAddButtonPaddingV)      }
        function onPaletteWsAddButtonColorChanged()   { bar._set("cfgWsAddButtonColor",         barState.config.paletteWsAddButtonColor)  }
        function onPaletteWsAddButtonBgColorChanged() { bar._set("cfgWsAddButtonBgColor",       barState.config.paletteWsAddButtonBgColor) }

        // mediaPlayer
        function onMpShowTextChanged()               { bar._set("cfgMpShowText",       barState.config.mpShowText)            }
        function onMpTextModeChanged()               { bar._set("cfgMpTextMode",        barState.config.mpTextMode)            }
        function onMpScrollSpeedChanged()            { bar._set("cfgMpScrollSpeed",     barState.config.mpScrollSpeed)         }
        function onMpScrollPauseMsChanged()          { bar._set("cfgMpScrollPauseMs",   barState.config.mpScrollPauseMs)       }
        function onMpScrollWidthChanged()            { bar._set("cfgMpScrollWidth",     barState.config.mpScrollWidth)         }
        function onMpTextStaticChanged()             { bar._set("cfgMpTextStatic",      barState.config.mpTextStatic)          }
        function onMpVolumeStepChanged()             { bar._set("cfgMpVolumeStep",      barState.config.mpVolumeStep)          }
        function onMpArtworkSizeChanged()            { bar._set("cfgMpArtworkSize",     barState.config.mpArtworkSize)         }
        function onMpArtworkRadiusChanged()          { bar._set("cfgMpArtworkRadius",   barState.config.mpArtworkRadius)       }
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
        function onMpPlayerPriorityChanged()         { bar._set("cfgMpPlayerPriority",  barState.config.mpPlayerPriority)         }
        function onMpIdleInhibitChanged()            { bar._set("cfgMpIdleInhibit",     barState.config.mpIdleInhibit)            }
        // clock
        function onPaletteClkTextColorChanged()   { bar._set("cfgClkTextColor",    barState.config.paletteClkTextColor)   }
        function onPaletteClkDimColorChanged()     { bar._set("cfgClkDimColor",     barState.config.paletteClkDimColor)    }
        function onPaletteClkAccentColorChanged()  { bar._set("cfgClkAccent",       barState.config.paletteClkAccentColor) }
        function onClkDismissDelayMsChanged()      { bar._set("cfgClkDismissDelay", barState.config.clkDismissDelayMs)     }
        // dmenu
        function onPaletteDmenuTextChanged()       { bar._set("cfgDmenuTextColor",     barState.config.paletteDmenuText)     }
        function onPaletteDmenuDimChanged()        { bar._set("cfgDmenuDimColor",      barState.config.paletteDmenuDim)      }
        function onPaletteDmenuAccentChanged()     { bar._set("cfgDmenuAccent",        barState.config.paletteDmenuAccent)   }
        function onDmenuDisplayModeChanged()       { bar._set("cfgDmenuDisplayMode",   barState.config.dmenuDisplayMode)     }
        function onDmenuIconGlyphChanged()         { bar._set("cfgDmenuIconGlyph",     barState.config.dmenuIconGlyph)       }
        function onDmenuEmptyTextChanged()         { bar._set("cfgDmenuEmptyText",     barState.config.dmenuEmptyText)       }
        function onDmenuTitleMaxWidthChanged()     { bar._set("cfgDmenuTitleMaxWidth", barState.config.dmenuTitleMaxWidth)   }
        function onDmenuOpenModeChanged()          { bar._set("cfgDmenuOpenMode",      barState.config.dmenuOpenMode)        }
        function onDmenuWindowIconSizeChanged()    { bar._set("cfgDmenuWindowIconSize", barState.config.dmenuWindowIconSize) }
        function onDmenuTextStaticChanged()        { bar._set("cfgDmenuTextStatic",     barState.config.dmenuTextStatic)     }
        function onDmenuScrollSpeedChanged()       { bar._set("cfgDmenuScrollSpeed",    barState.config.dmenuScrollSpeed)    }
        function onDmenuScrollPauseMsChanged()     { bar._set("cfgDmenuScrollPauseMs",  barState.config.dmenuScrollPauseMs)  }
        function onDmenuShowWorkspaceChanged()      { bar._set("cfgDmenuShowWorkspace",      barState.config.dmenuShowWorkspace)      }
        function onDmenuWorkspacePositionChanged()  { bar._set("cfgDmenuWorkspacePosition",  barState.config.dmenuWorkspacePosition)  }
        function onDmenuWorkspaceFormatChanged()    { bar._set("cfgDmenuWorkspaceFormat",    barState.config.dmenuWorkspaceFormat)    }
        function onDmenuWorkspaceChipWidthChanged() { bar._set("cfgDmenuWorkspaceChipWidth", barState.config.dmenuWorkspaceChipWidth) }
        function onDmenuWorkspaceIconMapChanged()   { bar._set("cfgDmenuWorkspaceIconMap",   barState.config.dmenuWorkspaceIconMap)   }
        function onPaletteTasksTextColorChanged()  { bar._set("cfgTasksTextColor",  barState.config.paletteTasksTextColor)   }
        function onPaletteTasksDimColorChanged()   { bar._set("cfgTasksDimColor",   barState.config.paletteTasksDimColor)    }
        function onPaletteTasksAccentColorChanged(){ bar._set("cfgTasksAccent",     barState.config.paletteTasksAccentColor) }
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
        function onBarTasksRefChanged() {
          var tk = barRoot.barTasksRef
          if (tk && "tasksContent" in tk)
            tk.tasksContent = tasksPopup.tasksContentRef
          // Mesmo raciocínio do clock acima: sem guard, sempre reaponta.
          barRoot.tasksContentRef = tasksPopup.tasksContentRef
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
        function onTasksPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelTasks);  panelCooldown.restart() }
        }
        function onQuickSettingsPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelQs);     panelCooldown.restart() }
        }
        function onNotificationsPanelRequested() {
          if (!panelCooldown.running) { bar.openPanel(barRoot.panelNotif);  panelCooldown.restart() }
        }
        // Dmenu não é um BarPopup interno — é o launcher externo gerenciado
        // por DmenuIpc (shell.qml). Só repassa o clique pra ele, no modo
        // configurado (cfgDmenuOpenMode / aba "Dmenu" do editor).
        function onDmenuRequested() {
          if (!panelCooldown.running) {
            var mode = barRoot.configRef ? barRoot.configRef.dmenuOpenMode : "drun"
            var ipc  = barRoot.dmenuIpcRef
            if (ipc) {
              // openNative() só fecha sozinho se dmenuConfig.dmenuToggle
              // estiver ligado (preferência global, pensada pro atalho de
              // teclado) — o clique do botão precisa ser toggle sempre,
              // então checamos panelVisible/currentNativeMode nós mesmos
              // (é exatamente pra isso que a DmenuIpc expõe as duas).
              if (ipc.panelVisible && ipc.currentNativeMode === mode) {
                ipc._closeAll()
              } else {
                ipc.openNative(mode)
              }
            }
            panelCooldown.restart()
          }
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
          if (loader.item.tasks) {
            barRoot.barTasksRef = loader.item.tasks
            if ("tasksContent" in loader.item.tasks)
              loader.item.tasks.tasksContent = tasksPopup.tasksContentRef
            if (!barRoot.tasksContentRef)
              barRoot.tasksContentRef = tasksPopup.tasksContentRef
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

      // ── Watchdog de re-sincronização do hyprMonitor ────────────────────
      // Após bloquear/desbloquear a tela, o Wayland/Hyprland passa por um
      // estado transitório sem nenhum output real ("no outputs — creating
      // placeholder screen", monitor "FALLBACK" no log) antes de re-
      // estabilizar. Se a Variants reagir a essa flutuação momentânea de
      // Quickshell.screens e recriar esta PanelWindow bem nesse instante, o
      // Component.onCompleted logo abaixo pode rodar ANTES de
      // Hyprland.monitors.values já refletir o monitor real de novo —
      // hyprMonitor fica preso em null e a Connections acima nunca mais
      // corrige sozinha, porque ela só reage a MUDANÇA da lista, e se a
      // lista não mudar de novo depois (já está "estável" do ponto de vista
      // do Hyprland), não há novo evento. Sintoma: fullscreen peek (e
      // cursorAtEdge, que também depende de hyprMonitor.x/y) param de
      // funcionar até reiniciar o shell. Esta é uma rede de segurança:
      // enquanto hyprMonitor estiver null, tenta re-resolver periodicamente.
      function _resyncHyprMonitor() {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
          var m = Hyprland.monitors.values[i]
          if (m.name === bar.screen.name) {
            console.log("[FS] hyprMonitor watchdog RECUPEROU monitor " + m.name)
            bar.hyprMonitor = m
            // hyprMonitor ficou null por um tempo → toda a cadeia de detecção
            // de fullscreen (que depende dele) pode estar desatualizada —
            // força uma verificação completa assim que ele voltar.
            bar._verifyMode = false
            bar._monProc.running = true
            return
          }
        }
      }

      Timer {
        id: _hyprMonitorWatchdog
        interval: 2000
        repeat:   true
        running:  bar.hyprMonitor === null
        onTriggered: bar._resyncHyprMonitor()
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
      property int _activeWsId: (hyprMonitor && hyprMonitor.activeWorkspace) ? hyprMonitor.activeWorkspace.id : -1
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
        // alwaysVisible e pinned têm prioridade máxima — a barra nunca
        // auto-oculta, nem por cursor (autoHide) nem por fullscreen peek.
        // (a diferença entre os dois está na layer — ver WlrLayershell.layer acima)
        if (barState.alwaysVisible) return false
        if (barState.pinned) return false
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

        anchorGroupSide: bar._anchorFor("volume", "sink").side
        anchorGroupX:    bar._anchorFor("volume", "sink").gx
        anchorGroupW:    bar._anchorFor("volume", "sink").gw
        anchorModuleX:   bar._anchorFor("volume", "sink").mx
        anchorModuleW:   bar._anchorFor("volume", "sink").mw

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

        anchorGroupSide: bar._anchorFor("volume", "source").side
        anchorGroupX:    bar._anchorFor("volume", "source").gx
        anchorGroupW:    bar._anchorFor("volume", "source").gw
        anchorModuleX:   bar._anchorFor("volume", "source").mx
        anchorModuleW:   bar._anchorFor("volume", "source").mw

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

        anchorGroupSide: bar._anchorFor("volume").side
        anchorGroupX:    bar._anchorFor("volume").gx
        anchorGroupW:    bar._anchorFor("volume").gw
        anchorModuleX:   bar._anchorFor("volume").mx
        anchorModuleW:   bar._anchorFor("volume").mw

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

        anchorGroupSide: bar._anchorFor("mediaplayer").side
        anchorGroupX:    bar._anchorFor("mediaplayer").gx
        anchorGroupW:    bar._anchorFor("mediaplayer").gw
        anchorModuleX:   bar._anchorFor("mediaplayer").mx
        anchorModuleW:   bar._anchorFor("mediaplayer").mw

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Clock ──────────────────────────────────────────────────────────
      ClockModule.ClockPopup {
        id: clockPopup
        barRef: bar

        popupW: barRoot.themePanelWidth
        popupH: barRoot.popupHClock

        panelOpen: bar.clockPanelOpen

        anchorGroupSide: bar._anchorFor("clock").side
        anchorGroupX:    bar._anchorFor("clock").gx
        anchorGroupW:    bar._anchorFor("clock").gw
        anchorModuleX:   bar._anchorFor("clock").mx
        anchorModuleW:   bar._anchorFor("clock").mw

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Tasks (Tarefas + Hábitos) ───────────────────────────────────────
      TasksModule.TasksPopup {
        id: tasksPopup
        barRef: bar

        popupW: barRoot.popupWTasks
        popupH: barRoot.popupHTasks

        panelOpen: bar.tasksPanelOpen

        anchorGroupSide: bar._anchorFor("tasks").side
        anchorGroupX:    bar._anchorFor("tasks").gx
        anchorGroupW:    bar._anchorFor("tasks").gw
        anchorModuleX:   bar._anchorFor("tasks").mx
        anchorModuleW:   bar._anchorFor("tasks").mw

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Quick Settings ─────────────────────────────────────────────────
      QsModule.QuickSettingsPopup {
        id: qsPopup
        barRef: bar

        popupW: barRoot.popupWQs
        popupH: barRoot.popupHQs

        panelOpen: bar.qsPanelOpen
        notifService: barRoot.notifService

        anchorGroupSide: bar._anchorFor("quicksettings").side
        anchorGroupX:    bar._anchorFor("quicksettings").gx
        anchorGroupW:    bar._anchorFor("quicksettings").gw
        anchorModuleX:   bar._anchorFor("quicksettings").mx
        anchorModuleW:   bar._anchorFor("quicksettings").mw

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

        anchorGroupSide: bar._anchorFor("notifications").side
        anchorGroupX:    bar._anchorFor("notifications").gx
        anchorGroupW:    bar._anchorFor("notifications").gw
        anchorModuleX:   bar._anchorFor("notifications").mx
        anchorModuleW:   bar._anchorFor("notifications").mw

        onCloseRequested: bar.closeAllPanels()
      }

      // ── Dmenu — gerenciado por DmenuIpc em shell.qml ──────────────────────

    } // PanelWindow bar
  } // Variants
}
