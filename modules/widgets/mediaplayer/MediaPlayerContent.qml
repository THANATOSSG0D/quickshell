import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root

  property bool grouped: false

  MediaPlayerConfig { id: config }

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── player ativo ──────────────────────────────────────────────────────
  // prioridade: preferredPlayerId (se configurado e presente) → primeiro
  // player tocando agora → primeiro player disponível → nenhum
  readonly property var players: Mpris.players.values
  readonly property var activePlayer: {
    if (config.preferredPlayerId !== "") {
      const p = players.find(p => p.identity === config.preferredPlayerId || p.desktopEntry === config.preferredPlayerId)
      if (p) return p
    }
    const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing)
    if (playing) return playing
    return players.length > 0 ? players[0] : null
  }
  readonly property bool hasPlayer: activePlayer !== null
  readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing

  // posição não atualiza reativamente sozinha — força emissão do sinal
  // enquanto está tocando, conforme recomendado pela própria doc do Mpris
  Timer {
    interval: 1000
    running: root.hasPlayer && root.isPlaying
    repeat: true
    triggeredOnStart: true
    onTriggered: root.activePlayer.positionChanged()
  }

  readonly property real _length: hasPlayer ? (activePlayer.length || 0) : 0
  readonly property real _position: hasPlayer ? (activePlayer.position || 0) : 0
  readonly property real progressRatio: _length > 0 ? Math.max(0, Math.min(1, _position / _length)) : 0

  function _fmt(sec) {
    if (!sec || sec < 0 || !isFinite(sec)) return "0:00"
    const m = Math.floor(sec / 60)
    const s = Math.floor(sec % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  Process {
    id: launchProc
    running: false
    command: config.launchCommand !== "" ? ["sh", "-c", config.launchCommand] : ["true"]
  }

  // ── sem player ativo: placeholder clicável que abre o app ────────────
  ColumnLayout {
    anchors.centerIn: parent
    visible: !root.hasPlayer
    spacing: 6

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "\uf001" // nota musical (Nerd Font)
      color: Colors[config.colorLabel]
      opacity: 0.35
      font { pixelSize: 26; family: "JetBrainsMono Nerd Font" }
    }
    Text {
      Layout.alignment: Qt.AlignHCenter
      text: config.appLabel
      color: Colors[config.colorLabel]
      opacity: 0.6
      font.pixelSize: 12
    }
    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: config.launchCommand !== ""
      text: "clique para abrir"
      color: Colors[config.colorLabel]
      opacity: 0.35
      font.pixelSize: 10
    }
  }

  MouseArea {
    anchors.fill: parent
    visible: !root.hasPlayer
    enabled: !root.hasPlayer && config.launchCommand !== ""
    cursorShape: config.launchCommand !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: { launchProc.running = false; launchProc.running = true }
  }

  // ── player ativo ───────────────────────────────────────────────────
  ColumnLayout {
    anchors.centerIn: parent
    visible: root.hasPlayer
    width: config.fixedWidth - 24
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        visible: config.showCoverArt
        width: 52; height: 52; radius: 8
        color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

        Image {
          anchors.fill: parent
          visible: root.hasPlayer && root.activePlayer.trackArtUrl !== ""
          source: root.hasPlayer ? root.activePlayer.trackArtUrl : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: !root.hasPlayer || root.activePlayer.trackArtUrl === ""
          text: "\uf001"
          color: Colors[config.colorLabel]
          opacity: 0.3
          font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text {
          Layout.fillWidth: true
          text: root.hasPlayer ? (root.activePlayer.trackTitle || "Sem título") : ""
          color: Colors[config.colorLabel]
          font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.DemiBold }
          elide: Text.ElideRight
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.8)
            shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; shadowScale: 1.02
          }
        }
        Text {
          Layout.fillWidth: true
          text: root.hasPlayer ? (root.activePlayer.trackArtist || "Artista desconhecido") : ""
          color: Colors[config.colorLabel]
          opacity: 0.65
          font.pixelSize: config.fontSizeValue - 3
          elide: Text.ElideRight
        }
      }
    }

    // ── progresso / seek ────────────────────────────────────────────
    ColumnLayout {
      Layout.fillWidth: true
      visible: config.showProgress
      spacing: 3

      Rectangle {
        id: progressTrack
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
          height: parent.height
          radius: parent.radius
          width: parent.width * root.progressRatio
          color: Colors[config.colorValue]
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          enabled: root.hasPlayer && root.activePlayer.canSeek
          cursorShape: Qt.PointingHandCursor
          onClicked: (mouse) => {
            const ratio = Math.max(0, Math.min(1, mouse.x / width))
            root.activePlayer.position = ratio * root._length
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: root._fmt(root._position)
          color: Colors[config.colorLabel]
          opacity: 0.55
          font.pixelSize: 9
        }
        Item { Layout.fillWidth: true }
        Text {
          text: root._fmt(root._length)
          color: Colors[config.colorLabel]
          opacity: 0.55
          font.pixelSize: 9
        }
      }
    }

    // ── controles ────────────────────────────────────────────────────
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 20

      Text {
        text: "\uf048" // prev
        color: Colors[config.colorLabel]
        opacity: (root.hasPlayer && root.activePlayer.canGoPrevious) ? 0.85 : 0.25
        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          enabled: root.hasPlayer && root.activePlayer.canGoPrevious
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activePlayer.previous()
        }
      }

      Text {
        text: root.isPlaying ? "\uf04c" : "\uf04b" // pause / play
        color: Colors[config.colorValue]
        opacity: (root.hasPlayer && root.activePlayer.canTogglePlaying) ? 1 : 0.3
        font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          enabled: root.hasPlayer && root.activePlayer.canTogglePlaying
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activePlayer.togglePlaying()
        }
      }

      Text {
        text: "\uf051" // next
        color: Colors[config.colorLabel]
        opacity: (root.hasPlayer && root.activePlayer.canGoNext) ? 0.85 : 0.25
        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          enabled: root.hasPlayer && root.activePlayer.canGoNext
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activePlayer.next()
        }
      }
    }
  }
}
