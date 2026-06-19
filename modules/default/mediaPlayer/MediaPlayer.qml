import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
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
  // pinnedPlayer (clique manual) só vence quando NENHUM player está
  // tocando — se algo começa a tocar (mesmo outro app), a prioridade
  // configurada assume e o pin é ignorado (mas não é limpo: volta a
  // valer se tudo parar de tocar de novo).
  property var pinnedPlayer: null

  // Prioridade de players — usada tanto para decidir entre vários tocando
  // ao mesmo tempo quanto, na ausência de qualquer um tocando, para
  // escolher entre os disponíveis. String separada por vírgula, em ordem
  // de preferência. Cada item é tratado como REGEX (case-insensitive),
  // testado contra desktopEntry/identity — necessário porque instâncias
  // MPRIS reais vêm com sufixos variáveis, ex: "vivaldi.instance2898207"
  // (Vivaldi com várias abas/janelas) ou "brave.instance2". Um item
  // simples como "vivaldi" já funciona como regex parcial (match em
  // qualquer parte da string); para casar só o início, use "^vivaldi".
  // Configurável em Config > Mídia > Prioridade de players.
  property string playerPriority: "spotify,ncspot,vivaldi,brave"

  function _priorityList() {
    return playerPriority.split(",")
      .map(function(s) { return s.trim() })
      .filter(function(s) { return s.length > 0 })
  }

  function _playerName(p) {
    return ((p.desktopEntry || p.identity || "") + "").toLowerCase()
  }

  function _isPlayerctld(p) {
    return _playerName(p).startsWith("playerctld")
  }

  // Retorna o índice de prioridade (menor = mais prioritário) do player,
  // ou Infinity se nenhum padrão da lista casar — assim players fora da
  // lista sempre ficam depois dos que estão, mas ainda participam do
  // fallback (primeiro tocando / primeiro disponível, na ordem natural).
  // Regex inválida na lista é ignorada silenciosamente (try/catch),
  // pra um erro de digitação na config não travar o módulo inteiro.
  function _priorityRank(p) {
    var name = _playerName(p)
    var list = _priorityList()
    for (var i = 0; i < list.length; i++) {
      try {
        var re = new RegExp(list[i], "i")
        if (re.test(name)) return i
      } catch (e) {
        // padrão regex inválido — ignora essa entrada
      }
    }
    return Infinity
  }

  // Escolhe o de maior prioridade (menor rank) dentro de uma lista de
  // players; em empate de rank, mantém a ordem natural recebida.
  function _pickByPriority(list) {
    if (list.length === 0) return null
    var best = list[0]
    var bestRank = _priorityRank(best)
    for (var i = 1; i < list.length; i++) {
      var rank = _priorityRank(list[i])
      if (rank < bestRank) { best = list[i]; bestRank = rank }
    }
    return best
  }

  readonly property var player: {
    var all = Mpris.players.values
    var candidates = []
    for (var j = 0; j < all.length; j++) {
      if (!_isPlayerctld(all[j])) candidates.push(all[j])
    }

    var playing = candidates.filter(function(p) { return p.isPlaying })

    // 1) Algo tocando → prioridade decide (mesmo com 1 só tocando, já
    //    cobre o caso "1 player ativo aparece" — rank é só usado como
    //    critério de desempate quando há 2+).
    if (playing.length > 0) {
      return _pickByPriority(playing)
    }

    // 2) Nada tocando → pin manual vence, se ainda existir na lista.
    if (pinnedPlayer) {
      for (var i = 0; i < all.length; i++) {
        if (all[i] === pinnedPlayer && !_isPlayerctld(all[i])) return pinnedPlayer
      }
      // pinnedPlayer saiu da lista de players — limpa fora do binding
      pinnedPlayer = null
    }

    // 3) Nada tocando e sem pin → prioridade decide entre os disponíveis.
    return _pickByPriority(candidates)
  }

  // ── Idle inhibitor — impede o sistema de dormir/bloquear enquanto QUALQUER
  // player MPRIS (não só o ativo/exibido) estiver tocando. Mais seguro: você
  // não quer a tela travando enquanto um podcast toca em segundo plano numa
  // aba que não é a exibida na barra.
  readonly property bool anyPlaying: {
    var all = Mpris.players.values
    for (var i = 0; i < all.length; i++) {
      if (!_isPlayerctld(all[i]) && all[i].isPlaying) return true
    }
    return false
  }

  // Toggle de config — permite desligar o idle inhibitor mesmo com mídia tocando.
  property bool idleInhibit: true

  IdleInhibitor {
    window:  root.QsWindow.window
    enabled: root.idleInhibit && root.anyPlaying
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

  // ── Volume via scroll do mouse na capa ──────────────────────────────────
  property real volumeStep: 0.05   // 5% por "clique" de scroll

  function _adjustVolume(delta) {
    if (!player) return
    if (player.volumeSupported === false) return
    var cur = (player.volume !== undefined && player.volume !== null) ? player.volume : 1.0
    var next = Math.max(0.0, Math.min(1.0, cur + delta))
    player.volume = next
    if (osdService) {
      var appName = player.identity || ""
      var label   = appName ? (appName + " — " + Math.round(next * 100) + "%") : (Math.round(next * 100) + "%")
      osdService.media("\uf028", label)
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
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.clicked()
            if (mouse.button === Qt.RightButton) root.clicked()
          }
          onEntered: MediaTooltip.show(art, root.player, root.barPosition)
          onExited:  MediaTooltip.hide()
          onWheel: (wheel) => {
            root._adjustVolume(wheel.angleDelta.y > 0 ? root.volumeStep : -root.volumeStep)
            wheel.accepted = true
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
