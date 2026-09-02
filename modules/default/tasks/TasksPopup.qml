import Quickshell
import QtQuick
import "../bar" as Bar
import "../../widgets/todo"   as TodoModule
import "../../widgets/habits" as HabitsModule

// ── TasksPopup ───────────────────────────────────────────────────────────
// Popup do módulo combinado Tarefas + Hábitos. Filho QML do PanelWindow da
// barra — mesmo esquema do ClockPopup (posicionamento via anchor.window/
// rect/edges definido em Bar.qml).
//
// tasksContentRef expõe o TasksContent pra que Tasks.qml receba a injeção
// de "tasksContent" feita em Bar.qml → onLoaded (mesmo padrão de
// clockContentRef/clockContent).
//
// As janelas de "adicionar/editar tarefa" e "adicionar/editar hábito" e os
// dashboards grandes são instanciadas aqui — uma única vez, reaproveitadas
// — exatamente como TodoWidget.qml / HabitsWidget.qml fazem para os
// widgets de área de trabalho standalone.

Bar.BarPopup {
  id: popup
  objectName: "TasksPopup"

  popupW: 300
  popupH: 560

  // Cores herdadas do Bar.BarPopup — ver nota em VolumePopupTabbed.qml

  // Referência capturada por Bar.qml para injetar em Tasks.qml
  readonly property var tasksContentRef: content

  // Repassa o pedido de abrir o calendário pro Bar.qml (mesmo esquema do
  // closeRequested do BarPopup) — quem decide o que fazer (abrir
  // panelTasksCalendar) é o Bar.qml, na instanciação deste popup.
  signal calendarRequested()

  // Injetada por Bar.qml a partir de barState.config.tasksCalendarEnabled — controla
  // se o ícone de calendário aparece no cabeçalho de TasksContent.
  property bool calendarEnabled: true

  TodoModule.TodoAddWindow  { id: addTaskWindow }
  HabitsModule.HabitsAddWindow { id: addHabitWindow }

  TodoModule.TodoDashboard {
    id: todoDashboardWindow
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onAddTaskRequested:  addTaskWindow.openForm()
  }

  HabitsModule.HabitsDashboard {
    id: habitsDashboardWindow
    onEditHabitRequested: (habit) => addHabitWindow.openEdit(habit)
    onAddHabitRequested:  addHabitWindow.openForm()
  }

  TasksContent {
    id: content
    anchors.fill: parent
    colorText:    popup.colorText
    colorTextDim: popup.colorTextDim
    colorAccent:  popup.colorAccent
    colorDivider: popup.colorDivider
    calendarEnabled: popup.calendarEnabled

    onAddTaskRequested:  addTaskWindow.openForm()
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onDashboardRequested: todoDashboardWindow.open()
    onCalendarRequested: popup.calendarRequested()

    onAddHabitRequested:  addHabitWindow.openForm()
    onEditHabitRequested: (habit) => addHabitWindow.openEdit(habit)
    onHabitsDashboardRequested: habitsDashboardWindow.open()

    onCloseRequested: popup.closeRequested()
  }
}
