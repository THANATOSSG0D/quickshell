import Quickshell
import QtQuick
import QtQuick.Layouts
import "../bar" as Bar

// ── Clock ──────────────────────────────────────────────────────────────────
// Widget da barra. Exibe relógio sempre visível + timer quando ativo.
// • Horizontal: HH:MM  [ícone MM:SS]  lado a lado
// • Vertical:   HH/MM empilhados, timer abaixo separado por linha
// • barTimerActive = false → timer não é exibido (sumiu após zerar no modo livre)
// • Scroll → ±1 min no timer

Item {
  id: root

  property bool isHorizontal: true
  property int  barPosition:  2

  property color textColor:   "white"
  property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
  property color accentColor: "white"
  // Tempo em ms antes de o timer expirado sumir da barra (modo livre)
  property int   dismissDelay: 8000

  signal panelRequested()

  // Estado derivado do ClockContent (injetado pelo Bar.qml)
  readonly property bool timerActive:    clockContent ? clockContent.barTimerActive : false
  readonly property bool timerRunning:   clockContent ? clockContent.barRunning     : false
  readonly property int  timerRemaining: clockContent ? clockContent.barRemaining   : 0
  readonly property bool timerExpired:   clockContent ? clockContent.barExpired     : false

  property var clockContent: null

  // Propaga dismissDelay para o ClockContent quando ele for injetado ou quando mudar
  onClockContentChanged: {
    if (clockContent && "dismissDelayMs" in clockContent)
      clockContent.dismissDelayMs = root.dismissDelay
  }
  onDismissDelayChanged: {
    if (clockContent && "dismissDelayMs" in clockContent)
      clockContent.dismissDelayMs = root.dismissDelay
  }

  // ── Tick ──────────────────────────────────────────────────────────────
  property bool _tick: false
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: root._tick = !root._tick
  }

  readonly property string hh: {
    var _ = _tick
    var h = new Date().getHours()
    return (h < 10 ? "0" : "") + h
  }
  readonly property string mm: {
    var _ = _tick
    var m = new Date().getMinutes()
    return (m < 10 ? "0" : "") + m
  }
  readonly property bool _colonOn: {
    var _ = _tick
    return new Date().getSeconds() % 2 === 0
  }

  readonly property string timerMm: {
    var s = Math.max(0, timerRemaining)
    var v = Math.floor(s / 60)
    return (v < 10 ? "0" : "") + v
  }
  readonly property string timerSs: {
    var s = Math.max(0, timerRemaining)
    var v = s % 60
    return (v < 10 ? "0" : "") + v
  }

  // ── Tamanho ────────────────────────────────────────────────────────────
  implicitWidth:  isHorizontal ? hContent.implicitWidth  + 12 : vContent.implicitWidth  + 4
  implicitHeight: isHorizontal ? hContent.implicitHeight + 6  : vContent.implicitHeight + 8

  // ════════════════════════════════════════════════════════════════════════
  // HORIZONTAL — relógio + [timer] lado a lado
  // ════════════════════════════════════════════════════════════════════════
  Item {
    id: hContent
    visible:          root.isHorizontal
    anchors.centerIn: parent
    implicitWidth:    hRow.implicitWidth
    implicitHeight:   hRow.implicitHeight

    Row {
      id: hRow
      anchors.centerIn: parent
      spacing: 8

      // Relógio
      Row {
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text:           root.hh
          color:          root.textColor
          font.pixelSize: 13
          font.weight:    Font.Medium
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
          text:           ":"
          color:          root._colonOn ? root.textColor : root.dimColor
          opacity:        root._colonOn ? 1.0 : 0.3
          font.pixelSize: 13
          font.weight:    Font.Medium
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on opacity { NumberAnimation { duration: 200 } }
          Behavior on color   { ColorAnimation  { duration: 200 } }
        }
        Text {
          text:           root.mm
          color:          root.textColor
          font.pixelSize: 13
          font.weight:    Font.Medium
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      // Separador visual entre relógio e timer
      Rectangle {
        visible:                root.timerActive
        anchors.verticalCenter: parent.verticalCenter
        width:   1
        height:  12
        radius:  1
        color:   root.dimColor
        opacity: 0.35
      }

      // Timer
      Row {
        visible:                root.timerActive
        spacing:                4
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:    root.timerExpired ? "\uf017" : root.timerRunning ? "\uf017" : "\uf28b"
          color:   root.timerExpired ? root.accentColor : root.timerRunning ? root.accentColor : root.dimColor
          opacity: (root.timerRunning && !root.timerExpired) ? (root._colonOn ? 1.0 : 0.4) : 1.0
          font.pixelSize: 10
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color   { ColorAnimation  { duration: 200 } }
          Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Row {
          spacing:                0
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text:           root.timerMm
            color:          root.timerExpired ? root.accentColor : root.textColor
            font.pixelSize: 13
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            Behavior on color { ColorAnimation { duration: 200 } }
          }
          Text {
            text:           ":"
            font.pixelSize: 13
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            color: (root.timerRunning && !root.timerExpired)
              ? (root._colonOn ? root.textColor : root.dimColor)
              : (root.timerExpired ? root.accentColor : root.dimColor)
            opacity: (root.timerRunning && !root.timerExpired)
              ? (root._colonOn ? 1.0 : 0.3)
              : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Behavior on color   { ColorAnimation  { duration: 200 } }
          }
          Text {
            text:           root.timerSs
            color:          root.timerExpired ? root.accentColor : root.textColor
            font.pixelSize: 13
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERTICAL — HH/MM empilhados + timer abaixo (se ativo)
  // ════════════════════════════════════════════════════════════════════════
  Item {
    id: vContent
    visible:          !root.isHorizontal
    anchors.centerIn: parent
    implicitWidth:    vCol.implicitWidth
    implicitHeight:   vCol.implicitHeight

    Column {
      id: vCol
      anchors.centerIn: parent
      spacing: 2

      // Relógio — HH cima, linha, MM baixo
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           root.hh
          color:          root.textColor
          font.pixelSize: 16
          font.weight:    Font.Bold
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 20; height: 1; radius: 1
          color:   root.dimColor
          opacity: 0.4
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           root.mm
          color:          root.dimColor
          font.pixelSize: 16
          font.weight:    Font.Bold
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      // Separador e timer (quando ativo)
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing:  0
        visible:  root.timerActive

        // FIX: topPadding não existe em Rectangle → substituído por Item espaçador
        Item { width: 1; height: 2 }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width:   16
          height:  1
          radius:  1
          color:   root.dimColor
          opacity: 0.2
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:    root.timerExpired ? "\uf017" : root.timerRunning ? "\uf017" : "\uf28b"
          color:   root.timerExpired ? root.accentColor : root.timerRunning ? root.accentColor : root.dimColor
          opacity: (root.timerRunning && !root.timerExpired) ? (root._colonOn ? 1.0 : 0.4) : 1.0
          font.pixelSize: 9
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color   { ColorAnimation  { duration: 200 } }
          Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           root.timerMm
          color:          root.timerExpired ? root.accentColor : root.textColor
          font.pixelSize: 15
          font.weight:    Font.Bold
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width:   18
          height:  1
          radius:  1
          color:   root.timerExpired ? root.accentColor : root.dimColor
          opacity: 0.4
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           root.timerSs
          color:          root.timerExpired ? root.accentColor : root.dimColor
          font.pixelSize: 15
          font.weight:    Font.Bold
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }
    }
  }

  // ── Interação ─────────────────────────────────────────────────────────
  MouseArea {
    anchors.fill:    parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled:    true

    onClicked: root.panelRequested()

    onWheel: (event) => {
      if (!root.clockContent) return
      var dy = event.angleDelta.y
      var dx = event.angleDelta.x
      root.clockContent.adjustTimer(
        Math.abs(dy) >= Math.abs(dx) ? (dy > 0 ? 60 : -60) : (dx > 0 ? -60 : 60)
      )
    }
  }
}
