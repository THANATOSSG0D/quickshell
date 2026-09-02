import QtQuick
import QtQuick.Layouts

// ── TasksCalendarContent ────────────────────────────────────────────────
// Calendário mensal interativo do módulo Tasks. Cada dia com tarefa ganha
// um pontinho colorido (accent = tem pendente atrasada, cor de prioridade
// = pendente futura/hoje, cinza = só concluídas). Clicar num dia seleciona
// a data e lista as tarefas daquele dia logo abaixo — com checkbox
// (toggleTask), editar e excluir — mais um "+" que emite
// addTaskRequested(dueDate) pro TasksCalendarPopup abrir o TodoAddWindow
// já mirando aquela data.
//
// Não escreve em TodoConfig diretamente (exceto toggle/remove, que já são
// ações de 1 clique existentes em TasksContent.qml) — criar/editar tarefa
// sempre passa pelo TodoAddWindow via addTaskRequested/editTaskRequested,
// mesmo esquema de TasksContent.qml.

Item {
  id: root

  required property var todoConfig

  property color colorText:    "#e2e2e2"
  property color colorTextDim: "#9e9e9e"
  property color colorAccent:  "#ffb4a9"
  property color colorDivider: "#474747"

  signal addTaskRequested(string dueDate)
  signal editTaskRequested(var task)

  readonly property var priorityColor: ({ alta: "#e5484d", media: "#f5a524", baixa: "#45a249" })
  readonly property var weekdayLabels: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  readonly property var monthLabels: [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  ]

  property int    viewYear:     new Date().getFullYear()
  property int    viewMonth:    new Date().getMonth()   // 0-based
  property string selectedDate: root._todayStr()

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS DE DATA
  // ═══════════════════════════════════════════════════════════════════════
  function _tint(a) { return Qt.rgba(1, 1, 1, a) }
  function _todayStr() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
  function _pad2(n) { return n < 10 ? "0" + n : String(n) }
  function _dateStr(y, m, d) { return y + "-" + root._pad2(m + 1) + "-" + root._pad2(d) }
  function _daysInMonth(y, m)  { return new Date(y, m + 1, 0).getDate() }
  function _firstWeekday(y, m) { return new Date(y, m, 1).getDay() }  // 0=dom

  function prevMonth() {
    if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear -= 1 }
    else root.viewMonth -= 1
  }
  function nextMonth() {
    if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear += 1 }
    else root.viewMonth += 1
  }
  function goToday() {
    var t = new Date()
    root.viewYear     = t.getFullYear()
    root.viewMonth    = t.getMonth()
    root.selectedDate = root._todayStr()
  }

  // Grade de 42 células (6 semanas) — inclui a cauda do mês anterior/
  // seguinte pra preencher a primeira e a última semana.
  function gridCells() {
    var y = root.viewYear, m = root.viewMonth
    var firstWd  = root._firstWeekday(y, m)
    var daysThis = root._daysInMonth(y, m)
    var prevY    = (m === 0)  ? y - 1 : y
    var prevM    = (m === 0)  ? 11    : m - 1
    var daysPrev = root._daysInMonth(prevY, prevM)
    var nextY    = (m === 11) ? y + 1 : y
    var nextM    = (m === 11) ? 0     : m + 1

    var cells = []
    for (var i = 0; i < firstWd; i++) {
      var d = daysPrev - firstWd + 1 + i
      cells.push({ day: d, date: root._dateStr(prevY, prevM, d), inMonth: false })
    }
    for (var d2 = 1; d2 <= daysThis; d2++)
      cells.push({ day: d2, date: root._dateStr(y, m, d2), inMonth: true })
    var d3 = 1
    while (cells.length < 42) {
      cells.push({ day: d3, date: root._dateStr(nextY, nextM, d3), inMonth: false })
      d3++
    }
    return cells
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAREFAS POR DATA
  // ═══════════════════════════════════════════════════════════════════════
  function tasksOnDate(dateStr) {
    if (!root.todoConfig) return []
    return root.todoConfig.tasks.filter(function(t) { return t.due === dateStr })
  }

  // null = sem tarefa nesse dia. accent = tem pendente atrasada (dia no
  // passado). cor de prioridade = pendente hoje/futura. cinza dim = só
  // tem tarefa concluída nesse dia.
  function cellDotColor(dateStr) {
    var list = root.tasksOnDate(dateStr)
    if (list.length === 0) return null
    var pending = list.filter(function(t) { return !t.done })
    if (pending.length === 0) return root._tint(0.35)
    if (dateStr < root._todayStr()) return root.colorAccent
    var order = { alta: 0, media: 1, baixa: 2 }
    pending.sort(function(a, b) {
      var ao = order[a.priority] !== undefined ? order[a.priority] : 1
      var bo = order[b.priority] !== undefined ? order[b.priority] : 1
      return ao - bo
    })
    return root.priorityColor[pending[0].priority] || "#999999"
  }

  function _selectedLabel() {
    var d    = new Date(root.selectedDate + "T00:00:00")
    var wd   = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"][d.getDay()]
    var base = Qt.formatDate(d, "dd/MM/yyyy") + " · " + wd
    return root.selectedDate === root._todayStr() ? ("Hoje · " + base) : base
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    Text {
      Layout.fillWidth: true
      text: "Calendário"
      color: root.colorText
      opacity: 0.55
      font { pixelSize: 10; family: "Inter"; weight: Font.DemiBold; letterSpacing: 1; capitalization: Font.AllUppercase }
    }

    // ── Navegação de mês ─────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "‹"
        color: root.colorTextDim
        font.pixelSize: 15
        MouseArea {
          anchors.fill: parent; anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          onClicked: root.prevMonth()
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.monthLabels[root.viewMonth] + " " + root.viewYear
        color: root.colorText
        font { pixelSize: 12; weight: Font.DemiBold }
      }

      Text {
        text: "›"
        color: root.colorTextDim
        font.pixelSize: 15
        MouseArea {
          anchors.fill: parent; anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextMonth()
        }
      }

      Rectangle {
        width: hojeLbl.implicitWidth + 12; height: 18; radius: 9
        color: hojeMa.containsMouse ? root._tint(0.14) : root._tint(0.07)
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          id: hojeLbl
          anchors.centerIn: parent
          text: "hoje"
          color: root.colorTextDim
          font.pixelSize: 9
        }
        MouseArea {
          id: hojeMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.goToday()
        }
      }
    }

    // ── Grade do mês — cabeçalho de dias da semana + 6 semanas, no MESMO
    // GridLayout pra garantir que as colunas fiquem alinhadas ──────────
    GridLayout {
      Layout.fillWidth: true
      columns: 7
      rowSpacing: 4
      columnSpacing: 4

      Repeater {
        model: root.weekdayLabels
        delegate: Text {
          required property string modelData
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: root.colorTextDim
          opacity: 0.6
          font { pixelSize: 9; family: "Inter"; weight: Font.DemiBold; capitalization: Font.AllUppercase }
        }
      }

      Repeater {
        model: root.gridCells()
        delegate: Rectangle {
          id: dayCell
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 8

          readonly property bool isToday:    dayCell.modelData.date === root._todayStr()
          readonly property bool isSelected: dayCell.modelData.date === root.selectedDate
          readonly property var  dot:        root.cellDotColor(dayCell.modelData.date)

          color: dayCell.isSelected
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
              : (dayCellMa.containsMouse ? root._tint(0.08) : "transparent")
          border.width: (dayCell.isToday && !dayCell.isSelected) ? 1 : 0
          border.color: root.colorAccent
          Behavior on color { ColorAnimation { duration: 80 } }

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: String(dayCell.modelData.day)
              color: !dayCell.modelData.inMonth ? root.colorTextDim
                   : dayCell.isToday             ? root.colorAccent
                   : root.colorText
              opacity: dayCell.modelData.inMonth ? 1.0 : 0.35
              font { pixelSize: 11; weight: dayCell.isToday ? Font.DemiBold : Font.Normal }
            }
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: 4; height: 4; radius: 2
              visible: !!dayCell.dot
              color: dayCell.dot || "transparent"
            }
          }

          MouseArea {
            id: dayCellMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var parts = dayCell.modelData.date.split("-")
              var ty = parseInt(parts[0]), tm = parseInt(parts[1]) - 1
              if (ty !== root.viewYear || tm !== root.viewMonth) {
                root.viewYear  = ty
                root.viewMonth = tm
              }
              root.selectedDate = dayCell.modelData.date
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.colorDivider; opacity: 0.3 }

    // ── Data selecionada + botão de adicionar ─────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Text {
        Layout.fillWidth: true
        text: root._selectedLabel()
        color: root.colorText
        opacity: 0.8
        font { pixelSize: 10; family: "Inter"; weight: Font.DemiBold }
        elide: Text.ElideRight
      }
      Rectangle {
        width: 20; height: 20; radius: 5
        color: addBtnMa.containsMouse ? root._tint(0.14) : root._tint(0.07)
        Behavior on color { ColorAnimation { duration: 80 } }
        Text { anchors.centerIn: parent; text: "+"; color: root.colorText; font.pixelSize: 13 }
        MouseArea {
          id: addBtnMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.addTaskRequested(root.selectedDate)
        }
      }
    }

    // ── Tarefas do dia selecionado ─────────────────────────────────────
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      Flickable {
        anchors.fill: parent
        contentHeight: dayCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: dayCol
          width: parent.width
          spacing: 2

          Text {
            Layout.fillWidth: true
            visible: root.tasksOnDate(root.selectedDate).length === 0
            text: "nenhuma tarefa nesta data"
            horizontalAlignment: Text.AlignHCenter
            color: root.colorTextDim
            opacity: 0.5
            font.pixelSize: 10
            Layout.topMargin: 6
            Layout.bottomMargin: 6
          }

          Repeater {
            model: root.tasksOnDate(root.selectedDate)
            delegate: Rectangle {
              id: dayTaskRow
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 28
              radius: 7
              color: dayTaskHover.hovered ? root._tint(0.06) : "transparent"
              Behavior on color { ColorAnimation { duration: 80 } }

              HoverHandler { id: dayTaskHover }

              RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                spacing: 7

                Rectangle {
                  width: 13; height: 13; radius: 6.5
                  border.width: 1.5
                  border.color: dayTaskRow.modelData.done ? "#45a249" : root._tint(0.4)
                  color: dayTaskRow.modelData.done ? "#45a249" : "transparent"
                  MouseArea {
                    anchors.fill: parent; anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.todoConfig.toggleTask(dayTaskRow.modelData.id)
                  }
                }

                Rectangle {
                  width: 6; height: 6; radius: 3
                  color: root.priorityColor[dayTaskRow.modelData.priority] || "#999999"
                }

                Text {
                  Layout.fillWidth: true
                  text: dayTaskRow.modelData.text
                  color: root.colorText
                  opacity: dayTaskRow.modelData.done ? 0.45 : 1.0
                  font { pixelSize: 11; family: "Inter"; strikeout: dayTaskRow.modelData.done }
                  elide: Text.ElideRight
                }

                Text {
                  visible: !!dayTaskRow.modelData.time
                  text: dayTaskRow.modelData.time || ""
                  color: root.colorTextDim
                  font.pixelSize: 8
                }

                Text {
                  visible: dayTaskHover.hovered
                  text: "\uf044"
                  color: root.colorTextDim
                  opacity: 0.6
                  font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                  MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editTaskRequested(dayTaskRow.modelData)
                  }
                }
                Text {
                  visible: dayTaskHover.hovered
                  text: "×"
                  color: root.colorTextDim
                  opacity: 0.6
                  font.pixelSize: 13
                  MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.todoConfig.removeTask(dayTaskRow.modelData.id)
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
