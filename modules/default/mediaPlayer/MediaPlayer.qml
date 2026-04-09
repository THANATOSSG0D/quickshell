import Quickshell
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
  property string textMode:      "artistAndTitle"
  property int    scrollSpeed:   40
  property int    scrollPauseMs: 1800
  property int    scrollWidth:   140

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
    if (pinnedPlayer) {
      for (var i = 0; i < Mpris.players.values.length; i++) {
        if (Mpris.players.values[i] === pinnedPlayer) return pinnedPlayer
      }
      Qt.callLater(function() { root.pinnedPlayer = null })
    }
    for (var j = 0; j < Mpris.players.values.length; j++) {
      if (Mpris.players.values[j].isPlaying) return Mpris.players.values[j]
    }
    return Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
  }

  visible: player !== null

  // ── Estado ativo ───────────────────────────────────────────────────────
  readonly property bool isActive: player !== null && player.isPlaying

  // cores efetivas — bindings simples, a animação fica em cada Text
  readonly property color effectiveTextColor: isActive ? textColorActive : textColor
  readonly property color effectiveDimColor:  isActive ? dimColorActive  : dimColor

  implicitWidth:  player === null ? 0 : (isHorizontal
    ? (bgEnabled ? hRow.implicitWidth  + bgPaddingH * 2 : hRow.implicitWidth  + 16)
    : 30)
  implicitHeight: player === null ? 0 : (isHorizontal
    ? (bgEnabled ? hRow.implicitHeight + bgPaddingV * 2 : hRow.implicitHeight + 8)
    : vCol.implicitHeight + 16)

  signal clicked()

  // Referência ao OsdService injetada pelo Bar.qml.
  property var osdService: null

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
    switch (textMode) {
      case "artistOnly": return artist || app || ""
      case "titleOnly":  return title  || ""
      case "appOnly":    return app    || ""
      default:
        if (artist && title) return artist + "  ·  " + title
        return artist || title || app || ""
    }
  }

  // ── Artwork com fallback em 3 camadas ─────────────────────────────────
  Component {
    id: artworkComp
    Item {
      id: art
      width: 22; height: 22

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
      Rectangle {
        anchors.fill: parent; radius: width / 2; clip: true; color: "transparent"
        Image {
          id: artImg; anchors.fill: parent; fillMode: Image.PreserveAspectCrop
          source:  (root.player && root.player.trackArtUrl && root.player.trackArtUrl.length > 0) ? root.player.trackArtUrl : ""
          visible: status === Image.Ready
        }
      }

      // camada 2 — ícone do app
      Rectangle {
        anchors.fill: parent; radius: width / 2; clip: true
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
          font.pixelSize: 12
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
      width: root.scrollWidth; height: 16; clip: true

      readonly property real overflowW: Math.max(0, hText.implicitWidth - width)
      readonly property bool needsScroll: overflowW > 0.5

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
        color: root.effectiveTextColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      onNeedsScrollChanged: hScroll.restart()
      Connections {
        target: root
        function onScrollTextChanged()  { hScroll.restart() }
        function onScrollWidthChanged() { hScroll.restart() }
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

    Loader { sourceComponent: artworkComp }
    Loader { anchors.verticalCenter: parent.verticalCenter; sourceComponent: hScrollComp }

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
      id: vScroll; width: 22; height: 80; clip: true
      anchors.horizontalCenter: parent.horizontalCenter

      readonly property real overflowH: Math.max(0, vText.implicitHeight - height)
      readonly property bool needsScroll: overflowH > 0.5

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
      Connections { target: root; function onScrollTextChanged() { vScroll.restart() } }
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
