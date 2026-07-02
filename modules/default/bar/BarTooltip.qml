pragma Singleton
import Quickshell
import QtQuick

// BarTooltip — singleton de tooltip global para a barra.
//
// API:
//   show(item, text, barPosition)   → mostra após 500ms de hover
//   update(item, text, barPosition) → mostra imediatamente (scroll), some após 1.5s
//   hide()                          → esconde com pequeno delay (evita piscar)

Singleton {
  id: root

  property color bgColor: Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor: "#e2e2e2"

  property var    _anchorItem: null
  property string _text:       ""
  property int    _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  // hover: mostra com delay
  function show(item, text, barPosition) {
    _anchorItem = item
    _text       = text
    _barPos     = barPosition
    hideTimer.stop()
    scrollHideTimer.stop()
    showTimer.restart()
  }

  // scroll: mostra imediatamente, some 1.5s após o último scroll
  function update(item, text, barPosition) {
    showTimer.stop()
    hideTimer.stop()
    _anchorItem   = item
    _text         = text
    _barPos       = barPosition
    popup.visible = true
    scrollHideTimer.restart()
  }

  // sai do hover: esconde com delay curto para não piscar entre ícones
  function hide() {
    showTimer.stop()
    // só agenda hide se não há scroll ativo
    if (!scrollHideTimer.running)
      hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: {
      if (root._anchorItem && root._text !== "")
        popup.visible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // some automaticamente após 1.5s de inatividade no scroll
  Timer {
    id: scrollHideTimer
    interval: 1500; repeat: false
    onTriggered: popup.visible = false
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    implicitWidth:  label.implicitWidth  + 16
    implicitHeight: label.implicitHeight + 10

    anchor.item: root._anchorItem

    // salta para fora da barra — lado oposto à borda
    anchor.edges: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left    // 2 = right
      }
    }
    anchor.gravity: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    Rectangle {
      anchors.fill: parent
      radius: 5
      color:  root.bgColor

      Text {
        id: label
        anchors.centerIn: parent
        // binding reativo — atualiza automaticamente quando _text muda
        text:           root._text
        color:          root.fgColor
        font.pixelSize: 11
        font.family:    "JetBrainsMono Nerd Font"
      }
    }
  }
}
