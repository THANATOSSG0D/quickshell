import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: panel

  required property var barScreen
  required property int barPosition
  required property int barSize
  required property int barMargin
  required property int panelWidth

  // referência ao MediaPlayer da barra para pinnar o player selecionado
  property var barMediaPlayer: null

  screen:        barScreen
  color:         "transparent"
  exclusionMode: ExclusionMode.Ignore

  // ── Cores injetadas pelo Bar.qml ───────────────────────────────────────
  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorProgressBg: "#474747"
  property color colorProgressFg: "#ffb4a9"
  property color colorAccent:     "#ffb4a9"

  // ── Geometria ──────────────────────────────────────────────────────────
  readonly property bool barIsHorizontal: barPosition === 1 || barPosition === 3
  readonly property int panelH: barIsHorizontal ? 420        : panelWidth
  readonly property int panelW: barIsHorizontal ? panelWidth : 280

  // ancora apenas no lado da barra + perpendiculares; lado oposto livre (para implicitSize)
  // 1=top: ancora top+left+right, bottom livre
  // 2=right: ancora right+top+bottom, left livre
  // 3=bottom: ancora bottom+left+right, top livre
  // 4=left: ancora left+top+bottom, right livre
  anchors.top:    barPosition === 1 || barPosition === 2 || barPosition === 4
  anchors.bottom: barPosition === 3 || barPosition === 2 || barPosition === 4
  anchors.left:   barPosition === 4 || barPosition === 1 || barPosition === 3
  anchors.right:  barPosition === 2 || barPosition === 1 || barPosition === 3

  // tamanho perpendicular à barra é definido pelo implicit;
  // tamanho paralelo é definido pelos anchors (preenche até sidePad)
  implicitWidth:  barIsHorizontal ? 1 : panelW   // vertical: width fixo; horizontal: anchors definem
  implicitHeight: barIsHorizontal ? panelH : 1   // horizontal: height fixo; vertical: anchors definem

  property int sidePad: barIsHorizontal
    ? Math.max(0, Math.floor((barScreen.width  - panelWidth) / 2))
    : Math.max(0, Math.floor((barScreen.height - panelWidth) / 2))

  property bool panelOpen: false
  property real slideProgress: 0.0
  visible: slideProgress > 0.0

  // Fecha ao perder foco — clique fora ou Esc
  signal closeRequested()

  HyprlandFocusGrab {
    id: panelFocusGrab
    windows: [ panel ]
    active:  panel.panelOpen
    onCleared: panel.closeRequested()
  }

  Behavior on slideProgress {
    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  // lado da barra: offset = barMargin + barSize (painel começa após a barra)
  // lados perpendiculares: sidePad (centraliza o painel)
  // lado oposto à barra: 0 (não ancora, então margin não importa)
  margins.top:    barPosition === 1 ? barMargin + barSize : sidePad
  margins.bottom: barPosition === 3 ? barMargin + barSize : sidePad
  margins.left:   barPosition === 4 ? barMargin + barSize : sidePad
  margins.right:  barPosition === 2 ? barMargin + barSize : sidePad

  // ── Player ativo (syncado com barMediaPlayer.player + permite pin local) ─
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
    running:  panel.visible && panel.activePlayer !== null &&
              panel.activePlayer.playbackState === MprisPlaybackState.Playing
    onTriggered: if (panel.activePlayer) panel.activePlayer.positionChanged()
  }

  // ── Conteúdo ───────────────────────────────────────────────────────────
  Item {
    id: clipContainer
    clip:    true
    opacity: Math.min(1.0, panel.slideProgress * 2)

    // ancora APENAS no lado da barra — o lado oposto é livre para animação
    // width/height * slideProgress cresce para dentro do monitor
    anchors.top:    barPosition === 1 ? parent.top    : undefined
    anchors.bottom: barPosition === 3 ? parent.bottom : undefined
    anchors.left:   barPosition === 4 ? parent.left   : undefined
    anchors.right:  barPosition === 2 ? parent.right  : undefined

    // dimensão paralela à barra: preenche o parent (definido pelos sidePad)
    // dimensão perpendicular: anima de 0 → tamanho total
    anchors.fill: (barPosition === 1 || barPosition === 3 || barPosition === 2 || barPosition === 4) ? undefined : parent
    width: {
      if (barPosition === 2 || barPosition === 4) return parent.width * panel.slideProgress
      return parent.width
    }
    height: {
      if (barPosition === 1 || barPosition === 3) return parent.height * panel.slideProgress
      return parent.height
    }

    // fundo com radius
    Rectangle {
      anchors.fill: parent; radius: 12
      color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g, panel.colorPanelBg.b, 0.95)
    }
    // cobre o radius no lado que toca a barra (faz cantos retos nesse lado)
    Rectangle {
      color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g, panel.colorPanelBg.b, 0.95)

      // faixa no lado da barra, com 12px de profundidade (cobre o radius)
      anchors.top:    barPosition === 1 ? parent.top    : barIsHorizontal ? parent.top    : undefined
      anchors.bottom: barPosition === 3 ? parent.bottom : barIsHorizontal ? parent.bottom : undefined
      anchors.left:   barPosition === 4 ? parent.left   : !barIsHorizontal ? parent.left  : undefined
      anchors.right:  barPosition === 2 ? parent.right  : !barIsHorizontal ? parent.right : undefined

      // dimensão paralela à barra: cobre toda a extensão
      // dimensão perpendicular: apenas 12px (suficiente para cobrir o radius)
      width:  barPosition === 2 || barPosition === 4 ? 12          : parent.width
      height: barPosition === 1 || barPosition === 3 ? 12          : parent.height
    }

    ColumnLayout {
      anchors.fill:    parent
      anchors.margins: 14
      spacing: 10

      // ── Seletor de player ──────────────────────────────────────────────
      // Só aparece quando há mais de 1 player real conectado
      RowLayout {
        Layout.fillWidth: true
        visible: panel.realPlayerCount > 1
        spacing: 6

        Repeater {
          // Model nativo do Mpris: reatividade automática e identidade de objeto
          // preservada — isActive (===) só funciona com o objeto original.
          model: Mpris.players.values

          Rectangle {
            required property var modelData
            // playerctld é proxy — oculta visualmente, não remove do model
            visible: !(modelData.desktopEntry || modelData.identity || "").toLowerCase().startsWith("playerctld")
            property bool isActive: panel.activePlayer === modelData

            Layout.preferredHeight: 24
            Layout.preferredWidth:  playerLabel.implicitWidth + 16
            radius: height / 2
            color:  isActive
              ? Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.25)
              : Qt.rgba(1, 1, 1, 0.06)
            border.color: isActive ? panel.colorAccent : "transparent"
            border.width: 1

            Text {
              id: playerLabel
              anchors.centerIn: parent
              text:           modelData.identity || "Player"
              color:          isActive ? panel.colorAccent : panel.colorTextDim
              font.pixelSize: 10
              font.weight:    isActive ? Font.Medium : Font.Normal
              elide:          Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (panel.barMediaPlayer)
                  panel.barMediaPlayer.pinnedPlayer = isActive ? null : modelData
              }
            }
          }
        }

        Item { Layout.fillWidth: true }
      }

      // ── Artwork ────────────────────────────────────────────────────────
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
            source:       panel.activePlayer ? panel.activePlayer.trackArtUrl : ""
            fillMode:     Image.PreserveAspectCrop
            visible:      status === Image.Ready
          }

          // fallback: ícone nerd-font quando sem artwork
          Text {
            anchors.centerIn: parent
            visible:        panelArtImg.status !== Image.Ready
            text:           "\uf001"
            color:          panel.colorTextDim
            font.pixelSize: 48
            font.family:    "JetBrainsMono Nerd Font"
          }
        }
      }

      // ── Título e artista ───────────────────────────────────────────────
      Text {
        Layout.fillWidth:    true
        text:                panel.activePlayer ? (panel.activePlayer.trackTitle || "") : ""
        color:               panel.colorText
        font.pixelSize:      13
        font.weight:         Font.Medium
        elide:               Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        Layout.fillWidth:    true
        text:                panel.activePlayer ? (panel.activePlayer.trackArtist || panel.activePlayer.identity || "") : ""
        color:               panel.colorTextDim
        font.pixelSize:      11
        elide:               Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      // ── Barra de progresso clicável ────────────────────────────────────
      Item {
        Layout.fillWidth:       true
        Layout.preferredHeight: 18   // área de toque maior que a barra visual

        // trilha
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: 4; radius: 2
          color: Qt.rgba(panel.colorProgressBg.r, panel.colorProgressBg.g, panel.colorProgressBg.b, 0.5)
        }

        // preenchimento
        Rectangle {
          id: progressFill
          anchors.verticalCenter: parent.verticalCenter
          height: 4; radius: 2
          color: panel.colorProgressFg
          width: {
            var p = panel.activePlayer
            if (!p || !p.lengthSupported || p.length <= 0) return 0
            return Math.max(0, Math.min(1, p.position / p.length)) * parent.width
          }
        }

        // thumb (bolinha) — aparece no hover
        Rectangle {
          id: progressThumb
          anchors.verticalCenter: parent.verticalCenter
          x: Math.max(0, Math.min(progressFill.width - width / 2, progressFill.width - width / 2))
          width: 12; height: 12; radius: 6
          color: panel.colorProgressFg
          visible: progressArea.containsMouse
          scale:   progressArea.pressed ? 0.85 : 1.0
          Behavior on scale { NumberAnimation { duration: 80 } }
        }

        MouseArea {
          id: progressArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: panel.activePlayer && panel.activePlayer.canSeek && panel.activePlayer.lengthSupported

          onClicked: function(mouse) {
            var p = panel.activePlayer
            if (!p || !p.canSeek || !p.lengthSupported || p.length <= 0) return
            var ratio    = Math.max(0, Math.min(1, mouse.x / width))
            var targetMs = ratio * p.length * 1000
            // seek recebe offset em ms a partir da posição atual
            var currentMs = p.position * 1000
            p.seek(targetMs - currentMs)
          }
        }
      }

      // ── Tempos ────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true

        Text {
          text:           panel.activePlayer ? formatTime(panel.activePlayer.position) : "0:00"
          color:          panel.colorTextDim
          font.pixelSize: 10
        }
        Item { Layout.fillWidth: true }
        Text {
          text: {
            var p = panel.activePlayer
            if (!p) return "0:00"
            if (!p.lengthSupported) return "–:––"
            return formatTime(p.length)
          }
          color:          panel.colorTextDim
          font.pixelSize: 10
        }
      }

      // ── Controles principais ───────────────────────────────────────────
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 4

        // Shuffle
        Item {
          width: 32; height: 32
          opacity: panel.activePlayer && panel.activePlayer.shuffleSupported ? 1.0 : 0.3
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: panel.activePlayer && panel.activePlayer.shuffleSupported && panel.activePlayer.shuffle
              ? Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.2)
              : "transparent"
          }
          Text {
            anchors.centerIn: parent
            text:           "\uf074"   // nf-fa-random (setas cruzadas = shuffle)
            color:          panel.activePlayer && panel.activePlayer.shuffle
                              ? panel.colorAccent : panel.colorTextDim
            font.pixelSize: 14
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea {
            anchors.fill: parent
            enabled: panel.activePlayer && panel.activePlayer.shuffleSupported
            onClicked: panel.activePlayer.shuffle = !panel.activePlayer.shuffle
          }
        }

        // Anterior
        Item {
          width: 32; height: 32
          opacity: panel.activePlayer && panel.activePlayer.canGoPrevious ? 1.0 : 0.35
          Text {
            anchors.centerIn: parent; text: "\uf048"   // nf-fa-step-backward
            color: panel.colorText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
          }
          MouseArea { anchors.fill: parent; onClicked: if (panel.activePlayer) panel.activePlayer.previous() }
        }

        // Play/Pause
        Item {
          width: 44; height: 44
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: panel.colorAccent
            opacity: playPauseArea.pressed ? 0.7 : 1.0
            Behavior on opacity { NumberAnimation { duration: 80 } }
          }
          Text {
            anchors.centerIn: parent
            text:           panel.activePlayer && panel.activePlayer.isPlaying ? "\uf04c" : "\uf04b"
            color:          panel.colorPanelBg
            font.pixelSize: 18
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea {
            id: playPauseArea
            anchors.fill: parent
            onClicked: if (panel.activePlayer) panel.activePlayer.togglePlaying()
          }
        }

        // Próximo
        Item {
          width: 32; height: 32
          opacity: panel.activePlayer && panel.activePlayer.canGoNext ? 1.0 : 0.35
          Text {
            anchors.centerIn: parent; text: "\uf051"   // nf-fa-step-forward
            color: panel.colorText; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
          }
          MouseArea { anchors.fill: parent; onClicked: if (panel.activePlayer) panel.activePlayer.next() }
        }

        // Loop
        Item {
          width: 32; height: 32
          opacity: panel.activePlayer && panel.activePlayer.loopSupported ? 1.0 : 0.3

          readonly property int loopState: panel.activePlayer && panel.activePlayer.loopSupported
            ? panel.activePlayer.loopState : MprisLoopState.None

          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: parent.loopState !== MprisLoopState.None
              ? Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.2)
              : "transparent"
          }
          Text {
            anchors.centerIn: parent
            // nf-md-repeat ou nf-md-repeat-once
            text:           parent.loopState === MprisLoopState.Track
                              ? "\uf01e"   // nf-fa-repeat (seta circular = loop track)
                              : "\uf021"   // nf-fa-refresh (setas = loop all)
            color:          parent.loopState !== MprisLoopState.None
                              ? panel.colorAccent : panel.colorTextDim
            font.pixelSize: 14
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea {
            anchors.fill: parent
            enabled: panel.activePlayer && panel.activePlayer.loopSupported
            onClicked: {
              var p = panel.activePlayer
              if (!p) return
              // cicla: None → Playlist → Track → None
              if (p.loopState === MprisLoopState.None)      p.loopState = MprisLoopState.Playlist
              else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track
              else                                              p.loopState = MprisLoopState.None
            }
          }
        }
      }

      // ── Volume ─────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // ícone de volume — apenas \uf026 e \uf028 (FA BMP garantidos)
        // opacity indica o nível sem depender de glyphs extras
        Text {
          text:    (!panel.activePlayer || panel.activePlayer.volume <= 0)
                     ? "\uf026" : "\uf028"
          opacity: {
            var p = panel.activePlayer
            if (!p || p.volume <= 0) return 1.0
            if (p.volume < 0.34)     return 0.45
            if (p.volume < 0.67)     return 0.72
            return 1.0
          }
          color:          panel.colorTextDim
          font.pixelSize: 13
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // trilha de volume clicável
        Item {
          Layout.fillWidth:       true
          Layout.preferredHeight: 18

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 3; radius: 2
            color: Qt.rgba(panel.colorProgressBg.r, panel.colorProgressBg.g, panel.colorProgressBg.b, 0.5)
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 3; radius: 2; color: panel.colorAccent
            width: {
              var p = panel.activePlayer
              return p ? Math.max(0, Math.min(1, p.volume)) * parent.width : 0
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: panel.activePlayer !== null

            onClicked: function(mouse) {
              if (!panel.activePlayer) return
              panel.activePlayer.volume = Math.max(0, Math.min(1, mouse.x / width))
            }
            onPositionChanged: function(mouse) {
              if (!pressed || !panel.activePlayer) return
              panel.activePlayer.volume = Math.max(0, Math.min(1, mouse.x / width))
            }
          }
        }

        // percentual
        Text {
          text: {
            var p = panel.activePlayer
            return p ? Math.round(p.volume * 100) + "%" : "–"
          }
          color:          panel.colorTextDim
          font.pixelSize: 10
          Layout.preferredWidth: 30
          horizontalAlignment: Text.AlignRight
        }
      }

    } // ColumnLayout
  } // clipContainer

  function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00"
    var m = Math.floor(seconds / 60)
    var s = Math.floor(seconds % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }
}
