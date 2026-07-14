import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../" as Shared

Scope {
  id: todoWidget

  TodoConfig { id: config }
  Shared.WidgetLayoutConfig { id: layoutCfg }

  // Janela centralizada de "nova tarefa" — única por Scope, reaproveitada
  // por qualquer tela onde o "+ nova tarefa" for clicado (ver referência
  // por id dentro do delegate abaixo).
  TodoAddWindow { id: addTaskWindow }

  // Painel grande (Kanban / Progresso / Agenda) — mesma ideia, uma
  // instância só, reaproveitada. Edição de tarefa dentro do painel abre a
  // mesma TodoAddWindow acima.
  TodoDashboard {
    id: dashboardWindow
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onAddTaskRequested: addTaskWindow.openForm()
  }

  Variants {
    model: (layoutCfg.isGrouped("todo") || !layoutCfg.isEnabled("todo")) ? [] : Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "todo-widget"

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
            if (positions[config.position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[config.position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[config.position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[config.position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: todoContent.implicitWidth
          height: todoContent.implicitHeight

          TodoContent {
            id: todoContent
            grouped: false
            onAddTaskRequested: addTaskWindow.openForm()
            onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
            onDashboardRequested: dashboardWindow.open()
          }
        }
      }
    }
  }
}
