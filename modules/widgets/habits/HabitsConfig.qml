import QtQuick
import Quickshell
import Quickshell.Io

// ── HabitsConfig ─────────────────────────────────────────────────────────
// Config do widget de Habit Tracking: lista de hábitos (cada um com nome,
// cor e um mapa de histórico "yyyy-MM-dd" → true) + heatmap agregado estilo
// GitHub. Segue o mesmo esqueleto de BluetoothConfig (FileView/JsonAdapter
// + mkdir init), mas com o cuidado extra de WidgetLayoutConfig pra
// propriedades `var` (arrays/objetos): comparação via JSON.stringify pra
// não disparar loop de escrita infinito.

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

  // [{ id, name, color, history: { "yyyy-MM-dd": true, ... } }]
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

  function addHabit(name) {
    const h = habits.slice()
    h.push({
      id: _uid(),
      name: (name && name.trim().length > 0) ? name.trim() : "Novo hábito",
      color: _colorRotation[h.length % _colorRotation.length],
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

  function toggleDate(id, dateKey) {
    habits = habits.map(h => {
      if (h.id !== id) return h
      const hist = Object.assign({}, h.history)
      if (hist[dateKey]) delete hist[dateKey]
      else hist[dateKey] = true
      return Object.assign({}, h, { history: hist })
    })
  }

  function toggleToday(id) { toggleDate(id, _todayKey()) }

  function isDoneOn(habit, dateKey) {
    return !!(habit.history && habit.history[dateKey])
  }

  // streak atual: conta dias consecutivos até hoje; se hoje ainda não foi
  // marcado, começa a contagem em ontem (janela de graça até virar o dia)
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
