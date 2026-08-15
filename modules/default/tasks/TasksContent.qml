import qs

import QtQuick
import QtQuick.Layouts
import "../../widgets/todo"   as TodoModule
import "../../widgets/habits" as HabitsModule

// ── TasksContent ─────────────────────────────────────────────────────────
// Painel combinado Tarefas + Hábitos — visão única (sem abas): as duas
// seções ficam sempre visíveis, uma embaixo da outra, num scroll só. Um
// hero no topo resume o estado das duas (e clicando nele abre o dashboard
// correspondente) — assim quem só quer o resumo nem precisa rolar.
//
// Usa TodoConfig/HabitsConfig diretamente (a camada de dados/persistência);
// a UI aqui é própria do painel, pensada pro formato compacto de popup de
// barra — cards, não linhas soltas de widget.

Item {
  id: root

  // ── Sinais pro TasksPopup abrir as janelas de add/editar/dashboard ─────
  signal addTaskRequested()
  signal editTaskRequested(var task)
  signal dashboardRequested()

  signal addHabitRequested()
  signal editHabitRequested(var habit)
  signal habitsDashboardRequested()

  signal closeRequested()

  TodoModule.TodoConfig     { id: todoConfig }
  HabitsModule.HabitsConfig { id: habitsConfig }

  // Expõe os configs pra quem vive fora deste arquivo (Tasks.qml na barra,
  // TasksTooltip.qml) — um `id` sozinho NÃO é visível de fora do QML que o
  // declara; precisa do alias explícito.
  property alias todoConfig:   todoConfig
  property alias habitsConfig: habitsConfig

  property color colorText:    "#e2e2e2"
  property color colorTextDim: "#9e9e9e"
  property color colorAccent:  "#ffb4a9"
  property color colorDivider: "#474747"

  // ═══════════════════════════════════════════════════════════════════════
  // DADOS/HELPERS — TAREFAS
  // ═══════════════════════════════════════════════════════════════════════
  readonly property var priorityColor: ({ alta: "#e5484d", media: "#f5a524", baixa: "#45a249" })
  readonly property var priorityOrder: ({ alta: 0, media: 1, baixa: 2 })
  readonly property var priorityLabels: ({ alta: "Alta", media: "Média", baixa: "Baixa" })
  readonly property var recurrenceLabels: ({ daily: "Diária", weekly: "Semanal", monthly: "Mensal" })
  readonly property var statusColor: ({ doing: "#5b9bd5", blocked: "#e08a3c" })
  readonly property var statusLabels: ({ doing: "Em andamento", blocked: "Bloqueada" })
  function priorityLabel(id)   { return priorityLabels[id] || "Média" }
  function recurrenceLabel(id) { return recurrenceLabels[id] || "" }

  property bool _tick: false
  Timer { interval: 60000; repeat: true; running: true; onTriggered: root._tick = !root._tick }
  function todayStr() { var _ = root._tick; return Qt.formatDate(new Date(), "yyyy-MM-dd") }

  function isPinned(t)     { return !t.done && !t.due && (t.priority === "alta" || t.priority === "media") }
  function isOverdueTask(t){ return !t.done && !!t.due && t.due < root.todayStr() }
  function daysUntil(dueStr) {
    var today = new Date(root.todayStr() + "T00:00:00")
    var due   = new Date(dueStr + "T00:00:00")
    return Math.round((due - today) / 86400000)
  }
  function isDueSoon(t)  { return !!t.due && root.daysUntil(t.due) <= todoConfig.dueSoonDays }
  function isFarTask(t)  { return !t.done && !!t.due && !root.isOverdueTask(t) && root.daysUntil(t.due) > todoConfig.dueSoonDays }
  function isDueToday(t) { return !t.done && !!t.due && t.due === root.todayStr() }
  function isUpcoming(t) { return !t.done && !!t.due && root.daysUntil(t.due) > 0 && root.daysUntil(t.due) <= todoConfig.dueSoonDays }

  function comparePriority(a, b) {
    var ao = priorityOrder[a.priority] !== undefined ? priorityOrder[a.priority] : 1
    var bo = priorityOrder[b.priority] !== undefined ? priorityOrder[b.priority] : 1
    return ao - bo
  }
  function compareDueThenPriority(a, b) {
    var ad = a.due || "9999-99-99", bd = b.due || "9999-99-99"
    if (ad !== bd) return ad < bd ? -1 : 1
    return root.comparePriority(a, b)
  }

  function taskSections() {
    var base = todoConfig.tasks.slice()
    if (todoConfig.hideFarTasks) base = base.filter(function(t) { return !root.isFarTask(t) })
    var pending = base.filter(function(t) { return !t.done })

    var pinned   = pending.filter(root.isPinned).sort(root.comparePriority)
    var overdue  = pending.filter(function(t) { return !root.isPinned(t) && root.isOverdueTask(t) }).sort(root.comparePriority)
    var today    = pending.filter(function(t) { return !root.isPinned(t) && root.isDueToday(t) }).sort(root.comparePriority)
    var upcoming = pending.filter(function(t) { return !root.isPinned(t) && root.isUpcoming(t) }).sort(root.compareDueThenPriority)
    var other    = pending.filter(function(t) {
      return !root.isPinned(t) && !root.isOverdueTask(t) && !root.isDueToday(t) && !root.isUpcoming(t)
    }).sort(root.compareDueThenPriority)
    var done = todoConfig.showCompleted
      ? base.filter(function(t) { return t.done }).sort(function(a, b) { return (b.due || "") < (a.due || "") ? -1 : 1 })
      : []

    var result = []
    if (pinned.length)   result.push({ key: "pinned",   label: "Fixadas",           tasks: pinned })
    if (overdue.length)  result.push({ key: "overdue",  label: "Atrasadas",         tasks: overdue })
    if (today.length)    result.push({ key: "today",    label: "Hoje",              tasks: today })
    if (upcoming.length) result.push({ key: "upcoming", label: "Próximos dias",     tasks: upcoming })
    if (other.length)    result.push({ key: "other",    label: "Sem prazo próximo", tasks: other })
    if (done.length)     result.push({ key: "done",     label: "Concluídas",        tasks: done })
    return result
  }

  readonly property int pendingCount: todoConfig.tasks.filter(function(t) { return !t.done }).length
  readonly property int overdueCount: {
    var list = todoConfig.tasks, n = 0
    for (var i = 0; i < list.length; i++) if (!list[i].done && root.isOverdueTask(list[i])) n++
    return n
  }
  readonly property bool hasOverdueTasks: root.overdueCount > 0
  readonly property int dueTodayCount: {
    var list = todoConfig.tasks, n = 0
    for (var i = 0; i < list.length; i++) if (root.isDueToday(list[i])) n++
    return n
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DADOS/HELPERS — HÁBITOS
  // ═══════════════════════════════════════════════════════════════════════
  readonly property var visibleHabits: habitsConfig.habits.slice(0, habitsConfig.maxVisible)
  readonly property int extraHabitsCount: Math.max(0, habitsConfig.habits.length - habitsConfig.maxVisible)
  readonly property int habitsDoneToday: {
    var today = root.todayStr(), n = 0
    for (var i = 0; i < habitsConfig.habits.length; i++) {
      var st = habitsConfig.habitStatus(habitsConfig.habits[i], today)
      if (st === "hit" || st === "limit") n++
    }
    return n
  }

  function _tint(a) { return Qt.rgba(1, 1, 1, a) }

  // ═══════════════════════════════════════════════════════════════════════
  // TOOLTIP DE HOVER — mesmo mecanismo do TodoContent.qml: um card único,
  // reaproveitado e reposicionado pra colar embaixo da linha sob o mouse.
  // Existe porque o painel é compacto (300px) e elide corta nome de tarefa
  // longo — o tooltip mostra tudo por extenso, sem cortar nada.
  // ═══════════════════════════════════════════════════════════════════════
  property var  tooltipTask:    null
  property var  tooltipHabit:   null
  property real tooltipY:       0
  property bool tooltipVisible: false

  Timer { id: tooltipShowTimer; interval: 380; onTriggered: root.tooltipVisible = true }

  function requestTaskTooltip(task, anchorItem) {
    root.tooltipHabit = null
    root.tooltipTask  = task
    root.tooltipY     = anchorItem.mapToItem(root, 0, anchorItem.height + 4).y
    if (!root.tooltipVisible) tooltipShowTimer.restart()
  }
  function requestHabitTooltip(habit, anchorItem) {
    root.tooltipTask  = null
    root.tooltipHabit = habit
    root.tooltipY     = anchorItem.mapToItem(root, 0, anchorItem.height + 4).y
    if (!root.tooltipVisible) tooltipShowTimer.restart()
  }
  function hideTaskTooltip(task) {
    if (root.tooltipTask && task && root.tooltipTask.id !== task.id) return
    tooltipShowTimer.stop()
    root.tooltipVisible = false
    root.tooltipTask    = null
  }
  function hideHabitTooltip(habit) {
    if (root.tooltipHabit && habit && root.tooltipHabit.id !== habit.id) return
    tooltipShowTimer.stop()
    root.tooltipVisible = false
    root.tooltipHabit   = null
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAMANHO
  // ═══════════════════════════════════════════════════════════════════════
  implicitWidth:  300
  implicitHeight: mainCol.implicitHeight + 28

  ColumnLayout {
    id: mainCol
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    // ── Cabeçalho ──────────────────────────────────────────────────────
    Text {
      Layout.fillWidth: true
      text: "Tarefas & Hábitos"
      color: root.colorText
      opacity: 0.55
      font { pixelSize: 10; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1; capitalization: Font.AllUppercase }
    }

    // ── Hero: dois cards de resumo — clicar abre o dashboard completo ────
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Rectangle {
        id: taskCard
        Layout.fillWidth: true
        Layout.preferredHeight: 66
        radius: 12
        color: taskCardMa.containsMouse ? root._tint(0.09) : root._tint(0.05)
        Behavior on color { ColorAnimation { duration: 100 } }

        ColumnLayout {
          anchors { fill: parent; margins: 10 }
          spacing: 1

          RowLayout {
            spacing: 5
            Text {
              text: "\uf0ae"
              color: root.hasOverdueTasks ? root.colorAccent : root.colorTextDim
              font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
            }
            Text {
              text: "TAREFAS"
              color: root.colorTextDim
              font { pixelSize: 9; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1 }
            }
          }
          Text {
            text: String(root.pendingCount)
            color: root.hasOverdueTasks ? root.colorAccent : root.colorText
            font { pixelSize: 22; family: "Inter"; weight: Font.Bold }
          }
          Text {
            text: root.pendingCount === 0 ? "tudo em dia"
              : (root.hasOverdueTasks ? root.overdueCount + " atrasada" + (root.overdueCount === 1 ? "" : "s") : "pendentes")
            color: root.hasOverdueTasks ? root.colorAccent : root.colorTextDim
            opacity: 0.85
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: taskCardMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.dashboardRequested()
        }
      }

      Rectangle {
        id: habitCard
        Layout.fillWidth: true
        Layout.preferredHeight: 66
        radius: 12
        color: habitCardMa.containsMouse ? root._tint(0.09) : root._tint(0.05)
        Behavior on color { ColorAnimation { duration: 100 } }

        readonly property bool allDone: habitsConfig.habits.length > 0 && root.habitsDoneToday === habitsConfig.habits.length

        ColumnLayout {
          anchors { fill: parent; margins: 10 }
          spacing: 1

          RowLayout {
            spacing: 5
            Text {
              text: "\uf645"
              color: habitCard.allDone ? "#45a249" : root.colorTextDim
              font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
            }
            Text {
              text: "HÁBITOS"
              color: root.colorTextDim
              font { pixelSize: 9; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1 }
            }
          }
          Text {
            text: habitsConfig.habits.length === 0 ? "—" : (root.habitsDoneToday + "/" + habitsConfig.habits.length)
            color: habitCard.allDone ? "#45a249" : root.colorText
            font { pixelSize: 22; family: "Inter"; weight: Font.Bold }
          }
          Text {
            text: habitsConfig.habits.length === 0 ? "nenhum cadastrado"
              : (habitCard.allDone ? "tudo em dia" : "hoje")
            color: habitCard.allDone ? "#45a249" : root.colorTextDim
            opacity: 0.85
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: habitCardMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.habitsDashboardRequested()
        }
      }
    }

    // ── Corpo: as duas seções, sempre juntas, um scroll só ────────────────
    Item {
      id: body
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(420, contentCol.implicitHeight)
      implicitHeight: contentCol.implicitHeight
      clip: true

      Flickable {
        id: bodyFlick
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onMovementStarted: { root.hideTaskTooltip(null); root.hideHabitTooltip(null) }

        ColumnLayout {
          id: contentCol
          width: parent.width
          spacing: 14

          // ── Seção Tarefas ───────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "TAREFAS"
                color: root.colorTextDim
                opacity: 0.75
                font { pixelSize: 9; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1 }
              }
              Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root._tint(0.08) }
              Rectangle {
                width: 20; height: 20; radius: 5
                color: addTaskMa.containsMouse ? root._tint(0.14) : root._tint(0.07)
                Behavior on color { ColorAnimation { duration: 80 } }
                Text { anchors.centerIn: parent; text: "+"; color: root.colorText; font.pixelSize: 13 }
                MouseArea {
                  id: addTaskMa
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.addTaskRequested()
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: root.taskSections().length === 0
              text: "nenhuma tarefa por aqui 🎉"
              horizontalAlignment: Text.AlignHCenter
              color: root.colorTextDim
              opacity: 0.55
              font.pixelSize: 11
              Layout.topMargin: 4
              Layout.bottomMargin: 4
            }

            Repeater {
              model: root.taskSections()
              delegate: ColumnLayout {
                id: sectionDelegate
                required property var modelData
                Layout.fillWidth: true
                spacing: 2

                Text {
                  text: sectionDelegate.modelData.label + " · " + sectionDelegate.modelData.tasks.length
                  color: sectionDelegate.modelData.key === "overdue" ? root.colorAccent : root.colorTextDim
                  opacity: sectionDelegate.modelData.key === "overdue" ? 0.9 : 0.55
                  font { pixelSize: 9; family: "Inter"; weight: Font.Medium }
                  Layout.topMargin: 2
                }

                Repeater {
                  model: sectionDelegate.modelData.tasks
                  delegate: Rectangle {
                    id: taskRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 7
                    readonly property bool overdue: root.isOverdueTask(modelData)
                    color: taskRowHover.hovered ? root._tint(0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    HoverHandler {
                      id: taskRowHover
                      onHoveredChanged: {
                        if (hovered) root.requestTaskTooltip(taskRow.modelData, taskRow)
                        else root.hideTaskTooltip(taskRow.modelData)
                      }
                    }

                    RowLayout {
                      anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                      spacing: 7

                      Rectangle {
                        width: 13; height: 13; radius: 6.5
                        border.width: 1.5
                        border.color: taskRow.modelData.done ? "#45a249" : root._tint(0.4)
                        color: taskRow.modelData.done ? "#45a249" : "transparent"
                        MouseArea {
                          anchors.fill: parent; anchors.margins: -3
                          cursorShape: Qt.PointingHandCursor
                          onClicked: todoConfig.toggleTask(taskRow.modelData.id)
                        }
                      }

                      Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.priorityColor[taskRow.modelData.priority] || "#999999"
                      }

                      Text {
                        Layout.fillWidth: true
                        text: taskRow.modelData.text
                        color: taskRow.overdue ? "#ff6b6b" : root.colorText
                        opacity: taskRow.modelData.done ? 0.45 : 1.0
                        font { pixelSize: 11; family: "Inter"; strikeout: taskRow.modelData.done }
                        elide: Text.ElideRight
                      }

                      Text {
                        visible: !!taskRow.modelData.due && (taskRow.overdue || root.isDueSoon(taskRow.modelData))
                        text: taskRow.modelData.due.slice(5) + (taskRow.modelData.time ? " " + taskRow.modelData.time : "")
                        color: taskRow.overdue ? "#ff6b6b" : root.colorTextDim
                        font { pixelSize: 8; weight: taskRow.overdue ? Font.DemiBold : Font.Normal }
                      }

                      Text {
                        visible: taskRowHover.hovered
                        text: "\uf044"
                        color: root.colorTextDim
                        opacity: 0.6
                        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        MouseArea {
                          anchors.fill: parent; anchors.margins: -4
                          cursorShape: Qt.PointingHandCursor
                          hoverEnabled: true
                          onClicked: root.editTaskRequested(taskRow.modelData)
                        }
                      }
                      Text {
                        visible: taskRowHover.hovered
                        text: "×"
                        color: root.colorTextDim
                        opacity: 0.6
                        font.pixelSize: 13
                        MouseArea {
                          anchors.fill: parent; anchors.margins: -4
                          cursorShape: Qt.PointingHandCursor
                          onClicked: todoConfig.removeTask(taskRow.modelData.id)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.colorDivider; opacity: 0.3 }

          // ── Seção Hábitos ────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "HÁBITOS"
                color: root.colorTextDim
                opacity: 0.75
                font { pixelSize: 9; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1 }
              }
              Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root._tint(0.08) }
              Rectangle {
                width: 20; height: 20; radius: 5
                color: addHabitMa.containsMouse ? root._tint(0.14) : root._tint(0.07)
                Behavior on color { ColorAnimation { duration: 80 } }
                Text { anchors.centerIn: parent; text: "+"; color: root.colorText; font.pixelSize: 13 }
                MouseArea {
                  id: addHabitMa
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.addHabitRequested()
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: habitsConfig.habits.length === 0
              text: "nenhum hábito cadastrado"
              horizontalAlignment: Text.AlignHCenter
              color: root.colorTextDim
              opacity: 0.55
              font.pixelSize: 11
              Layout.topMargin: 4
              Layout.bottomMargin: 4
            }

            Repeater {
              model: root.visibleHabits
              delegate: Rectangle {
                id: habitRowWrap
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 7
                color: habitRowHover.hovered ? root._tint(0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }
                HoverHandler {
                  id: habitRowHover
                  onHoveredChanged: {
                    if (hovered) root.requestHabitTooltip(habitRowWrap.modelData, habitRowWrap)
                    else root.hideHabitTooltip(habitRowWrap.modelData)
                  }
                }

                Loader {
                  anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                  sourceComponent: habitRowWrap.modelData.kind === "count" ? countHabitRow : checkHabitRow
                  property var habit: habitRowWrap.modelData
                }
              }
            }

            Text {
              visible: root.extraHabitsCount > 0
              text: "+" + root.extraHabitsCount + " mais — ver no painel"
              color: root.colorTextDim
              opacity: 0.55
              font.pixelSize: 9
              Layout.topMargin: 2

              MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.habitsDashboardRequested()
              }
            }
          }
        }
      }
    }
  }

  // ── Card do tooltip de hover — único, reaproveitado, reposicionado pra
  // colar embaixo da linha sob o mouse. Fica FORA do Flickable (irmão do
  // mainCol) de propósito: assim não é cortado pelo clip do corpo e não
  // fica espremido no espaço apertado do painel.
  Rectangle {
    id: tooltipCard
    visible: root.tooltipVisible && (root.tooltipTask !== null || root.tooltipHabit !== null)
    opacity: visible ? 1 : 0
    z: 1000
    x: 14
    y: root.tooltipY
    width: 244
    implicitHeight: tooltipCol.implicitHeight + 20
    radius: 10
    color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
    border.color: Qt.rgba(1, 1, 1, 0.14); border.width: 1
    Behavior on opacity { NumberAnimation { duration: 90 } }

    ColumnLayout {
      id: tooltipCol
      anchors { fill: parent; margins: 10 }
      spacing: 5

      // ── conteúdo quando é uma tarefa ────────────────────────────────────
      Text {
        Layout.fillWidth: true
        visible: !!root.tooltipTask
        text: root.tooltipTask ? root.tooltipTask.text : ""
        wrapMode: Text.WordWrap
        color: root.colorText
        font { pixelSize: 11; family: "Inter"; weight: Font.DemiBold
               strikeout: root.tooltipTask ? !!root.tooltipTask.done : false }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: !!root.tooltipTask

        Rectangle {
          width: 8; height: 8; radius: 4
          color: root.tooltipTask ? (root.priorityColor[root.tooltipTask.priority] || "#999999") : "transparent"
        }
        Text {
          text: root.tooltipTask ? ("Prioridade " + root.priorityLabel(root.tooltipTask.priority)) : ""
          color: root.colorTextDim
          font.pixelSize: 9
        }
        Item { Layout.fillWidth: true }
        Text {
          visible: !!(root.tooltipTask && root.tooltipTask.done)
          text: "concluída"
          color: "#45a249"
          font.pixelSize: 9
        }
        Text {
          visible: !!(root.tooltipTask && !root.tooltipTask.done && root.tooltipTask.status && root.statusLabels[root.tooltipTask.status] !== undefined)
          text: root.tooltipTask ? (root.statusLabels[root.tooltipTask.status] || "") : ""
          color: root.tooltipTask ? (root.statusColor[root.tooltipTask.status] || root.colorTextDim) : root.colorTextDim
          font.pixelSize: 9
        }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.due)
        text: root.tooltipTask
          ? ("Prazo: " + root.tooltipTask.due + (root.tooltipTask.time ? " às " + root.tooltipTask.time : "") + (root.isOverdueTask(root.tooltipTask) ? " · atrasada" : ""))
          : ""
        color: (root.tooltipTask && root.isOverdueTask(root.tooltipTask)) ? root.colorAccent : root.colorTextDim
        font { pixelSize: 9; weight: (root.tooltipTask && root.isOverdueTask(root.tooltipTask)) ? Font.DemiBold : Font.Normal }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.recurrence && root.tooltipTask.recurrence !== "none")
        text: root.tooltipTask ? ("Repete: " + root.recurrenceLabel(root.tooltipTask.recurrence)) : ""
        color: root.colorTextDim
        font.pixelSize: 9
      }

      Flow {
        Layout.fillWidth: true
        spacing: 4
        visible: !!(root.tooltipTask && root.tooltipTask.tags && root.tooltipTask.tags.length > 0)

        Repeater {
          model: (root.tooltipTask && root.tooltipTask.tags) || []
          delegate: Rectangle {
            required property string modelData
            width: ttTagLabel.implicitWidth + 10; height: 15; radius: 7
            color: root._tint(0.12)
            Text {
              id: ttTagLabel
              anchors.centerIn: parent
              text: modelData
              color: root.colorTextDim
              font.pixelSize: 8
            }
          }
        }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.created)
        text: root.tooltipTask ? ("Criada em " + Qt.formatDateTime(new Date(root.tooltipTask.created), "dd/MM/yyyy")) : ""
        color: root.colorTextDim
        opacity: 0.7
        font.pixelSize: 8
      }

      // ── conteúdo quando é um hábito ─────────────────────────────────────
      Text {
        visible: !!root.tooltipHabit
        Layout.fillWidth: true
        text: root.tooltipHabit ? root.tooltipHabit.name : ""
        wrapMode: Text.WordWrap
        color: root.colorText
        font { pixelSize: 11; family: "Inter"; weight: Font.DemiBold }
      }
      Text {
        visible: !!root.tooltipHabit
        text: root.tooltipHabit ? ("Sequência atual: " + habitsConfig.streakFor(root.tooltipHabit) + " dia(s)") : ""
        color: root.colorTextDim
        font.pixelSize: 9
      }
      Text {
        visible: !!(root.tooltipHabit && root.tooltipHabit.kind === "count")
        text: root.tooltipHabit
          ? ("Hoje: " + habitsConfig.amountOn(root.tooltipHabit, habitsConfig._todayKey())
             + "/" + root.tooltipHabit.target + (root.tooltipHabit.unit ? " " + root.tooltipHabit.unit : ""))
          : ""
        color: root.colorTextDim
        font.pixelSize: 9
      }
      Text {
        visible: !!(root.tooltipHabit && root.tooltipHabit.kind !== "count")
        text: root.tooltipHabit
          ? ("Hoje: " + (habitsConfig.isDoneOn(root.tooltipHabit, habitsConfig._todayKey()) ? "cumprido ✓" : "ainda não cumprido"))
          : ""
        color: root.colorTextDim
        font.pixelSize: 9
      }
    }
  }

  // ── linha de hábito "check" ─────────────────────────────────────────────
  Component {
    id: checkHabitRow
    RowLayout {
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      width: parent ? parent.width : undefined
      spacing: 8

      Rectangle {
        id: check
        readonly property bool done: habitsConfig.isDoneOn(habit, habitsConfig._todayKey())
        width: 15; height: 15; radius: 4
        color: done ? Colors[habit.color] : "transparent"
        border.width: 1.5
        border.color: done ? Colors[habit.color] : Qt.rgba(1, 1, 1, 0.35)
        scale: checkArea.pressed ? 0.85 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
          anchors.centerIn: parent
          visible: check.done
          text: "✓"
          color: "black"
          font.pixelSize: 10
          font.bold: true
        }
        MouseArea {
          id: checkArea
          anchors.fill: parent; anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: habitsConfig.toggleToday(habit.id)
        }
      }

      Text {
        Layout.fillWidth: true
        text: habit.name
        color: root.colorText
        opacity: 0.9
        font.pixelSize: 11
        elide: Text.ElideRight
      }

      Text {
        text: habitsConfig.streakFor(habit) + "d"
        color: Colors[habit.color]
        opacity: habitsConfig.streakFor(habit) > 0 ? 1 : 0.35
        font { pixelSize: 10; family: "Inter"; weight: Font.DemiBold }
      }
    }
  }

  // ── linha de hábito "count" ─────────────────────────────────────────────
  Component {
    id: countHabitRow
    RowLayout {
      id: countRowRoot
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      width: parent ? parent.width : undefined
      spacing: 6

      readonly property int amount: habitsConfig.amountOn(habit, habitsConfig._todayKey())
      readonly property real ratio: habitsConfig.progressOn(habit, habitsConfig._todayKey())
      readonly property string status: habitsConfig.habitStatus(habit, habitsConfig._todayKey())
      readonly property color statusC: habitsConfig.statusColor(countRowRoot.status) || Colors[habit.color]

      Canvas {
        id: ring
        width: 16; height: 16
        property color c: countRowRoot.statusC
        property real _ratio: countRowRoot.status === "over" ? 1 : countRowRoot.ratio
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var cx = width / 2, cy = height / 2, r = width / 2 - 2
          ctx.lineWidth = 2.2
          ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.2)
          ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
          if (_ratio > 0) {
            ctx.strokeStyle = c
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, _ratio))
            ctx.stroke()
          }
        }
        onCChanged: requestPaint()
        on_RatioChanged: requestPaint()
        Component.onCompleted: requestPaint()
      }

      Text {
        Layout.fillWidth: true
        text: habit.name
        color: root.colorText
        opacity: 0.9
        font.pixelSize: 11
        elide: Text.ElideRight
      }

      Text {
        text: countRowRoot.amount + "/" + habit.target + (habit.unit ? " " + habit.unit : "")
        color: countRowRoot.status === "over" ? habitsConfig.statusColorOver : root.colorTextDim
        font { pixelSize: 9; family: "Inter" }
      }

      Text {
        text: "−"
        visible: countRowRoot.amount > 0
        color: root.colorTextDim
        font { pixelSize: 12; bold: true }
        MouseArea {
          anchors.fill: parent; anchors.margins: -5
          cursorShape: Qt.PointingHandCursor
          onClicked: habitsConfig.logCount(habit.id, -1)
        }
      }
      Rectangle {
        width: 15; height: 15; radius: 4
        color: Qt.rgba(countRowRoot.statusC.r, countRowRoot.statusC.g, countRowRoot.statusC.b, 0.18)
        Text {
          anchors.centerIn: parent
          text: "+"
          color: countRowRoot.statusC
          font { pixelSize: 11; bold: true }
        }
        MouseArea {
          anchors.fill: parent; anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: habitsConfig.logCount(habit.id, 1)
        }
      }
    }
  }
}
