pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.singletons

// ── PanelRouter ─────────────────────────────────────────────────────────────
// Decide em qual instância (bar/dock/...) um popup deve abrir quando
// acionado por keybind/IPC, baseado em onde o módulo correspondente está
// atualmente presente no layout ativo (modulesLeft/Right/Top/Bottom/Middle/
// Center do tema em uso), com override manual persistido pela config UI.
//
// Cada instância do Bar.qml (barRoot) se registra aqui em
// Component.onCompleted via PanelRouter.registerInstance(instanceId, barRoot).
// Não precisa de fiação manual no shell.qml — funciona com quantas
// instâncias existirem (bar, dock, uma terceira futura, etc).
//
// Estrutura do JSON (state/PanelRouter.json):
//   {
//     "overrides": {
//       "volume":        "auto",   // "auto" | "<instanceId>" (ex: "bar", "dock")
//       "mediaplayer":    "auto",
//       "clock":          "auto",
//       "quicksettings":  "auto",
//       "notifications":  "auto",
//       "workspaces":     "auto",
//       "dmenu":          "auto"   // chave própria do dmenu — NÃO compartilha
//                                  // override com "workspaces" (ver searchModuleName)
//     }
//   }
//
// API pública:
//   PanelRouter.registerInstance(instanceId, barRootRef)  → void
//   PanelRouter.availableInstances()                      → [instanceId, ...]
//   PanelRouter.allInstances()                             → [barRootRef, ...]
//   PanelRouter.get(moduleName)                            → string ("auto" default)
//   PanelRouter.set(moduleName, value)                      → void
//   PanelRouter.reset(moduleName)                           → void
//   PanelRouter.resolveInstance(moduleName, callerRef, searchModuleName?)  → barRootRef
//     searchModuleName (opcional): nome usado pra procurar no layout ativo
//     durante o modo "auto". Default = moduleName. Existe pra painéis
//     "virtuais" sem módulo próprio na barra (ex: "dmenu"), que usam a
//     posição de outro módulo real (ex: "workspaces") como pista de onde
//     abrir — mas mantêm seu PRÓPRIO override persistido, independente.
//   PanelRouter.resolveInstanceId(moduleName, searchModuleName?)  → instanceId

