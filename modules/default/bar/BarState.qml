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

  property bool   autoHide:     true
  property string currentTheme: "Pill"
  property int    position:     2 

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
    function onThemeChanged()    { state.currentTheme = barConfig.theme    }
    function onAutoHideChanged() { state.autoHide     = barConfig.autoHide }
    function onPositionChanged() { state.position     = barConfig.position }
    function onModulesUpdated()  { state.modulesUpdated()                  }
  }

  onCurrentThemeChanged: barConfig.theme    = currentTheme
  onAutoHideChanged:     barConfig.autoHide = autoHide
  onPositionChanged:     barConfig.position = position

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
      var themes = ["Default", "Minimal", "Pill"]
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
}
