import Quickshell
import QtQuick
import QtQuick.Layouts
import "../bar" as Bar

// ── Tasks ──────────────────────────────────────────────────────────────────
// Widget da barra do módulo Tarefas + Hábitos — ícone + número de tarefas
// pendentes (opcional) + data de hoje (opcional). Ícone e número SEMPRE
// ficam grudados um no outro (sempre adjacentes, nunca tem nada entre os
// dois); a data (com seu divisor) é o bloco que se move — some inteiro
// antes ou some inteiro depois do par ícone+número, conforme
// datePosition. Muda de cor quando alguma tarefa está atrasada. Detalhe
// fica todo no tooltip (hover), que reproduz o mesmo cartão rico que
// TodoContent.qml já usa por tarefa, só que listando tudo de uma vez, sem
// cortar texto.

Item {
  id: root

  property bool isHorizontal: true
  property int  barPosition:  2

  property color textColor:   "white"
  property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
  property color accentColor: "white"
  property real  fontScale:   1.0

  signal panelRequested()
  // Botão direito — abre o painel do calendário de tarefas em vez do painel
  // normal (ver TasksCalendarPopup). Gated por calendarEnabled — quando
  // desligado nas configs do módulo, o clique direito não faz nada.
  signal calendarRequested()

  // Liga/desliga o botão direito do calendário — injetado pelo Bar.qml a
  // partir de barState.config.tasksCalendarEnabled (config "tasks" →
  // calendarEnabled, ver BarTabTasks.qml / BarConfig._resolveAll()).
  // Default true preserva o comportamento pra quem ainda não tem essa
  // fiação feita no tema.
  property bool calendarEnabled: true

  // Mostra/esconde o número de tarefas pendentes — injetada pelo Bar.qml a
  // partir de barState.config.tasksShowCount (config "tasks" → showCount).
  // Default true preserva o visual atual.
  property bool showCount: true

  // "off" | "short" (01/09) | "full" (por extenso, ex: "1 de setembro") —
  // mostra a data de hoje ao lado do contador de pendentes. Injetada pelo
  // Bar.qml a partir de barState.config.tasksDateDisplay (config "tasks" →
  // dateDisplay, ver BarTabTasks.qml / BarConfig._resolveAll()). Default
  // "off" preserva o visual atual (só ícone + contador) pra quem ainda não
  // tem a fiação no tema.
  property string dateDisplay: "off"
  readonly property bool _showDate: root.dateDisplay === "short" || root.dateDisplay === "full"

  // "after" (padrão — ícone+número, depois a data) | "before" (data
  // primeiro, depois ícone+número) — injetada a partir de
  // barState.config.tasksDatePosition. Ícone e número NUNCA se separam —
  // só o bloco data+divisor troca de lado (ver comentário no topo).
  property string datePosition: "after"
  readonly property bool _dateFirst:  root.datePosition === "before"
  readonly property bool _dateBefore: root._dateFirst  && root._showDate
  readonly property bool _dateAfter:  !root._dateFirst && root._showDate

  // ── Tick da data — mesmo padrão do _tick em Clock.qml (var _ = _tick
  // força a reavaliação), só que de minuto em minuto: a data não muda a
  // cada segundo como o relógio, não faz sentido bater 1000ms aqui.
  property bool _dateTick: false
  Timer {
    interval: 60000; repeat: true
    running: root.visible && root._showDate
    onTriggered: root._dateTick = !root._dateTick
  }

  readonly property var _monthNamesFull: [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
  ]
  readonly property string _dateText: {
    var _ = _dateTick
    if (root.dateDisplay === "short") return Qt.formatDate(new Date(), "dd/MM")
    if (root.dateDisplay === "full") {
      var d = new Date()
      return d.getDate() + " de " + root._monthNamesFull[d.getMonth()]
    }
    return ""
  }

  // Referência ao TasksContent (injetada pelo Bar.qml, mesmo esquema do
  // clockContent em Clock.qml)
  property var tasksContent: null

  readonly property int pendingCount: tasksContent ? tasksContent.pendingCount : 0
  readonly property bool hasOverdue:  tasksContent ? tasksContent.hasOverdueTasks : false
  readonly property color _color: hasOverdue ? root.accentColor : root.textColor

  implicitWidth:  isHorizontal ? hRow.implicitWidth  + Math.round(12 * root.fontScale) : vCol.implicitWidth  + Math.round(4 * root.fontScale)
  implicitHeight: isHorizontal ? hRow.implicitHeight + Math.round(6  * root.fontScale) : vCol.implicitHeight + Math.round(8 * root.fontScale)

  // ════════════════════════════════════════════════════════════════════════
  // HORIZONTAL — filhos em ORDEM FIXA de declaração: [data+divisor "antes"]
  // [ícone][número] [data+divisor "depois"]. Ícone e número são vizinhos
  // diretos sempre — nada entra entre eles. Só um dos dois blocos de data
  // fica visível por vez (mutuamente exclusivos por datePosition).
  // ════════════════════════════════════════════════════════════════════════
  Row {
    id: hRow
    visible:          root.isHorizontal
    anchors.centerIn: parent
    spacing: 4

    // Data — lado esquerdo (datePosition:"before")
    Text {
      visible:                 root._dateBefore
      anchors.verticalCenter:  parent.verticalCenter
      text:           root._dateText
      color:          root.dimColor
      // Mesma fonte/tamanho/peso do relógio (Clock.qml → hh/mm)
      font.pixelSize: Math.round(13 * root.fontScale)
      font.weight:    Font.Medium
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
    Rectangle {
      visible:                 root._dateBefore
      anchors.verticalCenter:  parent.verticalCenter
      width:   Math.round(1 * root.fontScale)
      height:  Math.round(12 * root.fontScale)
      radius:  1
      color:   root.dimColor
      opacity: 0.35
    }

    // Ícone + número — sempre adjacentes, nesta ordem, nunca se movem
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text:           "\uf0ae"
      color:          root._color
      font.pixelSize: Math.round(13 * root.fontScale)
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
    Text {
      visible:                 root.showCount
      anchors.verticalCenter:  parent.verticalCenter
      text:           String(root.pendingCount)
      color:          root._color
      font.pixelSize: Math.round(11 * root.fontScale)
      font.weight:    Font.DemiBold
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Data — lado direito (datePosition:"after", padrão)
    Rectangle {
      visible:                 root._dateAfter
      anchors.verticalCenter:  parent.verticalCenter
      width:   Math.round(1 * root.fontScale)
      height:  Math.round(12 * root.fontScale)
      radius:  1
      color:   root.dimColor
      opacity: 0.35
    }
    Text {
      visible:                 root._dateAfter
      anchors.verticalCenter:  parent.verticalCenter
      text:           root._dateText
      color:          root.dimColor
      font.pixelSize: Math.round(13 * root.fontScale)
      font.weight:    Font.Medium
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERTICAL — mesma regra, empilhado: [data+divisor "antes"] [ícone]
  // [número] [data+divisor "depois"].
  // ════════════════════════════════════════════════════════════════════════
  Column {
    id: vCol
    visible:          !root.isHorizontal
    anchors.centerIn: parent
    spacing: 2

    // Data — em cima (datePosition:"before")
    Text {
      visible:                   root._dateBefore
      anchors.horizontalCenter:  parent.horizontalCenter
      text:           root._dateText
      color:          root.dimColor
      // Mesmo peso/fonte do relógio; tamanho um pouco menor que o
      // principal do relógio pois aqui é rótulo secundário, não o valor
      // central do widget.
      font.pixelSize: Math.round(11 * root.fontScale)
      font.weight:    Font.Medium
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
    Rectangle {
      visible:                  root._dateBefore
      anchors.horizontalCenter: parent.horizontalCenter
      width:   Math.round(16 * root.fontScale)
      height:  Math.round(1 * root.fontScale)
      radius:  1
      color:   root.dimColor
      opacity: 0.2
    }

    // Ícone + número — sempre adjacentes, nesta ordem, nunca se movem
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text:           "\uf0ae"
      color:          root._color
      font.pixelSize: Math.round(14 * root.fontScale)
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
    Text {
      visible:                   root.showCount
      anchors.horizontalCenter:  parent.horizontalCenter
      text:           String(root.pendingCount)
      color:          root._color
      font.pixelSize: Math.round(10 * root.fontScale)
      font.weight:    Font.DemiBold
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Data — embaixo (datePosition:"after", padrão)
    Rectangle {
      visible:                  root._dateAfter
      anchors.horizontalCenter: parent.horizontalCenter
      width:   Math.round(16 * root.fontScale)
      height:  Math.round(1 * root.fontScale)
      radius:  1
      color:   root.dimColor
      opacity: 0.2
    }
    Text {
      visible:                   root._dateAfter
      anchors.horizontalCenter:  parent.horizontalCenter
      text:           root._dateText
      color:          root.dimColor
      font.pixelSize: Math.round(11 * root.fontScale)
      font.weight:    Font.Medium
      font.family:    "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ── Interação ─────────────────────────────────────────────────────────
  // Esquerdo → painel normal (Tarefas + Hábitos). Direito → painel do
  // calendário (só se calendarEnabled).
  MouseArea {
    anchors.fill:    parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled:    true

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        if (root.calendarEnabled) root.calendarRequested()
      } else {
        root.panelRequested()
      }
    }

    onEntered: TasksTooltip.show(root, root.tasksContent, root.barPosition)
    onExited:  TasksTooltip.hide()
  }
}
