import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// modules/widgets/todo/TodoDashboard.qml → modules/widgets/calendar/
import "../calendar" as CalMod

// ── TodoDashboard ────────────────────────────────────────────────────────
// Painel grande, centralizado (mesmo esqueleto do ConfigWindow/TodoAddWindow:
// PanelWindow em Overlay + HyprlandFocusGrab + animação _anim), com três
// visões das mesmas tarefas de state/TodoWidget.json:
//
//   • Kanban    — colunas Atrasadas / Hoje / Em breve / Sem prazo / Concluídas
//   • Progresso — totais, % concluído, distribuição por prioridade, últimos 7 dias
//   • Agenda    — semana / mês / ano
//
// Uso (dentro de TodoWidget.qml / WidgetHost.qml, junto da TodoAddWindow):
//   TodoDashboard { id: dashboardWindow }
//   TodoContent { onDashboardRequested: dashboardWindow.open() }
//   TodoDashboard {
//     onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
//     onAddTaskRequested:  () => addTaskWindow.openForm()
//   }
//
// Tem sua própria TodoConfig() — só lê/escreve o mesmo JSON que todo o
// resto do módulo, sincroniza sozinha.

PanelWindow {
  id: win

  property bool panelOpen: false
  signal closeRequested()
  signal editTaskRequested(var task)
  signal addTaskRequested()

  onCloseRequested: panelOpen = false

  TodoConfig { id: config }
  // só pra ler weekStartsMonday — o mesmo state/CalendarWidget.json que o
  // widget de calendário usa, pra semana/mês/ano seguirem a mesma
  // configuração de primeiro dia da semana em todo lugar
  CalMod.CalendarConfig { id: calConfig }

  // ── Vivo: hoje sempre atualizado (mesmo padrão do resto do módulo) ────
  property bool _tick: false
  Timer { interval: 60000; repeat: true; running: true; onTriggered: win._tick = !win._tick }
  function todayStr() { var _ = win._tick; return Qt.formatDate(new Date(), "yyyy-MM-dd") }

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
  // mesmos valores de TodoContent.qml — usados no selo "em andamento/bloqueada"
  // dos cards do Kanban (win.statusColor/win.statusLabels eram referenciados
  // aqui mas nunca tinham sido declarados nesse arquivo)
  readonly property var statusColor: ({
    doing:   "#5b9bd5",
    blocked: "#e08a3c",
  })
  readonly property var statusLabels: ({
    doing:   "Em andamento",
    blocked: "Bloqueada",
  })
  // cor de destaque do painel — usada em botões, abas ativas e nos anéis/
  // barras de progresso
  readonly property color accentColor: "#5b9bd5"

  function isOverdueTask(t) { return !t.done && !!t.due && t.due < win.todayStr() }
  function daysUntil(dueStr) {
    const today = new Date(win.todayStr() + "T00:00:00")
    const due   = new Date(dueStr + "T00:00:00")
    return Math.round((due - today) / 86400000)
  }
  function tasksForDate(dateStr) {
    return config.tasks.filter(function(t) { return t.due === dateStr })
  }
  function dayMarkerColor(dateStr) {
    const pending = win.tasksForDate(dateStr).filter(function(t) { return !t.done })
    if (!pending.length) return ""
    pending.sort(function(a, b) {
      const ao = win.priorityOrder[a.priority] !== undefined ? win.priorityOrder[a.priority] : 1
      const bo = win.priorityOrder[b.priority] !== undefined ? win.priorityOrder[b.priority] : 1
      return ao - bo
    })
    return win.priorityColor[pending[0].priority] || "#999999"
  }

  // ── Agrupamento pro Kanban ──────────────────────────────────────────
  // data decide primeiro; dentro do mesmo dia, horário desempata (quem
  // tem horário vem antes de quem não tem)
  function _compareDueThenTime(a, b) {
    const ad = a.due || "", bd = b.due || ""
    if (ad !== bd) return ad < bd ? -1 : 1
    const at = a.time || "", bt = b.time || ""
    if (at !== bt) {
      if (!at) return 1
      if (!bt) return -1
      return at < bt ? -1 : 1
    }
    return 0
  }
  function overdueList() {
    return config.tasks.filter(function(t) { return win.isOverdueTask(t) })
      .sort(win._compareDueThenTime)
  }
  function todayList() {
    return config.tasks.filter(function(t) { return !t.done && t.due === win.todayStr() })
      .sort(function(a, b) { return (a.time || "99:99") < (b.time || "99:99") ? -1 : 1 })
  }
  function soonList() {
    return config.tasks.filter(function(t) {
      return !t.done && !!t.due && t.due > win.todayStr() && win.daysUntil(t.due) <= config.dueSoonDays
    }).sort(win._compareDueThenTime)
  }
  function noDateList() {
    return config.tasks.filter(function(t) { return !t.done && !t.due })
      .sort(function(a, b) {
        const ao = win.priorityOrder[a.priority] !== undefined ? win.priorityOrder[a.priority] : 1
        const bo = win.priorityOrder[b.priority] !== undefined ? win.priorityOrder[b.priority] : 1
        return ao - bo
      })
  }
  function doneList() {
    return config.tasks.filter(function(t) { return t.done })
      .sort(function(a, b) { return (b.lastCompleted || "") < (a.lastCompleted || "") ? -1 : 1 })
  }

  readonly property var kanbanColumns: [
    { id: "overdue", label: "Atrasadas",  color: "#e5484d", icon: "\uf071" },
    { id: "today",   label: "Hoje",       color: "#f5a524", icon: "\uf073" },
    { id: "soon",    label: "Em breve",   color: "#5b9bd5", icon: "\uf017" },
    { id: "nodate",  label: "Sem prazo",  color: "#9b8afb", icon: "\uf0ca" },
    { id: "done",    label: "Concluídas", color: "#45a249", icon: "\uf00c" },
  ]
  function tasksForColumn(colId) {
    if (colId === "overdue") return win.overdueList()
    if (colId === "today")   return win.todayList()
    if (colId === "soon")    return win.soonList()
    if (colId === "nodate")  return win.noDateList()
    if (colId === "done")    return win.doneList()
    return []
  }

  // ── Estatísticas pro Progresso ──────────────────────────────────────
  function totalCount()   { return config.tasks.length }
  function doneCount()    { return config.tasks.filter(function(t) { return t.done }).length }
  function pendingCount() { return win.totalCount() - win.doneCount() }
  function completionPct() {
    return win.totalCount() === 0 ? 0 : win.doneCount() / win.totalCount()
  }
  function countByPriority(p) {
    return config.tasks.filter(function(t) { return !t.done && t.priority === p }).length
  }
  function completedOnDate(dateStr) {
    return config.tasks.filter(function(t) {
      if (!t.lastCompleted) return false
      return Qt.formatDate(new Date(t.lastCompleted), "yyyy-MM-dd") === dateStr
    }).length
  }
  function last7Days() {
    const arr = []
    const d = new Date(win.todayStr() + "T00:00:00")
    for (let i = 6; i >= 0; i--) {
      const dd = new Date(d)
      dd.setDate(dd.getDate() - i)
      arr.push(Qt.formatDate(dd, "yyyy-MM-dd"))
    }
    return arr
  }

  // ── Histórico de conclusão ───────────────────────────────────────────
  // lastCompleted é um ISO timestamp real (gravado no momento em que a
  // tarefa foi marcada como concluída, ver TodoConfig.toggleTask), não o
  // "due" da tarefa — por isso serve de horário de histórico de verdade,
  // diferente do prazo que ela tinha.
  function completedHistory(limit) {
    return config.tasks
      .filter(function(t) { return t.done && !!t.lastCompleted })
      .sort(function(a, b) { return a.lastCompleted < b.lastCompleted ? 1 : -1 })
      .slice(0, limit || 200)
  }
  function fmtCompletedAt(iso) {
    const d = new Date(iso)
    return Qt.formatDate(d, "dd/MM") + " · " + Qt.formatTime(d, "HH:mm")
  }
  function completedInMonth(y, m) {
    return config.tasks.filter(function(t) {
      if (!t.done || !t.lastCompleted) return false
      const d = new Date(t.lastCompleted)
      return d.getFullYear() === y && d.getMonth() === m
    }).sort(function(a, b) { return a.lastCompleted < b.lastCompleted ? 1 : -1 })
  }
  function pendingInMonth(y, m) {
    return config.tasks.filter(function(t) {
      if (t.done || !t.due) return false
      const d = new Date(t.due + "T00:00:00")
      return d.getFullYear() === y && d.getMonth() === m
    }).sort(function(a, b) { return (a.due || "") < (b.due || "") ? -1 : 1 })
  }
  function completedCountForMonth(y, m) { return win.completedInMonth(y, m).length }

  // ── Agenda: semana ───────────────────────────────────────────────────
  property string weekAnchor: ""
  function weekStartOf(dateStr) {
    const d = new Date(dateStr + "T00:00:00")
    const day = d.getDay()
    if (calConfig.weekStartsMonday) d.setDate(d.getDate() + (day === 0 ? -6 : 1 - day))
    else d.setDate(d.getDate() - day)
    return Qt.formatDate(d, "yyyy-MM-dd")
  }
  function weekDates(anchorStr) {
    const arr = []
    const d = new Date(anchorStr + "T00:00:00")
    for (let i = 0; i < 7; i++) {
      arr.push(Qt.formatDate(d, "yyyy-MM-dd"))
      d.setDate(d.getDate() + 1)
    }
    return arr
  }
  function _shiftDate(dateStr, days) {
    const d = new Date(dateStr + "T00:00:00")
    d.setDate(d.getDate() + days)
    return Qt.formatDate(d, "yyyy-MM-dd")
  }

  // ── Agenda: mês/ano ──────────────────────────────────────────────────
  property int viewYear:  new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property string selectedDate: ""
  readonly property var monthNames: [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
  ]
  readonly property var weekDayNamesMon: ["S", "T", "Q", "Q", "S", "S", "D"]
  readonly property var weekDayNamesSun: ["D", "S", "T", "Q", "Q", "S", "S"]
  readonly property var weekDayShort: calConfig.weekStartsMonday ? win.weekDayNamesMon : win.weekDayNamesSun

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function firstDayOffset(y, m) {
    let dow = new Date(y, m, 1).getDay()
    if (calConfig.weekStartsMonday) dow = (dow + 6) % 7
    return dow
  }
  function fmt(y, m, d) { return Qt.formatDate(new Date(y, m, d), "yyyy-MM-dd") }
  function buildMonthGrid() {
    const cells = []
    const offset = win.firstDayOffset(win.viewYear, win.viewMonth)
    const total  = win.daysInMonth(win.viewYear, win.viewMonth)
    for (let i = 0; i < offset; i++) cells.push({ valid: false })
    for (let d = 1; d <= total; d++) cells.push({ valid: true, day: d, dateStr: win.fmt(win.viewYear, win.viewMonth, d) })
    while (cells.length % 7 !== 0) cells.push({ valid: false })
    return cells
  }
  function monthPrev() {
    if (win.viewMonth === 0) { win.viewMonth = 11; win.viewYear -= 1 } else win.viewMonth -= 1
    win.selectedDate = ""
  }
  function monthNext() {
    if (win.viewMonth === 11) { win.viewMonth = 0; win.viewYear += 1 } else win.viewMonth += 1
    win.selectedDate = ""
  }
  function jumpToMonth(y, m) {
    win.viewYear = y; win.viewMonth = m
    win.agendaMode = "month"
    win.selectedDate = ""
  }
  function miniGridForMonth(y, m) {
    const cells = []
    const offset = win.firstDayOffset(y, m)
    const total  = win.daysInMonth(y, m)
    for (let i = 0; i < offset; i++) cells.push({ valid: false })
    for (let d = 1; d <= total; d++) cells.push({ valid: true, dateStr: win.fmt(y, m, d) })
    return cells
  }

  // ── Estado das abas ──────────────────────────────────────────────────
  property string activeTab: "kanban" // kanban | progress | agenda
  property string agendaMode: "week"  // week | month | year

  function open() {
    const today = win.todayStr()
    weekAnchor  = win.weekStartOf(today)
    viewYear    = new Date().getFullYear()
    viewMonth   = new Date().getMonth()
    selectedDate = ""
    activeTab = "kanban"
    _reveal()
  }
  function close() { panelOpen = false }

  function _reveal() {
    _closing = false; _alive = true
    _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
    openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
    panelOpen = true
  }

  onPanelOpenChanged: {
    if (!panelOpen) {
      _closing = true; openAnim.stop()
      closeAnim.from = _anim; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.restart()
      win.closeRequested()
    }
  }

  // ── Geometria ─────────────────────────────────────────────────────────
  readonly property int winW: 820
  readonly property int winH: 600

  visible:        _alive
  color:          "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.namespace:     "todo-dashboard"
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  margins.top:    screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.bottom: screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.left:   screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0
  margins.right:  screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0

  // ── Animação (mesmo padrão do ConfigWindow/TodoAddWindow) ─────────────
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
    color:     Qt.rgba(0.08, 0.08, 0.09, 0.98)
    border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

    ColumnLayout {
      id: mainCol
      anchors { fill: parent; margins: 16 }
      spacing: 10

      // ── Cabeçalho ────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          Layout.preferredWidth: 30; Layout.preferredHeight: 30
          radius: 9
          gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0.36, 0.61, 0.83, 0.35) }
            GradientStop { position: 1.0; color: Qt.rgba(0.36, 0.61, 0.83, 0.12) }
          }
          border.color: Qt.rgba(0.4, 0.7, 1, 0.4); border.width: 1
          Text {
            anchors.centerIn: parent
            text: "\uf0e4"
            color: "#ffffff"
            font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            text: "Painel de tarefas"
            color: Colors[config.colorText]
            font { pixelSize: config.fontSize + 1; family: "Inter"; weight: Font.DemiBold }
          }
          Text {
            text: win.pendingCount() + " pendentes · " + win.overdueList().length + " atrasadas · " + win.doneCount() + " concluídas"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: config.fontSize - 6
          }
        }

        Rectangle {
          width: 70; height: 24; radius: 6
          color: quickAddMa.containsMouse ? Qt.rgba(0.3, 0.6, 1, 0.3) : Qt.rgba(0.3, 0.6, 1, 0.18)
          border.color: Qt.rgba(0.4, 0.7, 1, 0.5); border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }
          Text {
            anchors.centerIn: parent
            text: "+ tarefa"
            color: Colors[config.colorText]
            font.pixelSize: config.fontSize - 5
          }
          MouseArea {
            id: quickAddMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.addTaskRequested()
          }
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
            onClicked: win.close()
          }
        }
      }

      // ── Abas principais ──────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: [
            { id: "kanban",   label: "Kanban",    icon: "\uf0db" },
            { id: "progress", label: "Progresso", icon: "\uf080" },
            { id: "agenda",   label: "Agenda",    icon: "\uf133" },
          ]
          delegate: Rectangle {
            id: tabChip
            required property var modelData
            readonly property bool active: win.activeTab === modelData.id
            Layout.preferredWidth: tabRow.implicitWidth + 24
            Layout.preferredHeight: 30
            radius: 8
            color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.22)
                           : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.55) : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
              id: tabRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: tabChip.modelData.icon
                color: tabChip.active ? win.accentColor : Qt.rgba(1, 1, 1, 0.5)
                font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
              }
              Text {
                text: tabChip.modelData.label
                color: Colors[config.colorText]
                opacity: tabChip.active ? 1.0 : 0.6
                font { pixelSize: config.fontSize - 3; weight: tabChip.active ? Font.DemiBold : Font.Normal }
              }
            }
            MouseArea {
              id: tabMa
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: win.activeTab = tabChip.modelData.id
            }
          }
        }

        Item { Layout.fillWidth: true }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      // ── Conteúdo ─────────────────────────────────────────────────────
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // ═══════════════ KANBAN ═══════════════
        RowLayout {
          anchors.fill: parent
          visible: win.activeTab === "kanban"
          spacing: 8

          Repeater {
            model: win.kanbanColumns
            delegate: Rectangle {
              id: kanbanCol
              required property var modelData
              Layout.preferredWidth: 148
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(1, 1, 1, 0.035)
              border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
              clip: true

              readonly property var colTasks: win.tasksForColumn(modelData.id)
              readonly property color colColor: modelData.color

              // barra de identidade da coluna, no topo
              Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 3
                color: kanbanCol.colColor
                opacity: 0.85
              }

              ColumnLayout {
                anchors { fill: parent; margins: 8; topMargin: 11 }
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 5
                  Text {
                    text: kanbanCol.modelData.icon
                    color: kanbanCol.colColor
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                  }
                  Text {
                    Layout.fillWidth: true
                    text: kanbanCol.modelData.label
                    color: Colors[config.colorText]
                    font { pixelSize: config.fontSize - 5; weight: Font.DemiBold }
                    elide: Text.ElideRight
                  }
                  Rectangle {
                    Layout.preferredWidth: countLabel.implicitWidth + 10
                    Layout.preferredHeight: 15
                    radius: 7
                    color: Qt.rgba(kanbanCol.colColor.r, kanbanCol.colColor.g, kanbanCol.colColor.b, 0.18)
                    Text {
                      id: countLabel
                      anchors.centerIn: parent
                      text: kanbanCol.colTasks.length
                      color: kanbanCol.colColor
                      font { pixelSize: config.fontSize - 7; weight: Font.DemiBold }
                    }
                  }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

                Flickable {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true
                  contentHeight: colInner.implicitHeight
                  boundsBehavior: Flickable.StopAtBounds

                  ColumnLayout {
                    id: colInner
                    width: parent.width
                    spacing: 5

                    Repeater {
                      model: kanbanCol.colTasks
                      delegate: Rectangle {
                        id: taskCard
                        required property var modelData
                        Layout.fillWidth: true
                        radius: 6
                        color: cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
                        border.color: cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                        border.width: 1
                        implicitHeight: cardCol.implicitHeight + 10
                        clip: true
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                          id: cardMa
                          anchors.fill: parent; hoverEnabled: true
                          acceptedButtons: Qt.NoButton
                        }

                        Rectangle {
                          anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                          width: 3
                          color: win.priorityColor[taskCard.modelData.priority] || "#999999"
                        }

                        ColumnLayout {
                          id: cardCol
                          anchors { fill: parent; margins: 5; leftMargin: 9 }
                          spacing: 2

                          RowLayout {
                            spacing: 4
                            Text {
                              Layout.fillWidth: true
                              text: taskCard.modelData.text
                              wrapMode: Text.WordWrap
                              maximumLineCount: 3
                              elide: Text.ElideRight
                              color: Colors[config.colorText]
                              opacity: taskCard.modelData.done ? 0.5 : 1.0
                              font { pixelSize: config.fontSize - 6; strikeout: taskCard.modelData.done }
                            }
                          }
                          RowLayout {
                            spacing: 4
                            visible: !!taskCard.modelData.status && win.statusColor[taskCard.modelData.status] !== undefined
                            Rectangle {
                              width: 5; height: 5; radius: 2.5
                              color: win.statusColor[taskCard.modelData.status] || "transparent"
                            }
                            Text {
                              text: win.statusLabels[taskCard.modelData.status] || ""
                              color: win.statusColor[taskCard.modelData.status] || Qt.rgba(1, 1, 1, 0.5)
                              font.pixelSize: config.fontSize - 8
                            }
                          }
                          Text {
                            visible: !!taskCard.modelData.due
                            text: (taskCard.modelData.time ? taskCard.modelData.time + " · " : "") + (taskCard.modelData.due || "")
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: config.fontSize - 7
                          }
                          RowLayout {
                            spacing: 8
                            Text {
                              text: taskCard.modelData.done ? "desfazer" : "concluir"
                              color: Qt.rgba(1, 1, 1, 0.45)
                              font { pixelSize: config.fontSize - 7; underline: doneMa.containsMouse }
                              MouseArea {
                                id: doneMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: config.toggleTask(taskCard.modelData.id)
                              }
                            }
                            Text {
                              text: "editar"
                              color: Qt.rgba(1, 1, 1, 0.45)
                              font { pixelSize: config.fontSize - 7; underline: editMa.containsMouse }
                              MouseArea {
                                id: editMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: win.editTaskRequested(taskCard.modelData)
                              }
                            }
                          }
                        }
                      }
                    }

                    ColumnLayout {
                      visible: kanbanCol.colTasks.length === 0
                      Layout.alignment: Qt.AlignHCenter
                      Layout.topMargin: 18
                      spacing: 3
                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: kanbanCol.modelData.icon
                        color: Qt.rgba(1, 1, 1, 0.15)
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                      }
                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "vazio"
                        color: Qt.rgba(1, 1, 1, 0.22)
                        font.pixelSize: config.fontSize - 6
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ═══════════════ PROGRESSO ═══════════════
        Flickable {
          anchors.fill: parent
          visible: win.activeTab === "progress"
          clip: true
          contentHeight: progressCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: progressCol
            width: parent.width
            spacing: 20

            // resumo em números
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              Repeater {
                model: [
                  { label: "Total",      value: win.totalCount(),         color: win.accentColor,  icon: "\uf03a" },
                  { label: "Pendentes",  value: win.pendingCount(),       color: "#f5a524",         icon: "\uf017" },
                  { label: "Concluídas", value: win.doneCount(),          color: "#45a249",         icon: "\uf00c" },
                  { label: "Atrasadas",  value: win.overdueList().length, color: "#e5484d",         icon: "\uf071" },
                ]
                delegate: Rectangle {
                  id: statCard
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredHeight: 68
                  radius: 10
                  color: Qt.rgba(1, 1, 1, 0.045)
                  clip: true

                  Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    width: 3
                    color: statCard.modelData.color
                    opacity: 0.85
                  }

                  ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    RowLayout {
                      Layout.alignment: Qt.AlignHCenter
                      spacing: 5
                      Text {
                        text: statCard.modelData.icon
                        color: statCard.modelData.color
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                      }
                      Text {
                        text: statCard.modelData.value
                        color: Colors[config.colorText]
                        font { pixelSize: config.fontSize + 5; weight: Font.DemiBold }
                      }
                    }
                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: statCard.modelData.label
                      color: Qt.rgba(1, 1, 1, 0.5)
                      font.pixelSize: config.fontSize - 6
                    }
                  }
                }
              }
            }

            // progresso geral — anel + distribuição por prioridade lado a lado
            RowLayout {
              Layout.fillWidth: true
              spacing: 20

              Item {
                Layout.preferredWidth: 108
                Layout.preferredHeight: 108

                Canvas {
                  id: progressRing
                  anchors.fill: parent
                  property real pct: win.completionPct()
                  onPctChanged: requestPaint()
                  Component.onCompleted: requestPaint()
                  onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = width / 2 - 9
                    ctx.lineWidth = 9
                    ctx.lineCap = "round"
                    ctx.strokeStyle = "rgba(255,255,255,0.08)"
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.stroke()
                    if (progressRing.pct > 0) {
                      ctx.strokeStyle = "#45a249"
                      ctx.beginPath()
                      ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progressRing.pct)
                      ctx.stroke()
                    }
                  }
                }
                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: -2
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Math.round(win.completionPct() * 100) + "%"
                    color: Colors[config.colorText]
                    font { pixelSize: config.fontSize + 2; weight: Font.DemiBold }
                  }
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "concluído"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: config.fontSize - 8
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                Text { text: "Pendentes por prioridade"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 3 }

                Repeater {
                  model: win.priorityList
                  delegate: RowLayout {
                    id: prioRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    readonly property int count: win.countByPriority(modelData.id)
                    readonly property int maxCount: Math.max(1, win.countByPriority("alta"), win.countByPriority("media"), win.countByPriority("baixa"))

                    Text {
                      Layout.preferredWidth: 42
                      text: prioRow.modelData.label
                      color: Qt.rgba(1, 1, 1, 0.6)
                      font.pixelSize: config.fontSize - 5
                    }
                    Rectangle {
                      Layout.fillWidth: true
                      height: 9; radius: 4.5
                      color: Qt.rgba(1, 1, 1, 0.08)
                      Rectangle {
                        width: parent.width * (prioRow.count / prioRow.maxCount)
                        height: parent.height; radius: 4.5
                        gradient: Gradient {
                          orientation: Gradient.Horizontal
                          GradientStop { position: 0.0; color: Qt.rgba(win.priorityColor[prioRow.modelData.id].r, win.priorityColor[prioRow.modelData.id].g, win.priorityColor[prioRow.modelData.id].b, 0.55) }
                          GradientStop { position: 1.0; color: win.priorityColor[prioRow.modelData.id] }
                        }
                        Behavior on width { NumberAnimation { duration: 200 } }
                      }
                    }
                    Text {
                      Layout.preferredWidth: 16
                      text: prioRow.count
                      color: Qt.rgba(1, 1, 1, 0.5)
                      font.pixelSize: config.fontSize - 5
                    }
                  }
                }
              }
            }

            // últimos 7 dias
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 8
              Text { text: "Concluídas nos últimos 7 dias"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 3 }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.03)

                RowLayout {
                  id: last7Row
                  anchors { fill: parent; margins: 10 }
                  spacing: 8
                  readonly property var days: win.last7Days()
                  readonly property int maxVal: {
                    let m = 1
                    for (const d of days) m = Math.max(m, win.completedOnDate(d))
                    return m
                  }

                  Repeater {
                    model: last7Row.days
                    delegate: ColumnLayout {
                      id: dayCol
                      required property string modelData
                      required property int index
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      spacing: 3
                      readonly property int val: win.completedOnDate(modelData)
                      readonly property bool isToday: modelData === win.todayStr()

                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: dayCol.val > 0 ? dayCol.val : ""
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font { pixelSize: config.fontSize - 7; weight: Font.DemiBold }
                      }
                      Item { Layout.fillHeight: true }
                      Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: Math.max(3, 44 * (dayCol.val / last7Row.maxVal))
                        radius: 4
                        gradient: Gradient {
                          orientation: Gradient.Vertical
                          GradientStop { position: 0.0; color: dayCol.isToday ? win.accentColor : Qt.rgba(1, 1, 1, 0.35) }
                          GradientStop { position: 1.0; color: dayCol.isToday ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.35) : Qt.rgba(1, 1, 1, 0.12) }
                        }
                      }
                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(new Date(dayCol.modelData + "T00:00:00"), "ddd")
                        color: dayCol.isToday ? win.accentColor : Qt.rgba(1, 1, 1, 0.4)
                        font { pixelSize: config.fontSize - 7; weight: dayCol.isToday ? Font.DemiBold : Font.Normal }
                      }
                    }
                  }
                }
              }
            }

            // histórico de conclusão — cada tarefa concluída com o horário
            // real em que foi marcada como feita (lastCompleted), mais
            // recente primeiro
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 8
              Text { text: "Histórico de conclusão"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 3 }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, Math.max(64, historyCol.implicitHeight + 16))
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.03)
                clip: true

                Flickable {
                  anchors { fill: parent; margins: 8 }
                  clip: true
                  contentHeight: historyCol.implicitHeight
                  boundsBehavior: Flickable.StopAtBounds

                  ColumnLayout {
                    id: historyCol
                    width: parent.width
                    spacing: 4

                    Repeater {
                      model: win.completedHistory(50)
                      delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                          text: "\uf00c"
                          color: "#45a249"
                          font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                        Text {
                          Layout.fillWidth: true
                          text: modelData.text
                          elide: Text.ElideRight
                          opacity: 0.75
                          color: Colors[config.colorText]
                          font { pixelSize: config.fontSize - 6; strikeout: true }
                        }
                        Text {
                          text: win.fmtCompletedAt(modelData.lastCompleted)
                          color: Qt.rgba(1, 1, 1, 0.4)
                          font.pixelSize: config.fontSize - 7
                        }
                      }
                    }
                    Text {
                      visible: win.completedHistory(1).length === 0
                      text: "Nenhuma tarefa concluída ainda."
                      color: Qt.rgba(1, 1, 1, 0.4)
                      font.pixelSize: config.fontSize - 6
                    }
                  }
                }
              }
            }
          }
        }

        // ═══════════════ AGENDA ═══════════════
        ColumnLayout {
          anchors.fill: parent
          visible: win.activeTab === "agenda"
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
              model: [
                { id: "week",  label: "Semana" },
                { id: "month", label: "Mês" },
                { id: "year",  label: "Ano" },
              ]
              delegate: Rectangle {
                id: subChip
                required property var modelData
                readonly property bool active: win.agendaMode === modelData.id
                Layout.preferredWidth: subLabel.implicitWidth + 18
                Layout.preferredHeight: 24
                radius: 6
                color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.2) : "transparent"
                border.color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.5) : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                  id: subLabel
                  anchors.centerIn: parent
                  text: subChip.modelData.label
                  color: subChip.active ? win.accentColor : Colors[config.colorText]
                  opacity: subChip.active ? 1.0 : 0.55
                  font { pixelSize: config.fontSize - 5; weight: subChip.active ? Font.DemiBold : Font.Normal }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: win.agendaMode = subChip.modelData.id
                }
              }
            }
            Item { Layout.fillWidth: true }
          }

          // ── Semana ─────────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: win.agendaMode === "week"
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 24; height: 22; radius: 6
                color: weekPrevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "‹"; color: Colors[config.colorText] }
                MouseArea { id: weekPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: win.weekAnchor = win._shiftDate(win.weekAnchor, -7) }
              }
              Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: win.weekDates(win.weekAnchor).length
                  ? (win.weekDates(win.weekAnchor)[0] + " – " + win.weekDates(win.weekAnchor)[6])
                  : ""
                color: Colors[config.colorText]
                font.pixelSize: config.fontSize - 4
              }
              Rectangle {
                width: 24; height: 22; radius: 6
                color: weekNextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "›"; color: Colors[config.colorText] }
                MouseArea { id: weekNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: win.weekAnchor = win._shiftDate(win.weekAnchor, 7) }
              }
              Rectangle {
                width: 46; height: 22; radius: 6
                color: weekTodayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "hoje"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 6 }
                MouseArea { id: weekTodayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: win.weekAnchor = win.weekStartOf(win.todayStr()) }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 6

              Repeater {
                model: win.weekDates(win.weekAnchor)
                delegate: Rectangle {
                  id: weekDayCard
                  required property string modelData
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: 8
                  readonly property bool isToday: modelData === win.todayStr()
                  color: isToday ? Qt.rgba(0.3, 0.6, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                  border.color: isToday ? Qt.rgba(0.4, 0.7, 1, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                  border.width: 1

                  ColumnLayout {
                    anchors { fill: parent; margins: 6 }
                    spacing: 4

                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: Qt.formatDate(new Date(weekDayCard.modelData + "T00:00:00"), "ddd") + " " +
                            Qt.formatDate(new Date(weekDayCard.modelData + "T00:00:00"), "d")
                      color: Colors[config.colorText]
                      opacity: weekDayCard.isToday ? 1.0 : 0.65
                      font { pixelSize: config.fontSize - 6; weight: weekDayCard.isToday ? Font.DemiBold : Font.Normal }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Flickable {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      clip: true
                      contentHeight: weekDayCol.implicitHeight
                      boundsBehavior: Flickable.StopAtBounds

                      ColumnLayout {
                        id: weekDayCol
                        width: parent.width
                        spacing: 3
                        Repeater {
                          model: win.tasksForDate(weekDayCard.modelData)
                          delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 3
                            Rectangle {
                              width: 5; height: 5; radius: 2.5
                              color: win.priorityColor[modelData.priority] || "#999"
                            }
                            Text {
                              Layout.fillWidth: true
                              text: modelData.text
                              elide: Text.ElideRight
                              opacity: modelData.done ? 0.4 : 1.0
                              color: Colors[config.colorText]
                              font { pixelSize: config.fontSize - 7; strikeout: modelData.done }
                            }
                            MouseArea {
                              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: win.editTaskRequested(modelData)
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // ── Mês ────────────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: win.agendaMode === "month"
            spacing: 20

            ColumnLayout {
              Layout.preferredWidth: 192
              Layout.maximumWidth: 192
              Layout.minimumWidth: 192
              Layout.alignment: Qt.AlignTop
              clip: true
              spacing: 6

              RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 192
                Rectangle {
                  width: 22; height: 20; radius: 6
                  color: monthPrevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                  Text { anchors.centerIn: parent; text: "‹"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 5 }
                  MouseArea { id: monthPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.monthPrev() }
                }
                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  horizontalAlignment: Text.AlignHCenter
                  text: win.monthNames[win.viewMonth] + " " + win.viewYear
                  elide: Text.ElideRight
                  color: Colors[config.colorText]
                  font.pixelSize: config.fontSize - 6
                }
                Rectangle {
                  width: 22; height: 20; radius: 6
                  color: monthNextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                  Text { anchors.centerIn: parent; text: "›"; color: Colors[config.colorText]; font.pixelSize: config.fontSize - 5 }
                  MouseArea { id: monthNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.monthNext() }
                }
                Rectangle {
                  width: 20; height: 20; radius: 6
                  color: monthTodayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                  Text { anchors.centerIn: parent; text: "\uf192"; color: Colors[config.colorText]; font { pixelSize: 9; family: "JetBrainsMono Nerd Font" } }
                  MouseArea { id: monthTodayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { win.viewYear = new Date().getFullYear(); win.viewMonth = new Date().getMonth() } }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 192
                spacing: 0
                Repeater {
                  model: win.weekDayShort
                  delegate: Text {
                    required property string modelData
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: config.fontSize - 8
                  }
                }
              }

              GridLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 192
                columns: 7
                rowSpacing: 1; columnSpacing: 0

                Repeater {
                  model: win.buildMonthGrid()
                  delegate: Item {
                    id: monthCell
                    required property var modelData
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 24

                    readonly property bool isToday: modelData.valid && modelData.dateStr === win.todayStr()
                    readonly property bool isSelected: modelData.valid && modelData.dateStr === win.selectedDate
                    readonly property string markColor: modelData.valid ? win.dayMarkerColor(modelData.dateStr) : ""

                    Rectangle {
                      anchors.fill: parent; anchors.margins: 1; radius: 5
                      color: monthCell.isToday ? Qt.rgba(0.3, 0.6, 1, 0.25) : "transparent"
                      border.color: monthCell.isSelected ? Qt.rgba(1, 1, 1, 0.5) : "transparent"
                      border.width: 1.5
                    }
                    Text {
                      anchors.centerIn: parent
                      anchors.verticalCenterOffset: -2
                      visible: monthCell.modelData.valid
                      text: monthCell.modelData.valid ? monthCell.modelData.day : ""
                      color: Colors[config.colorText]
                      font.pixelSize: config.fontSize - 7
                    }
                    Rectangle {
                      visible: monthCell.modelData.valid && monthCell.markColor !== ""
                      width: 3; height: 3; radius: 1.5
                      color: monthCell.markColor
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 3
                    }
                    MouseArea {
                      anchors.fill: parent
                      enabled: monthCell.modelData.valid
                      cursorShape: Qt.PointingHandCursor
                      onClicked: win.selectedDate = (win.selectedDate === monthCell.modelData.dateStr) ? "" : monthCell.modelData.dateStr
                    }
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 192
                Layout.topMargin: 4
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 192
                Layout.topMargin: 4
                spacing: 4
                Text {
                  text: "\uf00c"
                  color: "#45a249"
                  font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                }
                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: win.completedCountForMonth(win.viewYear, win.viewMonth) + " concluídas"
                  elide: Text.ElideRight
                  color: Qt.rgba(1, 1, 1, 0.45)
                  font.pixelSize: config.fontSize - 8
                }
              }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Qt.rgba(1, 1, 1, 0.08) }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 6

              RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                  Layout.fillWidth: true
                  text: win.selectedDate ? ("Tarefas em " + win.selectedDate) : (win.monthNames[win.viewMonth] + " " + win.viewYear)
                  color: Colors[config.colorText]
                  font { pixelSize: config.fontSize - 3; weight: Font.DemiBold }
                }
                Text {
                  visible: win.selectedDate !== ""
                  text: "limpar"
                  color: Qt.rgba(1, 1, 1, 0.45)
                  font { pixelSize: config.fontSize - 6; underline: monthClearMa.containsMouse }
                  MouseArea {
                    id: monthClearMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.selectedDate = ""
                  }
                }
              }

              // ── Um dia selecionado: tarefas daquele dia ──────────────
              Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: win.selectedDate !== ""
                clip: true
                contentHeight: monthDetailCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                  id: monthDetailCol
                  width: parent.width
                  spacing: 6

                  Repeater {
                    model: win.selectedDate ? win.tasksForDate(win.selectedDate) : []
                    delegate: Rectangle {
                      id: dayTaskCard
                      required property var modelData
                      Layout.fillWidth: true
                      radius: 8
                      color: dayCardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035)
                      border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                      implicitHeight: dayCardCol.implicitHeight + 16
                      clip: true
                      Behavior on color { ColorAnimation { duration: 100 } }

                      MouseArea {
                        id: dayCardMa
                        anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                      }

                      Rectangle {
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        width: 3
                        color: win.priorityColor[dayTaskCard.modelData.priority] || "#999999"
                      }

                      ColumnLayout {
                        id: dayCardCol
                        anchors { fill: parent; margins: 8; leftMargin: 12 }
                        spacing: 3

                        Text {
                          Layout.fillWidth: true
                          text: dayTaskCard.modelData.text
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          color: Colors[config.colorText]
                          opacity: dayTaskCard.modelData.done ? 0.5 : 1.0
                          font { pixelSize: config.fontSize - 3; strikeout: dayTaskCard.modelData.done }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 8
                          Text {
                            Layout.fillWidth: true
                            text: dayTaskCard.modelData.done && dayTaskCard.modelData.lastCompleted
                              ? ("\uf00c  concluída às " + Qt.formatTime(new Date(dayTaskCard.modelData.lastCompleted), "HH:mm"))
                              : (dayTaskCard.modelData.time || "sem horário")
                            color: dayTaskCard.modelData.done ? "#45a249" : Qt.rgba(1, 1, 1, 0.45)
                            font { pixelSize: config.fontSize - 6; family: dayTaskCard.modelData.done ? "JetBrainsMono Nerd Font" : "Inter" }
                          }
                          Text {
                            text: "editar"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font { pixelSize: config.fontSize - 6; underline: monthEditMa.containsMouse }
                            MouseArea {
                              id: monthEditMa
                              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: win.editTaskRequested(dayTaskCard.modelData)
                            }
                          }
                        }
                      }
                    }
                  }
                  Text {
                    visible: win.selectedDate !== "" && win.tasksForDate(win.selectedDate).length === 0
                    text: "Nenhuma tarefa neste dia."
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: config.fontSize - 5
                  }
                }
              }

              // ── Nenhum dia selecionado: visão geral do mês ───────────
              Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: win.selectedDate === ""
                clip: true
                contentHeight: monthOverviewCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                  id: monthOverviewCol
                  width: parent.width
                  spacing: 16

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                      text: "Pendentes com prazo no mês (" + win.pendingInMonth(win.viewYear, win.viewMonth).length + ")"
                      color: Qt.rgba(1, 1, 1, 0.55)
                      font.pixelSize: config.fontSize - 5
                    }
                    Repeater {
                      model: win.pendingInMonth(win.viewYear, win.viewMonth)
                      delegate: Rectangle {
                        id: pendingCard
                        required property var modelData
                        Layout.fillWidth: true
                        radius: 8
                        color: pendingCardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        implicitHeight: pendingCardCol.implicitHeight + 14
                        clip: true
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                          id: pendingCardMa
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: win.selectedDate = pendingCard.modelData.due
                        }

                        Rectangle {
                          anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                          width: 3
                          color: win.priorityColor[pendingCard.modelData.priority] || "#999999"
                        }

                        ColumnLayout {
                          id: pendingCardCol
                          anchors { fill: parent; margins: 7; leftMargin: 11 }
                          spacing: 2
                          Text {
                            Layout.fillWidth: true
                            text: pendingCard.modelData.text
                            elide: Text.ElideRight
                            color: Colors[config.colorText]
                            font.pixelSize: config.fontSize - 4
                          }
                          Text {
                            text: Qt.formatDate(new Date(pendingCard.modelData.due + "T00:00:00"), "dd/MM") +
                                  (pendingCard.modelData.time ? " · " + pendingCard.modelData.time : "")
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: config.fontSize - 6
                          }
                        }
                      }
                    }
                    Text {
                      visible: win.pendingInMonth(win.viewYear, win.viewMonth).length === 0
                      text: "Nada pendente neste mês."
                      color: Qt.rgba(1, 1, 1, 0.35)
                      font.pixelSize: config.fontSize - 6
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                      text: "Histórico de conclusão do mês (" + win.completedInMonth(win.viewYear, win.viewMonth).length + ")"
                      color: Qt.rgba(1, 1, 1, 0.55)
                      font.pixelSize: config.fontSize - 5
                    }
                    Repeater {
                      model: win.completedInMonth(win.viewYear, win.viewMonth)
                      delegate: Rectangle {
                        id: histCard
                        required property var modelData
                        Layout.fillWidth: true
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.025)
                        implicitHeight: histCardRow.implicitHeight + 12
                        clip: true

                        RowLayout {
                          id: histCardRow
                          anchors { fill: parent; margins: 7 }
                          spacing: 8
                          Text {
                            text: "\uf00c"
                            color: "#45a249"
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                          }
                          Text {
                            Layout.fillWidth: true
                            text: histCard.modelData.text
                            elide: Text.ElideRight
                            opacity: 0.75
                            color: Colors[config.colorText]
                            font { pixelSize: config.fontSize - 4; strikeout: true }
                          }
                          Text {
                            text: win.fmtCompletedAt(histCard.modelData.lastCompleted)
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: config.fontSize - 6
                          }
                        }
                      }
                    }
                    Text {
                      visible: win.completedInMonth(win.viewYear, win.viewMonth).length === 0
                      text: "Nenhuma conclusão neste mês."
                      color: Qt.rgba(1, 1, 1, 0.35)
                      font.pixelSize: config.fontSize - 6
                    }
                  }
                }
              }
            }
          }

          // ── Ano ────────────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: win.agendaMode === "year"
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 24; height: 22; radius: 6
                color: yearPrevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "‹"; color: Colors[config.colorText] }
                MouseArea { id: yearPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: win.viewYear -= 1 }
              }
              Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: String(win.viewYear)
                color: Colors[config.colorText]
                font.pixelSize: config.fontSize - 4
              }
              Rectangle {
                width: 24; height: 22; radius: 6
                color: yearNextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "›"; color: Colors[config.colorText] }
                MouseArea { id: yearNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: win.viewYear += 1 }
              }
            }

            GridLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignTop
              columns: 4
              rowSpacing: 10; columnSpacing: 10

              Repeater {
                model: 12
                delegate: Rectangle {
                  id: miniMonth
                  required property int index
                  Layout.fillWidth: true
                  Layout.preferredHeight: 104
                  radius: 8
                  color: miniMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                  border.color: (win.viewYear === new Date().getFullYear() && miniMonth.index === new Date().getMonth())
                    ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                  border.width: 1
                  Behavior on color { ColorAnimation { duration: 80 } }

                  ColumnLayout {
                    anchors { fill: parent; margins: 8 }
                    spacing: 5

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 4
                      Text {
                        Layout.fillWidth: true
                        text: win.monthNames[miniMonth.index]
                        color: Colors[config.colorText]
                        font { pixelSize: config.fontSize - 6; weight: Font.DemiBold }
                      }
                      Text {
                        visible: win.completedCountForMonth(win.viewYear, miniMonth.index) > 0
                        text: "\uf00c " + win.completedCountForMonth(win.viewYear, miniMonth.index)
                        color: "#45a249"
                        opacity: 0.8
                        font { pixelSize: config.fontSize - 8; family: "JetBrainsMono Nerd Font" }
                      }
                    }

                    GridLayout {
                      Layout.fillWidth: true
                      columns: 7
                      rowSpacing: 2; columnSpacing: 2

                      Repeater {
                        model: win.miniGridForMonth(win.viewYear, miniMonth.index)
                        delegate: Rectangle {
                          required property var modelData
                          Layout.preferredWidth: 8; Layout.preferredHeight: 8
                          radius: 2
                          color: !modelData.valid ? "transparent"
                            : (modelData.dateStr === win.todayStr() ? Qt.rgba(0.3, 0.6, 1, 0.6)
                              : (win.dayMarkerColor(modelData.dateStr) || Qt.rgba(1, 1, 1, 0.06)))
                        }
                      }
                    }

                    Item { Layout.fillHeight: true }
                  }

                  MouseArea {
                    id: miniMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.jumpToMonth(win.viewYear, miniMonth.index)
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }
        }
      }
    }
  }
}
