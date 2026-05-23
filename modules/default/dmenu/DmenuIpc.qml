import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// ── DmenuIpc ──────────────────────────────────────────────────────────────────
// Servidor IPC para scripts externos. Standalone — não conflita com o
// IpcHandler "dmenu" do Bar (que gerencia drun/run/window).
//
// Em shell.qml:
//   DmenuModule.DmenuIpc {
//     screen:      Quickshell.screens[0]
//     panelAnchor: "top-center"   // "top-center"|"top-left"|"top-right"|"center"|"bottom-center"
//     showIcons:   true
//     colorAccent: Colors.primary
//     // ...
//   }
//
// No terminal (qualquer script):
//   echo -e "a\nb\nc" | qs-dmenu --prompt "Título"
//   cmd_que_lista     | qs-dmenu -p "Prompt" -s " → " -l "SEÇÃO"

Item {
  id: root

  // ── Configuração pública ──────────────────────────────────────────────────
  property var    screen:      Quickshell.screens[0]
  property string panelAnchor: "top-center"
  property int    edgeMargin:  65
  property int    sideMargin:  40
  property bool   showIcons:   true

  // ── Cores ─────────────────────────────────────────────────────────────────
  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  // ── Estado interno ────────────────────────────────────────────────────────
  property bool   _busy:    false
  property string _fifoOut: ""

  // ── Servidor Python ───────────────────────────────────────────────────────
  Process {
    id: serverProc
    running: true

    property string _scriptPath: {
      var url = Qt.resolvedUrl("./qs-dmenu-server.py").toString()
      return url.replace(/^file:\/\//, "")
    }

    command: ["python3", _scriptPath]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: (line) => {
        var t = line.trim()
        if (t === "") return
        var msg
        try { msg = JSON.parse(t) } catch(e) { return }

        if (msg.ready === true) {
          root._fifoOut = msg.fifo_out || ""
          console.log("DmenuIpc: pronto —", msg.sock)
          return
        }

        if (root._busy) { root._respond(null); return }
        root._open(msg)
      }
    }

    onRunningChanged: {
      if (!running) { root._busy = false; restartTimer.start() }
    }
  }

  Timer {
    id: restartTimer; interval: 1500; repeat: false
    onTriggered: serverProc.running = true
  }

  // ── Abre o painel ─────────────────────────────────────────────────────────
  function _open(req) {
    var entries = req.entries || []
    if (entries.length === 0) { _respond(null); return }

    _busy = true

    ipcPanel.scriptEntries  = entries
    ipcPanel.scriptPrompt   = req.prompt || ">"
    ipcPanel.scriptLabel    = req.label  || "SCRIPT"
    ipcPanel.scriptSep      = req.sep    || ""
    ipcPanel.scriptCallback = function(selected) { root._respond(selected) }
    ipcPanel.mode           = "script"
    ipcPanel.open()
  }

  // ── Resposta via FIFO ─────────────────────────────────────────────────────
  Process {
    id: responseProc
    running: false
    onExited: root._busy = false
  }

  function _respond(selected) {
    if (_fifoOut === "") { _busy = false; return }
    var payload = JSON.stringify({
      selected: (selected !== null && selected !== undefined) ? selected : null
    })
    responseProc.command = ["bash", "-c",
      "printf '%s\\n' " + JSON.stringify(payload) + " > " + JSON.stringify(_fifoOut)]
    responseProc.running = true
  }

  // ── Painel ────────────────────────────────────────────────────────────────
  DmenuPanel {
    id: ipcPanel

    screen:      root.screen
    panelAnchor: root.panelAnchor
    edgeMargin:  root.edgeMargin
    sideMargin:  root.sideMargin
    showIcons:   root.showIcons

    colorPanelBg:  root.colorPanelBg
    colorText:     root.colorText
    colorTextDim:  root.colorTextDim
    colorAccent:   root.colorAccent
    colorSelected: root.colorSelected
    colorDivider:  root.colorDivider
    colorInputBg:  root.colorInputBg
  }
}
