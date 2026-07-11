import QtQuick
import QtQuick.Layouts

// ── DatePicker ──────────────────────────────────────────────────────────
// Mini calendário compacto: navega mês a mês, clicar num dia emite
// dateSelected("yyyy-MM-dd"). Sem sub-níveis de mês/ano (diferente do
// CalendarContent) — é só um seletor de data pontual, cabe dentro de um
// popup pequeno.

Item {
  id: root
  signal dateSelected(string date)

  property date today: new Date()
  property int viewYear:  today.getFullYear()
  property int viewMonth: today.getMonth()
  // "yyyy-MM-dd" já escolhida, pra destacar no grid (opcional)
  property string selectedDate: ""

  readonly property var monthNames: [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  ]
  readonly property var weekDayNames: ["D", "S", "T", "Q", "Q", "S", "S"]

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function firstDayOffset(y, m) { return new Date(y, m, 1).getDay() }

  function buildGrid() {
    const cells = []
    const offset = firstDayOffset(viewYear, viewMonth)
    const total = daysInMonth(viewYear, viewMonth)
    for (let i = 0; i < offset; i++) cells.push({ day: 0, valid: false })
    for (let d = 1; d <= total; d++) cells.push({ day: d, valid: true, dateStr: fmt(viewYear, viewMonth, d) })
    return cells
  }

  function fmt(y, m, d) { return Qt.formatDate(new Date(y, m, d), "yyyy-MM-dd") }

  function prevMonth() {
    if (viewMonth === 0) { viewMonth = 11; viewYear -= 1 } else viewMonth -= 1
  }
  function nextMonth() {
    if (viewMonth === 11) { viewMonth = 0; viewYear += 1 } else viewMonth += 1
  }

  implicitWidth: 200
  implicitHeight: layout.implicitHeight

  ColumnLayout {
    id: layout
    width: parent.width
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      Text {
        text: "‹"; color: "#ffffff"; font.pixelSize: 13
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevMonth() }
      }
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.monthNames[root.viewMonth] + " " + root.viewYear
        color: "#ffffff"
        font { pixelSize: 12; family: "Inter"; weight: Font.DemiBold }
      }
      Text {
        text: "›"; color: "#ffffff"; font.pixelSize: 13
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextMonth() }
      }
    }

    GridLayout {
      columns: 7
      rowSpacing: 2; columnSpacing: 2
      Layout.alignment: Qt.AlignHCenter

      Repeater {
        model: root.weekDayNames
        delegate: Text {
          required property string modelData
          Layout.preferredWidth: 22
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: "#ffffff"; opacity: 0.5
          font.pixelSize: 9
        }
      }

      Repeater {
        model: root.buildGrid()
        delegate: Rectangle {
          required property var modelData
          Layout.preferredWidth: 22; Layout.preferredHeight: 22
          radius: 5
          visible: modelData.valid
          readonly property bool isSelected: modelData.valid && modelData.dateStr === root.selectedDate
          color: isSelected ? "#3f9fff" : (dMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

          Text {
            anchors.centerIn: parent
            text: modelData.day
            color: "#ffffff"
            font.pixelSize: 10
          }
          MouseArea {
            id: dMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.dateSelected(modelData.dateStr)
          }
        }
      }
    }
  }
}
