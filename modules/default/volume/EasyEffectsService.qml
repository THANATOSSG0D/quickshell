pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// EasyEffectsService — singleton compartilhado de estado do EasyEffects.
//
// Antes, o polling de status ("easyeffects -s") e da lista de presets
// ("easyeffects -p") vivia só dentro de VolumeContent.qml. Isso significava
// que o VolumeTooltip (que roda a partir de Volume.qml, na barra) não tinha
// como saber se o EasyEffects estava ativo, em bypass, ou qual preset
// estava carregado — e, se algum outro lugar quisesse a mesma informação,
// teria que abrir mais um par de Process/SplitParser duplicado.
//
// Este singleton resolve isso: um único ponto de leitura/escrita, com
// polling periódico próprio, consumido por qualquer QML do módulo (barra,
// tooltip, painel) sem import extra — mesmo padrão do VolumeTooltip/
// TooltipSettings, que já são singletons resolvidos implicitamente dentro
// do módulo "qs".
//
// API:
//   refresh()                → reconsulta status + lista de presets
//   applyPreset(type, name)  → carrega um preset (type: "output"|"input" —
//                               só usado para atualizar o estado local
//                               otimisticamente; o EasyEffects decide o
//                               pipeline certo pelo nome do preset)
//   toggleBypass()           → alterna o bypass global
//
// Propriedades (todas somente-leitura na prática, escritas só internamente):
//   running         : bool   — EasyEffects detectado rodando
//   bypassed        : bool   — bypass ativo (estado local otimista)
//   activeOutput    : string — preset de saída carregado no momento
//   activeInput     : string — preset de entrada carregado no momento
//   outputProfiles  : array  — presets de saída disponíveis
//   inputProfiles   : array  — presets de entrada disponíveis

Singleton {
  id: root

  property bool   running:        false
  property bool   bypassed:       false
  property string activeOutput:   ""
  property string activeInput:    ""
  property var    outputProfiles: []
  property var    inputProfiles:  []

  function refresh() {
    if (!statusProc.running) { statusProc.command = ["easyeffects", "-s"]; statusProc.running = true }
    if (!listProc.running)   { listProc.command   = ["easyeffects", "-p"]; listProc.running   = true }
  }

  function applyPreset(type, name) {
    applyProc.command = ["easyeffects", "-l", name]; applyProc.running = true
    if (type === "output") root.activeOutput = name
    else                   root.activeInput  = name
  }

  function toggleBypass() {
    bypassProc.command = ["easyeffects", "--bypass-toggle"]; bypassProc.running = true
    root.bypassed = !root.bypassed
  }

  Process {
    id: statusProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => statusProc._buf += l + "\n" }
    onRunningChanged: {
      if (running) return
      var out = statusProc._buf.trim(); statusProc._buf = ""
      root.running = out !== "" && !out.includes("not running")
      var lines = out.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l.startsWith("output:")) root.activeOutput = l.replace("output:", "").trim()
        if (l.startsWith("input:"))  root.activeInput  = l.replace("input:",  "").trim()
      }
    }
  }

  Process {
    id: listProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => listProc._buf += l + "\n" }
    onRunningChanged: {
      if (running) return
      var raw = listProc._buf.trim(); listProc._buf = ""
      var lines = raw.split("\n")
      var outputs = []; var inputs = []; var inInput = false
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        if (l.includes("saída") || l.toLowerCase().includes("output")) { inInput = false; continue }
        if (l.includes("entrada") || l.toLowerCase().includes("input")) { inInput = true;  continue }
        var m = l.match(/^\s*\d+\s+(.+)$/)
        if (m) {
          var name = m[1].trim()
          if (inInput) inputs.push(name)
          else         outputs.push(name)
        }
      }
      root.outputProfiles = outputs
      root.inputProfiles  = inputs
    }
  }

  Process { id: applyProc }
  Process { id: bypassProc }

  // Poll periódico — mantém barra/tooltip/painel em sincronia mesmo se o
  // preset for trocado por fora (GUI do EasyEffects, outro script, etc).
  // triggeredOnStart cobre o refresh inicial, dispensando um
  // Component.onCompleted em cada consumidor.
  Timer {
    interval:         5000
    running:          true
    repeat:           true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
