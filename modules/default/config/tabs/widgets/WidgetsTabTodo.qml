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
  property string newTime: ""
  property string newTags: ""
  property string newRecurrence: "none"
  property bool showDatePicker: false

  readonly property var _priorities: [
    { id: "alta",  label: "Alta"  },
    { id: "media", label: "Média" },
    { id: "baixa", label: "Baixa" },
  ]
  readonly property var _recurrences: [
    { id: "none",    label: "Nunca"   },
    { id: "daily",   label: "↻ Diária"  },
    { id: "weekly",  label: "↻ Semanal" },
    { id: "monthly", label: "↻ Mensal"  },
  ]
  readonly property var _sortOptions: [
    { id: "priority", label: "Prioridade" },
    { id: "due",      label: "Vencimento" },
    { id: "created",  label: "Criação" },
  ]

  function resetForm() {
    newText = ""; newPriority = "media"; newDue = ""; newTime = ""
    newTags = ""; newRecurrence = "none"; showDatePicker = false
    taskInput.text = ""; tagsInput.text = ""; timeInput.text = ""
  }

  function isValidTime(s) { return /^([01]\d|2[0-3]):[0-5]\d$/.test(s) }

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
    C.CfgSection { title: "PRAZOS"; colorTextDim: root.colorTextDim }

    C.CfgSlider {
      label: "Prazo \"próximo\" (aparece por extenso na lista)"; from: 1; to: 30; step: 1; unit: " dias"
      value: todoCfg.dueSoonDays
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => todoCfg.dueSoonDays = v
    }

    C.CfgToggle {
      label: "Ocultar tarefas com prazo muito distante"
      checked: todoCfg.hideFarTasks
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: todoCfg.hideFarTasks = !todoCfg.hideFarTasks
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "LEMBRETES"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Tarefas com horário definido notificam individualmente, na hora. Tarefas do dia sem horário entram num resumo, disparado nos horários abaixo."
      color: root.colorTextDim
      font.pixelSize: 10
    }

    Rectangle {
      width: parent.width; height: 26; radius: 6
      color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
      border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
      border.width: 1

      TextInput {
        id: summaryTimesInput
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: root.colorText
        font.pixelSize: 12
        text: (todoCfg.summaryTimes || []).join(", ")

        Text {
          text: "horários, ex: 08:00, 20:00"
          color: root.colorTextDim
          font: summaryTimesInput.font
          visible: !summaryTimesInput.text.length && !summaryTimesInput.activeFocus
          anchors.verticalCenter: parent.verticalCenter
        }

        onEditingFinished: {
          const parsed = text.split(",")
            .map(function(s) { return s.trim() })
            .filter(function(s) { return root.isValidTime(s) })
          todoCfg.summaryTimes = parsed
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
          todoCfg.addTask(root.newText, root.newPriority, root.newDue, root.newTags, root.newRecurrence,
            root.isValidTime(root.newTime) ? root.newTime : "")
          root.resetForm()
        }
      }
    }

    Row {
      width: parent.width
      spacing: 6

      Rectangle {
        width: parent.width - 96; height: 26; radius: 6
        color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
        border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
        border.width: 1

        TextInput {
          id: tagsInput
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: root.colorText
          font.pixelSize: 11
          onTextChanged: root.newTags = text

          Text {
            text: "tags (separadas por vírgula)"
            color: root.colorTextDim
            font: tagsInput.font
            visible: !tagsInput.text.length && !tagsInput.activeFocus
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      Rectangle {
        width: 90; height: 26; radius: 6
        color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
        border.color: (root.newTime.length > 0 && !root.isValidTime(root.newTime))
          ? "#e5484d" : Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
        border.width: 1

        TextInput {
          id: timeInput
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: root.colorText
          font.pixelSize: 11
          maximumLength: 5
          onTextChanged: root.newTime = text

          Text {
            text: "HH:MM"
            color: root.colorTextDim
            font: timeInput.font
            visible: !timeInput.text.length && !timeInput.activeFocus
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    Text { text: "Prioridade"; color: root.colorTextDim; font.pixelSize: 9 }
    Flow {
      width: parent.width
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

    Text { text: "Recorrência"; color: root.colorTextDim; font.pixelSize: 9 }
    Flow {
      width: parent.width
      spacing: 6
      Repeater {
        model: root._recurrences
        delegate: C.CfgChip {
          required property var modelData
          label: modelData.label
          active: root.newRecurrence === modelData.id
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.newRecurrence = modelData.id
        }
      }
    }

    Text { text: "Prazo"; color: root.colorTextDim; font.pixelSize: 9 }
    Flow {
      width: parent.width
      spacing: 6
      C.CfgChip {
        label: "Sem prazo"; active: root.newDue === ""
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: { root.newDue = ""; root.showDatePicker = false }
      }
      C.CfgChip {
        label: "Hoje"
        active: root.newDue === Qt.formatDate(new Date(), "yyyy-MM-dd")
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: { root.newDue = Qt.formatDate(new Date(), "yyyy-MM-dd"); root.showDatePicker = false }
      }
      C.CfgChip {
        label: "Amanhã"
        active: root.newDue === Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: { root.newDue = Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd"); root.showDatePicker = false }
      }
      C.CfgChip {
        readonly property bool isCustom: root.newDue !== "" &&
          root.newDue !== Qt.formatDate(new Date(), "yyyy-MM-dd") &&
          root.newDue !== Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
        label: isCustom ? root.newDue : "Outra data"
        active: isCustom || root.showDatePicker
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.showDatePicker = !root.showDatePicker
      }
    }

    Rectangle {
      width: parent.width
      height: datePicker.implicitHeight + 12
      visible: root.showDatePicker
      radius: 8
      color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.05)

      Widgets.DatePicker {
        id: datePicker
        anchors { fill: parent; margins: 6 }
        selectedDate: root.newDue
        onDateSelected: (date) => { root.newDue = date; root.showDatePicker = false }
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
          todoCfg.addTask(root.newText, root.newPriority, root.newDue, root.newTags, root.newRecurrence,
            root.isValidTime(root.newTime) ? root.newTime : "")
          root.resetForm()
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "TAREFAS (" + todoCfg.tasks.length + ")"; colorTextDim: root.colorTextDim }

    ColumnLayout {
      width: parent.width
      spacing: 6

      Repeater {
        model: todoCfg.tasks
        delegate: ColumnLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 2

          RowLayout {
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
              visible: !!modelData.recurrence && modelData.recurrence !== "none"
              text: "↻"
              color: root.colorTextDim
              font.pixelSize: 10
            }

            Text {
              visible: !!modelData.due
              text: modelData.due + (modelData.time ? " " + modelData.time : "")
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

          Row {
            Layout.leftMargin: 20
            spacing: 4
            visible: !!modelData.tags && modelData.tags.length > 0

            Repeater {
              model: modelData.tags || []
              delegate: Rectangle {
                required property string modelData
                width: tLabel.implicitWidth + 10; height: 15; radius: 7
                color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.1)
                Text {
                  id: tLabel
                  anchors.centerIn: parent
                  text: modelData
                  color: root.colorTextDim
                  font.pixelSize: 8
                }
              }
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
