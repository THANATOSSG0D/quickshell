import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "clock"
import "todo"
import "calendar"
import "weather"

// ── WidgetHost ──────────────────────────────────────────────────────────
// Quando o modo combinado está ativo (WidgetLayoutConfig.groupEnabled),
// essa é a ÚNICA janela que renderiza os widgets listados em `members`,
// empilhados em ordem dentro de um card compartilhado, com divisores finos
// entre eles em vez de cada um flutuar separado. Os Widget.qml individuais
// (ClockWidget, TodoWidget, etc.) se desligam sozinhos quando o widget
// deles está em `members` (ver isGrouped() em cada um).

Scope {
  id: widgetHost

  WidgetLayoutConfig { id: layoutCfg }

  // Janela centralizada de "nova tarefa" do módulo Todo (se ele estiver
  // presente no grupo) — mesma janela usada pelo modo não-agrupado.
  TodoAddWindow { id: addTaskWindow }

  // Painel grande (Kanban / Progresso / Agenda) do módulo Todo — mesma
  // ideia, uma instância só.
  TodoDashboard {
    id: dashboardWindow
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onAddTaskRequested: addTaskWindow.openForm()
  }

  readonly property var labels: ({
    clock: "Relógio", todo: "Tarefas", calendar: "Calendário", weather: "Clima",
  })

  Component { id: clockComp;    ClockContent    { grouped: true } }
  Component { id: todoComp;     TodoContent     { grouped: true } }
  Component { id: calendarComp; CalendarContent { grouped: true } }
  Component { id: weatherComp;  WeatherContent  { grouped: true } }

  function componentFor(id) {
    switch (id) {
      case "clock":    return clockComp
      case "todo":     return todoComp
      case "calendar": return calendarComp
      case "weather":  return weatherComp
    }
    return null
  }

  Variants {
    model: (layoutCfg.groupEnabled && layoutCfg.members.length > 0) ? Quickshell.screens : []

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "widget-group"

        // data selecionada no Calendário (yyyy-MM-dd, "" = nenhuma) —
        // estado por tela, só existe enquanto os dois widgets (calendar +
        // todo) estiverem juntos no grupo. Ver wiring genérico no Loader
        // abaixo: não é específico de tipo, só liga quando os dois membros
        // existem e expõem as propriedades/sinais esperados.
        property string todoFilterDate: ""

        mask: Region { item: content }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
          { h: Qt.AlignRight,   v: Qt.AlignBottom  },
        ]

        Item {
          id: content
          x: {
            if (positions[layoutCfg.position].h === Qt.AlignLeft)  return layoutCfg.edgeMargin
            if (positions[layoutCfg.position].h === Qt.AlignRight) return parent.width - width - layoutCfg.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[layoutCfg.position].v === Qt.AlignTop)    return layoutCfg.edgeMargin
            if (positions[layoutCfg.position].v === Qt.AlignBottom) return parent.height - height - layoutCfg.edgeMargin
            return (parent.height - height) / 2
          }
          width: card.width
          height: card.implicitHeight

          Rectangle {
            id: card
            width: memberColumn.implicitWidth + 24
            implicitHeight: memberColumn.implicitHeight + 24
            radius: 14
            color: Qt.rgba(0.07, 0.07, 0.08, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            ColumnLayout {
              id: memberColumn
              anchors.centerIn: parent
              spacing: 0

              Repeater {
                model: layoutCfg.members
                delegate: ColumnLayout {
                  required property string modelData
                  required property int index
                  Layout.fillWidth: true
                  spacing: 0

                  Loader {
                    Layout.alignment: Qt.AlignHCenter
                    sourceComponent: widgetHost.componentFor(modelData)
                    onLoaded: {
                      if (item && item.addTaskRequested !== undefined)
                        item.addTaskRequested.connect(function() { addTaskWindow.openForm() })
                      if (item && item.editTaskRequested !== undefined)
                        item.editTaskRequested.connect(function(task) { addTaskWindow.openEdit(task) })
                      if (item && item.dashboardRequested !== undefined)
                        item.dashboardRequested.connect(function() { dashboardWindow.open() })

                      // Calendário combinado: clicar num dia informa a data
                      // selecionada pro estado da tela; a própria borda de
                      // seleção do calendário fica amarrada a esse mesmo
                      // estado (some se o filtro for limpo pelo lado do Todo).
                      if (item && item.dateSelected !== undefined) {
                        item.selectedDate = Qt.binding(function() { return panel.todoFilterDate })
                        item.dateSelected.connect(function(date) { panel.todoFilterDate = date })
                      }

                      // Todo combinado: filtra pela data escolhida no
                      // calendário (se ele também estiver no grupo — do
                      // contrário todoFilterDate nunca sai de "") e permite
                      // limpar o filtro pelo "×" do próprio cabeçalho.
                      if (item && item.filterDate !== undefined) {
                        item.filterDate = Qt.binding(function() { return panel.todoFilterDate })
                        if (item.clearFilterRequested !== undefined)
                          item.clearFilterRequested.connect(function() { panel.todoFilterDate = "" })
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10; Layout.bottomMargin: 10
                    height: 1
                    visible: index < layoutCfg.members.length - 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
