import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../" as Shared

Scope {
  id: habitsWidget

  HabitsConfig { id: config }
  Shared.WidgetLayoutConfig { id: layoutCfg }

  property int position: config.position
  onPositionChanged: config.position = position

  // Janela centralizada de "novo/editar hábito" — única por Scope,
  // reaproveitada por qualquer tela (mesmo padrão do TodoAddWindow).
  HabitsAddWindow { id: addHabitWindow }

  // Painel grande (Hábitos / Histórico) — mesma ideia, uma instância só.
  // Edição de hábito dentro do painel abre a mesma HabitsAddWindow acima.
  HabitsDashboard {
    id: dashboardWindow
    onEditHabitRequested: (habit) => addHabitWindow.openEdit(habit)
    onAddHabitRequested: addHabitWindow.openForm()
  }

  Variants {
    model: (layoutCfg.isGrouped("habits") || !layoutCfg.isEnabled("habits")) ? [] : Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "habits-widget"

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
            if (positions[position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: habitsContent.implicitWidth
          height: habitsContent.implicitHeight

          // clique direito muda posição (padrão dos outros widgets); o
          // clique esquerdo é usado pelos checkboxes/botões internos, então
          // não capturamos aqui — só a área fora deles de fato clica neles
          // porque o MouseArea de cada um está por cima.
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (mouse) => {
              habitsWidget.position = (habitsWidget.position + 8) % 9
            }
          }

          HabitsContent {
            id: habitsContent
            grouped: false
            onAddHabitRequested: addHabitWindow.openForm()
            onEditHabitRequested: (habit) => addHabitWindow.openEdit(habit)
            onHabitsDashboardRequested: dashboardWindow.open()
          }
        }
      }
    }
  }
}
