import QtQuick
import Quickshell
import Quickshell.Io

// ── WidgetLayoutConfig ──────────────────────────────────────────────────
// Config do "modo combinado": agora suporta MÚLTIPLOS grupos simultâneos.
// Cada grupo tem sua própria posição/margem e sua própria lista de
// `members` (na ordem em que aparecem dentro do card). Um widget só pode
// pertencer a um grupo por vez — ao marcá-lo num grupo, ele é removido
// automaticamente de qualquer outro.
//
// ids válidos em `members`: "clock", "todo", "calendar", "weather"
//
// Formato de cada grupo:
//   { id: string, enabled: bool, position: int, edgeMargin: int, members: [] }

Item {
  id: config
  visible: false

  property var groups: [] // [{ id, enabled, position, edgeMargin, members }]

  function _uid() {
    return "g" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
  }

  function addGroup() {
    const g = groups.slice()
    g.push({ id: _uid(), enabled: true, position: 4, edgeMargin: 48, members: [] })
    groups = g
  }

  function removeGroup(groupId) {
    groups = groups.filter(g => g.id !== groupId)
  }

  function _updateGroup(groupId, patch) {
    groups = groups.map(g => g.id === groupId ? Object.assign({}, g, patch) : g)
  }

  function setGroupEnabled(groupId, enabled)     { _updateGroup(groupId, { enabled }) }
  function setGroupPosition(groupId, position)   { _updateGroup(groupId, { position }) }
  function setGroupEdgeMargin(groupId, edgeMargin) { _updateGroup(groupId, { edgeMargin }) }

  // Alterna widgetId dentro do grupo groupId. Se ele já estiver em outro
  // grupo, é removido de lá primeiro (associação é exclusiva).
  function toggleMember(groupId, widgetId) {
    const g = groups.map(x => Object.assign({}, x, { members: x.members.slice() }))
    const target = g.find(x => x.id === groupId)
    if (!target) return

    const idx = target.members.indexOf(widgetId)
    if (idx !== -1) {
      target.members.splice(idx, 1)
    } else {
      g.forEach(other => {
        if (other.id === groupId) return
        const i = other.members.indexOf(widgetId)
        if (i !== -1) other.members.splice(i, 1)
      })
      target.members.push(widgetId)
    }
    groups = g
  }

  function moveMember(groupId, widgetId, dir) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const m = group.members.slice()
    const idx = m.indexOf(widgetId)
    if (idx === -1) return
    const newIdx = idx + dir
    if (newIdx < 0 || newIdx >= m.length) return
    const tmp = m[idx]; m[idx] = m[newIdx]; m[newIdx] = tmp
    _updateGroup(groupId, { members: m })
  }

  // true se o widget está em ALGUM grupo ativo — Widget.qml individuais
  // continuam chamando isGrouped("clock") do jeito que já chamavam.
  function isGrouped(widgetId) {
    return groups.some(g => g.enabled && g.members.indexOf(widgetId) !== -1)
  }

  function groupForWidget(widgetId) {
    const g = groups.find(g => g.enabled && g.members.indexOf(widgetId) !== -1)
    return g ? g.id : ""
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/WidgetLayout.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter

      // Campos legados (modo antigo, um único grupo) — mantidos só pra
      // migrar automaticamente um WidgetLayout.json de antes desta mudança.
      property bool groupEnabled: false
      property int position: 4
      property int edgeMargin: 48
      property var members: []

      property var groups: []

      onGroupsChanged: {
        if (JSON.stringify(groups) !== JSON.stringify(config.groups))
          config.groups = groups
      }

      // Dispara depois que os campos legados forem lidos do JSON antigo;
      // se `groups` já veio populado (JSON novo) isso é um no-op.
      onMembersChanged: config._migrateLegacy()
    }
  }

  function _migrateLegacy() {
    if (config.groups.length === 0 && adapter.groups.length === 0 && adapter.members.length > 0) {
      config.groups = [{
        id: _uid(),
        enabled: adapter.groupEnabled,
        position: adapter.position,
        edgeMargin: adapter.edgeMargin,
        members: adapter.members.slice(),
      }]
      // limpa os campos legados pra não remigrar depois que o usuário
      // apagar o grupo manualmente
      adapter.members = []
      adapter.groupEnabled = false
    }
  }

  onGroupsChanged: {
    if (JSON.stringify(groups) !== JSON.stringify(adapter.groups))
      adapter.groups = groups
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
