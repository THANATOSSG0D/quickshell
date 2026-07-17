import QtQuick
import QtQuick.Layouts

// ── QsCalendar ────────────────────────────────────────────────────────────────
// Calendário compacto estilo widget: cabeçalho com mês/ano + navegação + atalho
// "hoje", grid 7x6 de dias da semana com células de largura FIXA (centralizadas),
// destaque no dia atual e marcador opcional de dias com tarefa.
// Auto-contido — calcula o grid em JS puro, sem dependências externas.
//
// v2: a v1 usava Layout.fillWidth nas células do grid, o que espalhava os
// círculos de dia por toda a largura do painel (feio, "esticado"). Agora as
// células têm largura fixa e o grid inteiro é centralizado — mesmo padrão do
// DatePicker.qml e do CalendarContent.qml do widget de calendário.
//
// Marcadores de tarefa (opcional): passe `taskDates` como um objeto
// { "yyyy-MM-dd": "#corDoPonto", ... } — ex., vindo do TodoConfig:
//   property var taskDates: {
//       var m = ({})
//       for (var i = 0; i < todoConfig.tasks.length; i++) {
//           var t = todoConfig.tasks[i]
//           if (t.due && !t.done) m[t.due] = priorityColor[t.priority] || colorAccent
//       }
//       return m
//   }
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property bool compact: false   // true = células menores, espaçamento reduzido

    // Dias com marcador (opcional) — { "yyyy-MM-dd": "#cor" }
    property var taskDates: ({})

    // Dia atualmente selecionado (clicado) — "" = nenhum. Quem usa o
    // componente decide o que fazer com dateClicked; isso aqui só cuida do
    // destaque visual do dia escolhido.
    property string selectedDate: ""

    signal dateClicked(string date)   // emitido em qualquer clique num dia válido

    // Mês/ano exibido (independente da data real, para permitir navegação)
    property int viewYear:  new Date().getFullYear()
    property int viewMonth: new Date().getMonth()   // 0-11

    // ── "Hoje" sempre vivo — reavalia a cada minuto, não só na criação ──────
    property bool _dayTick: false
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root._dayTick = !root._dayTick }
    readonly property var today: { var _ = root._dayTick; return new Date() }
    readonly property int todayY: today.getFullYear()
    readonly property int todayM: today.getMonth()
    readonly property int todayD: today.getDate()

    readonly property bool onCurrentMonth: viewYear === todayY && viewMonth === todayM

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
    function _goToday() {
        viewYear  = todayY
        viewMonth = todayM
    }

    function _fmt(y, m, d) { return Qt.formatDate(new Date(y, m, d), "yyyy-MM-dd") }

    // Grid de 42 células (6 semanas x 7 dias). Cada célula: {day, inMonth, dateStr}
    readonly property var grid: {
        var firstOfMonth = new Date(viewYear, viewMonth, 1)
        var startWeekday = firstOfMonth.getDay()              // 0=domingo
        var daysInMonth  = new Date(viewYear, viewMonth + 1, 0).getDate()
        var daysInPrev   = new Date(viewYear, viewMonth, 0).getDate()

        var cells = []
        // dias do mês anterior para preencher a primeira semana
        for (var i = startWeekday - 1; i >= 0; i--) {
            var pm = viewMonth === 0 ? 11 : viewMonth - 1
            var py = viewMonth === 0 ? viewYear - 1 : viewYear
            cells.push({ day: daysInPrev - i, inMonth: false, dateStr: root._fmt(py, pm, daysInPrev - i) })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            cells.push({ day: d, inMonth: true, dateStr: root._fmt(viewYear, viewMonth, d) })
        }
        // completa até 42 células com dias do próximo mês
        var nextDay = 1
        var nm = viewMonth === 11 ? 0 : viewMonth + 1
        var ny = viewMonth === 11 ? viewYear + 1 : viewYear
        while (cells.length < 42) {
            cells.push({ day: nextDay, inMonth: false, dateStr: root._fmt(ny, nm, nextDay) })
            nextDay++
        }
        return cells
    }

    // ── Dimensões — únicas fontes de verdade pro tamanho da célula ──────────
    readonly property int cellW:   compact ? 26 : 34
    readonly property int cellH:   compact ? 22 : 28
    readonly property int circleD: compact ? 18 : 24
    readonly property int gridSpacing: compact ? 1 : 3

    implicitWidth:  col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.compact ? 3 : 6

        // ── Cabeçalho: mês/ano + navegação + atalho "hoje" ──────────────────
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
            // "Voltar pro mês atual" — só aparece quando faz sentido (navegou pra outro mês)
            Text {
                visible: !root.onCurrentMonth
                text: "\uf192"   // dot-circle-o
                color: todayMa.containsMouse ? root.colorAccent : root.colorTextDim
                font.pixelSize: root.compact ? 9 : 11; font.family: "JetBrainsMono Nerd Font"
                Layout.leftMargin: 2
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea { id: todayMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root._goToday() }
            }
        }

        // ── Cabeçalho de dias da semana ──────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.gridSpacing
            visible: !root.compact   // economiza espaço — dia atual já fica destacado no grid
            Repeater {
                model: root.weekDayLabels
                delegate: Text {
                    required property string modelData
                    Layout.preferredWidth: root.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: root.colorTextDim
                    font.pixelSize: 8; opacity: 0.6
                }
            }
        }

        // ── Grid de dias — largura FIXA por célula, grid centralizado ────────
        // (é a mudança que corrige o "esticado": antes cada célula usava
        // Layout.fillWidth, agora usa Layout.preferredWidth e o GridLayout
        // inteiro é centralizado, não esticado até a borda do painel)
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 7; rowSpacing: root.gridSpacing; columnSpacing: root.gridSpacing

            Repeater {
                model: root.grid
                delegate: Item {
                    required property var modelData
                    required property int index
                    Layout.preferredWidth:  root.cellW
                    Layout.preferredHeight: root.cellH

                    readonly property bool isToday:
                        modelData.inMonth &&
                        root.viewYear  === root.todayY &&
                        root.viewMonth === root.todayM &&
                        modelData.day  === root.todayD

                    readonly property string taskColor:
                        root.taskDates && root.taskDates[modelData.dateStr] ? root.taskDates[modelData.dateStr] : ""

                    readonly property bool isSelected:
                        modelData.inMonth && modelData.dateStr === root.selectedDate

                    Rectangle {
                        id: dayCircle
                        anchors.centerIn: parent
                        width: root.circleD; height: root.circleD
                        radius: width / 2
                        color: isSelected
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
                            : isToday
                                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
                                : (dayMa.containsMouse && modelData.inMonth ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: (isToday || isSelected) ? root.colorAccent : "transparent"
                        border.width: isSelected ? 1.5 : 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pixelSize: root.compact ? 8 : 10
                            font.weight: isSelected ? Font.DemiBold : Font.Normal
                            color: (isToday || isSelected) ? root.colorAccent
                                 : modelData.inMonth ? root.colorText
                                 : root.colorTextDim
                            opacity: modelData.inMonth ? 1.0 : 0.3
                        }

                        // Marcador de tarefa — pontinho pequeno no rodapé do círculo
                        Rectangle {
                            visible: parent.parent.taskColor !== ""
                            width: 4; height: 4; radius: 2
                            color: isSelected ? root.colorText : parent.parent.taskColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.compact ? 1 : 2
                        }
                    }

                    MouseArea {
                        id: dayMa
                        anchors.fill: parent
                        enabled: modelData.inMonth
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dateClicked(modelData.dateStr)
                    }
                }
            }
        }
    }
}
