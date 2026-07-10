import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 3
  property int edgeMargin: 48

  property int fontSize: 15
  property bool showCompleted: true
  // priority | due | created
  property string sortBy: "priority"
  // chave de paleta do texto
  property string colorText: "on_surface"

  // lista de tarefas: [{id, text, done, priority, due, created}]
  property var tasks: []

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/TodoWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position: 3
      property int edgeMargin: 48
      property int fontSize: 15
      property bool showCompleted: true
      property string sortBy: "priority"
      property string colorText: "on_surface"
      property var tasks: []

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeChanged:      config.fontSize      = fontSize
      onShowCompletedChanged: config.showCompleted = showCompleted
      onSortByChanged:        config.sortBy        = sortBy
      onColorTextChanged:     config.colorText     = colorText
      onTasksChanged:         config.tasks         = tasks
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onFontSizeChanged:      adapter.fontSize      = fontSize
  onShowCompletedChanged: adapter.showCompleted = showCompleted
  onSortByChanged:        adapter.sortBy        = sortBy
  onColorTextChanged:     adapter.colorText     = colorText
  onTasksChanged:         adapter.tasks         = tasks

  // ── Helpers de manipulação da lista ─────────────────────────────────
  // Sempre reatribuem o array inteiro (tasks = novoArray): mutar com
  // push/splice direto não dispara onTasksChanged e não salva no JSON.
  function addTask(text, priority, due) {
    if (!text || !text.trim()) return
    const t = tasks.slice()
    t.push({
      id: Date.now() + "-" + Math.floor(Math.random() * 1000),
      text: text.trim(),
      done: false,
      priority: priority || "media",
      due: due || "",
      created: new Date().toISOString(),
    })
    tasks = t
  }

  function toggleTask(id) {
    tasks = tasks.map(function(t) {
      return t.id === id ? Object.assign({}, t, { done: !t.done }) : t
    })
  }

  function removeTask(id) {
    tasks = tasks.filter(function(t) { return t.id !== id })
  }

  function updateTask(id, changes) {
    tasks = tasks.map(function(t) {
      return t.id === id ? Object.assign({}, t, changes) : t
    })
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
