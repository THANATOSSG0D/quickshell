import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// ── Dmenu ─────────────────────────────────────────────────────────────────────
// Singleton global. Instancie uma vez em shell.qml.
// Gerencia múltiplos modos (drun, run, window) e expõe open(mode, screen).
//
// Uso em shell.qml:
//
//   Dmenu {
//     id: globalDmenu
//     colorAccent: Colors.primary
//     // etc.
//   }
//
// Abrir de um atalho / botão:
//   globalDmenu.openMode("drun", someScreen)
//
// Atalho global de teclado (opcional, via Hyprland keybind ou GlobalShortcut):
//   GlobalShortcut { name: "dmenu"; description: "Abre o dmenu"
//     onPressed: globalDmenu.openMode("drun", Quickshell.screens[0]) }

Item {
  id: root

  // ── Cores ──────────────────────────────────────────────────────────────────
  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  // ── Configuração de modos ──────────────────────────────────────────────────
  // Cada modo define: prompt, comando para listar entradas, e handler de ação
  property var modes: ({
    "drun": {
      prompt:    "APPS",
      listCmd:   ["bash", "-c", "compgen -c | sort -u"],
      // Sobrescreva com comando real de .desktop entries se preferir:
      // listCmd: ["bash", "-c", "ls /usr/share/applications/ | sed 's/.desktop//'"],
      runCmd:    (entry) => ["bash", "-c", entry + " &"]
    },
    "run": {
      prompt:    "RUN",
      listCmd:   ["bash", "-c", "compgen -c | sort -u"],
      runCmd:    (entry) => ["bash", "-c", entry + " &"]
    },
    "window": {
      prompt:    "WINDOW",
      listCmd:   ["bash", "-c",
        "hyprctl clients -j | python3 -c \"import sys,json; [print(f'{c[\\\"class\\\"]} → {c[\\\"title\\\"]}') for c in json.load(sys.stdin)]\""],
      runCmd:    (entry) => {
        // entry = "class → title", foca a janela
        var cls = entry.split(" → ")[0].trim()
        return ["bash", "-c", "hyprctl dispatch 'hl.dsp.focus({ window = \'class:" + cls + "\' })' &"]
      }
    }
  })

  // ── Estado ─────────────────────────────────────────────────────────────────
  property string _activeMode:   "drun"
  property var    _activeScreen: null
  property var    _entries:      []
  property bool   _loading:      false

  // ── Método principal ───────────────────────────────────────────────────────
  function openMode(mode, screen) {
    if (!(mode in modes)) {
      console.warn("Dmenu: modo desconhecido:", mode)
      return
    }
    _activeMode   = mode
    _activeScreen = screen ?? Quickshell.screens[0]
    _entries      = []
    _loading      = true

    // Atualiza o painel antes de abrir
    panel.entries     = []
    panel.prompt      = modes[mode].prompt
    panel.screen      = _activeScreen
    panel.open()

    // Dispara o processo de listagem
    listProc.command = modes[mode].listCmd
    listProc.running = true
  }

  function _runEntry(entry) {
    var modeConf = modes[_activeMode]
    if (!modeConf) return
    var cmd = modeConf.runCmd(entry)
    runProc.command = cmd
    runProc.running = true
  }

  // ── Processo de listagem ───────────────────────────────────────────────────
  Process {
    id:      listProc
    running: false

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: (line) => {
        var t = line.trim()
        if (t !== "") root._entries.push(t)
      }
    }

    onExited: (code, status) => {
      root._loading = false
      // Atualiza entries no painel de uma vez (evita binding loop)
      panel.entries = root._entries.slice()
    }
  }

  // ── Processo de execução ───────────────────────────────────────────────────
  Process {
    id:      runProc
    running: false
    // Sem stdout/stderr — fire-and-forget
  }

  // ── Painel ─────────────────────────────────────────────────────────────────
  DmenuPanel {
    id:     panel
    screen: root._activeScreen ?? Quickshell.screens[0]

    colorPanelBg:  root.colorPanelBg
    colorText:     root.colorText
    colorTextDim:  root.colorTextDim
    colorAccent:   root.colorAccent
    colorSelected: root.colorSelected
    colorDivider:  root.colorDivider
    colorInputBg:  root.colorInputBg

    onAccepted:  (text) => root._runEntry(text)
    onDismissed: { /* painel já fechou, nada mais a fazer */ }
  }
}