QtObject {
  id: root

  // ── Registro em runtime (não persistido) ────────────────────────────────
  property var _instances: ({})   // instanceId -> barRootRef
  property var _order:     []     // ordem de registro, usada como desempate

  function registerInstance(instanceId, ref) {
    if (!instanceId || !ref) return
    var map = root._instances
    map[instanceId] = ref
    root._instances = map
    if (root._order.indexOf(instanceId) === -1) {
      var o = root._order.slice()
      o.push(instanceId)
      root._order = o
    }
  }

  // Lista de instanceIds registrados — útil pra popular dropdowns na config UI.
  function availableInstances() {
    return root._order.slice()
  }

  // Lista das referências (barRoot) registradas, na ordem de registro.
  function allInstances() {
    var out = []
    for (var i = 0; i < root._order.length; i++) {
      var inst = root._instances[root._order[i]]
      if (inst) out.push(inst)
    }
    return out
  }

  // ── _hasModule: procura moduleName em qualquer lista do layout ativo ────
  function _hasModule(inst, moduleName) {
    if (!inst) return false
    var lists = [inst.modulesLeft, inst.modulesRight, inst.modulesTop,
                 inst.modulesBottom, inst.modulesMiddle, inst.modulesCenter]
    for (var i = 0; i < lists.length; i++) {
      var l = lists[i]
      if (l && l.indexOf(moduleName) !== -1) return true
    }
    return false
  }

  // ── resolveInstance: decide onde abrir ────────────────────────────────────
  // 1. Override manual (config UI) apontando pra uma instância registrada
  //    → sempre vence, mesmo que o módulo não esteja lá no momento.
  // 2. "auto" (padrão): prioriza a instância que fez a chamada (callerRef) —
  //    se o módulo estiver lá, abre ali mesmo. Senão, percorre as demais
  //    instâncias registradas (ordem de registro) — a primeira que tiver o
  //    módulo no layout ativo vence.
  // 3. Módulo não encontrado em nenhuma instância → mantém o comportamento
  //    original (abre na instância que chamou).
  function resolveInstance(moduleName, callerRef, searchModuleName) {
    var searchName = searchModuleName || moduleName

    var ov = root.get(moduleName)
    if (ov && ov !== "auto") {
      var forced = root._instances[ov]
      if (forced) return forced
      // override aponta pra uma instância inexistente/desligada — cai pro auto
    }

    if (root._hasModule(callerRef, searchName)) return callerRef

    for (var i = 0; i < root._order.length; i++) {
      var inst = root._instances[root._order[i]]
      if (inst && inst !== callerRef && root._hasModule(inst, searchName))
        return inst
    }

    return callerRef
  }

  // Versão de resolveInstance() sem callerRef — pra UI (dropdown da aba
  // Painéis) conseguir mostrar/usar o que "Automático" resolveria AGORA,
  // sem precisar simular quem seria o "chamador". Usa _defaultCaller quando
  // disponível (ver setDefaultCaller) — senão cai na primeira instância
  // registrada ("bar", tipicamente) como último recurso.
  //
  // _defaultCaller existe porque, pra rotas com searchModuleName próprio
  // (ex: "dmenu" buscando "workspaces"), o desempate de "auto" depende de
  // QUEM chamou (ver resolveInstance acima, regra 2). Sem isso, se
  // "workspaces" existir em mais de uma instância ao mesmo tempo, esta
  // função podia resolver pra uma instância diferente da que o caller real
  // (ex: DmenuIpc.barRoot) resolve em runtime — fazendo a config UI editar
  // o PopupConfig da instância errada (o slider "grava" mas não parece
  // fazer efeito nenhum, porque quem lê é a outra instância).
  function resolveInstanceId(moduleName, searchModuleName) {
    var insts = root.allInstances()
    if (insts.length === 0) return "bar"
    var caller = root._defaultCaller || insts[0]
    var resolved = root.resolveInstance(moduleName, caller, searchModuleName)
    return (resolved && resolved.instanceId) ? resolved.instanceId
                                              : (caller.instanceId || "bar")
  }

  // ── _defaultCaller ────────────────────────────────────────────────────────
  // Referência usada por resolveInstanceId() como desempate de "auto" quando
  // não há um callerRef real disponível (ver comentário acima). Chamadores
  // com um "dono" fixo e único (ex: DmenuIpc, que sempre resolve usando o
  // mesmo root.barRoot) devem se registrar aqui uma vez, pra manter a UI e o
  // runtime consistentes. Não precisa ser chamado por módulos "normais"
  // (volume, clock, etc.) que não usam searchModuleName — a ambiguidade só
  // existe quando módulo-de-busca ≠ módulo-da-rota.
  property var _defaultCaller: null
  function setDefaultCaller(ref) {
    root._defaultCaller = ref
  }

  // ── Overrides persistidos ─────────────────────────────────────────────────
  property int _dep: 0
  function _bump() { _dep++ }

  // get(moduleName) → "auto" | "<instanceId>"
  function get(moduleName) {
    var _ = root._dep  // reatividade
    try {
      var ov = _adapter.overrides
      if (ov && ov[moduleName] !== undefined) return ov[moduleName]
    } catch(e) {}
    return "auto"
  }

  // set(moduleName, value) — value: "auto" | "<instanceId>"
  function set(moduleName, value) {
    var ov = {}
    try { ov = JSON.parse(JSON.stringify(_adapter.overrides)) } catch(e) {}
    ov[moduleName] = value
    _adapter.overrides = ov
    _file.writeAdapter()
    _bump()
  }

  function reset(moduleName) {
    var ov = {}
    try { ov = JSON.parse(JSON.stringify(_adapter.overrides)) } catch(e) {}
    delete ov[moduleName]
    _adapter.overrides = ov
    _file.writeAdapter()
    _bump()
  }

  // ── Arquivo ────────────────────────────────────────────────────────────
  property var _file: FileView {
    id: _file
    path: Quickshell.shellDir + "/state/PanelRouter.json"
    watchChanges: true

    JsonAdapter {
      id: _adapter
      property var overrides: ({})
      onOverridesChanged: root._bump()
    }
  }

  // Garante que o arquivo exista na primeira execução
  function _initIfEmpty() {
    if (!_adapter.overrides || Object.keys(_adapter.overrides).length === 0) {
      _adapter.overrides = {}
      _file.writeAdapter()
    }
  }

  property var _stateDirConn: Connections {
    target: StateDir
    function onReadyChanged() {
      if (StateDir.ready) root._initIfEmpty()
    }
  }

  Component.onCompleted: if (StateDir.ready) root._initIfEmpty()
}
