import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

PanelWindow {
  id: root

  // PowerMenuConfig injetada pelo shell.qml (mesmo padrão de bar.configRef /
  // dmenuIpc.configRef). Fica nullable pra o componente não quebrar se for
  // usado sem essa integração — nesse caso cai nos defaultEntries do config
  // OU, se nem config for passado, num fallback mínimo hardcoded.
  property var config: null

  readonly property var _entries: root.config
    ? root.config.getEntries()
    : [
        { id: "lock",     text: "\uf023", label: "Travar",    keybind: "l", action: "loginctl lock-session", confirm: false, danger: false },
        { id: "logout",   text: "\uf08b", label: "Sair",      keybind: "e", action: "hyprctl dispatch exit", confirm: true,  danger: false },
        { id: "reboot",   text: "\uf021", label: "Reiniciar", keybind: "r", action: "systemctl reboot",      confirm: true,  danger: true  },
        { id: "shutdown", text: "\uf011", label: "Desligar",  keybind: "d", action: "systemctl poweroff",    confirm: true,  danger: true  },
      ]

  property bool _open:         false
  property int  _focused:      -1
  // Índice aguardando confirmação (segundo Enter/clique). -1 = nenhum.
  property int  _pendingIndex: -1

  visible: _alive
  color:   "transparent"

  // ── Geometria ─────────────────────────────────────────────────────────────
  // Modo tela cheia (fullscreen=true, padrão): a superfície cobre a tela
  // toda, como sempre foi — dim de fundo cobrindo tudo, card desenhado
  // centralizado por cima (PowerMenuPanel cuida disso).
  //
  // Modo janela (fullscreen=false): a superfície layer-shell passa a ter o
  // tamanho REAL do conteúdo (PowerMenuPanel.contentWidth/contentHeight,
  // que o próprio card calcula a partir dos itens) e é ancorada num ponto
  // configurável da tela (windowPosition) — igual ao padrão já usado pelo
  // ConfigWindow.qml (anchors nos 4 lados + margins calculadas pra
  // posicionar uma superfície de tamanho fixo dentro da tela).
  readonly property bool   _fullscreenMode: root.config ? root.config.get("fullscreen", true) : true
  readonly property string _windowPosition: root.config ? root.config.get("windowPosition", "center") : "center"
  readonly property int    _marginX:        root.config ? root.config.get("windowMarginX", 56) : 56
  readonly property int    _marginY:        root.config ? root.config.get("windowMarginY", 56) : 56

  readonly property int _contentW: panel ? panel.contentWidth  : 0
  readonly property int _contentH: panel ? panel.contentHeight : 0

  readonly property int _winW: root._fullscreenMode ? (root.screen ? root.screen.width  : 0) : Math.max(1, root._contentW)
  readonly property int _winH: root._fullscreenMode ? (root.screen ? root.screen.height : 0) : Math.max(1, root._contentH)

  // mapa windowPosition → eixo "start" (perto da borda 0) / "end" (perto da
  // borda oposta) / "center", pros dois eixos independentemente
  readonly property var _posAxis: ({
    "center":       { h: "center", v: "center" },
    "top":          { h: "center", v: "start"  },
    "bottom":       { h: "center", v: "end"    },
    "left":         { h: "start",  v: "center" },
    "right":        { h: "end",    v: "center" },
    "top-left":     { h: "start",  v: "start"  },
    "top-right":    { h: "end",    v: "start"  },
    "bottom-left":  { h: "start",  v: "end"    },
    "bottom-right": { h: "end",    v: "end"    },
  })
  readonly property var _axis: root._posAxis[root._windowPosition] || root._posAxis["center"]

  // Calcula (margemInicial, margemFinal) de um eixo pra posicionar uma caixa
  // de `size` dentro de `screenSize`, ancorada em "start"/"end"/"center".
  function _axisMargins(size, screenSize, mode, gap) {
    if (mode === "start") return [gap, Math.max(0, screenSize - size - gap)]
    if (mode === "end")   return [Math.max(0, screenSize - size - gap), gap]
    var c = Math.max(0, Math.floor((screenSize - size) / 2))
    return [c, c]
  }

  readonly property var _hMargins: root.screen
    ? root._axisMargins(root._winW, root.screen.width,  root._fullscreenMode ? "center" : root._axis.h, root._marginX)
    : [0, 0]
  readonly property var _vMargins: root.screen
    ? root._axisMargins(root._winH, root.screen.height, root._fullscreenMode ? "center" : root._axis.v, root._marginY)
    : [0, 0]

  implicitWidth:  root._winW
  implicitHeight: root._winH

  anchors.top:    true
  anchors.bottom: true
  anchors.left:   true
  anchors.right:  true

  margins.left:   root._fullscreenMode ? 0 : root._hMargins[0]
  margins.right:  root._fullscreenMode ? 0 : root._hMargins[1]
  margins.top:    root._fullscreenMode ? 0 : root._vMargins[0]
  margins.bottom: root._fullscreenMode ? 0 : root._vMargins[1]

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  // ── Fechar ao perder o foco — só faz sentido no modo janela: no modo
  // tela cheia já existe o MouseArea no dim de fundo (PowerMenuPanel) pra
  // fechar ao clicar fora, e a superfície cobre a tela toda mesmo (não tem
  // "fora" de verdade pro Hyprland detectar). No modo janela a superfície
  // agora é do tamanho do card, então clicar fora dela é clicar em outra
  // janela/desktop — é isso que o HyprlandFocusGrab detecta. ───────────────
  HyprlandFocusGrab {
    windows: [root]
    active:  root._open && !root._fullscreenMode &&
      (root.config ? root.config.get("closeOnClickOutside", true) : true)
    onCleared: { if (root._open) root._open = false }
  }

  // ── Animação de entrada/saída (mesmo padrão do ConfigWindow) ─────────────
  property real _anim:    0.0
  property bool _alive:   false
  property bool _closing: false

  readonly property int _panelAnimMs: root.config ? root.config.get("panelAnimMs", 200) : 200

  on_OpenChanged: {
    if (_open) {
      _closing = false; _alive = true
      _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
      openAnim.duration = root._panelAnimMs
      openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
    } else {
      _pendingIndex = -1
      _closing = true; openAnim.stop()
      closeAnim.duration = Math.round(root._panelAnimMs * 0.9)
      closeAnim.from = _anim; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.interval = closeAnim.duration + 240
      _safetyTimer.restart()
    }
  }

  NumberAnimation { id: openAnim;  target: root; property: "_anim"; duration: 200; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: root; property: "_anim"; duration: 180; easing.type: Easing.OutCubic
    onStopped: { if (root._closing) _unmapTimer.restart() } }
  Timer { id: _unmapTimer;  interval: 17;  onTriggered: { if (root._closing) { root._alive = false; root._closing = false } } }
  Timer { id: _safetyTimer; interval: 440; onTriggered: { if (!root._open) { root._alive = false; root._closing = false; _unmapTimer.stop() } } }

  // ── Timer de auto-cancelamento da confirmação pendente ────────────────────
  Timer {
    id: pendingTimer
    interval: root.config ? root.config.get("confirmTimeoutMs", 4000) : 4000
    running: false
    onTriggered: root._pendingIndex = -1
  }

  // ── Fluxo central de ativação — usado tanto pelo mouse (Panel) quanto
  // pelo teclado (Tab/Enter/letra abaixo). Garante que os dois caminhos
  // respeitem a MESMA regra de confirmação. ─────────────────────────────────
  function requestAction(idx) {
    if (idx < 0 || idx >= root._entries.length) return
    var entry = root._entries[idx]
    var needsConfirm = entry.confirm === true &&
      (root.config ? root.config.get("confirmDestructive", true) : true)

    if (needsConfirm && root._pendingIndex !== idx) {
      root._pendingIndex = idx
      root._focused      = idx
      pendingTimer.restart()
      return
    }

    root._pendingIndex = -1
    root._open = false
    runner.command = ["bash", "-c", entry.action]
    runner.running  = true
  }

  // ── IPC ───────────────────────────────────────────────────────────────────
  IpcHandler {
    target: "powerMenu"

    function open() {
      root._focused      = -1
      root._pendingIndex = -1
      root._open         = true
    }

    function close() {
      root._open = false
    }

    function toggle() {
      if (root._open) {
        root._open = false
      } else {
        root._focused      = -1
        root._pendingIndex = -1
        root._open         = true
      }
    }
  }

  // ── Captura de teclado (precisa ser Item filho — PanelWindow não é Item) ──
  Item {
    id: keyCapture
    anchors.fill: parent
    focus: root._open

    Keys.onPressed: (event) => {
      if (!root._open) return

      if (event.key === Qt.Key_Escape) {
        if (root._pendingIndex !== -1) {
          // 1º ESC cancela a confirmação pendente; 2º ESC fecha o menu
          root._pendingIndex = -1
        } else {
          root._open = false
        }
        event.accepted = true; return
      }
      if (event.key === Qt.Key_Tab) {
        root._pendingIndex = -1
        var n = root._entries.length
        if (n > 0) root._focused = (root._focused + 1) % n
        event.accepted = true; return
      }
      if (event.key === Qt.Key_Backtab) {
        root._pendingIndex = -1
        var n2 = root._entries.length
        if (n2 > 0) root._focused = (root._focused - 1 + n2) % n2
        event.accepted = true; return
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
        if (root._focused >= 0 && root._focused < root._entries.length) {
          root.requestAction(root._focused)
        }
        event.accepted = true; return
      }
      var key = event.text.toLowerCase()
      if (key.length === 1) {
        for (var i = 0; i < root._entries.length; i++) {
          var kb = root._entries[i].keybind
          if (kb && kb.toLowerCase() === key) {
            root.requestAction(i)
            event.accepted = true; return
          }
        }
      }
    }

    PowerMenuPanel {
      id: panel
      anchors.fill: parent
      entries:      root._entries
      focused:      root._focused
      pendingIndex: root._pendingIndex
      config:       root.config
      anim:         root._anim

      onFocusIndexChanged: (idx) => { root._focused = idx; root._pendingIndex = -1 }
      onActivateRequested: (idx) => { root.requestAction(idx) }
      onCloseRequested:    { root._open = false }
    }
  }

  Process {
    id: runner
    running: false
    onExited: (code) => { if (code !== 0) console.warn("[PowerMenu] saiu com código", code) }
  }
}
