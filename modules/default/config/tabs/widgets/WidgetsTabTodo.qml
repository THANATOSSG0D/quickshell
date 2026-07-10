import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabTodo.qml → modules/widgets/todo/
import '../../../../widgets/todo' as Widgets

Item {
  id: root

  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  anchors.fill: parent

  Widgets.TodoConfig { id: todoCfg }

  property string newText: ""
  property string newPriority: "media"
  property string newDue: ""

  readonly property var _priorities: [
    { id: "alta",  label: "Alta"  },
    { id: "media", label: "Média" },
    { id: "baixa", label: "Baixa" },
  ]
  readonly property var _sortOptions: [
    { id: "priority", label: "Prioridade" },
    { id: "due",      label: "Vencimento" },
    { id: "created",  label: "Criação" },
  ]

  C.CfgScroll {

    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: todoCfg.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => todoCfg.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: todoCfg.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => todoCfg.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "APARÊNCIA"; colorTextDim: root.colorTextDim }

    C.CfgSlider {
      label: "Tamanho da fonte"; from: 10; to: 26; step: 1; unit: " px"
      value: todoCfg.fontSize
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => todoCfg.fontSize = v
    }

    C.CfgToggle {
      label: "Mostrar tarefas concluídas"
      checked: todoCfg.showCompleted
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: todoCfg.showCompleted = !todoCfg.showCompleted
    }

    Row {
      spacing: 6
      Repeater {
        model: root._sortOptions
        delegate: C.CfgChip {
          required property var modelData
          label: "Ordenar: " + modelData.label
          active: todoCfg.sortBy === modelData.id
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: todoCfg.sortBy = modelData.id
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "NOVA TAREFA"; colorTextDim: root.colorTextDim }

    Rectangle {
      width: parent.width; height: 30; radius: 6
      color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
      border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
      border.width: 1

      TextInput {
        id: taskInput
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: root.colorText
        font.pixelSize: 12
        onTextChanged: root.newText = text

        Text {
          text: "descrição da tarefa..."
          color: root.colorTextDim
          font: taskInput.font
          visible: !taskInput.text.length && !taskInput.activeFocus
          anchors.verticalCenter: parent.verticalCenter
        }

        onAccepted: {
          todoCfg.addTask(root.newText, root.newPriority, root.newDue)
          root.newText = ""; text = ""
        }
      }
    }

    Row {
      spacing: 6
      Repeater {
        model: root._priorities
        delegate: C.CfgChip {
          required property var modelData
          label: modelData.label
          active: root.newPriority === modelData.id
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.newPriority = modelData.id
        }
      }
    }

    Row {
      spacing: 6
      C.CfgChip {
        label: "Sem prazo"; active: root.newDue === ""
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.newDue = ""
      }
      C.CfgChip {
        label: "Hoje"
        active: root.newDue === Qt.formatDate(new Date(), "yyyy-MM-dd")
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.newDue = Qt.formatDate(new Date(), "yyyy-MM-dd")
      }
      C.CfgChip {
        label: "Amanhã"
        active: root.newDue === Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.newDue = Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
      }
    }

    Rectangle {
      width: parent.width; height: 26; radius: 6
      color: addMa.containsMouse
        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
        : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
      border.color: root.colorAccent; border.width: 1
      Behavior on color { ColorAnimation { duration: 60 } }

      Text {
        anchors.centerIn: parent
        text: "+ adicionar tarefa"
        color: root.colorAccent
        font.pixelSize: 11
      }
      MouseArea {
        id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
          todoCfg.addTask(root.newText, root.newPriority, root.newDue)
          root.newText = ""; taskInput.text = ""
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "TAREFAS (" + todoCfg.tasks.length + ")"; colorTextDim: root.colorTextDim }

    ColumnLayout {
      width: parent.width
      spacing: 4

      Repeater {
        model: todoCfg.tasks
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            width: 14; height: 14; radius: 7
            border.width: 1.5
            border.color: modelData.done ? "#45a249" : root.colorTextDim
            color: modelData.done ? "#45a249" : "transparent"
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: todoCfg.toggleTask(modelData.id)
            }
          }

          Text {
            Layout.fillWidth: true
            text: modelData.text
            color: root.colorText
            opacity: modelData.done ? 0.5 : 1.0
            font { pixelSize: 12; strikeout: modelData.done }
            elide: Text.ElideRight
          }

          Text {
            visible: !!modelData.due
            text: modelData.due
            color: root.colorTextDim
            font.pixelSize: 10
          }

          Text {
            text: "excluir"
            color: root.colorTextDim
            font.pixelSize: 10
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: todoCfg.removeTask(modelData.id)
            }
          }
        }
      }

      Text {
        visible: todoCfg.tasks.length === 0
        text: "Nenhuma tarefa ainda."
        color: root.colorTextDim
        font.pixelSize: 11
      }
    }
  }
}
