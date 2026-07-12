import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// ── TodoAddWindow ───────────────────────────────────────────────────────
// Janela centralizada para criar uma nova tarefa — substitui o antigo
// formulário inline (que expandia o próprio popup da lista). Segue o mesmo
// esqueleto do ConfigWindow.qml: PanelWindow em layer Overlay, animação de
// abrir/fechar via _anim, e HyprlandFocusGrab pra fechar ao clicar fora /
// perder foco.
//
// Uso (dentro de TodoWidget.qml / WidgetHost.qml):
//   TodoAddWindow { id: addTaskWindow }
//   TodoContent { onAddTaskRequested: addTaskWindow.openForm() }
//
// Tem sua própria TodoConfig() — assim como TodoContent, ela só lê/escreve
// o mesmo state/TodoWidget.json, então fica sincronizada automaticamente
// sem precisar receber nada de fora.

PanelWindow {
  id: win

  property bool panelOpen: false
  signal closeRequested()
  signal taskAdded()
  signal taskUpdated()

  onCloseRequested: panelOpen = false

  TodoConfig { id: config }

  readonly property var priorityColor: ({
    alta:  "#e5484d",
    media: "#f5a524",
    baixa: "#45a249",
  })
  readonly property var priorityList: [
    { id: "alta",  label: "Alta"  },
    { id: "media", label: "Média" },
    { id: "baixa", label: "Baixa" },
  ]
  readonly property var recurrenceList: [
    { id: "none",    label: "Nunca",   icon: "" },
    { id: "daily",   label: "Diária",  icon: "↻" },
    { id: "weekly",  label: "Semanal", icon: "↻" },
    { id: "monthly", label: "Mensal",  icon: "↻" },
  ]
  // status é opcional — pensado pra tarefas mais longas/com etapas, onde
  // vale a pena marcar que já começou ou que está travada esperando algo
  readonly property var statusList: [
    { id: "",        label: "—"             },
    { id: "doing",   label: "Em andamento"  },
    { id: "blocked", label: "Bloqueada"     },
  ]
  readonly property var statusColor: ({
    doing:   "#5b9bd5",
    blocked: "#e08a3c",
  })

  // "" → criando tarefa nova; caso contrário, id da tarefa sendo editada
  // (ver openEdit()) — confirmForm() ramifica em addTask/updateTask com
  // base nisso.
  property string editingTaskId: ""
  readonly property bool isEditing: editingTaskId !== ""

  property string formText: ""
  property string formPriority: "media"
  property string formDue: ""
  property string formTime: ""
  property string formTags: ""
  property string formRecurrence: "none"
  property string formStatus: ""
  property bool showDatePicker: false

  function isValidTime(s) { return /^([01]\d|2[0-3]):[0-5]\d$/.test(s) }

  function _reveal() {
    _closing = false; _alive = true
    _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
    openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
    panelOpen = true
    _focusTimer.restart()
  }

  function openForm() {
    editingTaskId = ""
    formText = ""; formPriority = "media"; formDue = ""; formTime = ""
    formTags = ""; formRecurrence = "none"; formStatus = ""; showDatePicker = false
    _reveal()
  }

  // abre a janela pré-preenchida com os dados de uma tarefa existente —
  // `task` é o mesmo objeto do modelData do Repeater em TodoContent.qml
  function openEdit(task) {
    if (!task) return
    editingTaskId  = task.id
    formText       = task.text || ""
    formPriority   = task.priority || "media"
    formDue        = task.due || ""
    formTime       = task.time || ""
    formTags       = (task.tags || []).join(", ")
    formRecurrence = task.recurrence || "none"
    formStatus     = task.status || ""
    showDatePicker = false
    _reveal()
  }

  function cancelForm() { panelOpen = false }
  function confirmForm() {
    if (formText.trim().length > 0) {
      const time = win.isValidTime(formTime) ? formTime : ""
      if (win.isEditing) {
        config.updateTask(win.editingTaskId, {
          text:       formText.trim(),
          priority:   formPriority,
          due:        formDue,
          time:       time,
          tags:       config.normalizeTags(formTags),
          recurrence: formRecurrence,
          status:     formStatus,
        })
        win.taskUpdated()
      } else {
        config.addTask(formText, formPriority, formDue, formTags, formRecurrence, time, formStatus)
        win.taskAdded()
      }
    }
    panelOpen = false
  }

  Timer { id: _focusTimer; interval: 20; onTriggered: formInput.forceActiveFocus() }

  onPanelOpenChanged: {
    if (!panelOpen) {
      _closing = true; openAnim.stop()
      closeAnim.from = _anim; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.restart()
      win.closeRequested()
    }
  }

  // ── Geometria ─────────────────────────────────────────────────────────
  readonly property int winW: 380
  readonly property int winH: Math.min(600, mainCol.implicitHeight + 40)

  visible:        _alive
  color:          "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.namespace:     "todo-add-window"
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  margins.top:    screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.bottom: screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.left:   screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0
  margins.right:  screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0

  // ── Animação ──────────────────────────────────────────────────────────
  property real _anim:    0.0
  property bool _alive:   false
  property bool _closing: false

  NumberAnimation { id: openAnim;  target: win; property: "_anim"; duration: 200; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: win; property: "_anim"; duration: 160; easing.type: Easing.OutCubic
    onStopped: { if (win._closing) _unmapTimer.restart() } }
  Timer { id: _unmapTimer;  interval: 17;  onTriggered: { if (win._closing) { win._alive = false; win._closing = false } } }
  Timer { id: _safetyTimer; interval: 380; onTriggered: { if (!win.panelOpen) { win._alive = false; win._closing = false; _unmapTimer.stop() } } }

  HyprlandFocusGrab {
    windows: [win]; active: win.panelOpen
    onCleared: win.panelOpen = false
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════
  Rectangle {
    id: mainRect
    anchors.fill: parent; radius: 14; clip: true
    opacity:   Math.min(1.0, win._anim * 1.4)
    transform: Translate { y: 10 * (1.0 - win._anim) }
    color:     Qt.rgba(0.08, 0.08, 0.09, 0.97)
    border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

    ColumnLayout {
      id: mainCol
      anchors { fill: parent; margins: 16 }
      spacing: 12

      // ── Cabeçalho ────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "\uf0ae"
          color: Colors[config.colorText]
          font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
        }
        Text {
          Layout.fillWidth: true
          text: win.isEditing ? "Editar tarefa" : "Nova tarefa"
          color: Colors[config.colorText]
          font { pixelSize: config.fontSize; family: "Inter"; weight: Font.DemiBold }
        }

        Rectangle {
          width: 24; height: 24; radius: 6
          color: closeHov.containsMouse ? Qt.rgba(0.9, 0.28, 0.3, 0.18) : Qt.rgba(1, 1, 1, 0.06)
          Behavior on color { ColorAnimation { duration: 100 } }
          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: closeHov.containsMouse ? "#e5484d" : Colors[config.colorText]
            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
          }
          MouseArea {
            id: closeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.cancelForm()
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      // ── Descrição ────────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        height: 34; radius: 8
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: formInput.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 80 } }

        TextInput {
          id: formInput
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: Colors[config.colorText]
          font { pixelSize: config.fontSize - 2; family: "Inter" }
          clip: true
          text: win.formText
          onTextChanged: win.formText = text

          Text {
            text: "descrição da tarefa..."
            color: Qt.rgba(1, 1, 1, 0.4)
            font: formInput.font
            visible: !formInput.text.length && !formInput.activeFocus
            anchors.verticalCenter: parent.verticalCenter
          }

          Keys.onEscapePressed: win.cancelForm()
          onAccepted: win.confirmForm()
        }
      }

      // ── Tags ─────────────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        height: 28; radius: 7
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: tagsInput.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 80 } }

        TextInput {
          id: tagsInput
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: Colors[config.colorText]
          font { pixelSize: config.fontSize - 4; family: "Inter" }
          clip: true
          text: win.formTags
          onTextChanged: win.formTags = text
          Keys.onEscapePressed: win.cancelForm()
          onAccepted: win.confirmForm()

          Text {
            text: "tags (separadas por vírgula)"
            color: Qt.rgba(1, 1, 1, 0.4)
            font: tagsInput.font
            visible: !tagsInput.text.length && !tagsInput.activeFocus
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ── Prioridade ───────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Prioridade"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: config.fontSize - 6 }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: win.priorityList
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.formPriority === modelData.id
              width: pLabel.implicitWidth + 16; height: 24; radius: 12
              color: active ? win.priorityColor[modelData.id] : Qt.rgba(1, 1, 1, 0.08)
              Behavior on color { ColorAnimation { duration: 100 } }

              Text {
                id: pLabel
                anchors.centerIn: parent
                text: modelData.label
                color: parent.active ? "#ffffff" : Colors[config.colorText]
                font.pixelSize: config.fontSize - 4
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: win.formPriority = modelData.id
              }
            }
          }
        }
      }

      // ── Recorrência ──────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Repetir"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: config.fontSize - 6 }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: win.recurrenceList
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.formRecurrence === modelData.id
              width: rLabel.implicitWidth + 16; height: 24; radius: 12
              color: active ? Qt.rgba(0.3, 0.6, 1, 0.35) : Qt.rgba(1, 1, 1, 0.08)
              border.color: active ? Qt.rgba(0.4, 0.7, 1, 0.5) : "transparent"; border.width: 1

              Text {
                id: rLabel
                anchors.centerIn: parent
                text: (modelData.icon ? modelData.icon + " " : "") + modelData.label
                color: Colors[config.colorText]
                font.pixelSize: config.fontSize - 4
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: win.formRecurrence = modelData.id
              }
            }
          }
        }
      }

      // ── Status (opcional, pra tarefas mais longas/com etapas) ─────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Status"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: config.fontSize - 6 }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: win.statusList
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.formStatus === modelData.id
              readonly property color dotColor: win.statusColor[modelData.id] || Qt.rgba(1, 1, 1, 0.35)
              width: sRow.implicitWidth + 16; height: 24; radius: 12
              color: active ? Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.28) : Qt.rgba(1, 1, 1, 0.08)
              border.color: active ? Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.6) : "transparent"; border.width: 1

              RowLayout {
                id: sRow
                anchors.centerIn: parent
                spacing: 4
                Rectangle {
                  visible: modelData.id !== ""
                  width: 6; height: 6; radius: 3
                  color: parent.parent.dotColor
                }
                Text {
                  text: modelData.label
                  color: Colors[config.colorText]
                  font.pixelSize: config.fontSize - 4
                }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: win.formStatus = modelData.id
              }
            }
          }
        }
      }

      // ── Prazo ────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Prazo"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: config.fontSize - 6 }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: [
              { id: "",  label: "Sem prazo" },
              { id: Qt.formatDate(new Date(), "yyyy-MM-dd"), label: "Hoje" },
              { id: Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd"), label: "Amanhã" },
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.formDue === modelData.id
              width: dLabel.implicitWidth + 16; height: 24; radius: 12
              color: active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
              border.color: active ? Qt.rgba(1, 1, 1, 0.4) : "transparent"; border.width: 1

              Text {
                id: dLabel
                anchors.centerIn: parent
                text: modelData.label
                color: Colors[config.colorText]
                font.pixelSize: config.fontSize - 4
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { win.formDue = modelData.id; win.showDatePicker = false }
              }
            }
          }

          Rectangle {
            readonly property bool isCustom: win.formDue !== "" &&
              win.formDue !== Qt.formatDate(new Date(), "yyyy-MM-dd") &&
              win.formDue !== Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
            width: customLabel.implicitWidth + 16; height: 24; radius: 12
            color: (isCustom || win.showDatePicker) ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
            border.color: (isCustom || win.showDatePicker) ? Qt.rgba(1, 1, 1, 0.4) : "transparent"; border.width: 1

            Text {
              id: customLabel
              anchors.centerIn: parent
              text: parent.isCustom ? win.formDue : "outra data"
              color: Colors[config.colorText]
              font.pixelSize: config.fontSize - 4
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: win.showDatePicker = !win.showDatePicker
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: datePicker.implicitHeight + 12
          visible: win.showDatePicker
          radius: 8
          color: Qt.rgba(1, 1, 1, 0.05)

          DatePicker {
            id: datePicker
            anchors { fill: parent; margins: 6 }
            selectedDate: win.formDue
            onDateSelected: (date) => { win.formDue = date; win.showDatePicker = false }
          }
        }

        // horário só faz sentido junto de um prazo — some quando "Sem prazo"
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 8
          visible: win.formDue !== ""

          Text { text: "Horário"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: config.fontSize - 6 }

          Rectangle {
            width: 70; height: 24; radius: 7
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: (win.formTime.length > 0 && !win.isValidTime(win.formTime))
              ? "#e5484d"
              : (timeInput.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15))
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 80 } }

            TextInput {
              id: timeInput
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              verticalAlignment: TextInput.AlignVCenter
              color: Colors[config.colorText]
              font { pixelSize: config.fontSize - 4; family: "Inter" }
              maximumLength: 5
              clip: true
              text: win.formTime
              onTextChanged: win.formTime = text
              Keys.onEscapePressed: win.cancelForm()
              onAccepted: win.confirmForm()

              Text {
                text: "--:--"
                color: Qt.rgba(1, 1, 1, 0.35)
                font: timeInput.font
                visible: !timeInput.text.length && !timeInput.activeFocus
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Text {
            visible: win.formTime !== ""
            text: "limpar"
            color: Qt.rgba(1, 1, 1, 0.4)
            font { pixelSize: config.fontSize - 6; underline: clearTimeMa.containsMouse }
            MouseArea {
              id: clearTimeMa
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { win.formTime = ""; timeInput.text = "" }
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "notifica na hora certa; sem horário, entra no resumo do dia"
            color: Qt.rgba(1, 1, 1, 0.35)
            font.pixelSize: config.fontSize - 7
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 140
          }
        }
      }

      Item { Layout.fillHeight: true }

      // ── Rodapé ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        Rectangle {
          width: cancelLabel.implicitWidth + 20; height: 28; radius: 7
          color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
          Text {
            id: cancelLabel
            anchors.centerIn: parent
            text: "cancelar"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 4
          }
          MouseArea {
            id: cancelMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.cancelForm()
          }
        }

        Rectangle {
          width: addLabel.implicitWidth + 22; height: 28; radius: 7
          color: confirmMa.containsMouse ? Qt.rgba(0.3, 0.6, 1, 0.4) : Qt.rgba(0.3, 0.6, 1, 0.26)
          border.color: Qt.rgba(0.4, 0.7, 1, 0.55); border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }
          Text {
            id: addLabel
            anchors.centerIn: parent
            text: win.isEditing ? "salvar" : "adicionar"
            color: Colors[config.colorText]; font.pixelSize: config.fontSize - 4
          }
          MouseArea {
            id: confirmMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.confirmForm()
          }
        }
      }
    }
  }
}
