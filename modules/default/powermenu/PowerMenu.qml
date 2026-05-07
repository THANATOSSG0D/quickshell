import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

PanelWindow {
  id: root

  readonly property string layoutPath: Quickshell.shellDir + "/modules/default/powermenu/layout.json"

  property bool _open:    false
  property var  _entries: []
  property int  _focused: -1

  visible: _open
  color:   "transparent"

  anchors.top:    true
  anchors.bottom: true
  anchors.left:   true
  anchors.right:  true

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  // ── Leitura do JSON ───────────────────────────────────────────────────────
  FileView {
    id: layoutView
    path: root.layoutPath
    watchChanges: true

    // onTextChanged NÃO dispara no boot — lemos manualmente no onCompleted
    onTextChanged: { root._parseJson() }
  }

  Component.onCompleted: {
    // leitura inicial forçada — o FileView já tem o conteúdo mas não emitiu signal
    Qt.callLater(root._parseJson)
  }

  function _parseJson() {
    var content = layoutView.text()
    if (!content || content.trim() === "") return
    try {
      var parsed = JSON.parse(content)
      root._entries = parsed
      console.log("[PowerMenu] layout carregado:", parsed.length, "entradas")
    } catch(e) {
      console.error("[PowerMenu] Erro ao parsear layout.json:", e)
    }
  }

  // ── IPC ───────────────────────────────────────────────────────────────────
  IpcHandler {
    target: "powerMenu"

    function open() {
      root._focused = -1
      root._open    = true
    }

    function close() {
      root._open = false
    }

    function toggle() {
      if (root._open) root._open = false
      else { root._focused = -1; root._open = true }
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
        root._open = false; event.accepted = true; return
      }
      if (event.key === Qt.Key_Tab) {
        var n = root._entries.length
        if (n > 0) root._focused = (root._focused + 1) % n
        event.accepted = true; return
      }
      if (event.key === Qt.Key_Backtab) {
        var n2 = root._entries.length
        if (n2 > 0) root._focused = (root._focused - 1 + n2) % n2
        event.accepted = true; return
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
        if (root._focused >= 0 && root._focused < root._entries.length) {
          root._open = false
          runner.command = ["bash", "-c", root._entries[root._focused].action]
          runner.running = true
        }
        event.accepted = true; return
      }
      var key = event.text.toLowerCase()
      if (key.length === 1) {
        for (var i = 0; i < root._entries.length; i++) {
          var kb = root._entries[i].keybind
          if (kb && kb.toLowerCase() === key) {
            root._open = false
            runner.command = ["bash", "-c", root._entries[i].action]
            runner.running = true
            event.accepted = true; return
          }
        }
      }
    }

    PowerMenuPanel {
      anchors.fill: parent
      entries:      root._entries
      focused:      root._focused

      onFocusIndexChanged: (idx) => { root._focused = idx }
      onActionRequested:   (cmd) => { root._open = false; runner.command = ["bash", "-c", cmd]; runner.running = true }
      onCloseRequested:    { root._open = false }
    }
  }

  Process {
    id: runner
    running: false
    onExited: (code) => { if (code !== 0) console.warn("[PowerMenu] saiu com código", code) }
  }
}
