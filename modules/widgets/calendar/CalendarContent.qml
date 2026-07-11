import qs

import QtQuick
import QtQuick.Layouts

// modules/widgets/calendar/CalendarContent.qml → modules/widgets/todo/
import "../todo" as TodoMod

Item {
  id: root
  property bool grouped: false

  CalendarConfig { id: config }

  // Instância própria de TodoConfig — só lê state/TodoWidget.json (mesmo
  // arquivo que o TodoWidget usa) pra saber quais dias têm tarefa e marcar
  // o dia com a cor da tarefa de maior prioridade. Não escreve nada nele.
  TodoMod.TodoConfig { id: todoConfig }

  readonly property var priorityColor: ({
    alta:  "#e5484d",
    media: "#f5a524",
    baixa: "#45a249",
  })
  readonly property var priorityOrder: ({ alta: 0, media: 1, baixa: 2 })

  // dia selecionado (yyyy-MM-dd) — clicar num dia com o mouse alterna a
  // seleção. Quando este widget está no modo combinado (grouped), a
  // WidgetHost escuta `dateSelected` e usa pra filtrar o TodoContent ao
  // lado; sozinho, serve só de destaque visual mesmo.
  property string selectedDate: ""
  signal dateSelected(string date)

  function toggleSelected(dateStr) {
    root.selectedDate = (root.selectedDate === dateStr) ? "" : dateStr
    root.dateSelected(root.selectedDate)
  }

  // tarefas com prazo == dateStr
  function tasksForDate(dateStr) {
    return todoConfig.tasks.filter(function(t) { return t.due === dateStr })
  }

  // cor do "pontinho" do dia: prioridade mais alta entre as tarefas
  // pendentes daquele dia; se só houver tarefas concluídas, um tom neutro;
  // sem tarefas, string vazia (sem marcador)
  function dayMarkerColor(dateStr) {
    const tasks = root.tasksForDate(dateStr)
    if (!tasks.length) return ""
    const pending = tasks.filter(function(t) { return !t.done })
    if (!pending.length) return Qt.rgba(1, 1, 1, 0.35)
    pending.sort(function(a, b) {
      const ao = root.priorityOrder[a.priority] !== undefined ? root.priorityOrder[a.priority] : 1
      const bo = root.priorityOrder[b.priority] !== undefined ? root.priorityOrder[b.priority] : 1
      return ao - bo
    })
    return root.priorityColor[pending[0].priority] || Qt.rgba(1, 1, 1, 0.4)
  }

  // ── Data "agora" sempre viva ─────────────────────────────────────────
  // Antes era `property date today: new Date()` — um valor calculado UMA
  // VEZ na criação do componente e nunca mais reavaliado. Como o shell
  // roda como daemon por dias, isso deixava o "hoje" (e por tabela
  // viewYear/viewMonth, que nasciam a partir dele) preso na data em que o
  // Quickshell foi iniciado: depois de passar da meia-noite, o dia
  // marcado como hoje ficava errado. Segue aqui o mesmo padrão de tick
  // que o ClockContent usa pro relógio.
  property bool _dayTick: false
  Timer { interval: 60000; repeat: true; running: true; onTriggered: root._dayTick = !root._dayTick }
  readonly property date today: { var _ = root._dayTick; return new Date() }

  property int viewYear:  today.getFullYear()
  property int viewMonth: today.getMonth() // 0-11
  property int pickerMode: 0 // 0 dias, 1 meses, 2 anos (década)

  readonly property int decadeStart: Math.floor(viewYear / 10) * 10 - 1

  readonly property var monthNames: [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  ]
  readonly property var monthNamesShort: [
    "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"
  ]
  readonly property var weekDayNamesMon: ["S", "T", "Q", "Q", "S", "S", "D"]
  readonly property var weekDayNamesSun: ["D", "S", "T", "Q", "Q", "S", "S"]

  function daysInMonth(year, month) { return new Date(year, month + 1, 0).getDate() }

  function firstDayOffset(year, month) {
    let dow = new Date(year, month, 1).getDay()
    if (config.weekStartsMonday) dow = (dow + 6) % 7
    return dow
  }

  function fmt(y, m, d) { return Qt.formatDate(new Date(y, m, d), "yyyy-MM-dd") }

  function buildGrid() {
    const cells = []
    const offset = firstDayOffset(viewYear, viewMonth)
    const total = daysInMonth(viewYear, viewMonth)
    for (let i = 0; i < offset; i++) cells.push({ day: 0, valid: false })
    for (let d = 1; d <= total; d++) cells.push({ day: d, valid: true, dateStr: fmt(viewYear, viewMonth, d) })
    while (cells.length % 7 !== 0) cells.push({ day: 0, valid: false })
    return cells
  }

  function buildMonthGrid() {
    const cells = []
    for (let m = 0; m < 12; m++) cells.push({ m: m, label: monthNamesShort[m] })
    return cells
  }

  function buildDecadeGrid() {
    const cells = []
    for (let i = 0; i < 12; i++) {
      const y = decadeStart + i
      cells.push({ y: y, edge: (i === 0 || i === 11) })
    }
    return cells
  }

  function headerParts() {
    if (pickerMode === 0) {
      return [
        { label: monthNames[viewMonth], level: 1 },
        { label: String(viewYear),      level: 2 },
      ]
    }
    if (pickerMode === 1) return [ { label: String(viewYear), level: 2 } ]
    return [ { label: (decadeStart + 1) + " – " + (decadeStart + 10), level: -1 } ]
  }

  function isToday(d) {
    return d === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear()
  }

  function isWeekend(index) {
    if (config.weekStartsMonday) return index === 5 || index === 6
    return index === 0 || index === 6
  }

  function goPrev() {
    if (pickerMode === 0) {
      if (viewMonth === 0) { viewMonth = 11; viewYear -= 1 } else viewMonth -= 1
    } else if (pickerMode === 1) viewYear -= 1
    else viewYear -= 10
  }
  function goNext() {
    if (pickerMode === 0) {
      if (viewMonth === 11) { viewMonth = 0; viewYear += 1 } else viewMonth += 1
    } else if (pickerMode === 1) viewYear += 1
    else viewYear += 10
  }
  // volta a visualização pro mês/ano atuais (o binding de viewYear/viewMonth
  // com `today` é quebrado assim que o usuário navega manualmente — esse
  // botão restaura explicitamente)
  function goToday() {
    viewYear  = today.getFullYear()
    viewMonth = today.getMonth()
    pickerMode = 0
  }

  implicitWidth: 230
  implicitHeight: layout.implicitHeight

  ColumnLayout {
    id: layout
    width: parent.width
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      Rectangle {
        Layout.preferredWidth: 28; Layout.preferredHeight: 28
        radius: 6
        color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "‹"; color: Colors[config.colorText]; font.pixelSize: config.fontSizeHeader
        }
        MouseArea {
          id: prevMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.goPrev()
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight

        Row {
          id: headerRow
          anchors.centerIn: parent
          spacing: 6

          Repeater {
            model: root.headerParts()
            delegate: Rectangle {
              required property var modelData
              width: partText.implicitWidth + 6; height: partText.implicitHeight + 4
              radius: 4
              color: partMa.containsMouse && modelData.level >= 0 ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

              Text {
                id: partText
                anchors.centerIn: parent
                text: modelData.label
                color: Colors[config.colorText]
                font { pixelSize: config.fontSizeHeader; family: "Inter"; weight: Font.DemiBold }
              }
              MouseArea {
                id: partMa
                anchors.fill: parent; hoverEnabled: true
                enabled: modelData.level >= 0
                cursorShape: modelData.level >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.pickerMode = modelData.level
              }
            }
          }
        }
      }

      Rectangle {
        Layout.preferredWidth: 28; Layout.preferredHeight: 28
        radius: 6
        color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "›"; color: Colors[config.colorText]; font.pixelSize: config.fontSizeHeader
        }
        MouseArea {
          id: nextMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.goNext()
        }
      }

      Rectangle {
        Layout.preferredWidth: 24; Layout.preferredHeight: 24
        Layout.leftMargin: 2
        radius: 6
        readonly property bool onToday: root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth() && root.pickerMode === 0
        color: todayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        opacity: onToday ? 0.35 : 1.0
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "\uf192" // dot-circle-o — "voltar pra hoje"
          color: Colors[config.colorText]
          font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
        }
        MouseArea {
          id: todayMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.goToday()
        }
      }
    }

    GridLayout {
      visible: root.pickerMode === 0
      columns: 7
      rowSpacing: 4; columnSpacing: 4
      Layout.alignment: Qt.AlignHCenter

      Repeater {
        model: config.weekStartsMonday ? root.weekDayNamesMon : root.weekDayNamesSun
        delegate: Text {
          required property string modelData
          Layout.preferredWidth: 24
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: Colors[config.colorWeekend]
          opacity: 0.6
          font.pixelSize: config.fontSize - 2
        }
      }

      Repeater {
        model: root.buildGrid()
        delegate: Item {
          required property var modelData
          required property int index
          Layout.preferredWidth: 24
          Layout.preferredHeight: 26

          Rectangle {
            anchors.fill: parent
            radius: 6
            visible: modelData.valid && root.isToday(modelData.day)
            color: Colors[config.colorToday]
            opacity: 0.85
          }
          Rectangle {
            anchors.fill: parent
            radius: 6
            color: "transparent"
            visible: modelData.valid && root.selectedDate === modelData.dateStr
            border.color: Colors[config.colorToday]
            border.width: 1.5
          }
          Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            visible: modelData.valid
            text: modelData.day
            color: (modelData.valid && root.isToday(modelData.day))
              ? "#ffffff"
              : (root.isWeekend(index % 7) ? Colors[config.colorWeekend] : Colors[config.colorText])
            opacity: (modelData.valid && root.isToday(modelData.day))
              ? 1.0
              : (root.isWeekend(index % 7) ? 0.7 : 1.0)
            font.pixelSize: config.fontSize
          }
          Row {
            visible: config.showTaskDots && modelData.valid && root.tasksForDate(modelData.dateStr).length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            spacing: 2

            Rectangle {
              width: 4; height: 4; radius: 2
              anchors.verticalCenter: parent.verticalCenter
              color: modelData.valid ? root.dayMarkerColor(modelData.dateStr) : "transparent"
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.valid ? root.tasksForDate(modelData.dateStr).length : ""
              color: Colors[config.colorText]
              opacity: 0.65
              font.pixelSize: 7
            }
          }
          MouseArea {
            anchors.fill: parent
            enabled: modelData.valid
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSelected(modelData.dateStr)
          }
        }
      }
    }

    GridLayout {
      visible: root.pickerMode === 1
      columns: 3
      rowSpacing: 6; columnSpacing: 6
      Layout.alignment: Qt.AlignHCenter

      Repeater {
        model: root.buildMonthGrid()
        delegate: Rectangle {
          required property var modelData
          Layout.preferredWidth: 66
          Layout.preferredHeight: 34
          radius: 6
          readonly property bool isSelected: modelData.m === root.viewMonth
          color: isSelected ? Colors[config.colorToday] : (monthMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
          opacity: isSelected ? 0.85 : 1.0

          Text {
            anchors.centerIn: parent
            text: modelData.label
            color: parent.isSelected ? "#ffffff" : Colors[config.colorText]
            font.pixelSize: config.fontSize
          }
          MouseArea {
            id: monthMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.viewMonth = modelData.m; root.pickerMode = 0 }
          }
        }
      }
    }

    GridLayout {
      visible: root.pickerMode === 2
      columns: 3
      rowSpacing: 6; columnSpacing: 6
      Layout.alignment: Qt.AlignHCenter

      Repeater {
        model: root.buildDecadeGrid()
        delegate: Rectangle {
          required property var modelData
          Layout.preferredWidth: 66
          Layout.preferredHeight: 34
          radius: 6
          readonly property bool isSelected: modelData.y === root.viewYear
          color: isSelected ? Colors[config.colorToday] : (yearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
          opacity: isSelected ? 0.85 : (modelData.edge ? 0.4 : 1.0)

          Text {
            anchors.centerIn: parent
            text: modelData.y
            color: parent.isSelected ? "#ffffff" : Colors[config.colorText]
            font.pixelSize: config.fontSize
          }
          MouseArea {
            id: yearMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.viewYear = modelData.y; root.pickerMode = 0 }
          }
        }
      }
    }
  }
}
