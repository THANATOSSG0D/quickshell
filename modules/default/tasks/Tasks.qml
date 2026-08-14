import Quickshell
import QtQuick
import QtQuick.Layouts
import "../bar" as Bar

// ── Tasks ──────────────────────────────────────────────────────────────────
// Widget da barra do módulo Tarefas + Hábitos — minimalista de propósito:
// só o ícone + o número de tarefas pendentes. Muda de cor quando alguma
// está atrasada. Detalhe fica todo no tooltip (hover), que reproduz o
// mesmo cartão rico que TodoContent.qml já usa por tarefa, só que listando
// tudo de uma vez, sem cortar texto.

Item {
  id: root

  property bool isHorizontal: true
  property int  barPosition:  2

  property color textColor:   "white"
  property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
  property color accentColor: "white"
  property real  fontScale:   1.0

  signal panelRequested()

  // Referência ao TasksContent (injetada pelo Bar.qml, mesmo esquema do
  // clockContent em Clock.qml)
  property var tasksContent: null

  readonly property int pendingCount: tasksContent ? tasksContent.pendingCount : 0
  readonly property bool hasOverdue:  tasksContent ? tasksContent.hasOverdueTasks : false
  readonly property color _color: hasOverdue ? root.accentColor : root.textColor

  implicitWidth:  isHorizontal ? hRow.implicitWidth  + Math.round(12 * root.fontScale) : vCol.implicitWidth  + Math.round(4 * root.fontScale)
  implicitHeight: isHorizontal ? hRow.implicitHeight + Math.round(6  * root.fontScale) : vCol.implicitHeight + Math.round(8 * root.fontScale)

  // ════════════════════════════════════════════════════════════════════════
  // HORIZONTAL
  // ════════════════════════════════════════════════════════════════════════
  Row {
    id: hRow
    visible:          root.isHorizontal
    anchors.centerIn: parent
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text:           "\uf0ae"
      color:          root._color
      font.pixelSize: Math.round(13 * root.fontScale)
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text:           String(root.pendingCount)
      color:          root._color
      font.pixelSize: Math.round(11 * root.fontScale)
      font.weight:    Font.DemiBold
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERTICAL
  // ════════════════════════════════════════════════════════════════════════
  Column {
    id: vCol
    visible:          !root.isHorizontal
    anchors.centerIn: parent
    spacing: 2

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text:           "\uf0ae"
      color:          root._color
      font.pixelSize: Math.round(14 * root.fontScale)
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text:           String(root.pendingCount)
      color:          root._color
      font.pixelSize: Math.round(10 * root.fontScale)
      font.weight:    Font.DemiBold
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ── Interação ─────────────────────────────────────────────────────────
  MouseArea {
    anchors.fill:    parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled:    true

    onClicked: root.panelRequested()

    onEntered: TasksTooltip.show(root, root.tasksContent, root.barPosition)
    onExited:  TasksTooltip.hide()
  }
}
