pragma Singleton
import Quickshell
import QtQuick
import qs

// TasksTooltip — tooltip do módulo combinado Tarefas + Hábitos, focado só
// no que é "de hoje" (mesmo escopo do indicador na barra):
//   • tarefas atrasadas + que vencem hoje, listadas com nome e prazo
//   • hábitos: X/Y hoje, e a lista dos que ainda faltam
//
// API:
//   show(item, tasksContent, barPosition)  → mostra após 500ms de hover
//   hide()                                 → esconde com pequeno delay

Singleton {
  id: root

  property color bgColor:     Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:     "#e2e2e2"
  property color fgDimColor:  Qt.rgba(1, 1, 1, 0.55)
  property color accentColor: "#ffb4a9"
  property color okColor:     "#45a249"

  property var _anchorItem:   null
  property var _tasksContent: null
  property int _barPos:       2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, tasksContent, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem   = item
    _tasksContent = tasksContent
    _barPos       = barPosition
    hideTimer.stop()
    showTimer.restart()
  }

  function hide() {
    showTimer.stop()
    hideTimer.restart()
  }

  Timer { id: showTimer; interval: 500; repeat: false; onTriggered: if (root._anchorItem) popup.visible = true }
  Timer { id: hideTimer; interval: 150; repeat: false; onTriggered: popup.visible = false }

  // ── Leituras do TasksContent — só o que é "de hoje" ─────────────────────
  readonly property var _todoConfig:   _tasksContent ? _tasksContent.todoConfig   : null
  readonly property var _habitsConfig: _tasksContent ? _tasksContent.habitsConfig : null

  readonly property var _pendingTasks: {
    if (!_todoConfig) return []
    return _todoConfig.tasks.filter(function(t) { return !t.done })
  }

  // "de hoje" = atrasada (já devia ter sido feita) ou vence hoje. Nada de
  // "em 3 dias" aqui — isso é backlog, não é pauta de hoje.
  readonly property var _todayTasks: {
    if (!_tasksContent) return []
    var list = _pendingTasks.filter(function(t) {
      return _tasksContent.isOverdueTask(t) || _tasksContent.isDueToday(t)
    })
    list.sort(function(a, b) {
      var ad = a.due || "", bd = b.due || ""
      if (ad !== bd) return ad < bd ? -1 : 1
      // mesmo dia (ou ambas atrasadas sem due comparável) → horário decide
      var at = a.time || "", bt = b.time || ""
      if (at !== bt) {
        if (!at) return 1
        if (!bt) return -1
        return at < bt ? -1 : 1
      }
      return 0
    })
    return list
  }
  readonly property int _overdueCount: {
    if (!_tasksContent) return 0
    var n = 0
    for (var i = 0; i < _todayTasks.length; i++) if (_tasksContent.isOverdueTask(_todayTasks[i])) n++
    return n
  }
  readonly property int _todayCount: _todayTasks.length

  function _taskLabel(t) {
    if (_tasksContent.isOverdueTask(t))
      return t.text + " · atrasada há " + Math.abs(_tasksContent.daysUntil(t.due)) + "d"
    return t.text + (t.time ? " · " + t.time : " · hoje")
  }

  readonly property var _priorityColor: ({ alta: "#e5484d", media: "#f5a524", baixa: "#45a249" })
  readonly property var _priorityLabel: ({ alta: "Alta", media: "Média", baixa: "Baixa" })
  readonly property var _recurrenceLabel: ({ daily: "Diária", weekly: "Semanal", monthly: "Mensal" })

  readonly property int _habitsTotal: _habitsConfig ? (_habitsConfig.habits ? _habitsConfig.habits.length : 0) : 0
  readonly property var _habitsPending: {
    if (!_habitsConfig || !_habitsConfig.habits) return []
    var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
    return _habitsConfig.habits.filter(function(h) {
      var st = _habitsConfig.habitStatus(h, today)
      return st !== "hit" && st !== "limit"
    })
  }
  readonly property int _habitsDoneToday: _habitsTotal - _habitsPending.length

  // ── Resolução de ancoragem (mesma lógica de ClockTooltip/BarTooltip) ───
  function _resolveAnchor() {
    if (!root._anchorItem) return root._anchorItem
    if (root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "bar" && root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "section")
      return root._anchorItem
    var wantPrefix = root._cfg(root._anchorItem, "Align", TooltipSettings.align) === "bar" ? "barContentRoot" : "barSection"
    var it = root._anchorItem, guard = 0
    while (it && it.objectName.indexOf(wantPrefix) !== 0 && guard < 40) { it = it.parent; guard++ }
    return it || root._anchorItem
  }

  function _cfg(startItem, key, dflt) {
    var it = startItem, guard = 0
    while (it && it.objectName !== "barContentRoot" && guard < 40) { it = it.parent; guard++ }
    var propName = "cfgTooltip" + key
    if (it && it[propName] !== undefined) return it[propName]
    return dflt
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    readonly property int  _touchOffset: root._cfg(root._anchorItem, "Offset", TooltipSettings.offset)
    readonly property bool _barVertical: root._barPos === 2 || root._barPos === 4

    // era hardcoded em 260, ignorando completamente MinWidth/MaxWidth —
    // agora clampado igual aos outros 6 tooltips. 260 fica só como
    // baseline (mesmo valor de antes) quando o usuário não mexe nos
    // sliders; o conteúdo continua usando WordWrap, então se ajusta
    // sozinho à largura resultante.
    implicitWidth: Math.min(
      root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth),
      Math.max(root._cfg(root._anchorItem, "MinWidth", TooltipSettings.minWidth), 260)
    ) + (_barVertical ? _touchOffset : 0)
    implicitHeight: content.implicitHeight + 20 + (_barVertical ? 0 : _touchOffset)

    anchor.item: root._resolveAnchor()

    anchor.edges: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.gravity: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin:   root._barPos === 4 ? popup._touchOffset : 0
      anchors.rightMargin:  (root._barPos !== 1 && root._barPos !== 3 && root._barPos !== 4) ? popup._touchOffset : 0
      anchors.topMargin:    root._barPos === 1 ? popup._touchOffset : 0
      anchors.bottomMargin: root._barPos === 3 ? popup._touchOffset : 0
      radius: 10
      color:  root.bgColor

      Column {
        id: content
        x: 10; y: 10
        width: parent.width - 20
        spacing: 8

        // ── Tarefas de hoje ───────────────────────────────────────────────
        Row {
          id: taskHeaderRow
          spacing: 5
          Text {
            text: "\uf073"
            color: root._overdueCount > 0 ? root.accentColor : root.fgColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
          }
          Text {
            text: root._todayCount === 0
              ? "Nenhuma tarefa pra hoje"
              : (root._todayCount + " tarefa" + (root._todayCount === 1 ? "" : "s") + " pra hoje"
                 + (root._overdueCount > 0 ? " · " + root._overdueCount + " atrasada" + (root._overdueCount === 1 ? "" : "s") : ""))
            color: root._overdueCount > 0 ? root.accentColor : root.fgColor
            font.pixelSize: 11
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
          }
        }

        // um "card" por tarefa — texto completo com wrap, nada de elide
        Column {
          width: parent.width
          spacing: 6
          Repeater {
            model: root._todayTasks
            delegate: Rectangle {
              id: taskCard
              required property var modelData
              readonly property bool overdue: _tasksContent && _tasksContent.isOverdueTask(modelData)
              width: parent.width
              implicitHeight: taskCol.implicitHeight + 14
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.06)

              Column {
                id: taskCol
                x: 8; y: 7
                width: parent.width - 16
                spacing: 3

                Text {
                  width: parent.width
                  text: taskCard.modelData.text
                  wrapMode: Text.WordWrap
                  color: root.fgColor
                  font { pixelSize: 11; family: "Inter"; weight: Font.DemiBold }
                }

                Row {
                  spacing: 6
                  Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._priorityColor[taskCard.modelData.priority] || "#999999"
                  }
                  Text {
                    text: "Prioridade " + (root._priorityLabel[taskCard.modelData.priority] || "Média")
                    color: root.fgDimColor
                    font.pixelSize: 9
                  }
                }

                Text {
                  visible: !!taskCard.modelData.due
                  text: "Prazo: " + taskCard.modelData.due
                    + (taskCard.modelData.time ? " às " + taskCard.modelData.time : "")
                    + (taskCard.overdue ? " · atrasada" : "")
                  color: taskCard.overdue ? root.accentColor : root.fgDimColor
                  font { pixelSize: 9; weight: taskCard.overdue ? Font.DemiBold : Font.Normal }
                }

                Text {
                  visible: !!taskCard.modelData.recurrence && taskCard.modelData.recurrence !== "none"
                  text: "Repete: " + (root._recurrenceLabel[taskCard.modelData.recurrence] || "")
                  color: root.fgDimColor
                  font.pixelSize: 9
                }
              }
            }
          }
        }

        Rectangle {
          visible: root._habitsTotal > 0
          width: parent.width; height: 1
          color: Qt.rgba(1, 1, 1, 0.1)
        }

        // ── Hábitos ────────────────────────────────────────────────────────
        Row {
          id: habitsHeaderRow
          visible: root._habitsTotal > 0
          spacing: 5
          Text {
            text: "\uf645"
            color: root._habitsPending.length === 0 ? root.okColor : root.fgDimColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
          }
          Text {
            text: root._habitsDoneToday + "/" + root._habitsTotal + " hábitos hoje"
              + (root._habitsPending.length === 0 ? " · tudo em dia ✓" : "")
            color: root._habitsPending.length === 0 ? root.okColor : root.fgColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
          }
        }

        // lista completa dos que faltam — sem cortar, sem "+N outros"
        Column {
          visible: root._habitsPending.length > 0
          width: parent.width
          spacing: 3
          Repeater {
            model: root._habitsPending
            delegate: Text {
              required property var modelData
              width: parent.width
              text: "· " + modelData.name
              wrapMode: Text.WordWrap
              color: root.fgDimColor
              font.pixelSize: 10
            }
          }
        }
      }
    }
  }
}
