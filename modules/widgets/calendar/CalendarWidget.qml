import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
  id: calendarWidget

  CalendarConfig { id: config }

  property date today: new Date()
  property int viewYear:  today.getFullYear()
  property int viewMonth: today.getMonth() // 0-11

  // 0 = dias, 1 = meses, 2 = anos (década)
  property int pickerMode: 0

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

  // índice do primeiro dia do mês (0..6), já ajustado pro início de semana configurado
  function firstDayOffset(year, month) {
    let dow = new Date(year, month, 1).getDay() // 0 = domingo
    if (config.weekStartsMonday) dow = (dow + 6) % 7
    return dow
  }

  function buildGrid() {
    const cells = []
    const offset = firstDayOffset(viewYear, viewMonth)
    const total = daysInMonth(viewYear, viewMonth)
    for (let i = 0; i < offset; i++) cells.push({ day: 0, valid: false })
    for (let d = 1; d <= total; d++) cells.push({ day: d, valid: true })
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
    if (pickerMode === 1) {
      return [ { label: String(viewYear), level: 2 } ]
    }
    return [ { label: (decadeStart + 1) + " – " + (decadeStart + 10), level: -1 } ]
  }

  function isToday(d) {
    return d === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear()
  }

  // index = posição na semana (0..6) conforme config.weekStartsMonday
  function isWeekend(index) {
    if (config.weekStartsMonday) return index === 5 || index === 6 // sáb/dom
    return index === 0 || index === 6 // dom/sáb
  }

  function goPrev() {
    if (pickerMode === 0) {
      if (viewMonth === 0) { viewMonth = 11; viewYear -= 1 } else viewMonth -= 1
    } else if (pickerMode === 1) {
      viewYear -= 1
    } else {
      viewYear -= 10
    }
  }
  function goNext() {
    if (pickerMode === 0) {
      if (viewMonth === 11) { viewMonth = 0; viewYear += 1 } else viewMonth += 1
    } else if (pickerMode === 1) {
      viewYear += 1
    } else {
      viewYear += 10
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        // Bottom: widgets ficam abaixo dos apps de propósito — nunca por
        // cima de janelas em fullscreen, etc.
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "calendar-widget"

        // Sem isso, a região de input da surface (tela cheia, transparente)
        // não necessariamente cobre onde o widget está desenhado — os
        // MouseArea internos nunca recebem o clique porque o evento nem
        // chega no QML.
        mask: Region { item: content }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
          { h: Qt.AlignRight,   v: Qt.AlignBottom  },
        ]

        Item {
          id: content
          x: {
            if (positions[config.position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[config.position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[config.position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[config.position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: 230
          height: layout.implicitHeight

          ColumnLayout {
            id: layout
            width: parent.width
            spacing: 6

            // ── Cabeçalho: setas + mês/ano clicáveis (drill-down) ──────
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
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: calendarWidget.goPrev()
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
                    model: calendarWidget.headerParts()
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
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.level >= 0
                        cursorShape: modelData.level >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: calendarWidget.pickerMode = modelData.level
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
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: calendarWidget.goNext()
                }
              }
            }

            // ── Vista de DIAS ───────────────────────────────────────────
            GridLayout {
              visible: calendarWidget.pickerMode === 0
              columns: 7
              rowSpacing: 4; columnSpacing: 4
              Layout.fillWidth: true

              Repeater {
                model: config.weekStartsMonday ? calendarWidget.weekDayNamesMon : calendarWidget.weekDayNamesSun
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
                model: calendarWidget.buildGrid()
                delegate: Item {
                  required property var modelData
                  required property int index
                  Layout.preferredWidth: 24
                  Layout.preferredHeight: 24

                  Rectangle {
                    anchors.fill: parent
                    radius: 6
                    visible: modelData.valid && calendarWidget.isToday(modelData.day)
                    color: Colors[config.colorToday]
                    opacity: 0.85
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: modelData.valid
                    text: modelData.day
                    color: (modelData.valid && calendarWidget.isToday(modelData.day))
                      ? "#ffffff"
                      : (calendarWidget.isWeekend(index % 7) ? Colors[config.colorWeekend] : Colors[config.colorText])
                    opacity: (modelData.valid && calendarWidget.isToday(modelData.day))
                      ? 1.0
                      : (calendarWidget.isWeekend(index % 7) ? 0.7 : 1.0)
                    font.pixelSize: config.fontSize
                  }
                }
              }
            }

            // ── Vista de MESES ──────────────────────────────────────────
            GridLayout {
              visible: calendarWidget.pickerMode === 1
              columns: 3
              rowSpacing: 6; columnSpacing: 6
              Layout.fillWidth: true

              Repeater {
                model: calendarWidget.buildMonthGrid()
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34
                  radius: 6
                  readonly property bool isSelected: modelData.m === calendarWidget.viewMonth
                  color: isSelected
                    ? Colors[config.colorToday]
                    : (monthMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                  opacity: isSelected ? 0.85 : 1.0

                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.isSelected ? "#ffffff" : Colors[config.colorText]
                    font.pixelSize: config.fontSize
                  }
                  MouseArea {
                    id: monthMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      calendarWidget.viewMonth = modelData.m
                      calendarWidget.pickerMode = 0
                    }
                  }
                }
              }
            }

            // ── Vista de ANOS (década) ──────────────────────────────────
            GridLayout {
              visible: calendarWidget.pickerMode === 2
              columns: 3
              rowSpacing: 6; columnSpacing: 6
              Layout.fillWidth: true

              Repeater {
                model: calendarWidget.buildDecadeGrid()
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34
                  radius: 6
                  readonly property bool isSelected: modelData.y === calendarWidget.viewYear
                  color: isSelected
                    ? Colors[config.colorToday]
                    : (yearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                  opacity: isSelected ? 0.85 : (modelData.edge ? 0.4 : 1.0)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.y
                    color: parent.isSelected ? "#ffffff" : Colors[config.colorText]
                    font.pixelSize: config.fontSize
                  }
                  MouseArea {
                    id: yearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      calendarWidget.viewYear = modelData.y
                      calendarWidget.pickerMode = 0
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
}
