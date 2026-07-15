import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
  id: root

  property bool grouped: false

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

  // ── grade de datas do heatmap (estilo GitHub: colunas = semanas) ──────
  function _mondayOnOrBefore(date) {
    const d = new Date(date)
    const day = d.getDay()
    const diff = (day === 0) ? 6 : day - 1
    d.setDate(d.getDate() - diff)
    d.setHours(0, 0, 0, 0)
    return d
  }

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
        let done = 0
        for (const h of config.habits) if (config.isDoneOn(h, key)) done++
        const ratio = totalHabits > 0 ? done / totalHabits : 0
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
      spacing: 8
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
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 4

      Repeater {
        model: root.visibleHabits
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            id: check
            readonly property bool done: config.isDoneOn(modelData, config._todayKey())
            width: 16; height: 16; radius: 4
            color: done ? Colors[modelData.color] : "transparent"
            border.width: 1.5
            border.color: done ? Colors[modelData.color] : Qt.rgba(Colors[config.colorLabel].r, Colors[config.colorLabel].g, Colors[config.colorLabel].b, 0.4)

            Text {
              anchors.centerIn: parent
              visible: check.done
              text: "✓"
              color: Colors[config.colorValue]
              font.pixelSize: 11
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              cursorShape: Qt.PointingHandCursor
              onClicked: config.toggleToday(modelData.id)
            }
          }

          Text {
            Layout.fillWidth: true
            text: modelData.name
            color: Colors[config.colorLabel]
            opacity: 0.9
            font.pixelSize: 12
            elide: Text.ElideRight
          }

          Text {
            text: config.streakFor(modelData) + "d"
            color: Colors[modelData.color]
            opacity: config.streakFor(modelData) > 0 ? 1 : 0.35
            font { pixelSize: 12; family: "Inter"; weight: Font.DemiBold }
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
        }
      }
    }
  }
}
