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

  // detecta troca de faixa (uniqueId do MPRIS) pra disparar as animações
  // de transição — pop na capa + fade no título/artista
  readonly property int trackKey: hasPlayer ? activePlayer.uniqueId : -1
  onTrackKeyChanged: trackPop.restart()

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

      SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: !root.hasPlayer
        NumberAnimation { to: 0.15; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
      }
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
    id: playerLayout
    anchors.centerIn: parent
    visible: root.hasPlayer
    width: config.fixedWidth - 24
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      // ── capa (com giro estilo vinil + brilho colorido de fundo) ─────
      Item {
        visible: config.showCoverArt
        width: 52; height: 52

        // brilho suave atrás da capa, na cor de destaque — só reforça
        // presença visual, sem imagem real por trás
        Rectangle {
          anchors.centerIn: parent
          width: 60; height: 60; radius: 30
          color: Colors[config.colorValue]
          opacity: root.isPlaying ? 0.25 : 0.08
          layer.enabled: true
          layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 32 }
          Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }

        Item {
          id: coverMask
          anchors.fill: parent
          layer.enabled: true

          Rectangle {
            id: coverClip
            anchors.fill: parent
            radius: config.rotateCoverArt ? width / 2 : 8
            color: Qt.rgba(1, 1, 1, 0.06)
            clip: true

            Image {
              id: coverImg
              anchors.fill: parent
              visible: root.hasPlayer && root.activePlayer.trackArtUrl !== ""
              source: root.hasPlayer ? root.activePlayer.trackArtUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true

              RotationAnimator on rotation {
                id: vinylSpin
                from: 0; to: 360
                duration: 8000
                loops: Animation.Infinite
                running: config.rotateCoverArt && root.isPlaying && coverImg.visible
              }
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

          // furinho central — só aparece no modo "vinil" (capa redonda)
          Rectangle {
            visible: config.rotateCoverArt
            anchors.centerIn: parent
            width: 6; height: 6; radius: 3
            color: Qt.rgba(0, 0, 0, 0.5)
          }
        }

        // animação de "pop" ao trocar de faixa
        SequentialAnimation {
          id: trackPop
          NumberAnimation { target: coverMask; property: "scale"; to: 0.85; duration: 90; easing.type: Easing.OutCubic }
          NumberAnimation { target: coverMask; property: "scale"; to: 1.0;  duration: 220; easing.type: Easing.OutBack }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        clip: true

        // ── título com marquee quando não cabe ──────────────────────
        Item {
          id: titleBox
          Layout.fillWidth: true
          height: titleMetrics.height
          clip: true

          TextMetrics {
            id: titleMetrics
            font.pixelSize: config.fontSizeValue
            font.family: "Inter"
            font.weight: Font.DemiBold
            text: root.hasPlayer ? (root.activePlayer.trackTitle || "Sem título") : ""
          }

          readonly property bool overflowing: config.marqueeText && titleMetrics.advanceWidth > titleBox.width
          // ao parar de rolar (texto mudou pra algo mais curto, marquee
          // desligado etc.) volta pro início em vez de ficar deslocado
          onOverflowingChanged: if (!overflowing) titleText.x = 0

          Text {
            id: titleText
            text: titleMetrics.text
            color: Colors[config.colorLabel]
            font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.DemiBold }
            // largura sempre natural (implicitWidth não depende de width —
            // sem isso, width:parent.width + elide dinâmico cria loop);
            // quem corta o excesso é o clip:true do titleBox
            width: implicitWidth
            elide: Text.ElideNone

            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Component.onCompleted: opacity = 1
            Connections {
              target: root
              function onTrackKeyChanged() { titleText.opacity = 0; fadeInTimer.start() }
            }
            Timer { id: fadeInTimer; interval: 80; onTriggered: titleText.opacity = 1 }

            SequentialAnimation {
              id: marqueeAnim
              running: titleBox.overflowing
              loops: Animation.Infinite
              PauseAnimation { duration: 1200 }
              NumberAnimation {
                target: titleText; property: "x"
                to: -(titleText.width - titleBox.width) - 12
                duration: Math.max(1800, titleText.width * 18)
                easing.type: Easing.Linear
              }
              PauseAnimation { duration: 900 }
              NumberAnimation { target: titleText; property: "x"; to: 0; duration: 800; easing.type: Easing.InOutQuad }
            }
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

    // ── canvas visualizer (equalizador decorativo) ──────────────────
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 22
      visible: config.showVisualizer

      Canvas {
        id: viz
        anchors.fill: parent
        readonly property int barCount: 24
        property var heights: []

        Component.onCompleted: {
          const arr = []
          for (let i = 0; i < barCount; i++) arr.push(0.12)
          heights = arr
        }

        Timer {
          interval: 140
          running: viz.visible
          repeat: true
          onTriggered: {
            const arr = viz.heights.slice()
            for (let i = 0; i < arr.length; i++) {
              if (root.isPlaying) {
                // random-walk suave em direção a um alvo aleatório
                const target = 0.15 + Math.random() * 0.85
                arr[i] = arr[i] + (target - arr[i]) * 0.5
              } else {
                arr[i] = arr[i] + (0.08 - arr[i]) * 0.3
              }
            }
            viz.heights = arr
            viz.requestPaint()
          }
        }

        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const c = Colors[config.colorValue]
          const gap = 3
          const bw = (width - gap * (barCount - 1)) / barCount
          for (let i = 0; i < barCount; i++) {
            const h = Math.max(2, heights[i] * height)
            const x = i * (bw + gap)
            const y = height - h
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, root.isPlaying ? 0.85 : 0.3)
            ctx.beginPath()
            if (ctx.roundRect) ctx.roundRect(x, y, bw, h, bw / 2)
            else ctx.rect(x, y, bw, h)
            ctx.fill()
          }
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
          id: progressFill
          height: parent.height
          radius: parent.radius
          width: parent.width * root.progressRatio
          color: Colors[config.colorValue]
          Behavior on width { enabled: !seekArea.pressed; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // "thumb" que só aparece no hover/drag, com leve glow
        Rectangle {
          visible: seekArea.containsMouse || seekArea.pressed
          width: 10; height: 10; radius: 5
          color: Colors[config.colorValue]
          x: progressFill.width - width / 2
          y: (parent.height - height) / 2
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Colors[config.colorValue]
            shadowBlur: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0
          }
        }

        MouseArea {
          id: seekArea
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
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
      spacing: 16

      // shuffle
      Item {
        visible: config.showShuffleRepeat
        width: 20; height: 20
        readonly property bool active: root.hasPlayer && root.activePlayer.shuffleSupported && root.activePlayer.shuffle
        readonly property bool usable: root.hasPlayer && root.activePlayer.shuffleSupported && root.activePlayer.canControl

        Text {
          anchors.centerIn: parent
          text: "\uf074" // fa-random
          color: parent.active ? Colors[config.colorValue] : Colors[config.colorLabel]
          opacity: parent.usable ? (parent.active ? 1 : 0.55) : 0.2
          font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        MouseArea {
          anchors.fill: parent
          enabled: parent.usable
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activePlayer.shuffle = !root.activePlayer.shuffle
        }
      }

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

      Rectangle {
        id: playBtn
        width: 32; height: 32; radius: 16
        color: Qt.rgba(1, 1, 1, root.isPlaying ? 0.08 : 0)
        border.width: 1
        border.color: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.4)
        scale: playArea.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Text {
          anchors.centerIn: parent
          text: root.isPlaying ? "\uf04c" : "\uf04b" // pause / play
          color: Colors[config.colorValue]
          opacity: (root.hasPlayer && root.activePlayer.canTogglePlaying) ? 1 : 0.3
          font { pixelSize: 15; family: "JetBrainsMono Nerd Font" }
        }
        MouseArea {
          id: playArea
          anchors.fill: parent
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

      // repeat — cicla None → Playlist → Track → None; "1" sobreposto
      // quando está repetindo só a faixa atual
      Item {
        visible: config.showShuffleRepeat
        width: 20; height: 20
        readonly property bool supported: root.hasPlayer && root.activePlayer.loopSupported && root.activePlayer.canControl
        readonly property int state: root.hasPlayer ? root.activePlayer.loopState : MprisLoopState.None

        Text {
          anchors.centerIn: parent
          text: "\uf01e" // fa-repeat
          color: parent.state !== MprisLoopState.None ? Colors[config.colorValue] : Colors[config.colorLabel]
          opacity: parent.supported ? (parent.state !== MprisLoopState.None ? 1 : 0.55) : 0.2
          font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        Text {
          visible: parent.state === MprisLoopState.Track
          text: "1"
          color: Colors[config.colorValue]
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -2
          anchors.bottomMargin: -3
          font { pixelSize: 7; bold: true; family: "Inter" }
        }
        MouseArea {
          anchors.fill: parent
          enabled: parent.supported
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            const s = root.activePlayer.loopState
            if (s === MprisLoopState.None) root.activePlayer.loopState = MprisLoopState.Playlist
            else if (s === MprisLoopState.Playlist) root.activePlayer.loopState = MprisLoopState.Track
            else root.activePlayer.loopState = MprisLoopState.None
          }
        }
      }
    }
  }
}
