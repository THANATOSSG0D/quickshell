import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ── Conteúdo do Media Player ───────────────────────────────────────────────
// Pode ser embutido em PanelWindow, PopupWindow ou qualquer outro container.
// O host deve fornecer as propriedades required abaixo e conectar closeRequested.
Item {
  id: root

  // ── Props obrigatórias fornecidas pelo host ────────────────────────────
  // referência ao MediaPlayer da barra para pinnar o player selecionado
  required property var barMediaPlayer

  // ── Cores injetadas pelo host ──────────────────────────────────────────
  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorProgressBg: "#474747"
  property color colorProgressFg: "#ffb4a9"
  property color colorAccent:     "#ffb4a9"

  // ── Sinal para o host fechar a janela ─────────────────────────────────
  signal closeRequested()

  // ── Player ativo ──────────────────────────────────────────────────────
  readonly property var activePlayer: barMediaPlayer ? barMediaPlayer.player : null

  // Conta players reais (sem playerctld) — controla visibilidade do seletor
  readonly property int realPlayerCount: {
    var c = 0
    var all = Mpris.players.values
    for (var i = 0; i < all.length; i++) {
      var e = (all[i].desktopEntry || all[i].identity || "").toLowerCase()
      if (!e.startsWith("playerctld")) c++
    }
    return c
  }

  // Timer para atualizar position (MPRIS não notifica em tempo real)
  Timer {
    interval: 500
    repeat:   true
    running:  root.visible && root.activePlayer !== null &&
              root.activePlayer.playbackState === MprisPlaybackState.Playing
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }

  // ── Seletor de player ──────────────────────────────────────────────────
  ColumnLayout {
    anchors.fill:    parent
    anchors.margins: 14
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      visible: root.realPlayerCount > 1
      spacing: 6

      Repeater {
        // Model nativo do Mpris: reatividade automática e identidade de objeto
        // preservada — isActive (===) só funciona com o objeto original.
        model: Mpris.players.values

        Rectangle {
          required property var modelData
          // playerctld é proxy — oculta visualmente, não remove do model
          visible: !(modelData.desktopEntry || modelData.identity || "").toLowerCase().startsWith("playerctld")
          property bool isActive: root.activePlayer === modelData

          Layout.preferredHeight: 24
          Layout.preferredWidth:  playerLabel.implicitWidth + 16
          radius: height / 2
          color:  isActive
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
            : Qt.rgba(1, 1, 1, 0.06)
          border.color: isActive ? root.colorAccent : "transparent"
          border.width: 1

          Text {
            id: playerLabel
            anchors.centerIn: parent
            text:           modelData.identity || "Player"
            color:          isActive ? root.colorAccent : root.colorTextDim
            font.pixelSize: 10
            font.weight:    isActive ? Font.Medium : Font.Normal
            elide:          Text.ElideRight
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              if (root.barMediaPlayer)
                root.barMediaPlayer.pinnedPlayer = isActive ? null : modelData
            }
          }
        }
      }

      Item { Layout.fillWidth: true }
    }

    // ── Artwork ──────────────────────────────────────────────────────────
    Item {
      Layout.fillWidth:     true
      Layout.fillHeight:    true
      Layout.maximumHeight: 160

      Rectangle {
        anchors.centerIn: parent
        width:  Math.min(parent.width, parent.height)
        height: width
        radius: 10
        clip:   true
        color:  Qt.rgba(1, 1, 1, 0.06)

        Image {
          id: panelArtImg
          anchors.fill: parent
          source:       root.activePlayer ? root.activePlayer.trackArtUrl : ""
          fillMode:     Image.PreserveAspectCrop
          visible:      status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible:        panelArtImg.status !== Image.Ready
          text:           "\uf001"
          color:          root.colorTextDim
          font.pixelSize: 48
          font.family:    "JetBrainsMono Nerd Font"
        }
      }
    }

    // ── Título e artista ──────────────────────────────────────────────────
    Text {
      Layout.fillWidth:    true
      text:                root.activePlayer ? (root.activePlayer.trackTitle || "") : ""
      color:               root.colorText
      font.pixelSize:      13
      font.weight:         Font.Medium
      elide:               Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      Layout.fillWidth:    true
      text:                root.activePlayer ? (root.activePlayer.trackArtist || root.activePlayer.identity || "") : ""
      color:               root.colorTextDim
      font.pixelSize:      11
      elide:               Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }

    // ── Barra de progresso clicável ───────────────────────────────────────
    Item {
      Layout.fillWidth:       true
      Layout.preferredHeight: 18

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 4; radius: 2
        color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5)
      }

      Rectangle {
        id: progressFill
        anchors.verticalCenter: parent.verticalCenter
        height: 4; radius: 2
        color: root.colorProgressFg
        width: {
          var p = root.activePlayer
          if (!p || !p.lengthSupported || p.length <= 0) return 0
          return Math.max(0, Math.min(1, p.position / p.length)) * parent.width
        }
      }

      Rectangle {
        id: progressThumb
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(progressFill.width - width / 2, progressFill.width - width / 2))
        width: 12; height: 12; radius: 6
        color: root.colorProgressFg
        visible: progressArea.containsMouse
        scale:   progressArea.pressed ? 0.85 : 1.0
        Behavior on scale { NumberAnimation { duration: 80 } }
      }

      MouseArea {
        id: progressArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.activePlayer && root.activePlayer.canSeek && root.activePlayer.lengthSupported

        onClicked: function(mouse) {
          var p = root.activePlayer
          if (!p || !p.canSeek || !p.lengthSupported || p.length <= 0) return
          var ratio    = Math.max(0, Math.min(1, mouse.x / width))
          var targetMs = ratio * p.length * 1000
          var currentMs = p.position * 1000
          p.seek(targetMs - currentMs)
        }
      }
    }

    // ── Tempos ────────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true

      Text {
        text:           root.activePlayer ? formatTime(root.activePlayer.position) : "0:00"
        color:          root.colorTextDim
        font.pixelSize: 10
      }
      Item { Layout.fillWidth: true }
      Text {
        text: {
          var p = root.activePlayer
          if (!p) return "0:00"
          if (!p.lengthSupported) return "–:––"
          return formatTime(p.length)
        }
        color:          root.colorTextDim
        font.pixelSize: 10
      }
    }

    // ── Controles principais ──────────────────────────────────────────────
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 4

      // Shuffle
      Item {
        width: 32; height: 32
        opacity: root.activePlayer && root.activePlayer.shuffleSupported ? 1.0 : 0.3
        Rectangle {
          anchors.fill: parent; radius: width / 2
          color: root.activePlayer && root.activePlayer.shuffleSupported && root.activePlayer.shuffle
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
            : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text:           "\uf074"
          color:          root.activePlayer && root.activePlayer.shuffle
                            ? root.colorAccent : root.colorTextDim
          font.pixelSize: 14
          font.family:    "JetBrainsMono Nerd Font"
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.activePlayer && root.activePlayer.shuffleSupported
          onClicked: root.activePlayer.shuffle = !root.activePlayer.shuffle
        }
      }

      // Anterior
      Item {
        width: 32; height: 32
        opacity: root.activePlayer && root.activePlayer.canGoPrevious ? 1.0 : 0.35
        Text {
          anchors.centerIn: parent; text: "\uf048"
          color: root.colorText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer) root.activePlayer.previous() }
      }

      // Play/Pause
      Item {
        width: 44; height: 44
        Rectangle {
          anchors.fill: parent; radius: width / 2
          color: root.colorAccent
          opacity: playPauseArea.pressed ? 0.7 : 1.0
          Behavior on opacity { NumberAnimation { duration: 80 } }
        }
        Text {
          anchors.centerIn: parent
          text:           root.activePlayer && root.activePlayer.isPlaying ? "\uf04c" : "\uf04b"
          color:          root.colorPanelBg
          font.pixelSize: 18
          font.family:    "JetBrainsMono Nerd Font"
        }
        MouseArea {
          id: playPauseArea
          anchors.fill: parent
          onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
        }
      }

      // Próximo
      Item {
        width: 32; height: 32
        opacity: root.activePlayer && root.activePlayer.canGoNext ? 1.0 : 0.35
        Text {
          anchors.centerIn: parent; text: "\uf051"
          color: root.colorText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer) root.activePlayer.next() }
      }

      // Loop
      Item {
        width: 32; height: 32
        opacity: root.activePlayer && root.activePlayer.loopSupported ? 1.0 : 0.3

        readonly property int loopState: root.activePlayer && root.activePlayer.loopSupported
          ? root.activePlayer.loopState : MprisLoopState.None

        Rectangle {
          anchors.fill: parent; radius: width / 2
          color: parent.loopState !== MprisLoopState.None
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
            : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text:           parent.loopState === MprisLoopState.Track
                            ? "\uf01e" : "\uf021"
          color:          parent.loopState !== MprisLoopState.None
                            ? root.colorAccent : root.colorTextDim
          font.pixelSize: 14
          font.family:    "JetBrainsMono Nerd Font"
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.activePlayer && root.activePlayer.loopSupported
          onClicked: {
            var p = root.activePlayer
            if (!p) return
            if (p.loopState === MprisLoopState.None)         p.loopState = MprisLoopState.Playlist
            else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track
            else                                               p.loopState = MprisLoopState.None
          }
        }
      }
    }

    // ── Volume ────────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text:    (!root.activePlayer || root.activePlayer.volume <= 0)
                   ? "\uf026" : "\uf028"
        opacity: {
          var p = root.activePlayer
          if (!p || p.volume <= 0) return 1.0
          if (p.volume < 0.34)     return 0.45
          if (p.volume < 0.67)     return 0.72
          return 1.0
        }
        color:          root.colorTextDim
        font.pixelSize: 13
        font.family:    "JetBrainsMono Nerd Font"
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      Item {
        Layout.fillWidth:       true
        Layout.preferredHeight: 18

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: 3; radius: 2
          color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5)
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          height: 3; radius: 2; color: root.colorAccent
          width: {
            var p = root.activePlayer
            return p ? Math.max(0, Math.min(1, p.volume)) * parent.width : 0
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          enabled: root.activePlayer !== null

          onClicked: function(mouse) {
            if (!root.activePlayer) return
            root.activePlayer.volume = Math.max(0, Math.min(1, mouse.x / width))
          }
          onPositionChanged: function(mouse) {
            if (!pressed || !root.activePlayer) return
            root.activePlayer.volume = Math.max(0, Math.min(1, mouse.x / width))
          }
        }
      }

      Text {
        text: {
          var p = root.activePlayer
          return p ? Math.round(p.volume * 100) + "%" : "–"
        }
        color:          root.colorTextDim
        font.pixelSize: 10
        Layout.preferredWidth: 30
        horizontalAlignment: Text.AlignRight
      }
    }

  } // ColumnLayout

  function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00"
    var m = Math.floor(seconds / 60)
    var s = Math.floor(seconds % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }
}
