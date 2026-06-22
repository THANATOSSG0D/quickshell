import QtQuick
import QtQuick.Layouts

// ── QsCalendar ────────────────────────────────────────────────────────────────
// Calendário compacto estilo widget: cabeçalho com mês/ano + setas de
// navegação, grid 7x6 de dias da semana, destaque no dia atual.
// Auto-contido — calcula o grid em JS puro, sem dependências externas.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property bool compact: false   // true = células menores, espaçamento reduzido

    // Mês/ano exibido (independente da data real, para permitir navegação)
    property int viewYear:  new Date().getFullYear()
    property int viewMonth: new Date().getMonth()   // 0-11

    readonly property var today: new Date()
    readonly property int todayY: today.getFullYear()
    readonly property int todayM: today.getMonth()
    readonly property int todayD: today.getDate()

    readonly property var monthNames: [
        "Janeiro","Fevereiro","Março","Abril","Maio","Junho",
        "Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"
    ]
    readonly property var weekDayLabels: ["D","S","T","Q","Q","S","S"]

    function _prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear-- } else { viewMonth-- }
    }
    function _nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++ } else { viewMonth++ }
    }

    // Grid de 42 células (6 semanas x 7 dias). Cada célula: {day, inMonth}
    readonly property var grid: {
        var firstOfMonth = new Date(viewYear, viewMonth, 1)
        var startWeekday = firstOfMonth.getDay()              // 0=domingo
        var daysInMonth  = new Date(viewYear, viewMonth + 1, 0).getDate()
        var daysInPrev   = new Date(viewYear, viewMonth, 0).getDate()

        var cells = []
        // dias do mês anterior para preencher a primeira semana
        for (var i = startWeekday - 1; i >= 0; i--) {
            cells.push({ day: daysInPrev - i, inMonth: false })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            cells.push({ day: d, inMonth: true })
        }
        // completa até 42 células com dias do próximo mês
        var nextDay = 1
        while (cells.length < 42) {
            cells.push({ day: nextDay, inMonth: false })
            nextDay++
        }
        return cells
    }

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: root.compact ? 3 : 6

        // ── Cabeçalho: mês/ano + navegação ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 4

            Text {
                text: "\uf053"   // chevron_left
                color: root.colorTextDim
                font.pixelSize: root.compact ? 8 : 10; font.family: "JetBrainsMono Nerd Font"
                MouseArea { anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor; onClicked: root._prevMonth() }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.viewMonth] + " " + root.viewYear
                color: root.colorText
                font.pixelSize: root.compact ? 9 : 11; font.weight: Font.Medium
            }
            Text {
                text: "\uf054"   // chevron_right
                color: root.colorTextDim
                font.pixelSize: root.compact ? 8 : 10; font.family: "JetBrainsMono Nerd Font"
                MouseArea { anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor; onClicked: root._nextMonth() }
            }
        }

        // ── Cabeçalho de dias da semana ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 0
            visible: !root.compact   // economiza espaço — dia atual já fica destacado no grid
            Repeater {
                model: root.weekDayLabels
                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: root.colorTextDim
                    font.pixelSize: 8; opacity: 0.6
                }
            }
        }

        // ── Grid de dias ──────────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 7; rowSpacing: root.compact ? 1 : 2; columnSpacing: 0

            Repeater {
                model: root.grid
                delegate: Item {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 15 : 20

                    readonly property bool isToday:
                        modelData.inMonth &&
                        root.viewYear  === root.todayY &&
                        root.viewMonth === root.todayM &&
                        modelData.day  === root.todayD

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.compact ? 14 : 18; height: root.compact ? 14 : 18
                        radius: width / 2
                        color: isToday
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
                            : "transparent"
                        border.color: isToday ? root.colorAccent : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pixelSize: root.compact ? 7 : 9
                            color: isToday ? root.colorAccent
                                 : modelData.inMonth ? root.colorText
                                 : root.colorTextDim
                            opacity: modelData.inMonth ? 1.0 : 0.3
                        }
                    }
                }
            }
        }
    }
}
