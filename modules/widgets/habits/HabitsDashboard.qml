import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// ── HabitsDashboard ──────────────────────────────────────────────────────
// Painel grande, centralizado (mesmo esqueleto do ConfigWindow/TodoDashboard:
// PanelWindow em Overlay + HyprlandFocusGrab + animação _anim), com duas
// visões:
//
//   • Hábitos    — lista completa (sem o limite de maxVisible do widget
//                  compacto), com edição/remoção/cor, abre HabitsAddWindow
//   • Histórico  — escolhe um hábito e vê: heatmap grande (26 semanas),
//                  streak atual/recorde, total de conclusões, conclusões
//                  do mês, e o log de registros dia a dia
//
// Uso (dentro de HabitsWidget.qml / WidgetHost.qml, junto da HabitsAddWindow):
//   HabitsDashboard { id: dashboardWindow }
//   HabitsContent { onHabitsDashboardRequested: dashboardWindow.open() }
//   HabitsDashboard {
//     onEditHabitRequested: (h) => addHabitWindow.openEdit(h)
//     onAddHabitRequested:  () => addHabitWindow.openForm()
//   }

PanelWindow {
  id: win

  property bool panelOpen: false
  signal closeRequested()
  signal editHabitRequested(var habit)
  signal addHabitRequested()

  function open()  { panelOpen = true }
  function close() { panelOpen = false }

  onCloseRequested: panelOpen = false

  HabitsConfig { id: config }

  readonly property color accentColor: "#5b9bd5"
  property string tab: "habitos" // "habitos" | "historico"
  property string selectedHabitId: ""
  // dia sob o mouse no heatmap grande — {date, ratio} | null
  property var hoveredCell: null

  readonly property var selectedHabit: config.habits.find(h => h.id === win.selectedHabitId) || null

  property int viewYear:  new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  readonly property var monthNames: ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]

  // ── grade do heatmap grande (26 semanas, estilo GitHub) ───────────────
  function _mondayOnOrBefore(date) {
    const d = new Date(date)
    const day = d.getDay()
    const diff = (day === 0) ? 6 : day - 1
    d.setDate(d.getDate() - diff)
    d.setHours(0, 0, 0, 0)
    return d
  }
  readonly property int heatmapWeeks: 26
  readonly property var bigHeatmapCells: {
    if (!win.selectedHabit) return []
    const weeks = win.heatmapWeeks
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const startCol = win._mondayOnOrBefore(today)
    startCol.setDate(startCol.getDate() - (weeks - 1) * 7)
    const cells = []
    for (let col = 0; col < weeks; col++) {
      for (let row = 0; row < 7; row++) {
        const d = new Date(startCol)
        d.setDate(d.getDate() + col * 7 + row)
        if (d > today) { cells.push({ row, col, future: true, ratio: 0, date: "", status: "empty" }); continue }
        const key = Qt.formatDate(d, "yyyy-MM-dd")
        cells.push({
          row, col, future: false, date: key,
          ratio: config.progressOn(win.selectedHabit, key),
          status: config.habitStatus(win.selectedHabit, key),
        })
      }
    }
    return cells
  }
  // rótulos de mês acima do heatmap — um por coluna onde o mês muda
  readonly property var monthLabels: {
    const labels = []
    let lastMonth = -1
    for (const c of win.bigHeatmapCells) {
      if (c.row !== 0 || !c.date) continue
      const m = new Date(c.date + "T00:00:00").getMonth()
      if (m !== lastMonth) { labels.push({ col: c.col, label: win.monthNames[m] }); lastMonth = m }
    }
    return labels
  }

  // ── Geometria ─────────────────────────────────────────────────────────
  readonly property int winW: 560
  readonly property int winH: 540

  visible:        _alive
  color:          "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.namespace:     "habits-dashboard"
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  margins.top:    screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.bottom: screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.left:   screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0
  margins.right:  screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0

  // ── Animação (mesmo padrão do TodoDashboard/ConfigWindow) ──────────────
  property real _anim:    0.0
  property bool _alive:   false
  property bool _closing: false

  NumberAnimation { id: openAnim;  target: win; property: "_anim"; duration: 200; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: win; property: "_anim"; duration: 160; easing.type: Easing.OutCubic
    onStopped: { if (win._closing) _unmapTimer.restart() } }
  Timer { id: _unmapTimer;  interval: 17;  onTriggered: { if (win._closing) { win._alive = false; win._closing = false } } }
  Timer { id: _safetyTimer; interval: 380; onTriggered: { if (!win.panelOpen) { win._alive = false; win._closing = false; _unmapTimer.stop() } } }

  onPanelOpenChanged: {
    if (panelOpen) {
      // garante que sempre exista uma seleção válida pro Histórico
      if (!win.selectedHabit && config.habits.length > 0)
        win.selectedHabitId = config.habits[0].id

      _closing = false; _alive = true
      _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
      openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
    } else {
      _closing = true; openAnim.stop()
      closeAnim.from = _anim; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.restart()
      win.closeRequested()
    }
  }

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
    color:     Qt.rgba(0.08, 0.08, 0.09, 0.97)
    border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

    ColumnLayout {
      anchors { fill: parent; margins: 16 }
      spacing: 12

      // ── Cabeçalho ────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: "\uf5eb"
          color: Colors[config.colorLabel]
          font { pixelSize: 15; family: "JetBrainsMono Nerd Font" }
        }
        Text {
          text: "Hábitos"
          color: Colors[config.colorLabel]
          font { pixelSize: 15; family: "Inter"; weight: Font.DemiBold }
        }

        Item { Layout.fillWidth: true }

        // ── seletor de aba ──────────────────────────────────────────
        Row {
          spacing: 4
          Repeater {
            model: [{ id: "habitos", label: "Hábitos" }, { id: "historico", label: "Histórico" }]
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.tab === modelData.id
              width: tabLabel.implicitWidth + 20; height: 26; radius: 8
              color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.28) : Qt.rgba(1, 1, 1, 0.06)
              border.color: active ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.55) : "transparent"
              border.width: 1
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                id: tabLabel
                anchors.centerIn: parent
                text: modelData.label
                color: Colors[config.colorLabel]
                font.pixelSize: 11
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.tab = modelData.id }
            }
          }
        }

        Rectangle {
          width: 24; height: 24; radius: 6
          color: closeHov.containsMouse ? Qt.rgba(0.9, 0.28, 0.3, 0.18) : Qt.rgba(1, 1, 1, 0.06)
          Behavior on color { ColorAnimation { duration: 100 } }
          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: closeHov.containsMouse ? "#e5484d" : Colors[config.colorLabel]
            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
          }
          MouseArea {
            id: closeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.close()
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      // ══════════════════════════════════════════════════════════════
      // ABA: HÁBITOS — lista completa, gerenciamento
      // ══════════════════════════════════════════════════════════════
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: win.tab === "habitos"
        spacing: 10

        Rectangle {
          Layout.fillWidth: true
          height: 30; radius: 8
          color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
          border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }
          Text {
            anchors.centerIn: parent
            text: "+ novo hábito"
            color: Colors[config.colorLabel]
            font.pixelSize: 12
          }
          MouseArea {
            id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: win.addHabitRequested()
          }
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: habitsListCol.implicitHeight
          clip: true

          ColumnLayout {
            id: habitsListCol
            width: parent.width
            spacing: 6

            Text {
              visible: config.habits.length === 0
              text: "nenhum hábito ainda — crie o primeiro acima"
              color: Qt.rgba(1, 1, 1, 0.4)
              font.pixelSize: 11
            }

            Repeater {
              model: config.habits
              delegate: Rectangle {
                id: habitRow
                required property var modelData
                readonly property bool isCount: modelData.kind === "count"
                Layout.fillWidth: true
                height: 44; radius: 10
                color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035)
                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 10

                  Rectangle { width: 12; height: 12; radius: 6; color: Colors[modelData.color] || win.accentColor }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                      text: modelData.name
                      color: Colors[config.colorLabel]
                      font { pixelSize: 12; weight: Font.DemiBold }
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                    Text {
                      text: habitRow.isCount
                        ? ((modelData.goalType === "max" ? "limite: máx " : "meta: ") + modelData.target + (modelData.unit ? " " + modelData.unit : "") + "/dia")
                        : "marcar feito"
                      color: Qt.rgba(1, 1, 1, 0.45)
                      font.pixelSize: 9
                    }
                  }

                  Text {
                    readonly property string todayStatus: config.habitStatus(modelData, config._todayKey())
                    text: config.statusLabel(todayStatus)
                    color: config.statusColor(todayStatus) || (Colors[modelData.color] || win.accentColor)
                    opacity: todayStatus === "empty" ? 0.35 : 1
                    font { pixelSize: 9; weight: Font.DemiBold }
                  }

                  Text {
                    text: config.streakFor(modelData) + "d seguidos"
                    color: win.accentColor
                    opacity: config.streakFor(modelData) > 0 ? 1 : 0.35
                    font.pixelSize: 10
                  }

                  Text {
                    text: "\uf201" // gráfico (ver histórico)
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      anchors.fill: parent; anchors.margins: -6
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { win.selectedHabitId = modelData.id; win.tab = "historico" }
                    }
                  }

                  Text {
                    text: "\uf044"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      anchors.fill: parent; anchors.margins: -6
                      cursorShape: Qt.PointingHandCursor
                      onClicked: win.editHabitRequested(modelData)
                    }
                  }

                  Text {
                    text: "×"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 15
                    MouseArea {
                      anchors.fill: parent; anchors.margins: -6
                      cursorShape: Qt.PointingHandCursor
                      onClicked: config.removeHabit(modelData.id)
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ══════════════════════════════════════════════════════════════
      // ABA: HISTÓRICO — heatmap grande + stats + log
      // ══════════════════════════════════════════════════════════════
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: win.tab === "historico"
        spacing: 10

        Text {
          visible: config.habits.length === 0
          text: "cadastre um hábito primeiro na aba \"Hábitos\""
          color: Qt.rgba(1, 1, 1, 0.4)
          font.pixelSize: 11
        }

        // ── seletor de hábito (chips) ──────────────────────────────
        Flow {
          Layout.fillWidth: true
          visible: config.habits.length > 0
          spacing: 6
          Repeater {
            model: config.habits
            delegate: Rectangle {
              required property var modelData
              readonly property bool active: win.selectedHabitId === modelData.id
              width: chipLabel.implicitWidth + 22; height: 26; radius: 13
              readonly property color hc: Colors[modelData.color] || win.accentColor
              color: active ? Qt.rgba(hc.r, hc.g, hc.b, 0.3) : Qt.rgba(1, 1, 1, 0.07)
              border.color: active ? Qt.rgba(hc.r, hc.g, hc.b, 0.6) : "transparent"; border.width: 1
              RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5
                Rectangle { width: 7; height: 7; radius: 3.5; color: parent.parent.hc }
                Text {
                  id: chipLabel
                  text: modelData.name
                  color: Colors[config.colorLabel]
                  font.pixelSize: 10
                }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.selectedHabitId = modelData.id }
            }
          }
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: win.selectedHabit !== null
          contentWidth: width
          contentHeight: histCol.implicitHeight
          clip: true

          ColumnLayout {
            id: histCol
            width: parent.width
            spacing: 14

            // ── estatísticas ──────────────────────────────────────
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Repeater {
                model: {
                  if (!win.selectedHabit) return []
                  const h = win.selectedHabit
                  const base = [
                    { label: "streak atual",   value: config.streakFor(h) + "d" },
                    { label: "streak recorde", value: config.longestStreak(h) + "d" },
                    { label: "total",          value: config.totalCompletions(h) + "×" },
                    { label: "este mês",       value: config.completionsInMonth(h, win.viewYear, win.viewMonth) + "×" },
                  ]
                  if (h.kind === "count" && h.goalType === "max") {
                    const overCount = Object.keys(h.history || {}).filter(k => config.habitStatus(h, k) === "over").length
                    base.push({ label: "excessos", value: overCount + "×", warn: overCount > 0 })
                  }
                  return base
                }
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  height: 52; radius: 10
                  color: Qt.rgba(1, 1, 1, 0.04)
                  ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: modelData.value
                      color: modelData.warn ? config.statusColorOver : (win.selectedHabit ? (Colors[win.selectedHabit.color] || win.accentColor) : win.accentColor)
                      font { pixelSize: 16; weight: Font.DemiBold }
                    }
                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: modelData.label
                      color: Qt.rgba(1, 1, 1, 0.45)
                      font.pixelSize: 8
                    }
                  }
                }
              }
            }

            // ── heatmap grande (26 semanas) ─────────────────────────
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "Últimas " + win.heatmapWeeks + " semanas"
                  color: Qt.rgba(1, 1, 1, 0.5)
                  font.pixelSize: 9
                }
                Item { Layout.fillWidth: true }
                // dia sob o mouse — atualiza ao passar pelas células
                Text {
                  text: win.hoveredCell ? (win.hoveredCell.date + " · " + config.statusLabel(win.hoveredCell.status)) : ""
                  color: win.hoveredCell ? (config.statusColor(win.hoveredCell.status) || (win.selectedHabit ? (Colors[win.selectedHabit.color] || win.accentColor) : win.accentColor)) : Qt.rgba(1, 1, 1, 0.6)
                  font { pixelSize: 9; weight: Font.DemiBold }
                }
              }

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Repeater {
                  model: win.monthLabels
                  delegate: Text {
                    required property var modelData
                    x: modelData.col * 13
                    text: modelData.label
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 8
                  }
                }
              }

              GridLayout {
                columns: win.heatmapWeeks
                rowSpacing: 2; columnSpacing: 2

                Repeater {
                  model: win.bigHeatmapCells
                  delegate: Rectangle {
                    id: heatCell
                    required property var modelData
                    Layout.row: modelData.row
                    Layout.column: modelData.col
                    width: 11; height: 11; radius: 2
                    readonly property color base: win.selectedHabit ? (Colors[win.selectedHabit.color] || win.accentColor) : win.accentColor
                    readonly property color statusOverride: config.statusColor(modelData.status)
                    color: {
                      if (modelData.future) return "transparent"
                      if (statusOverride) return Qt.rgba(statusOverride.r, statusOverride.g, statusOverride.b, 0.75)
                      return modelData.ratio > 0
                        ? Qt.rgba(base.r, base.g, base.b, 0.15 + modelData.ratio * 0.85)
                        : Qt.rgba(base.r, base.g, base.b, 0.10)
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    border.width: (win.hoveredCell && win.hoveredCell.date === modelData.date && modelData.date) ? 1 : 0
                    border.color: Colors[config.colorLabel]

                    HoverHandler {
                      enabled: !!heatCell.modelData.date
                      onHoveredChanged: {
                        if (hovered) win.hoveredCell = { date: heatCell.modelData.date, ratio: heatCell.modelData.ratio, status: heatCell.modelData.status }
                        else if (win.hoveredCell && win.hoveredCell.date === heatCell.modelData.date) win.hoveredCell = null
                      }
                    }
                  }
                }
              }
            }

            // ── log de registros ─────────────────────────────────
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "Registros recentes"
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: 9
              }
              Repeater {
                model: win.selectedHabit ? config.historyEntries(win.selectedHabit, 60) : []
                delegate: RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: 8
                  Text {
                    text: modelData.date
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 10
                    Layout.preferredWidth: 76
                  }
                  Text {
                    text: win.selectedHabit && win.selectedHabit.kind === "count"
                      ? (modelData.amount + "/" + win.selectedHabit.target + (win.selectedHabit.unit ? " " + win.selectedHabit.unit : ""))
                      : "concluído"
                    color: modelData.done ? (win.selectedHabit ? (Colors[win.selectedHabit.color] || win.accentColor) : win.accentColor) : Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 10
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: config.statusLabel(modelData.status)
                    color: config.statusColor(modelData.status) || (win.selectedHabit ? (Colors[win.selectedHabit.color] || win.accentColor) : win.accentColor)
                    font { pixelSize: 9; weight: Font.DemiBold }
                  }
                  Text {
                    text: modelData.status === "over" ? "\uf071"
                          : (modelData.status === "hit" || modelData.status === "limit") ? "\uf00c"
                          : "\uf00d"
                    color: modelData.status === "over" ? config.statusColorOver
                           : (modelData.status === "hit" || modelData.status === "limit") ? "#45a249"
                           : Qt.rgba(1, 1, 1, 0.35)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                  }
                }
              }
              Text {
                visible: win.selectedHabit && config.historyEntries(win.selectedHabit, 60).length === 0
                text: "nenhum registro ainda"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 10
              }
            }
          }
        }
      }
    }
  }
}
