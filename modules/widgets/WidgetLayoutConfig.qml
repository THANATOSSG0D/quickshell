import QtQuick
import Quickshell
import Quickshell.Io

// ── WidgetLayoutConfig ──────────────────────────────────────────────────
// Config do "modo combinado": quando ativo, os widgets listados em
// `members` (na ordem em que aparecem) deixam de abrir sua própria janela
// flutuante individual e passam a ser renderizados juntos, dentro de um
// único card, pela WidgetHost.qml.
//
// ids válidos em `members`: "clock", "todo", "calendar", "weather"

Item {
  id: config
  visible: false

  property bool groupEnabled: false
  property int position: 4
  property int edgeMargin: 48
  property var members: [] // ex: ["clock", "weather"]

  function isGrouped(widgetId) {
    return groupEnabled && members.indexOf(widgetId) !== -1
  }

  function toggleMember(widgetId) {
    const m = members.slice()
    const idx = m.indexOf(widgetId)
    if (idx === -1) m.push(widgetId)
    else m.splice(idx, 1)
    members = m
  }

  function moveMember(widgetId, dir) {
    const m = members.slice()
    const idx = m.indexOf(widgetId)
    if (idx === -1) return
    const newIdx = idx + dir
    if (newIdx < 0 || newIdx >= m.length) return
    const tmp = m[idx]; m[idx] = m[newIdx]; m[newIdx] = tmp
    members = m
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/WidgetLayout.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property bool groupEnabled: false
      property int position: 4
      property int edgeMargin: 48
      property var members: []

      onGroupEnabledChanged: config.groupEnabled = groupEnabled
      onPositionChanged:     config.position      = position
      onEdgeMarginChanged:   config.edgeMargin     = edgeMargin
      onMembersChanged: {
        if (JSON.stringify(members) !== JSON.stringify(config.members))
          config.members = members
      }
    }
  }

  onGroupEnabledChanged: adapter.groupEnabled = groupEnabled
  onPositionChanged:     adapter.position      = position
  onEdgeMarginChanged:   adapter.edgeMargin    = edgeMargin
  onMembersChanged: {
    if (JSON.stringify(members) !== JSON.stringify(adapter.members))
      adapter.members = members
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
