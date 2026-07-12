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

  // horários (HH:mm) em que tarefas do dia SEM horário próprio definido
  // entram num resumo agendado via notify-send (ver TodoReminderService).
  // Tarefas COM horário (task.time) notificam individualmente, na hora.
  property var summaryTimes: ["08:00", "20:00"]

  // lista de tarefas:
  // {id, text, done, priority, due, time, created, tags: [], recurrence, lastCompleted, status}
  // recurrence: "none" | "daily" | "weekly" | "monthly"
  // time: "" | "HH:mm" — horário específico dentro do dia do prazo (opcional)
  // status: "" | "doing" | "blocked" — metadado extra pra tarefas mais
  // longas/com etapas (não substitui "done", só marca "estou nisso agora"
  // ou "travada esperando algo"); zera sozinho quando a tarefa é concluída
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
      property var summaryTimes: ["08:00", "20:00"]
      property var tasks: []

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeChanged:      config.fontSize      = fontSize
      onShowCompletedChanged: config.showCompleted = showCompleted
      onSortByChanged:        config.sortBy        = sortBy
      onColorTextChanged:     config.colorText     = colorText
      onDueSoonDaysChanged:   config.dueSoonDays   = dueSoonDays
      onHideFarTasksChanged:  config.hideFarTasks  = hideFarTasks
      onSummaryTimesChanged: {
        if (JSON.stringify(summaryTimes) !== JSON.stringify(config.summaryTimes))
          config.summaryTimes = summaryTimes
      }
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
  onSummaryTimesChanged: {
    if (JSON.stringify(summaryTimes) !== JSON.stringify(adapter.summaryTimes))
      adapter.summaryTimes = summaryTimes
  }
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

  // "time" é opcional (HH:mm) — tarefa com horário próprio dispara um
  // lembrete individual naquele horário (ver TodoReminderService); sem
  // horário, a tarefa entra no resumo agendado (config.summaryTimes).
  // "status" é opcional ("" | "doing" | "blocked") — pensado pra tarefas
  // mais longas, que vale a pena marcar "em andamento" ou "bloqueada".
  function addTask(text, priority, due, tags, recurrence, time, status) {
    if (!text || !text.trim()) return
    const t = tasks.slice()
    t.push({
      id: Date.now() + "-" + Math.floor(Math.random() * 1000),
      text: text.trim(),
      done: false,
      priority: priority || "media",
      due: due || "",
      time: time || "",
      created: new Date().toISOString(),
      tags: normalizeTags(tags),
      recurrence: recurrence || "none",
      lastCompleted: "",
      status: status || "",
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
          status: "",
        })
      }
      // ao concluir, status (em andamento/bloqueada) não faz mais sentido
      const nowDone = !t.done
      return Object.assign({}, t, { done: nowDone, status: nowDone ? "" : t.status })
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
