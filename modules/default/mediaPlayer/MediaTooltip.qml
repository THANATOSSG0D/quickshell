pragma Singleton
import Quickshell
import QtQuick

// MediaTooltip — singleton de tooltip rico para o módulo de mídia.
//
// Mesma filosofia do BarTooltip (PopupWindow leve, anexado ao item da
// barra, aparece com delay no hover), só que com layout próprio: capa do
// álbum, player, artista, título e álbum — em vez de só uma linha de texto.
//
// API:
//   show(item, player, barPosition)  → mostra após 500ms de hover
//   hide()                           → esconde com pequeno delay (evita piscar)
//
// "player" é o objeto Mpris (root.player do MediaPlayer.qml) — lido
// diretamente, então o conteúdo do tooltip atualiza em tempo real
// (próxima música, troca de player, etc) enquanto ele estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"

  property int artSize:   84

  property var _anchorItem: null
  property var _player:     null
  property int _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, player, barPosition) {
    _anchorItem = item
    _player     = player
    _barPos     = barPosition
    hideTimer.stop()
    showTimer.restart()
  }

  function hide() {
    showTimer.stop()
    hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: {
      if (root._anchorItem && root._player)
        popup.visible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do player ───────────────────────────────────
  readonly property string _title:  root._player ? (root._player.trackTitle  || "") : ""
  readonly property string _artist: root._player ? (root._player.trackArtist || "") : ""
  readonly property string _album:  root._player ? (root._player.trackAlbum  || "") : ""
  readonly property string _app:    root._player ? (root._player.identity    || "") : ""
  readonly property string _artUrl: root._player ? (root._player.trackArtUrl || "") : ""
  readonly property bool   _volSupported: root._player ? (root._player.volumeSupported !== false) : false
  readonly property real   _volume:       (root._player && root._player.volume !== undefined && root._player.volume !== null) ? root._player.volume : 1.0

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    implicitWidth:  Math.max(220, content.implicitWidth  + 28)
    implicitHeight: content.implicitHeight + 20

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

      Row {
        id: content
        anchors.centerIn: parent
        spacing: 10

        // ── Capa do álbum (com mesmo fallback visual do módulo da barra) ──
        Item {
          id: tooltipArtBox
          width: root.artSize; height: root.artSize
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            id: tooltipArtBg
            anchors.fill: parent
            color: "transparent"

            Image {
              id: tooltipArt
              anchors.fill: parent
              source:   root._artUrl
              fillMode: Image.PreserveAspectCrop
              visible:  status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible:        tooltipArt.status !== Image.Ready
              text:           "\uf001"
              color:          root.fgDimColor
              font.pixelSize: Math.round(root.artSize * 0.4)
              font.family:    "JetBrainsMono Nerd Font"
            }
          }
        }

        // ── Textos ───────────────────────────────────────────────────────
        Column {
          id: textCol
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          // Largura única para toda a coluna — cresce com o texto mais
          // longo (até um teto), e o slider de volume ocupa essa mesma
          // largura inteira, em vez de ficar fixo em 60px.
          readonly property int textColWidth: Math.max(
            120,
            Math.min(220, Math.max(
              titleText.implicitWidth,
              artistText.implicitWidth,
              albumText.implicitWidth,
              appText.implicitWidth
            ))
          )

          Text {
            id: titleText
            text:           root._title || root._app || "—"
            color:          root.fgColor
            font.pixelSize: 12
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: artistText
            visible:        root._artist.length > 0
            text:           root._artist
            color:          root.accentColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: albumText
            visible:        root._album.length > 0
            text:           root._album
            color:          root.fgDimColor
            font.pixelSize: 10
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: appText
            visible:        root._app.length > 0
            text:           root._app
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }

          // ── Volume ───────────────────────────────────────────────────
          Row {
            visible: root._volSupported
            spacing: 5
            topPadding: 3
            width: textCol.textColWidth

            Text {
              id: volIcon
              text:           "\uf028"   // nf-fa-volume_up
              color:          root.fgDimColor
              font.pixelSize: 9
              font.family:    "JetBrainsMono Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
              id: volTrack
              width:  textCol.textColWidth - volIcon.implicitWidth - volPct.implicitWidth - parent.spacing * 2
              height: 4; radius: 2
              color: Qt.rgba(1, 1, 1, 0.15)
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                width:  parent.width * root._volume
                height: parent.height
                radius: parent.radius
                color:  root.accentColor
                Behavior on width { NumberAnimation { duration: 120 } }
              }
            }
            Text {
              id: volPct
              text:           Math.round(root._volume * 100) + "%"
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
}
