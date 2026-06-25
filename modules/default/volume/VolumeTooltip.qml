pragma Singleton
import Quickshell
import QtQuick

// VolumeTooltip — singleton de tooltip rico para o módulo de volume (sink/source).
//
// Mesma filosofia do MediaTooltip/ClockTooltip/QsTooltip (PopupWindow leve,
// anexado ao item da barra, aparece com delay no hover, mesma paleta e
// mesmo radius:10) — em vez do texto simples de uma linha que o BarTooltip
// genérico mostrava, agora exibe ícone + nome do dispositivo + barra de
// volume, no mesmo estilo da linha de volume do MediaTooltip.
//
// API:
//   show(item, volumeRoot, isSink, barPosition)   → mostra após 500ms de hover
//   update(item, volumeRoot, isSink, barPosition) → mostra imediatamente (scroll),
//                                                    some após 1.5s
//   hide()                                        → esconde com pequeno delay
//
// "volumeRoot" é a referência ao Volume.qml (root.volumeWidget) — lida
// diretamente, então o tooltip atualiza em tempo real (volume mudando,
// dispositivo trocando, mute) enquanto estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"
  property color mutedColor:   "#cf6679"

  property var    _anchorItem: null
  property var    _volumeRoot: null
  property bool   _isSink:     true
  property int    _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, volumeRoot, isSink, barPosition) {
    _anchorItem = item
    _volumeRoot = volumeRoot
    _isSink     = isSink
    _barPos     = barPosition
    hideTimer.stop()
    scrollHideTimer.stop()
    showTimer.restart()
  }

  // scroll: mostra imediatamente, some 1.5s após o último scroll
  function update(item, volumeRoot, isSink, barPosition) {
    showTimer.stop()
    hideTimer.stop()
    _anchorItem   = item
    _volumeRoot   = volumeRoot
    _isSink       = isSink
    _barPos       = barPosition
    popup.visible = true
    scrollHideTimer.restart()
  }

  function hide() {
    showTimer.stop()
    if (!scrollHideTimer.running)
      hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: { if (root._anchorItem && root._volumeRoot) popup.visible = true }
  }
  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }
  Timer {
    id: scrollHideTimer
    interval: 1500; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do volumeRoot ──────────────────────────────
  readonly property var    _device: {
    if (!_volumeRoot) return null
    return _isSink ? _volumeRoot.sink : _volumeRoot.source
  }
  readonly property string _name: {
    if (!_device) return _isSink ? "Saída" : "Microfone"
    return _device.nickname || _device.description || _device.name || (_isSink ? "Saída" : "Microfone")
  }
  readonly property real _volume: {
    if (!_volumeRoot) return 0
    return _isSink ? _volumeRoot.sinkVolume : _volumeRoot.sourceVolume
  }
  readonly property bool _muted: {
    if (!_volumeRoot) return false
    return _isSink ? _volumeRoot.sinkMuted : _volumeRoot.sourceMuted
  }
  readonly property string _icon: {
    if (_isSink) return (_muted || _volume <= 0) ? "\uf026" : "\uf028"
    return (_muted || _volume <= 0) ? "\uf131" : "\uf130"
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    implicitWidth:  Math.max(140, content.implicitWidth  + 20)
    implicitHeight: content.implicitHeight + 14

    anchor.item: root._anchorItem

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
    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.FlipY

    Rectangle {
      anchors.fill: parent
      radius: 10
      color:  root.bgColor

      Column {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // contentRowWidth: largura comum para título e barra — garante que
        // a barra de volume sempre estique até o final do tooltip, em vez
        // de ficar limitada à largura (curta) do título.
        readonly property int contentRowWidth: Math.max(96, titleRow.implicitWidth)

        // ── Nome do dispositivo ────────────────────────────────────────
        Row {
          id: titleRow
          spacing: 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root._icon
            color:          root._muted ? root.mutedColor : root.accentColor
            font.pixelSize: 12
            font.family:    "JetBrainsMono Nerd Font"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root._name
            color:          root.fgColor
            font.pixelSize: 11
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
          }
        }

        // ── Barra de volume — mesmo estilo do MediaTooltip/QsTooltip ───
        Row {
          spacing: 5
          width:   content.contentRowWidth

          Rectangle {
            id: volTrack
            width:  content.contentRowWidth - volPct.implicitWidth - parent.spacing
            height: 4; radius: 2
            color:  Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width:  parent.width * Math.min(1.0, root._volume)
              height: parent.height
              radius: parent.radius
              color:  root._muted ? root.mutedColor : root.accentColor
              Behavior on width { NumberAnimation { duration: 120 } }
            }
          }
          Text {
            id: volPct
            text:           (root._muted ? "mudo · " : "") + Math.round(root._volume * 100) + "%"
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
