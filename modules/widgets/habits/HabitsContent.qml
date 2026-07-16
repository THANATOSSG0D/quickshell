import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
  id: root

  property bool grouped: false

  // mesmo padrão do TodoContent: quem hospeda esse conteúdo (HabitsWidget
  // sozinho, ou WidgetHost agrupado) escuta esses sinais pra abrir a
  // HabitsAddWindow / HabitsDashboard — janelas próprias, reaproveitadas.
  signal addHabitRequested()
  signal editHabitRequested(var habit)
  signal habitsDashboardRequested()

  HabitsConfig { id: config }

  implicitWidth: config.fixedWidth
  implicitHeight: contentHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  readonly property var visibleHabits: config.habits.slice(0, config.maxVisible)
  readonly property int extraCount: Math.max(0, config.habits.length - config.maxVisible)

  // altura calculada: linhas de hábito + heatmap opcional, com teto no
  // fixedHeight configurado (igual ao resto dos widgets, evita crescer
  // sem limite quando o usuário cadastra muitos hábitos)
  readonly property int contentHeight: Math.min(config.fixedHeight, layout.implicitHeight + 24)

  // ── Tooltip flutuante ao passar o mouse num hábito ──────────────────
  // Mesmo padrão do TodoContent: um único card reaproveitado, mostra nome
  // completo (sem elide) + streak atual/recorde + total de conclusões.
  property var tooltipHabit: null
  property real tooltipY: 0
  property bool tooltipVisible: false

  Timer { id: tooltipShowTimer; interval: 380; onTriggered: root.tooltipVisible = true }

  function requestTooltip(habit, y) {
    root.tooltipHabit = habit
    root.tooltipY = y
    if (!root.tooltipVisible) tooltipShowTimer.restart()
  }
  function hideTooltip(habit) {
    if (root.tooltipHabit && habit && root.tooltipHabit.id !== habit.id) return
    tooltipShowTimer.stop()
    root.tooltipVisible = false
    root.tooltipHabit = null
  }

  // ── grade de datas do heatmap (estilo GitHub: colunas = semanas) ──────
  function _mondayOnOrBefore(date) {
    const d = new Date(date)
    const day = d.getDay()
    const diff = (day === 0) ? 6 : day - 1
    d.setDate(d.getDate() - diff)
    d.setHours(0, 0, 0, 0)
    return d
  }

  // intensidade do dia = média da fração de meta cumprida entre todos os
  // hábitos (partial credit: meio copo d'água pinta o quadrado pela metade)
  readonly property var heatmapCells: {
    if (!config.showHeatmap) return []
    const weeks = Math.max(1, config.heatmapWeeks)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const startCol = _mondayOnOrBefore(today)
    startCol.setDate(startCol.getDate() - (weeks - 1) * 7)

    const cells = []
    const totalHabits = config.habits.length
    for (let col = 0; col < weeks; col++) {
      for (let row = 0; row < 7; row++) {
        const d = new Date(startCol)
        d.setDate(d.getDate() + col * 7 + row)
        if (d > today) { cells.push({ row, col, future: true, ratio: 0 }); continue }
        const key = Qt.formatDate(d, "yyyy-MM-dd")
        let sum = 0
        for (const h of config.habits) sum += config.progressOn(h, key)
        const ratio = totalHabits > 0 ? sum / totalHabits : 0
        cells.push({ row, col, future: false, ratio })
      }
    }
    return cells
  }

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    width: config.fixedWidth - 24
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Text {
        text: "HÁBITOS"
        color: Colors[config.colorLabel]
        font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
      }
      Item { Layout.fillWidth: true }
      Text {
        visible: config.habits.length === 0
        text: "nenhum hábito"
        color: Colors[config.colorLabel]
        opacity: 0.5
        font.pixelSize: 11
      }

      // ícone do painel — abre HabitsDashboard (gerenciar + histórico)
      Rectangle {
        width: 18; height: 18; radius: 5
        color: dashboardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "\uf0e4"
          color: Colors[config.colorLabel]
          font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
        }
        MouseArea {
          id: dashboardMa
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: root.habitsDashboardRequested()
        }
      }
    }

    // ── "+ novo hábito" ───────────────────────────────────────────────
    Rectangle {
      Layout.fillWidth: true
      height: 24; radius: 6
      color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
      border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
      Behavior on color { ColorAnimation { duration: 80 } }

      Text {
        anchors.centerIn: parent
        text: "+ novo hábito"
        color: Colors[config.colorLabel]
        font { pixelSize: 10; family: "Inter" }
      }
      MouseArea {
        id: addMa
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.addHabitRequested()
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 5

      Repeater {
        model: root.visibleHabits
        delegate: ColumnLayout {
          id: habitDelegate
          required property var modelData
          Layout.fillWidth: true
          spacing: 0

          HoverHandler {
            id: rowHover
            onHoveredChanged: {
              if (hovered) root.requestTooltip(habitDelegate.modelData, habitDelegate.y + habitDelegate.height + 4)
              else root.hideTooltip(habitDelegate.modelData)
            }
          }

          Loader {
            Layout.fillWidth: true
            sourceComponent: habitDelegate.modelData.kind === "count" ? countRow : checkRow
            property var habit: habitDelegate.modelData
          }
        }
      }

      Text {
        visible: root.extraCount > 0
        text: "+" + root.extraCount + " mais"
        color: Colors[config.colorLabel]
        opacity: 0.5
        font.pixelSize: 10
      }
    }

    // ── heatmap agregado ──────────────────────────────────────────────
    GridLayout {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 4
      visible: config.showHeatmap && config.habits.length > 0
      columns: config.heatmapWeeks
      rowSpacing: 2
      columnSpacing: 2

      Repeater {
        model: root.heatmapCells
        delegate: Rectangle {
          required property var modelData
          Layout.row: modelData.row
          Layout.column: modelData.col
          width: config.squareSize
          height: config.squareSize
          radius: 2
          readonly property color base: Colors[config.colorValue]
          color: modelData.future
                 ? "transparent"
                 : (modelData.ratio > 0
                    ? Qt.rgba(base.r, base.g, base.b, 0.15 + modelData.ratio * 0.85)
                    : Qt.rgba(base.r, base.g, base.b, 0.10))
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }
    }
  }

  // ── linha de hábito tipo "check" (feito/não feito) ───────────────────
  Component {
    id: checkRow
    RowLayout {
      spacing: 8

      Rectangle {
        id: check
        readonly property bool done: config.isDoneOn(habit, config._todayKey())
        width: 16; height: 16; radius: 4
        color: done ? Colors[habit.color] : "transparent"
        border.width: 1.5
        border.color: done ? Colors[habit.color] : Qt.rgba(Colors[config.colorLabel].r, Colors[config.colorLabel].g, Colors[config.colorLabel].b, 0.4)
        scale: checkArea.pressed ? 0.85 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
          anchors.centerIn: parent
          visible: check.done
          text: "✓"
          color: Colors[config.colorValue]
          font.pixelSize: 11
          font.bold: true
          scale: check.done ? 1 : 0.4
          opacity: check.done ? 1 : 0
          Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
          Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
          id: checkArea
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: config.toggleToday(habit.id)
        }
      }

      Text {
        Layout.fillWidth: true
        text: habit.name
        color: Colors[config.colorLabel]
        opacity: 0.9
        font.pixelSize: 12
        elide: Text.ElideRight
      }

      Text {
        text: config.streakFor(habit) + "d"
        color: Colors[habit.color]
        opacity: config.streakFor(habit) > 0 ? 1 : 0.35
        font { pixelSize: 12; family: "Inter"; weight: Font.DemiBold }
      }

      Text {
        text: "\uf044"
        color: Colors[config.colorLabel]
        opacity: 0.35
        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
        MouseArea {
          anchors.fill: parent; anchors.margins: -5
          cursorShape: Qt.PointingHandCursor
          onClicked: root.editHabitRequested(habit)
        }
      }
    }
  }

  // ── linha de hábito tipo "count" (meta numérica, ex: água) ───────────
  Component {
    id: countRow
    RowLayout {
      id: countRowRoot
      spacing: 6

      readonly property int amount: config.amountOn(habit, config._todayKey())
      readonly property real ratio: config.progressOn(habit, config._todayKey())
      readonly property bool done: ratio >= 1

      // anel de progresso miniatura (Canvas)
      Canvas {
        id: ring
        width: 18; height: 18
        readonly property color c: Colors[habit.color]
        // cópia local da ratio — repinta sempre que ela mudar
        property real _ratio: countRowRoot.ratio
        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const cx = width / 2, cy = height / 2, r = width / 2 - 2
          ctx.lineWidth = 2.5
          ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.2)
          ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
          if (_ratio > 0) {
            ctx.strokeStyle = c
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, _ratio))
            ctx.stroke()
          }
        }
        on_RatioChanged: requestPaint()
        Component.onCompleted: requestPaint()
      }

      Text {
        Layout.fillWidth: true
        text: habit.name
        color: Colors[config.colorLabel]
        opacity: 0.9
        font.pixelSize: 12
        elide: Text.ElideRight
      }

      Text {
        text: countRowRoot.amount + "/" + habit.target + (habit.unit ? " " + habit.unit : "")
        color: countRowRoot.done ? Colors[habit.color] : Colors[config.colorLabel]
        opacity: countRowRoot.done ? 1 : 0.6
        font { pixelSize: 10; family: "Inter"; weight: countRowRoot.done ? Font.DemiBold : Font.Normal }
      }

      Text {
        text: "−"
        visible: countRowRoot.amount > 0
        color: Colors[config.colorLabel]
        opacity: 0.5
        font { pixelSize: 13; bold: true }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -5
          cursorShape: Qt.PointingHandCursor
          onClicked: config.logCount(habit.id, -1)
        }
      }

      Rectangle {
        width: 16; height: 16; radius: 4
        color: Qt.rgba(Colors[habit.color].r, Colors[habit.color].g, Colors[habit.color].b, 0.18)
        scale: plusArea.pressed ? 0.85 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Text {
          anchors.centerIn: parent
          text: "+"
          color: Colors[habit.color]
          font { pixelSize: 12; bold: true }
        }
        MouseArea {
          id: plusArea
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: config.logCount(habit.id, 1)
        }
      }

      Text {
        text: "\uf044"
        color: Colors[config.colorLabel]
        opacity: 0.35
        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
        MouseArea {
          anchors.fill: parent; anchors.margins: -5
          cursorShape: Qt.PointingHandCursor
          onClicked: root.editHabitRequested(habit)
        }
      }
    }
  }

  // ── Card do tooltip ─────────────────────────────────────────────────
  // Único, reaproveitado — reposicionado pra colar embaixo do hábito sob
  // o mouse. Mostra o nome completo (sem elide), tipo, streak atual e
  // recorde, e total de conclusões — o "olhar rápido" antes de abrir o
  // painel completo pra ver o histórico de verdade.
  Rectangle {
    id: tooltipCard
    visible: root.tooltipVisible && root.tooltipHabit !== null
    opacity: visible ? 1 : 0
    z: 1000
    x: 0
    y: root.tooltipY
    width: 210
    implicitHeight: tooltipCol.implicitHeight + 20
    radius: 10
    color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
    border.color: Qt.rgba(1, 1, 1, 0.14); border.width: 1
    Behavior on opacity { NumberAnimation { duration: 90 } }

    ColumnLayout {
      id: tooltipCol
      anchors { fill: parent; margins: 10 }
      spacing: 5

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
          width: 8; height: 8; radius: 4
          color: root.tooltipHabit ? (Colors[root.tooltipHabit.color] || Colors[config.colorValue]) : "transparent"
        }
        Text {
          Layout.fillWidth: true
          text: root.tooltipHabit ? root.tooltipHabit.name : ""
          wrapMode: Text.WordWrap
          color: Colors[config.colorLabel]
          font { pixelSize: 12; family: "Inter"; weight: Font.DemiBold }
        }
      }

      Text {
        visible: !!(root.tooltipHabit && root.tooltipHabit.kind === "count")
        text: root.tooltipHabit
          ? ("Hoje: " + config.amountOn(root.tooltipHabit, config._todayKey()) + "/" + root.tooltipHabit.target + (root.tooltipHabit.unit ? " " + root.tooltipHabit.unit : ""))
          : ""
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 10
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: !!root.tooltipHabit
        Text {
          text: root.tooltipHabit ? ("Streak: " + config.streakFor(root.tooltipHabit) + "d") : ""
          color: Qt.rgba(1, 1, 1, 0.7)
          font.pixelSize: 10
        }
        Text {
          text: root.tooltipHabit ? ("Recorde: " + config.longestStreak(root.tooltipHabit) + "d") : ""
          color: Qt.rgba(1, 1, 1, 0.7)
          font.pixelSize: 10
        }
      }

      Text {
        visible: !!root.tooltipHabit
        text: root.tooltipHabit ? ("Total de conclusões: " + config.totalCompletions(root.tooltipHabit)) : ""
        color: Qt.rgba(1, 1, 1, 0.5)
        font.pixelSize: 9
      }

      Text {
        visible: !!root.tooltipHabit
        text: "clique no lápis pra editar · painel (\uf0e4) pro histórico completo"
        color: Qt.rgba(1, 1, 1, 0.35)
        font { pixelSize: 8; family: "Inter" }
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }
}
