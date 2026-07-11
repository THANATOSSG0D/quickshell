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

  // janela (em dias) que conta como "prazo próximo" — dentro dela, o
  // prazo aparece por extenso na linha da tarefa; fora dela, só um ícone
  // discreto (o valor completo continua no tooltip do hover)
  property int dueSoonDays: 7
  // tarefas com prazo além da janela acima somem da lista por padrão
  // (continuam aparecendo se filtradas por data no Calendário combinado,
  // ou se marcadas concluídas com showCompleted ligado)
  property bool hideFarTasks: true

  // lista de tarefas:
  // {id, text, done, priority, due, created, tags: [], recurrence, lastCompleted}
  // recurrence: "none" | "daily" | "weekly" | "monthly"
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
      property int dueSoonDays: 7
      property bool hideFarTasks: true
      property var tasks: []

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeChanged:      config.fontSize      = fontSize
      onShowCompletedChanged: config.showCompleted = showCompleted
      onSortByChanged:        config.sortBy        = sortBy
      onColorTextChanged:     config.colorText     = colorText
      onDueSoonDaysChanged:   config.dueSoonDays   = dueSoonDays
      onHideFarTasksChanged:  config.hideFarTasks  = hideFarTasks
      onTasksChanged: {
        if (JSON.stringify(tasks) !== JSON.stringify(config.tasks))
          config.tasks = tasks
      }
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onFontSizeChanged:      adapter.fontSize      = fontSize
  onShowCompletedChanged: adapter.showCompleted = showCompleted
  onSortByChanged:        adapter.sortBy        = sortBy
  onColorTextChanged:     adapter.colorText     = colorText
  onDueSoonDaysChanged:   adapter.dueSoonDays   = dueSoonDays
  onHideFarTasksChanged:  adapter.hideFarTasks  = hideFarTasks
  onTasksChanged: {
    if (JSON.stringify(tasks) !== JSON.stringify(adapter.tasks))
      adapter.tasks = tasks
  }

  // ── Helpers de manipulação da lista ─────────────────────────────────
  // Sempre reatribuem o array inteiro (tasks = novoArray): mutar com
  // push/splice direto não dispara onTasksChanged e não salva no JSON.

  function normalizeTags(tags) {
    if (!tags) return []
    if (typeof tags === "string") {
      return tags.split(",").map(function(t) { return t.trim() }).filter(function(t) { return t.length > 0 })
    }
    return tags.filter(function(t) { return t && t.length > 0 })
  }

  // calcula a próxima data com base na recorrência, a partir do prazo
  // anterior (ou de hoje, se a tarefa não tinha prazo definido)
  function computeNextDue(due, recurrence) {
    const base = due ? new Date(due + "T00:00:00") : new Date()
    if (recurrence === "daily") base.setDate(base.getDate() + 1)
    else if (recurrence === "weekly") base.setDate(base.getDate() + 7)
    else if (recurrence === "monthly") base.setMonth(base.getMonth() + 1)
    return Qt.formatDate(base, "yyyy-MM-dd")
  }

  function addTask(text, priority, due, tags, recurrence) {
    if (!text || !text.trim()) return
    const t = tasks.slice()
    t.push({
      id: Date.now() + "-" + Math.floor(Math.random() * 1000),
      text: text.trim(),
      done: false,
      priority: priority || "media",
      due: due || "",
      created: new Date().toISOString(),
      tags: normalizeTags(tags),
      recurrence: recurrence || "none",
      lastCompleted: "",
    })
    tasks = t
  }

  function toggleTask(id) {
    tasks = tasks.map(function(t) {
      if (t.id !== id) return t

      // tarefa recorrente + ainda não concluída → já reagenda pro próximo
      // ciclo em vez de simplesmente marcar como concluída pra sempre
      if (t.recurrence && t.recurrence !== "none" && !t.done) {
        return Object.assign({}, t, {
          done: false,
          due: config.computeNextDue(t.due, t.recurrence),
          lastCompleted: new Date().toISOString(),
        })
      }
      return Object.assign({}, t, { done: !t.done })
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
