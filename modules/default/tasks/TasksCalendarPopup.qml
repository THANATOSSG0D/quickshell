import Quickshell
import QtQuick
import "../bar" as Bar
import "../../widgets/todo" as TodoModule

// ── TasksCalendarPopup ──────────────────────────────────────────────────
// Painel do calendário de tarefas. Aberto pelo botão direito no módulo
// Tasks da barra (Tasks.qml → calendarRequested) ou pelo ícone de
// calendário no cabeçalho do TasksPopup (TasksContent.qml →
// calendarRequested) — Bar.qml decide qual panelId abrir em ambos os
// casos. Mesmo esquema de todos os outros popups (filho QML do
// PanelWindow da barra).
//
// todoConfig é INJETADO por Bar.qml, reaproveitando a MESMA instância que
// já vive dentro do TasksPopup (tasksPopup.tasksContentRef.todoConfig) —
// evita ter dois TodoConfig/FileView separados lendo e escrevendo o mesmo
// Todo.json ao mesmo tempo.

Bar.BarPopup {
  id: popup
  objectName: "TasksCalendarPopup"

  popupW: 320
  popupH: 480

  property var todoConfig: null

  TodoModule.TodoAddWindow { id: addTaskWindow }

  TasksCalendarContent {
    id: content
    anchors.fill: parent
    todoConfig:   popup.todoConfig
    colorText:    popup.colorText
    colorTextDim: popup.colorTextDim
    colorAccent:  popup.colorAccent
    colorDivider: popup.colorDivider

    // openForm() recebe um objeto de pré-preenchimento opcional — se o seu
    // TodoAddWindow.openForm() ainda não aceitar isso, o argumento extra é
    // simplesmente ignorado (QML/JS não reclama de argumento a mais), e o
    // campo de data fica em branco pra preencher na mão. Se quiser o
    // pré-preenchimento de verdade funcionando, é só o openForm() aceitar
    // um objeto parcial (mesma ideia do openEdit(task)) e usar opts.due
    // como valor inicial do campo de data.
    onAddTaskRequested:  (dueDate) => addTaskWindow.openForm({ due: dueDate })
    onEditTaskRequested: (task)    => addTaskWindow.openEdit(task)
  }
}
