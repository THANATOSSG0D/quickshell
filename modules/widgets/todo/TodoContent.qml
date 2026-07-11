import qs

import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property bool grouped: false

  // quem hospeda esse conteúdo (TodoWidget.qml sozinho, ou WidgetHost.qml
  // agrupado) escuta esse sinal pra abrir a TodoAddWindow — janela própria
  // centralizada na tela, em vez do antigo formulário inline que expandia
  // este popup.
  signal addTaskRequested()

  // filtro por data (yyyy-MM-dd) — só usado no modo combinado, quando o
  // Calendário também está no grupo: a WidgetHost liga isso na data
  // selecionada no CalendarContent. Vazio = sem filtro (lista normal).
  property string filterDate: ""
  signal clearFilterRequested()

  // clicar no lápis de uma tarefa pede pra abrir a TodoAddWindow em modo
  // de edição (mesma janela do "+ nova tarefa", pré-preenchida)
  signal editTaskRequested(var task)

  TodoConfig { id: config }

  readonly property var priorityColor: ({
    alta:  "#e5484d",
    media: "#f5a524",
    baixa: "#45a249",
  })
  readonly property var priorityOrder: ({ alta: 0, media: 1, baixa: 2 })
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

  // tarefas sem prazo definido, com prioridade alta ou média, ficam sempre
  // fixadas no topo da lista — inclusive quando há um filterDate ativo
  // (o filtro por data normalmente as excluiria, já que due !== filterDate)
  function isPinned(t) {
    return !t.done && !t.due && (t.priority === "alta" || t.priority === "media")
  }

  // "hoje" sempre vivo (mesmo padrão do ClockContent/CalendarContent) —
  // sem isso, tarefas ficariam "atrasadas" ou não dependendo de quando o
  // shell foi iniciado, não da data real.
  property bool _tick: false
  Timer { interval: 60000; repeat: true; running: true; onTriggered: root._tick = !root._tick }
  function todayStr() { var _ = root._tick; return Qt.formatDate(new Date(), "yyyy-MM-dd") }

  function isOverdueTask(t) {
    return !t.done && !!t.due && t.due < root.todayStr()
  }

  // quantos dias faltam até `dueStr` (negativo = já passou)
  function daysUntil(dueStr) {
    const today = new Date(root.todayStr() + "T00:00:00")
    const due   = new Date(dueStr + "T00:00:00")
    return Math.round((due - today) / 86400000)
  }

  // só vale a pena poupar espaço na linha mostrando o prazo quando ele é
  // relevante agora: atrasado, hoje, ou dentro da janela de "em breve"
  // (config.dueSoonDays). Prazo muito distante nem entra na lista por
  // padrão (config.hideFarTasks) — só aparece no tooltip (hover) ou
  // filtrando por aquele dia específico no Calendário combinado.
  function isDueSoon(t) {
    return !!t.due && root.daysUntil(t.due) <= config.dueSoonDays
  }
  function isFarTask(t) {
    return !t.done && !!t.due && !root.isOverdueTask(t) && root.daysUntil(t.due) > config.dueSoonDays
  }
  // quantas tarefas estão fora da lista agora só por causa do hideFarTasks
  // (pra dar um indicador discreto — "sumiu" é diferente de "não existe")
  function farHiddenCount() {
    if (!config.hideFarTasks || root.filterDate) return 0
    return config.tasks.filter(function(t) {
      return (config.showCompleted || !t.done) && root.isFarTask(t)
    }).length
  }

  function priorityLabel(id) {
    const found = root.priorityList.find(function(p) { return p.id === id })
    return found ? found.label : id
  }
  function recurrenceLabel(id) {
    const found = root.recurrenceList.find(function(r) { return r.id === id })
    return found ? found.label : id
  }

  function sortedTasks() {
    let list = config.tasks.slice()
    if (!config.showCompleted) list = list.filter(function(t) { return !t.done })
    // "muito longe" só se aplica na visão geral — se o usuário clicou num
    // dia específico do Calendário (filterDate), a tarefa daquele dia tem
    // que aparecer mesmo que esteja em outro mês
    if (config.hideFarTasks && !root.filterDate)
      list = list.filter(function(t) { return !root.isFarTask(t) })
    if (root.filterDate)
      list = list.filter(function(t) { return t.due === root.filterDate || root.isPinned(t) })
    list.sort(function(a, b) {
      const ap = root.isPinned(a), bp = root.isPinned(b)
      if (ap !== bp) return ap ? -1 : 1
      if (a.done !== b.done) return a.done ? 1 : -1
      if (ap && bp) {
        // dentro do grupo fixado no topo, prioridade decide (alta antes de média)
        const ao = priorityOrder[a.priority] !== undefined ? priorityOrder[a.priority] : 1
        const bo = priorityOrder[b.priority] !== undefined ? priorityOrder[b.priority] : 1
        if (ao !== bo) return ao - bo
      }
      if (config.sortBy === "priority") {
        const ao = priorityOrder[a.priority] !== undefined ? priorityOrder[a.priority] : 1
        const bo = priorityOrder[b.priority] !== undefined ? priorityOrder[b.priority] : 1
        return ao - bo
      }
      if (config.sortBy === "due")
        return (a.due || "9999-99-99") < (b.due || "9999-99-99") ? -1 : 1
      return (a.created || "") < (b.created || "") ? -1 : 1
    })
    return list
  }

  implicitWidth: 260
  implicitHeight: listLayout.implicitHeight

  // ── Tooltip flutuante ao passar o mouse numa tarefa ────────────────────
  // Mostra o texto completo (sem elide), prioridade, prazo e detalhes —
  // um único card reaproveitado (não um por tarefa), reposicionado pra
  // ficar colado embaixo da linha que está sob o mouse.
  property var tooltipTask: null
  property real tooltipY: 0
  property bool tooltipVisible: false

  Timer { id: tooltipShowTimer; interval: 380; onTriggered: root.tooltipVisible = true }

  function requestTooltip(task, y) {
    root.tooltipTask = task
    root.tooltipY = y
    if (!root.tooltipVisible) tooltipShowTimer.restart()
  }
  function hideTooltip(task) {
    if (root.tooltipTask && task && root.tooltipTask.id !== task.id) return
    tooltipShowTimer.stop()
    root.tooltipVisible = false
    root.tooltipTask = null
  }

  // ── Modo LISTA ──────────────────────────────────────────────────────
  ColumnLayout {
    id: listLayout
    width: parent.width
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        Layout.fillWidth: true
        horizontalAlignment: root.filterDate ? Text.AlignLeft : Text.AlignHCenter
        text: root.filterDate
          ? "Tarefas em " + root.filterDate + " · " + root.sortedTasks().length
          : "Tarefas · " + root.sortedTasks().filter(function(t) { return !t.done }).length + " pendentes"
        color: Colors[config.colorText]
        font { pixelSize: config.fontSize; family: "Inter"; weight: Font.DemiBold }
      }

      Rectangle {
        visible: !!root.filterDate
        width: 16; height: 16; radius: 8
        color: clearFilterMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "×"
          color: Colors[config.colorText]
          font.pixelSize: 10
        }
        MouseArea {
          id: clearFilterMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.clearFilterRequested()
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      height: 28; radius: 6
      color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
      border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
      Behavior on color { ColorAnimation { duration: 80 } }

      Text {
        anchors.centerIn: parent
        text: "+ nova tarefa"
        color: Colors[config.colorText]
        font { pixelSize: config.fontSize - 3; family: "Inter" }
      }
      MouseArea {
        id: addMa
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.addTaskRequested()
      }
    }

    Repeater {
      model: root.sortedTasks()
      delegate: ColumnLayout {
        id: taskDelegate
        required property var modelData
        Layout.fillWidth: true
        spacing: 0

        readonly property bool overdue: root.isOverdueTask(modelData)

        HoverHandler {
          id: rowHover
          onHoveredChanged: {
            if (hovered) root.requestTooltip(taskDelegate.modelData, taskDelegate.y + taskDelegate.height + 4)
            else root.hideTooltip(taskDelegate.modelData)
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: innerCol.implicitHeight + (taskDelegate.overdue ? 8 : 0)
          radius: 6
          color: taskDelegate.overdue ? Qt.rgba(0.9, 0.23, 0.23, 0.10) : "transparent"
          border.color: taskDelegate.overdue ? Qt.rgba(0.9, 0.3, 0.3, 0.4) : "transparent"
          border.width: taskDelegate.overdue ? 1 : 0
          Behavior on color { ColorAnimation { duration: 120 } }

          ColumnLayout {
            id: innerCol
            anchors { fill: parent; margins: taskDelegate.overdue ? 4 : 0 }
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Rectangle {
                width: 14; height: 14; radius: 7
                border.width: 1.5
                border.color: modelData.done ? "#45a249" : Qt.rgba(1, 1, 1, 0.4)
                color: modelData.done ? "#45a249" : "transparent"
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: config.toggleTask(modelData.id)
                }
              }

              Rectangle {
                width: 6; height: 6; radius: 3
                color: root.priorityColor[modelData.priority] || "#999999"
              }

              Text {
                visible: taskDelegate.overdue
                text: "\uf071"
                color: "#ff6b6b"
                font { pixelSize: config.fontSize - 6; family: "JetBrainsMono Nerd Font" }
              }

              Text {
                Layout.fillWidth: true
                text: modelData.text
                color: taskDelegate.overdue ? "#ff6b6b" : Colors[config.colorText]
                opacity: modelData.done ? 0.45 : 1.0
                font { pixelSize: config.fontSize - 3; family: "Inter"; strikeout: modelData.done }
                elide: Text.ElideRight
              }

              Text {
                visible: !!modelData.recurrence && modelData.recurrence !== "none"
                text: "↻"
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: config.fontSize - 4
              }

              Text {
                visible: !!modelData.due && (taskDelegate.overdue || root.isDueSoon(modelData))
                text: modelData.due + (taskDelegate.overdue ? " ⚠" : "")
                color: taskDelegate.overdue ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.5)
                font { pixelSize: config.fontSize - 5; weight: taskDelegate.overdue ? Font.DemiBold : Font.Normal }
              }

              // prazo existe mas está longe — só um marcador discreto de
              // "tem prazo" (o valor completo aparece no tooltip do hover)
              Text {
                visible: !!modelData.due && !taskDelegate.overdue && !root.isDueSoon(modelData)
                text: "\uf133"
                color: Qt.rgba(1, 1, 1, 0.3)
                font { pixelSize: config.fontSize - 6; family: "JetBrainsMono Nerd Font" }
              }

              Text {
                text: "\uf044"
                color: Qt.rgba(1, 1, 1, 0.4)
                font { pixelSize: config.fontSize - 5; family: "JetBrainsMono Nerd Font" }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: root.editTaskRequested(modelData)
                }
              }

              Text {
                text: "×"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: config.fontSize
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: config.removeTask(modelData.id)
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
                  width: tagLabel.implicitWidth + 10; height: 15; radius: 7
                  color: Qt.rgba(1, 1, 1, 0.1)
                  Text {
                    id: tagLabel
                    anchors.centerIn: parent
                    text: modelData
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 8
                  }
                }
              }
            }
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: root.farHiddenCount() > 0
      height: 22; radius: 6
      color: showFarMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
      Behavior on color { ColorAnimation { duration: 80 } }

      Text {
        anchors.centerIn: parent
        text: "+ " + root.farHiddenCount() + " com prazo mais distante"
        color: Qt.rgba(1, 1, 1, 0.45)
        font.pixelSize: config.fontSize - 6
      }
      MouseArea {
        id: showFarMa
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: config.hideFarTasks = false
      }
    }
  }

  // ── Card do tooltip ─────────────────────────────────────────────────
  // Único, reaproveitado — reposicionado pra colar embaixo da tarefa sob
  // o mouse. Mostra o texto completo (sem elide), prioridade, prazo,
  // recorrência, tags e data de criação.
  Rectangle {
    id: tooltipCard
    visible: root.tooltipVisible && root.tooltipTask !== null
    opacity: visible ? 1 : 0
    z: 1000
    x: 0
    y: root.tooltipY
    width: 236
    implicitHeight: tooltipCol.implicitHeight + 20
    radius: 10
    color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
    border.color: Qt.rgba(1, 1, 1, 0.14); border.width: 1
    Behavior on opacity { NumberAnimation { duration: 90 } }

    ColumnLayout {
      id: tooltipCol
      anchors { fill: parent; margins: 10 }
      spacing: 5

      Text {
        Layout.fillWidth: true
        text: root.tooltipTask ? root.tooltipTask.text : ""
        wrapMode: Text.WordWrap
        color: Colors[config.colorText]
        font { pixelSize: config.fontSize - 2; family: "Inter"; weight: Font.DemiBold
               strikeout: root.tooltipTask ? !!root.tooltipTask.done : false }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: !!root.tooltipTask

        Rectangle {
          width: 8; height: 8; radius: 4
          color: root.tooltipTask ? (root.priorityColor[root.tooltipTask.priority] || "#999999") : "transparent"
        }
        Text {
          text: root.tooltipTask ? ("Prioridade " + root.priorityLabel(root.tooltipTask.priority)) : ""
          color: Qt.rgba(1, 1, 1, 0.7)
          font.pixelSize: config.fontSize - 5
        }
        Item { Layout.fillWidth: true }
        Text {
          visible: !!(root.tooltipTask && root.tooltipTask.done)
          text: "concluída"
          color: "#45a249"
          font.pixelSize: config.fontSize - 5
        }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.due)
        text: root.tooltipTask
          ? ("Prazo: " + root.tooltipTask.due + (root.isOverdueTask(root.tooltipTask) ? " · atrasada" : ""))
          : ""
        color: (root.tooltipTask && root.isOverdueTask(root.tooltipTask)) ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.7)
        font { pixelSize: config.fontSize - 5; weight: (root.tooltipTask && root.isOverdueTask(root.tooltipTask)) ? Font.DemiBold : Font.Normal }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.recurrence && root.tooltipTask.recurrence !== "none")
        text: root.tooltipTask ? ("Repete: " + root.recurrenceLabel(root.tooltipTask.recurrence)) : ""
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: config.fontSize - 5
      }

      Flow {
        Layout.fillWidth: true
        spacing: 4
        visible: !!(root.tooltipTask && root.tooltipTask.tags && root.tooltipTask.tags.length > 0)

        Repeater {
          model: (root.tooltipTask && root.tooltipTask.tags) || []
          delegate: Rectangle {
            required property string modelData
            width: ttTagLabel.implicitWidth + 10; height: 15; radius: 7
            color: Qt.rgba(1, 1, 1, 0.12)
            Text {
              id: ttTagLabel
              anchors.centerIn: parent
              text: modelData
              color: Qt.rgba(1, 1, 1, 0.65)
              font.pixelSize: 8
            }
          }
        }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.created)
        text: root.tooltipTask ? ("Criada em " + Qt.formatDateTime(new Date(root.tooltipTask.created), "dd/MM/yyyy")) : ""
        color: Qt.rgba(1, 1, 1, 0.45)
        font.pixelSize: config.fontSize - 6
      }
    }
  }

}
