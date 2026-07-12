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
// Quando existe pelo menos um grupo ativo em WidgetLayoutConfig.groups,
// essa é a ÚNICA janela que renderiza os widgets agrupados: um card por
// grupo (cada um com sua própria posição/margem), empilhados em ordem
// dentro do card, com divisores finos entre eles em vez de cada um
// flutuar separado. Os Widget.qml individuais (ClockWidget, TodoWidget,
// etc.) se desligam sozinhos quando o widget deles está em algum grupo
// (ver isGrouped() em cada um).

Scope {
  id: widgetHost

  WidgetLayoutConfig { id: layoutCfg }

  // Janela centralizada de "nova tarefa" do módulo Todo (se ele estiver
  // presente em algum grupo) — mesma janela usada pelo modo não-agrupado,
  // compartilhada entre todos os cards.
  TodoAddWindow { id: addTaskWindow }

  // Painel grande (Kanban / Progresso / Agenda) do módulo Todo — mesma
  // ideia, uma instância só pra todos os grupos.
  TodoDashboard {
    id: dashboardWindow
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onAddTaskRequested: addTaskWindow.openForm()
  }

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

  // produto cartesiano tela × grupo-ativo — cada combinação vira uma
  // PanelWindow própria, então grupos com posições diferentes na mesma
  // tela não brigam pela mesma janela/máscara
  readonly property var _instances: {
    const list = []
    const activeGroups = layoutCfg.groups.filter(g => g.enabled && g.members.length > 0)
    for (const screen of Quickshell.screens) {
      for (const group of activeGroups) {
        list.push({ screen: screen, group: group })
      }
    }
    return list
  }

  Variants {
    model: widgetHost._instances

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        readonly property var group: modelData.group
        screen: modelData.screen

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "widget-group-" + group.id

        // data selecionada no Calendário (yyyy-MM-dd, "" = nenhuma) —
        // estado por card, só existe enquanto os dois widgets (calendar +
        // todo) estiverem juntos NESSE grupo. Ver wiring genérico no
        // Loader abaixo: não é específico de tipo, só liga quando os dois
        // membros existem e expõem as propriedades/sinais esperados.
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
            if (positions[panel.group.position].h === Qt.AlignLeft)  return panel.group.edgeMargin
            if (positions[panel.group.position].h === Qt.AlignRight) return parent.width - width - panel.group.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[panel.group.position].v === Qt.AlignTop)    return panel.group.edgeMargin
            if (positions[panel.group.position].v === Qt.AlignBottom) return parent.height - height - panel.group.edgeMargin
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
                model: panel.group.members
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
                      // selecionada pro estado do card; a própria borda de
                      // seleção do calendário fica amarrada a esse mesmo
                      // estado (some se o filtro for limpo pelo lado do Todo).
                      if (item && item.dateSelected !== undefined) {
                        item.selectedDate = Qt.binding(function() { return panel.todoFilterDate })
                        item.dateSelected.connect(function(date) { panel.todoFilterDate = date })
                      }

                      // Todo combinado: filtra pela data escolhida no
                      // calendário (se ele também estiver nesse mesmo
                      // grupo — do contrário todoFilterDate nunca sai de
                      // "") e permite limpar o filtro pelo "×" do próprio
                      // cabeçalho.
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
                    visible: index < panel.group.members.length - 1
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
