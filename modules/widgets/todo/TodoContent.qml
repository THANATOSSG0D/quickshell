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

  // abre o painel grande (Kanban / Progresso / Agenda) — TodoDashboard.qml
  signal dashboardRequested()

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
  readonly property var statusColor: ({
    doing:   "#5b9bd5",
    blocked: "#e08a3c",
  })
  readonly property var statusLabels: ({
    doing:   "Em andamento",
    blocked: "Bloqueada",
  })

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
  function isDueToday(t) {
    return !t.done && !!t.due && t.due === root.todayStr()
  }
  // "próximos dias": tem prazo, não é hoje nem atrasada, e cai dentro da
  // janela de "em breve" (config.dueSoonDays) — vira sua própria seção
  // na lista, separada do resto.
  function isUpcoming(t) {
    return !t.done && !!t.due && root.daysUntil(t.due) > 0 && root.daysUntil(t.due) <= config.dueSoonDays
  }

  function comparePriority(a, b) {
    const ao = priorityOrder[a.priority] !== undefined ? priorityOrder[a.priority] : 1
    const bo = priorityOrder[b.priority] !== undefined ? priorityOrder[b.priority] : 1
    return ao - bo
  }
  // ordena por prazo (mais cedo primeiro; sem prazo vai pro fim) e usa
  // prioridade como critério de desempate dentro do mesmo dia
  function compareDueThenPriority(a, b) {
    const ad = a.due || "9999-99-99", bd = b.due || "9999-99-99"
    if (ad !== bd) return ad < bd ? -1 : 1
    return root.comparePriority(a, b)
  }

  // ── Seções da lista ──────────────────────────────────────────────────
  // Em vez de uma lista única, as tarefas são agrupadas por urgência:
  // Fixadas (sem prazo, prioridade alta/média) → Atrasadas → Hoje →
  // Próximos dias → Sem prazo próximo → Concluídas. Dentro de cada seção,
  // prioridade decide empates (e, na seção "Próximos dias", o prazo em si
  // decide primeiro). Com filterDate ativo (um dia específico escolhido no
  // Calendário combinado) a lista volta a ser plana, sem seções.
  function sections() {
    if (root.filterDate) {
      const list = config.tasks.filter(function(t) {
        if (!config.showCompleted && t.done) return false
        return t.due === root.filterDate || root.isPinned(t)
      }).sort(function(a, b) {
        if (a.done !== b.done) return a.done ? 1 : -1
        return root.comparePriority(a, b)
      })
      return list.length ? [{ key: "filtered", label: "", tasks: list }] : []
    }

    let base = config.tasks.slice()
    if (config.hideFarTasks) base = base.filter(function(t) { return !root.isFarTask(t) })
    const pending = base.filter(function(t) { return !t.done })

    const pinned   = pending.filter(root.isPinned).sort(root.comparePriority)
    const overdue  = pending.filter(function(t) { return !root.isPinned(t) && root.isOverdueTask(t) }).sort(root.comparePriority)
    const today    = pending.filter(function(t) { return !root.isPinned(t) && root.isDueToday(t) }).sort(root.comparePriority)
    const upcoming = pending.filter(function(t) { return !root.isPinned(t) && root.isUpcoming(t) }).sort(root.compareDueThenPriority)
    const other    = pending.filter(function(t) {
      return !root.isPinned(t) && !root.isOverdueTask(t) && !root.isDueToday(t) && !root.isUpcoming(t)
    }).sort(root.compareDueThenPriority)
    const done = config.showCompleted
      ? base.filter(function(t) { return t.done }).sort(function(a, b) { return (b.due || "") < (a.due || "") ? -1 : 1 })
      : []

    const result = []
    if (pinned.length)   result.push({ key: "pinned",   label: "Fixadas",           tasks: pinned })
    if (overdue.length)  result.push({ key: "overdue",  label: "Atrasadas",         tasks: overdue })
    if (today.length)    result.push({ key: "today",    label: "Hoje",              tasks: today })
    if (upcoming.length) result.push({ key: "upcoming", label: "Próximos dias",     tasks: upcoming })
    if (other.length)    result.push({ key: "other",    label: "Sem prazo próximo", tasks: other })
    if (done.length)     result.push({ key: "done",     label: "Concluídas",        tasks: done })
    return result
  }

  // achatado — usado pra contagens no cabeçalho e pra saber o que está
  // visível agora (o resto vira "oculto")
  function visibleTaskList() {
    const flat = []
    root.sections().forEach(function(s) { flat.push.apply(flat, s.tasks) })
    return flat
  }

  // quaisquer tarefas que existem mas não aparecem na lista agora — seja
  // por estarem "muito longe" (hideFarTasks) ou concluídas escondidas
  // (showCompleted desligado). Filtro por data (filterDate) não conta como
  // "oculto": é uma visão intencional, não algo escondido por engano.
  function hiddenTasks() {
    if (root.filterDate) return []
    const visibleIds = {}
    root.visibleTaskList().forEach(function(t) { visibleIds[t.id] = true })
    return config.tasks.filter(function(t) { return !visibleIds[t.id] })
  }

  function priorityLabel(id) {
    const found = root.priorityList.find(function(p) { return p.id === id })
    return found ? found.label : id
  }
  function recurrenceLabel(id) {
    const found = root.recurrenceList.find(function(r) { return r.id === id })
    return found ? found.label : id
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

  // painel expansível de tarefas ocultas, no fim da lista — não altera
  // nenhuma config permanentemente, só dá uma espiada temporária
  property bool showHiddenPanel: false

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
          ? "Tarefas em " + root.filterDate + " · " + root.visibleTaskList().length
          : "Tarefas · " + root.visibleTaskList().filter(function(t) { return !t.done }).length + " pendentes"
        color: Colors[config.colorText]
        font { pixelSize: config.fontSize; family: "Inter"; weight: Font.DemiBold }
      }

      Rectangle {
        width: 18; height: 18; radius: 5
        color: dashboardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "\uf0e4"
          color: Colors[config.colorText]
          font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
        }
        MouseArea {
          id: dashboardMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.dashboardRequested()
        }
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

    Component {
      id: taskRowDelegate
      ColumnLayout {
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

              Rectangle {
                visible: !!modelData.status && root.statusColor[modelData.status] !== undefined
                Layout.preferredWidth: statusDot.implicitWidth + 2
                Layout.preferredHeight: 12
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.1)
                Text {
                  id: statusDot
                  anchors.centerIn: parent
                  text: modelData.status === "doing" ? "\uf04b" : (modelData.status === "blocked" ? "\uf05e" : "")
                  color: root.statusColor[modelData.status] || Qt.rgba(1, 1, 1, 0.5)
                  font { pixelSize: 7; family: "JetBrainsMono Nerd Font" }
                }
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
                text: modelData.due + (modelData.time ? " " + modelData.time : "") + (taskDelegate.overdue ? " ⚠" : "")
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

    Repeater {
      model: root.sections()
      delegate: ColumnLayout {
        id: sectionDelegate
        required property var modelData
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: !!sectionDelegate.modelData.label

          Text {
            text: sectionDelegate.modelData.label + " · " + sectionDelegate.modelData.tasks.length
            color: Qt.rgba(1, 1, 1, 0.45)
            font { pixelSize: config.fontSize - 6; family: "Inter"; weight: Font.DemiBold }
          }
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.08)
          }
        }

        Repeater {
          model: sectionDelegate.modelData.tasks
          delegate: taskRowDelegate
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: root.hiddenTasks().length > 0
      height: 22; radius: 6
      color: showHiddenMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
      Behavior on color { ColorAnimation { duration: 80 } }

      RowLayout {
        anchors.centerIn: parent
        spacing: 4
        Text {
          text: (root.showHiddenPanel ? "▾ " : "▸ ") + root.hiddenTasks().length + " tarefa(s) oculta(s)"
          color: Qt.rgba(1, 1, 1, 0.45)
          font.pixelSize: config.fontSize - 6
        }
      }
      MouseArea {
        id: showHiddenMa
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.showHiddenPanel = !root.showHiddenPanel
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 4
      visible: root.showHiddenPanel && root.hiddenTasks().length > 0

      Repeater {
        model: root.showHiddenPanel ? root.hiddenTasks() : []
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 6
          opacity: 0.75

          Rectangle {
            width: 12; height: 12; radius: 6
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
            Layout.fillWidth: true
            text: modelData.text
            color: Colors[config.colorText]
            opacity: modelData.done ? 0.5 : 1.0
            font { pixelSize: config.fontSize - 4; strikeout: modelData.done }
            elide: Text.ElideRight
          }
          Text {
            visible: !!modelData.due
            text: modelData.due + (modelData.time ? " " + modelData.time : "")
            color: Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize: config.fontSize - 6
          }
          Text {
            text: "\uf044"
            color: Qt.rgba(1, 1, 1, 0.4)
            font { pixelSize: config.fontSize - 6; family: "JetBrainsMono Nerd Font" }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.editTaskRequested(modelData)
            }
          }
          Text {
            text: "×"
            color: Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize: config.fontSize - 2
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: config.removeTask(modelData.id)
            }
          }
        }
      }

      // atalho: se o que está escondendo tarefa é o hideFarTasks, deixa
      // óbvio como desligar isso de vez (em vez de só espiar toda hora)
      Text {
        visible: config.hideFarTasks
        text: "mostrar tarefas distantes sempre →"
        color: Qt.rgba(1, 1, 1, 0.4)
        font { pixelSize: config.fontSize - 6; underline: farLinkMa.containsMouse }
        MouseArea {
          id: farLinkMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: config.hideFarTasks = false
        }
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
        Text {
          visible: !!(root.tooltipTask && !root.tooltipTask.done && root.tooltipTask.status && root.statusLabels[root.tooltipTask.status] !== undefined)
          text: root.tooltipTask ? (root.statusLabels[root.tooltipTask.status] || "") : ""
          color: root.tooltipTask ? (root.statusColor[root.tooltipTask.status] || Qt.rgba(1, 1, 1, 0.6)) : Qt.rgba(1, 1, 1, 0.6)
          font.pixelSize: config.fontSize - 5
        }
      }

      Text {
        visible: !!(root.tooltipTask && root.tooltipTask.due)
        text: root.tooltipTask
          ? ("Prazo: " + root.tooltipTask.due + (root.tooltipTask.time ? " às " + root.tooltipTask.time : "") + (root.isOverdueTask(root.tooltipTask) ? " · atrasada" : ""))
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
