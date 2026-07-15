import QtQuick
import Quickshell
import Quickshell.Io

// ── WidgetVisibilityConfig ──────────────────────────────────────────────
// Liga/desliga widgets individualmente — funciona tanto pra widgets
// avulsos (fora de grupo) quanto pra membros dentro de um grupo
// combinado (ver uso em WidgetHost.qml). Guarda só os IDs DESATIVADOS;
// qualquer id que não esteja na lista é considerado ativado por padrão
// (inclusive widgets novos que ainda não existiam quando o JSON foi
// salvo pela última vez).
//
// ids válidos: "clock", "todo", "calendar", "weather", "cpu", "ram",
//              "gpu", "network", "disk", "bluetooth", "habits",
//              "mediaplayer", "favorites"

Item {
  id: config
  visible: false

  property var disabled: [] // [widgetId, ...]

  function isEnabled(widgetId) {
    return disabled.indexOf(widgetId) === -1
  }

  function setEnabled(widgetId, value) {
    if (value) {
      if (disabled.indexOf(widgetId) === -1) return
      disabled = disabled.filter(id => id !== widgetId)
    } else {
      if (disabled.indexOf(widgetId) !== -1) return
      disabled = disabled.concat([widgetId])
    }
  }

  function toggleEnabled(widgetId) {
    setEnabled(widgetId, !isEnabled(widgetId))
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/WidgetVisibility.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property var disabled: []

      onDisabledChanged: {
        if (JSON.stringify(disabled) !== JSON.stringify(config.disabled))
          config.disabled = disabled
      }
    }
  }

  onDisabledChanged: {
    if (JSON.stringify(disabled) !== JSON.stringify(adapter.disabled))
      adapter.disabled = disabled
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
