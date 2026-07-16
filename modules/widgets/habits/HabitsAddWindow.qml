import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// ── HabitsAddWindow ────────────────────────────────────────────────────
// Janela centralizada pra criar/editar um hábito — mesmo esqueleto do
// TodoAddWindow.qml: PanelWindow em layer Overlay, animação de abrir/
// fechar via _anim, HyprlandFocusGrab pra fechar ao clicar fora.
//
// Uso (dentro de HabitsWidget.qml / WidgetHost.qml):
//   HabitsAddWindow { id: addHabitWindow }
//   HabitsContent { onAddHabitRequested: addHabitWindow.openForm() }
//
// Tem sua própria HabitsConfig() — só lê/escreve o mesmo state/
// HabitsWidget.json, fica sincronizada automaticamente.

PanelWindow {
  id: win

  property bool panelOpen: false
  signal closeRequested()
  signal habitAdded()
  signal habitUpdated()

  onCloseRequested: panelOpen = false

  HabitsConfig { id: config }

  readonly property var colorList: ["primary", "secondary", "tertiary", "error", "primary_container"]

  // "" → criando hábito novo; caso contrário, id do hábito sendo editado
  property string editingHabitId: ""
  readonly property bool isEditing: editingHabitId !== ""

  property string formName: ""
  property string formKind: "check"
  property string formTarget: "8"
  property string formUnit: ""
  property string formColor: "primary"

  function _reveal() {
    _closing = false; _alive = true
    _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
    openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
    panelOpen = true
    _focusTimer.restart()
  }

  function openForm() {
    editingHabitId = ""
    formName = ""; formKind = "check"; formTarget = "8"; formUnit = ""
    formColor = colorList[config.habits.length % colorList.length]
    _reveal()
  }

  // pré-preenche com um hábito existente — `habit` é o mesmo objeto do
  // modelData usado em HabitsContent.qml
  function openEdit(habit) {
    if (!habit) return
    editingHabitId = habit.id
    formName   = habit.name || ""
    formKind   = habit.kind || "check"
    formTarget = String(habit.target || 8)
    formUnit   = habit.unit || ""
    formColor  = habit.color || "primary"
    _reveal()
  }

  function cancelForm() { panelOpen = false }
  function confirmForm() {
    if (formName.trim().length > 0) {
      const target = Math.max(1, parseInt(formTarget) || 8)
      if (win.isEditing) {
        config.renameHabit(win.editingHabitId, formName)
        config.setHabitTarget(win.editingHabitId, target, formUnit)
        config.setHabitColor(win.editingHabitId, formColor)
        win.habitUpdated()
      } else {
        config.addHabit(formName, formKind, target, formUnit)
        // addHabit já escolhe uma cor por rotação — sobrescreve com a
        // que a pessoa escolheu no formulário, se for diferente
        const created = config.habits[config.habits.length - 1]
        if (created && created.color !== formColor) config.setHabitColor(created.id, formColor)
        win.habitAdded()
      }
    }
    panelOpen = false
  }

  function requestDelete() {
    if (win.isEditing) config.removeHabit(win.editingHabitId)
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
  readonly property int winW: 340
  readonly property int winH: Math.min(520, mainCol.implicitHeight + 40)

  visible:        _alive
  color:          "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.namespace:     "habits-add-window"
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
          text: win.formKind === "count" ? "\uf1fe" : "\uf00c"
          color: Colors[config.colorLabel]
          font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
        }
        Text {
          Layout.fillWidth: true
          text: win.isEditing ? "Editar hábito" : "Novo hábito"
          color: Colors[config.colorLabel]
          font { pixelSize: 14; family: "Inter"; weight: Font.DemiBold }
        }

        Rectangle {
          width: 24; height: 24; radius: 6
          color: closeHov.containsMouse ? Qt.rgba(0.9, 0.28, 0.3, 0.18) : Qt.rgba(1, 1, 1, 0.06)
          Behavior on color { ColorAnimation { duration: 100 } }
          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: closeHov.containsMouse ? "#e5484d" : Colors[config.colorLabel]
            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
          }
          MouseArea {
            id: closeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.cancelForm()
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      // ── Nome ─────────────────────────────────────────────────────────
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
          color: Colors[config.colorLabel]
          font { pixelSize: 12; family: "Inter" }
          clip: true
          text: win.formName
          onTextChanged: win.formName = text

          Text {
            text: win.formKind === "count" ? "nome (ex: Água)..." : "nome (ex: Meditar)..."
            color: Qt.rgba(1, 1, 1, 0.4)
            font: formInput.font
            visible: !formInput.text.length && !formInput.activeFocus
            anchors.verticalCenter: parent.verticalCenter
          }

          Keys.onEscapePressed: win.cancelForm()
          onAccepted: win.confirmForm()
        }
      }

      // ── Tipo ─────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Tipo"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8 }
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          enabled: !win.isEditing // tipo não muda depois de criado (mudaria a semântica do histórico)
          opacity: enabled ? 1 : 0.4

          Rectangle {
            Layout.fillWidth: true
            height: 28; radius: 8
            color: win.formKind === "check" ? Qt.rgba(0.3, 0.6, 1, 0.28) : Qt.rgba(1, 1, 1, 0.08)
            border.color: win.formKind === "check" ? Qt.rgba(0.4, 0.7, 1, 0.55) : "transparent"; border.width: 1
            Text { anchors.centerIn: parent; text: "marcar feito"; color: Colors[config.colorLabel]; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.formKind = "check" }
          }
          Rectangle {
            Layout.fillWidth: true
            height: 28; radius: 8
            color: win.formKind === "count" ? Qt.rgba(0.3, 0.6, 1, 0.28) : Qt.rgba(1, 1, 1, 0.08)
            border.color: win.formKind === "count" ? Qt.rgba(0.4, 0.7, 1, 0.55) : "transparent"; border.width: 1
            Text { anchors.centerIn: parent; text: "meta com contador"; color: Colors[config.colorLabel]; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.formKind = "count" }
          }
        }
        Text {
          visible: win.isEditing
          text: "o tipo não pode ser alterado depois de criado — apague e crie de novo se precisar"
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          color: Qt.rgba(1, 1, 1, 0.35)
          font.pixelSize: 9
        }
      }

      // ── Meta / unidade (só pro tipo contador) ──────────────────────────
      RowLayout {
        Layout.fillWidth: true
        visible: win.formKind === "count"
        spacing: 8

        ColumnLayout {
          spacing: 4
          Text { text: "Meta"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8 }
          Rectangle {
            width: 60; height: 28; radius: 7
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: targetInput.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
            TextInput {
              id: targetInput
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              verticalAlignment: TextInput.AlignVCenter
              color: Colors[config.colorLabel]
              font { pixelSize: 12; family: "Inter" }
              validator: IntValidator { bottom: 1; top: 999 }
              text: win.formTarget
              onTextChanged: win.formTarget = text
              Keys.onEscapePressed: win.cancelForm()
              onAccepted: win.confirmForm()
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Unidade"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8 }
          Rectangle {
            Layout.fillWidth: true
            height: 28; radius: 7
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: unitInput.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
            TextInput {
              id: unitInput
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              verticalAlignment: TextInput.AlignVCenter
              color: Colors[config.colorLabel]
              font { pixelSize: 12; family: "Inter" }
              text: win.formUnit
              onTextChanged: win.formUnit = text
              Keys.onEscapePressed: win.cancelForm()
              onAccepted: win.confirmForm()

              Text {
                text: "copos, min, páginas…"
                color: Qt.rgba(1, 1, 1, 0.4)
                font: unitInput.font
                visible: !unitInput.text.length && !unitInput.activeFocus
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }

      // ── Cor ──────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Cor"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8 }
        RowLayout {
          spacing: 6
          Repeater {
            model: win.colorList
            delegate: Rectangle {
              required property string modelData
              readonly property bool active: win.formColor === modelData
              width: 24; height: 24; radius: 12
              color: Colors[modelData]
              border.width: active ? 2 : 0
              border.color: Colors[config.colorLabel]
              scale: active ? 1.15 : 1.0
              Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
              MouseArea {
                anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                onClicked: win.formColor = modelData
              }
            }
          }
        }
      }

      Item { Layout.fillHeight: true }

      // ── Rodapé ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
          visible: win.isEditing
          width: delLabel.implicitWidth + 20; height: 28; radius: 7
          color: delMa.containsMouse ? Qt.rgba(0.9, 0.28, 0.3, 0.22) : Qt.rgba(0.9, 0.28, 0.3, 0.1)
          border.color: Qt.rgba(0.9, 0.4, 0.4, 0.4); border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }
          Text {
            id: delLabel
            anchors.centerIn: parent
            text: "apagar"; color: "#ff8080"; font.pixelSize: 11
          }
          MouseArea {
            id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.requestDelete()
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: cancelLabel.implicitWidth + 20; height: 28; radius: 7
          color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
          Text {
            id: cancelLabel
            anchors.centerIn: parent
            text: "cancelar"; color: Colors[config.colorLabel]; font.pixelSize: 11
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
            color: Colors[config.colorLabel]; font.pixelSize: 11
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
