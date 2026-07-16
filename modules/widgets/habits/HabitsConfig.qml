import QtQuick
import Quickshell
import Quickshell.Io

// ── HabitsConfig ─────────────────────────────────────────────────────────
// Config do widget de Habit Tracking, pensado pro dia a dia: hábitos podem
// ser do tipo "check" (marca feito/não feito, ex: "meditar") ou "count" —
// uma meta numérica registrada ao longo do dia (ex: "8 copos de água",
// "30min de exercício"), incrementada com +1 conforme o uso. Cada hábito
// guarda { id, name, color, kind: "check"|"count", target, unit,
// history: { "yyyy-MM-dd": number } } — pra "check" o valor no histórico é
// sempre 0 ou 1; pra "count" é a quantidade acumulada naquele dia (pode
// passar do alvo, fica sobressalente). Isso unifica streak/heatmap: um dia
// é "concluído" quando o valor registrado bate a meta (1 pro check, target
// pro count). Heatmap agregado estilo GitHub. Mesmo esqueleto de
// BluetoothConfig (FileView/JsonAdapter + mkdir init), com o cuidado extra
// de WidgetLayoutConfig pra propriedades `var` (arrays/objetos):
// comparação via JSON.stringify pra não disparar loop de escrita infinito.

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 20
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  240
  property int fixedHeight: 240

  // [{ id, name, color, kind: "check"|"count", target, unit,
  //    history: { "yyyy-MM-dd": number } }]
  property var habits: []

  property bool showHeatmap:  true
  property int  heatmapWeeks: 10
  property int  squareSize:   10
  property int  maxVisible:   4

  readonly property var _colorRotation: [
    "primary", "secondary", "tertiary", "error", "primary_container"
  ]

  function _uid() {
    return "h" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
  }

  function _todayKey() {
    return Qt.formatDate(new Date(), "yyyy-MM-dd")
  }

  // kind: "check" (padrão) ou "count". target/unit só valem pra "count"
  // (ex: addHabit("Água", "count", 8, "copos")).
  function addHabit(name, kind, target, unit) {
    const h = habits.slice()
    const k = (kind === "count") ? "count" : "check"
    h.push({
      id: _uid(),
      name: (name && name.trim().length > 0) ? name.trim() : "Novo hábito",
      color: _colorRotation[h.length % _colorRotation.length],
      kind: k,
      target: k === "count" ? Math.max(1, target || 8) : 1,
      unit: k === "count" ? (unit || "") : "",
      history: {},
    })
    habits = h
  }

  function removeHabit(id) {
    habits = habits.filter(h => h.id !== id)
  }

  function renameHabit(id, name) {
    habits = habits.map(h => h.id === id ? Object.assign({}, h, { name }) : h)
  }

  function setHabitColor(id, color) {
    habits = habits.map(h => h.id === id ? Object.assign({}, h, { color }) : h)
  }

  function cycleHabitColor(id) {
    const h = habits.find(x => x.id === id)
    if (!h) return
    const idx = _colorRotation.indexOf(h.color)
    setHabitColor(id, _colorRotation[(idx + 1) % _colorRotation.length])
  }

  function setHabitTarget(id, target, unit) {
    habits = habits.map(h => h.id === id
      ? Object.assign({}, h, { target: Math.max(1, target || 1), unit: unit !== undefined ? unit : h.unit })
      : h)
  }

  // ── check (feito/não feito) ────────────────────────────────────────
  function toggleDate(id, dateKey) {
    habits = habits.map(h => {
      if (h.id !== id) return h
      const hist = Object.assign({}, h.history)
      hist[dateKey] = hist[dateKey] ? 0 : 1
      return Object.assign({}, h, { history: hist })
    })
  }

  function toggleToday(id) { toggleDate(id, _todayKey()) }

  // ── count (meta numérica, ex: garrafas de água) ─────────────────────
  // delta pode ser negativo (corrige registro errado); nunca vai abaixo de 0
  function logCount(id, delta, dateKey) {
    const key = dateKey || _todayKey()
    habits = habits.map(h => {
      if (h.id !== id) return h
      const hist = Object.assign({}, h.history)
      const cur = hist[key] || 0
      const next = Math.max(0, cur + delta)
      if (next === 0) delete hist[key]
      else hist[key] = next
      return Object.assign({}, h, { history: hist })
    })
  }

  function resetToday(id) {
    habits = habits.map(h => {
      if (h.id !== id) return h
      const hist = Object.assign({}, h.history)
      delete hist[_todayKey()]
      return Object.assign({}, h, { history: hist })
    })
  }

  function amountOn(habit, dateKey) {
    return (habit.history && habit.history[dateKey]) || 0
  }

  // 0..1 — fração da meta cumprida naquele dia (1 = concluído ou excedido)
  function progressOn(habit, dateKey) {
    const amount = amountOn(habit, dateKey)
    const target = (habit.kind === "count") ? (habit.target || 1) : 1
    return target > 0 ? Math.max(0, Math.min(1, amount / target)) : 0
  }

  function isDoneOn(habit, dateKey) {
    return progressOn(habit, dateKey) >= 1
  }

  // streak atual: conta dias consecutivos até hoje; se hoje ainda não bateu
  // a meta, começa a contagem em ontem (janela de graça até virar o dia)
  function streakFor(habit) {
    if (!habit || !habit.history) return 0
    const d = new Date()
    if (!isDoneOn(habit, Qt.formatDate(d, "yyyy-MM-dd"))) d.setDate(d.getDate() - 1)
    let streak = 0
    while (isDoneOn(habit, Qt.formatDate(d, "yyyy-MM-dd"))) {
      streak++
      d.setDate(d.getDate() - 1)
    }
    return streak
  }

  // maior streak já alcançado (não só o atual) — varre dia a dia desde o
  // primeiro registro até hoje; ok custar um pouco mais já que só roda
  // quando o painel de histórico está aberto, não no widget compacto
  function longestStreak(habit) {
    if (!habit || !habit.history) return 0
    const dates = Object.keys(habit.history)
    if (dates.length === 0) return 0
    dates.sort()
    const d = new Date(dates[0] + "T00:00:00")
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    let best = 0, cur = 0
    while (d <= today) {
      const key = Qt.formatDate(d, "yyyy-MM-dd")
      if (isDoneOn(habit, key)) { cur++; if (cur > best) best = cur }
      else cur = 0
      d.setDate(d.getDate() + 1)
    }
    return best
  }

  function totalCompletions(habit) {
    if (!habit || !habit.history) return 0
    return Object.keys(habit.history).filter(k => isDoneOn(habit, k)).length
  }

  function completionsInMonth(habit, year, month) {
    if (!habit || !habit.history) return 0
    return Object.keys(habit.history).filter(k => {
      if (!isDoneOn(habit, k)) return false
      const d = new Date(k + "T00:00:00")
      return d.getFullYear() === year && d.getMonth() === month
    }).length
  }

  // log de entradas (mais recente primeiro) — usado na aba de Histórico
  function historyEntries(habit, limit) {
    if (!habit || !habit.history) return []
    return Object.keys(habit.history)
      .filter(k => (habit.history[k] || 0) > 0)
      .sort((a, b) => a < b ? 1 : -1)
      .slice(0, limit || 90)
      .map(k => ({ date: k, amount: habit.history[k], done: isDoneOn(habit, k) }))
  }

  // remove entradas de histórico com mais de ~1 ano, pra não crescer sem limite
  function _pruneOld() {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - 370)
    habits = habits.map(h => {
      const hist = {}
      for (const key in h.history) {
        if (new Date(key) >= cutoff) hist[key] = h.history[key]
      }
      return Object.assign({}, h, { history: hist })
    })
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/HabitsWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 20
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  240
      property int fixedHeight: 240

      property var habits: []

      property bool showHeatmap:  true
      property int  heatmapWeeks: 10
      property int  squareSize:   10
      property int  maxVisible:   4

      onPositionChanged:        config.position        = position
      onEdgeMarginChanged:      config.edgeMargin      = edgeMargin
      onFontSizeValueChanged:   config.fontSizeValue   = fontSizeValue
      onColorValueChanged:      config.colorValue      = colorValue
      onColorLabelChanged:      config.colorLabel      = colorLabel
      onColorLineChanged:       config.colorLine       = colorLine
      onFixedWidthChanged:      config.fixedWidth      = fixedWidth
      onFixedHeightChanged:     config.fixedHeight     = fixedHeight
      onShowHeatmapChanged:     config.showHeatmap     = showHeatmap
      onHeatmapWeeksChanged:    config.heatmapWeeks    = heatmapWeeks
      onSquareSizeChanged:      config.squareSize      = squareSize
      onMaxVisibleChanged:      config.maxVisible      = maxVisible

      onHabitsChanged: {
        if (JSON.stringify(habits) !== JSON.stringify(config.habits))
          config.habits = habits
      }
    }
  }

  onPositionChanged:        adapter.position        = position
  onEdgeMarginChanged:      adapter.edgeMargin      = edgeMargin
  onFontSizeValueChanged:   adapter.fontSizeValue   = fontSizeValue
  onColorValueChanged:      adapter.colorValue      = colorValue
  onColorLabelChanged:      adapter.colorLabel      = colorLabel
  onColorLineChanged:       adapter.colorLine       = colorLine
  onFixedWidthChanged:      adapter.fixedWidth      = fixedWidth
  onFixedHeightChanged:     adapter.fixedHeight     = fixedHeight
  onShowHeatmapChanged:     adapter.showHeatmap     = showHeatmap
  onHeatmapWeeksChanged:    adapter.heatmapWeeks    = heatmapWeeks
  onSquareSizeChanged:      adapter.squareSize      = squareSize
  onMaxVisibleChanged:      adapter.maxVisible      = maxVisible

  onHabitsChanged: {
    if (JSON.stringify(habits) !== JSON.stringify(adapter.habits))
      adapter.habits = habits
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      file.reload()
      initTimer.start()
    }
  }

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  // limpa histórico antigo uma vez por dia (não precisa ser muito preciso)
  Timer {
    interval: 6 * 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: config._pruneOld()
  }

  Component.onCompleted: mkdirProc.running = true
}
