import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property bool isHorizontal: true

  // ── Cores ──────────────────────────────────────────────────────────────
  property color textColor:       "white"
  property color textColorActive: "white"               // cor do texto quando tocando
  property color dimColor:        Qt.rgba(1, 1, 1, 0.5)
  property color dimColorActive:  Qt.rgba(1, 1, 1, 0.5) // cor dim quando tocando
  property color accentColor:     "white"

  // ── Configs de scroll (via Bar.json → BarConfig → tema → aqui) ────────
  property bool   showText:      true
  property bool   textStatic:    false   // true = texto fixo (elide), sem carretel
  property string textMode:      "artistAndTitle"
  property int    scrollSpeed:   40
  property int    scrollPauseMs: 1800
  property int    scrollWidth:   140

  // ── Configs da capa do álbum (módulo na barra) ─────────────────────────
  property int artworkSize:   22
  property int artworkRadius: 11   // 11 = metade de 22 (círculo perfeito)

  // ── Posição da barra — necessário para o MediaTooltip saltar do lado certo
  property int barPosition: 2   // 1=top, 2=right(default), 3=bottom, 4=left

  // ── Fundo (independente do Workspaces) ─────────────────────────────────
  property bool  bgEnabled:         false
  property color bgColor:           Qt.rgba(1, 1, 1, 0.08)
  property color bgColorActive:     Qt.rgba(1, 1, 1, 0.08)
  property real  bgOpacity:         0.8
  property real  bgOpacityActive:   1.0
  property real  bgPaddingH:        8
  property real  bgPaddingV:        4

  // ── Seleção de player ──────────────────────────────────────────────────
  property var pinnedPlayer: null

  readonly property var player: {
    var all = Mpris.players.values
    // pinnedPlayer ainda na lista e não é playerctld?
    if (pinnedPlayer) {
      for (var i = 0; i < all.length; i++) {
        if (all[i] === pinnedPlayer) {
          var pe = (all[i].desktopEntry || all[i].identity || "").toLowerCase()
          if (!pe.startsWith("playerctld")) return pinnedPlayer
        }
      }
      // pinnedPlayer saiu da lista — limpa fora do binding
      pinnedPlayer = null
    }
    // primeiro não-playerctld que esteja tocando
    for (var j = 0; j < all.length; j++) {
      var je = (all[j].desktopEntry || all[j].identity || "").toLowerCase()
      if (!je.startsWith("playerctld") && all[j].isPlaying) return all[j]
    }
    // primeiro não-playerctld disponível
    for (var k = 0; k < all.length; k++) {
      var ke = (all[k].desktopEntry || all[k].identity || "").toLowerCase()
      if (!ke.startsWith("playerctld")) return all[k]
    }
    return null
  }

  // Colapsa completamente quando não há player ativo (não ocupa espaço na pill)
  visible:       player !== null
  implicitWidth: player === null ? 0 : (
    isHorizontal
      ? (bgEnabled ? hRow.implicitWidth  + bgPaddingH * 2 : hRow.implicitWidth  + 16)
      : (bgEnabled ? vCol.implicitWidth  + bgPaddingH * 2 : Math.max(vCol.implicitWidth, artworkSize) + 8)
  )
  implicitHeight: player === null ? 0 : (
    isHorizontal
      ? (bgEnabled ? hRow.implicitHeight + bgPaddingV * 2 : hRow.implicitHeight + 8)
      : (bgEnabled ? vCol.implicitHeight + bgPaddingV * 2 : vCol.implicitHeight + 16)
  )

  // ── Estado ativo ───────────────────────────────────────────────────────
  readonly property bool isActive: player !== null && player.isPlaying

  // cores efetivas — bindings simples, a animação fica em cada Text
  readonly property color effectiveTextColor: isActive ? textColorActive : textColor
  readonly property color effectiveDimColor:  isActive ? dimColorActive  : dimColor



  signal clicked()

  onPlayerChanged: if (player === null) MediaTooltip.hide()

  // Referência ao OsdService injetada pelo Bar.qml.
  property var osdService: null

  // ── Hover/tooltip + scroll de volume em todo o módulo ───────────────────
  // Fica embaixo (declarado antes dos Row/Column) para não roubar clique
  // dos botões de play/pause/next, que ficam por cima na pilha de z-order.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton   // só hover + wheel; clique passa pro item de cima
    onEntered: MediaTooltip.show(root, root.player, root.barPosition)
    onExited:  MediaTooltip.hide()
    onWheel: (wheel) => {
      root._adjustVolume(wheel.angleDelta.y > 0 ? root.volumeStep : -root.volumeStep)
      wheel.accepted = true
    }
  }

  // ── Volume via scroll do mouse na capa ──────────────────────────────────
  property real volumeStep: 0.05   // 5% por "clique" de scroll

  function _adjustVolume(delta) {
    if (!player) return
    if (player.volumeSupported === false) return
    var cur = (player.volume !== undefined && player.volume !== null) ? player.volume : 1.0
    var next = Math.max(0.0, Math.min(1.0, cur + delta))
    player.volume = next
    if (osdService) {
      osdService.mediaVolume("\uf001", Math.round(next * 100) + "%", next, player.trackArtUrl)
    }
  }

  function _mediaLabel() {
    if (!player) return ""
    var title  = player.trackTitle  || ""
    var artist = player.trackArtist || ""
    if (artist && title) return artist + " – " + title
    return title || artist
  }

  // ── Fundo pill ─────────────────────────────────────────────────────────
  Rectangle {
    visible:      root.bgEnabled
    anchors.fill: parent
    radius:       Math.min(width, height) / 2
    color:        root.isActive ? root.bgColorActive : root.bgColor
    opacity:      root.isActive ? root.bgOpacityActive : root.bgOpacity
    Behavior on color   { ColorAnimation  { duration: 200 } }
    Behavior on opacity { NumberAnimation { duration: 200 } }
  }

  // ── Texto scroll ───────────────────────────────────────────────────────
  readonly property string scrollText: {
    if (!player) return ""
    var artist = player.trackArtist || ""
    var title  = player.trackTitle  || ""
    var app    = player.identity    || ""
    var album = player.trackAlbum || ""
    switch (textMode) {
      case "artist":     return artist || app || ""
      case "title":      return title  || ""
      case "album":      return album  || title || ""
      case "appOnly":    return app    || ""
      default:           // "artistAndTitle"
        if (artist && title) return artist + "  ·  " + title
        return artist || title || app || ""
    }
  }

  // ── Artwork com fallback em 3 camadas ─────────────────────────────────
  Component {
    id: artworkComp
    Item {
      id: art
      width: root.artworkSize; height: root.artworkSize

      readonly property string appId: root.player
        ? (root.player.identity || "").toLowerCase().replace(/\s+/g, "-") : ""

      readonly property var desktopEntry: {
        var _l = DesktopEntries.applications.values.length
        if (!appId) return null
        return DesktopEntries.byId(appId)
            || DesktopEntries.byId(appId.replace(/-/g, ""))
            || DesktopEntries.heuristicLookup(appId)
            || null
      }

      readonly property string appIconName: {
        if (!desktopEntry) return ""
        var icon = desktopEntry.icon || ""
        if (!icon || icon.startsWith("/")) return icon
        return icon.replace(/-launcher$/, "").replace(/-client$/, "")
      }

      readonly property var appIconPaths: {
        var n = appIconName
        if (!n) return []
        if (n.startsWith("/")) return ["file://" + n]
        var home = Quickshell.env("HOME") || ("/home/" + Quickshell.env("USER"))
        return [
          "file:///usr/share/icons/Papirus/48x48/apps/"    + n + ".svg",
          "file:///usr/share/icons/Papirus/32x32/apps/"    + n + ".svg",
          "file:///usr/share/icons/hicolor/scalable/apps/" + n + ".svg",
          "file:///usr/share/icons/hicolor/256x256/apps/"  + n + ".png",
          "file:///usr/share/icons/hicolor/128x128/apps/"  + n + ".png",
          "file:///usr/share/icons/hicolor/48x48/apps/"    + n + ".png",
          "file:///usr/share/pixmaps/" + n + ".png",
          "file:///usr/share/pixmaps/" + n + ".svg",
          "file://" + home + "/.local/share/icons/hicolor/scalable/apps/" + n + ".svg",
          "file://" + home + "/.local/share/icons/hicolor/48x48/apps/"    + n + ".png",
        ]
      }

      property int  appIconAttempt:   0
      property bool appIconExhausted: false

      readonly property string appIconSource: {
        if (appIconExhausted || appIconPaths.length === 0) return ""
        return appIconPaths[Math.min(appIconAttempt, appIconPaths.length - 1)]
      }

      onAppIconPathsChanged: { appIconAttempt = 0; appIconExhausted = false }

      // camada 1 — capa do álbum
      // ClippingRectangle (Quickshell.Widgets) usa shader próprio para recortar
      // seguindo o radius — Rectangle.clip comum NUNCA respeita radius, só
      // recorta em bounding-box reto (limitação documentada do Qt Quick).
      ClippingRectangle {
        id: artBg
        anchors.fill: parent
        radius: root.artworkRadius
        color:  "transparent"

        Image {
          id: artImg; anchors.fill: parent; fillMode: Image.PreserveAspectCrop
          source: (root.player && root.player.trackArtUrl && root.player.trackArtUrl.length > 0) ? root.player.trackArtUrl : ""
          visible: status === Image.Ready
        }
      }

      // camada 2 — ícone do app
      ClippingRectangle {
        id: artFallbackBg
        anchors.fill: parent; radius: root.artworkRadius
        color:   Qt.rgba(1, 1, 1, 0.08)
        visible: artImg.status !== Image.Ready

        Image {
          id: appIconImg; anchors.centerIn: parent
          width: parent.width * 0.72; height: parent.height * 0.72
          fillMode: Image.PreserveAspectFit
          source:   art.appIconSource
          visible:  !art.appIconExhausted && art.appIconPaths.length > 0
          onStatusChanged: {
            if (status === Image.Error) {
              if (art.appIconAttempt < art.appIconPaths.length - 1) art.appIconAttempt++
              else art.appIconExhausted = true
            }
          }
        }

        // camada 3 — nerd-font
        Text {
          anchors.centerIn: parent
          visible:        art.appIconExhausted || art.appIconPaths.length === 0
          text:           "\uf001"
          color:          root.effectiveDimColor
          font.pixelSize: Math.round(root.artworkSize * 0.55)
          font.family:    "JetBrainsMono Nerd Font"
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.clicked()
            if (mouse.button === Qt.RightButton) root.clicked()
          }
      }
    }
  }

  // ── Scroll horizontal ──────────────────────────────────────────────────
  Component {
    id: hScrollComp
    Item {
      id: hScroll
      width: root.scrollWidth; height: 16; clip: !root.textStatic

      readonly property real overflowW: Math.max(0, hText.implicitWidth - width)
      readonly property bool needsScroll: !root.textStatic && overflowW > 0.5

      function restart() {
        scrollAnim.stop(); resetTimer.stop(); pauseTimer.stop()
        hText.x = 0
        if (needsScroll) pauseTimer.start()
      }

      Timer   { id: pauseTimer;  interval: root.scrollPauseMs; repeat: false; onTriggered: scrollAnim.start() }
      NumberAnimation {
        id: scrollAnim; target: hText; property: "x"
        from: 0; to: -hScroll.overflowW
        duration: hScroll.overflowW * root.scrollSpeed
        easing.type: Easing.Linear; onFinished: resetTimer.start()
      }
      Timer { id: resetTimer; interval: 600; repeat: false
        onTriggered: { hText.x = 0; pauseTimer.start() } }

      Text {
        id: hText
        font.pixelSize: 12
        text: root.scrollText
        x: 0
        width:  root.textStatic ? hScroll.width : implicitWidth
        elide:  root.textStatic ? Text.ElideRight : Text.ElideNone
        color: root.effectiveTextColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      onNeedsScrollChanged: hScroll.restart()
      Connections {
        target: root
        function onScrollTextChanged()  { hScroll.restart() }
        function onScrollWidthChanged() { hScroll.restart() }
        function onTextStaticChanged()  { hScroll.restart() }
      }
      Component.onCompleted: hScroll.restart()
      MouseArea { anchors.fill: parent; onClicked: root.clicked() }
    }
  }

  // ── HORIZONTAL ─────────────────────────────────────────────────────────
  Row {
    id: hRow
    visible:          root.isHorizontal
    anchors.centerIn: parent
    spacing: 8

    Loader { anchors.verticalCenter: parent.verticalCenter; sourceComponent: artworkComp }
    Loader { visible: root.showText; anchors.verticalCenter: parent.verticalCenter; sourceComponent: root.showText ? hScrollComp : null }

    // play/pause
    Item {
      width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
      Text {
        anchors.centerIn: parent
        text:           root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
        color: root.effectiveTextColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      MouseArea { anchors.fill: parent; onClicked: {
        if (!root.player) return
        var wasPlaying = root.player.isPlaying
        root.player.togglePlaying()
        if (root.osdService) root.osdService.media(wasPlaying ? "\uf04c" : "\uf04b", root._mediaLabel())
      } }
    }

    // next
    Item {
      width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
      Text {
        anchors.centerIn: parent; text: "\uf051"   // nf-fa-step_forward
        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
        color: root.player && root.player.canGoNext ? root.effectiveTextColor : root.effectiveDimColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      MouseArea { anchors.fill: parent; onClicked: {
        if (!root.player) return
        root.player.next()
        if (root.osdService) Qt.callLater(function() { root.osdService.media("\uf051", root._mediaLabel()) })
      } }
    }
  }

  // ── VERTICAL ───────────────────────────────────────────────────────────
  Column {
    id: vCol
    visible:          !root.isHorizontal
    anchors.centerIn: parent
    spacing: 6

    Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: artworkComp }

    Item {
      id: vScroll; width: Math.max(22, root.artworkSize); height: root.showText ? (root.textStatic ? Math.min(vText.implicitHeight, 80) : 80) : 0; clip: true
      visible: root.showText
      anchors.horizontalCenter: parent.horizontalCenter

      readonly property real overflowH: Math.max(0, vText.implicitHeight - height)
      readonly property bool needsScroll: !root.textStatic && overflowH > 0.5

      function restart() {
        vScrollAnim.stop(); vResetTimer.stop(); vPauseTimer.stop()
        vText.y = 0
        if (needsScroll) vPauseTimer.start()
      }

      Timer   { id: vPauseTimer;  interval: root.scrollPauseMs; repeat: false; onTriggered: vScrollAnim.start() }
      NumberAnimation {
        id: vScrollAnim; target: vText; property: "y"
        from: 0; to: -vScroll.overflowH
        duration: vScroll.overflowH * root.scrollSpeed
        easing.type: Easing.Linear; onFinished: vResetTimer.start()
      }
      Timer { id: vResetTimer; interval: 600; repeat: false
        onTriggered: { vText.y = 0; vPauseTimer.start() } }

      Text {
        id: vText; anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: 11; lineHeight: 1.15
        horizontalAlignment: Text.AlignHCenter
        text: root.scrollText.split("").join("\n"); y: 0
        color: root.effectiveTextColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      onNeedsScrollChanged: vScroll.restart()
      Connections {
        target: root
        function onScrollTextChanged() { vScroll.restart() }
        function onTextStaticChanged() { vScroll.restart() }
      }
      Component.onCompleted: vScroll.restart()
      MouseArea { anchors.fill: parent; onClicked: root.clicked() }
    }

    // play/pause
    Item {
      width: 18; height: 18; anchors.horizontalCenter: parent.horizontalCenter
      Text {
        anchors.centerIn: parent
        text:           root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
        color: root.effectiveTextColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      MouseArea { anchors.fill: parent; onClicked: {
        if (!root.player) return
        var wasPlaying = root.player.isPlaying
        root.player.togglePlaying()
        if (root.osdService) root.osdService.media(wasPlaying ? "\uf04c" : "\uf04b", root._mediaLabel())
      } }
    }

    // next
    Item {
      width: 18; height: 18; anchors.horizontalCenter: parent.horizontalCenter
      Text {
        anchors.centerIn: parent; text: "\uf051"   // nf-fa-step_forward
        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
        color: root.player && root.player.canGoNext ? root.effectiveTextColor : root.effectiveDimColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      MouseArea { anchors.fill: parent; onClicked: {
        if (!root.player) return
        root.player.next()
        if (root.osdService) Qt.callLater(function() { root.osdService.media("\uf051", root._mediaLabel()) })
      } }
    }
  }
}
