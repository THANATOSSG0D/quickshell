import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

QtObject {
  id: state

  readonly property int edgeThreshold: 5
  readonly property int hideDelayMs:   300

  property int cursorX: 0
  property int cursorY: 0

  // Valores iniciais — serão sobrescritos pelo BarConfig assim que o JSON carregar.
  // NÃO colocar valores hardcoded aqui que conflitem com o que está salvo no JSON;
  // o guard _configReady evita que esses defaults sejam escritos de volta no BarConfig.
  property bool   autoHide:     false
  property bool   silenceMode:  false   // suprime OSD, toasts e autohide fullscreen
  property string currentTheme: "Pill"
  property int    position:     3

  // Guard: só propaga mudanças do BarState → BarConfig depois que o BarConfig
  // já carregou do JSON. Evita que os defaults acima sobrescrevam o JSON salvo.
  property bool _configReady: false

  // ── Fullscreen peek ──────────────────────────────────────────────────
  property bool fullscreenPeekEnabled: true
  signal fullscreenChanged(bool state)
  // Emitido quando workspace ou foco muda — a janela fullscreen visível
  // pode ter mudado sem emitir evento fullscreen (ex: troca de workspace)
  signal workspaceOrFocusChanged()

  property var _fsConn: Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "fullscreen") {
        console.log("[FS] rawEvent fullscreen | data:", event.data)
        state.fullscreenChanged(event.data === "1")
      } else if (event.name === "workspace"    ||
                 event.name === "focusedmon"   ||
                 event.name === "activewindow" ||
                 event.name === "movewindow")
        state.workspaceOrFocusChanged()
    }
  }

  property var config: BarConfig { id: barConfig }

  // ── Módulos re-expostos como propriedades diretas ────────────────────
  // Bindings em Bar.qml usam barState.modulesLeft etc. em vez de
  // barState.config.modulesLeft porque o QML NÃO rastreia mudanças em
  // propriedades acessadas através de uma property var (barState.config é
  // property var). Expor via propriedades diretas do BarState torna os
  // Bindings completamente reativos: quando barConfig.modulesLeft muda
  // (JSON carregado, editor salvo), barState.modulesLeft atualiza,
  // e o Binding no Bar.qml propaga para o Pill automaticamente.
  property var modulesLeft:   barConfig.modulesLeft
  property var modulesCenter: barConfig.modulesCenter
  property var modulesRight:  barConfig.modulesRight
  property var modulesTop:    barConfig.modulesTop
  property var modulesMiddle: barConfig.modulesMiddle
  property var modulesBottom: barConfig.modulesBottom

  // Relay de modulesUpdated: BarConfig.modulesUpdated() não pode ser escutado
  // via Connections{target:barState.config} em contextos filhos (PopupWindow,
  // Variants) porque BarConfig é Item filho de QtObject passado como property var.
  // BarState re-emite o signal — barState é QtObject direto, sempre acessível.
  signal modulesUpdated()

  property var _configConn: Connections {
    target: barConfig
    function onThemeChanged()    {
      state.currentTheme = barConfig.theme
      state._configReady = true
    }
    function onAutoHideChanged() {
      state.autoHide     = barConfig.autoHide
      state._configReady = true
    }
    function onSilenceModeChanged() {
      state.silenceMode  = barConfig.silenceMode
      state._configReady = true
    }
    function onPositionChanged() {
      state.position     = barConfig.position
      state._configReady = true
    }
    function onModulesUpdated()  { state.modulesUpdated() }
    // Fallback: quando o BarConfig termina de carregar o JSON (_ready→true),
    // sincroniza tudo de uma vez e libera o guard — garante que funciona mesmo
    // quando os valores do JSON são idênticos aos defaults (signals não disparam)
    function on_ReadyChanged() {
      if (!barConfig._ready) return
      state.currentTheme = barConfig.theme
      state.autoHide     = barConfig.autoHide
      state.silenceMode  = barConfig.silenceMode
      state.position     = barConfig.position
      state._configReady = true
    }
  }

  // NOTA: autoHide e position agora são readonly no BarConfig (calculados
  // por tema via get("bar", key)) — não dá pra atribuir direto, então
  // propagamos via set("bar", key, value), que grava no tema atual.
  onCurrentThemeChanged: if (_configReady) barConfig.theme       = currentTheme
  onAutoHideChanged:     if (_configReady) barConfig.set("bar", "autoHide", autoHide)
  onSilenceModeChanged:  if (_configReady) barConfig.silenceMode = silenceMode
  onPositionChanged:     if (_configReady) barConfig.set("bar", "position", position)

  property var _proc: Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: SplitParser {
      onRead: data => {
        var parts = data.split(",")
        if (parts.length === 2) {
          state.cursorX = parseInt(parts[0].trim())
          state.cursorY = parseInt(parts[1].trim())
        }
      }
    }
  }

  property var _timer: Timer {
    interval: 100
    repeat:   true
    running:  true
    onTriggered: cursorProc.running = true
  }

  property var _toggleShortcut: GlobalShortcut {
    name:        "toggleBar"
    description: "Toggle auto-hide da barra"
    onPressed:   state.autoHide = !state.autoHide
  }

  property var _themeShortcut: GlobalShortcut {
    name:        "nextTheme"
    description: "Próximo tema do bar"
    onPressed: {
      var themes = ["Default", "Minimal", "Pill", "Dock", "Aurora", "Bento"]
      var idx    = themes.indexOf(state.currentTheme)
      state.currentTheme = themes[(idx + 1) % themes.length]
    }
  }

  property var _positionShortcut: GlobalShortcut {
    name:        "nextBarPosition"
    description: "Próxima posição do bar (top→right→bottom→left)"
    onPressed: {
      // 1=top 2=right 3=bottom 4=left — cicla apenas as posições horizontais/verticais
      var positions = [1, 2, 3, 4]
      var idx       = positions.indexOf(state.position)
      state.position = positions[(idx + 1) % positions.length]
    }
  }

  // Sinal para abrir o editor — escutado pelo Bar.qml via Connections
  signal editorRequested()

  property var _editorShortcut: GlobalShortcut {
    name:        "openBarEditor"
    description: "Abrir editor visual da barra"
    onPressed:   state.editorRequested()
  }

  property var _silenceShortcut: GlobalShortcut {
    name:        "toggleSilence"
    description: "Ativar/desativar modo Silence (sem OSD, sem toasts, sem autohide fullscreen)"
    onPressed:   state.silenceMode = !state.silenceMode
  }
}
