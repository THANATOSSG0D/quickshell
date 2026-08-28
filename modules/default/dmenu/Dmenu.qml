import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

// ── Dmenu ──────────────────────────────────────────────────────────────────
// Widget da barra. Botão que abre o dmenu (launcher) ao clique esquerdo.
//
// displayMode:
//   "title"      → título da janela focada, com carretel (scroll) opcional
//                  — mesmo padrão de scroll/font do MediaPlayer.qml
//   "icon"       → glifo fixo escolhido pelo usuário (iconGlyph)
//   "windowIcon" → ícone do APP da janela focada (Hyprland.activeToplevel.appId
//                  → DesktopEntries → fallback de caminhos de tema de ícone
//                  → glifo Nerd Font se nada for achado) — mesmo fallback em
//                  camadas do artworkComp do MediaPlayer.qml, sem a camada de
//                  capa de álbum (não existe equivalente aqui).
//
// Espaço FIXO: assim como o MediaPlayer.qml (que reserva scrollWidth/
// artworkSize sempre, título curto ou longo), implicitWidth/Height aqui são
// calculados só a partir de config (titleMaxWidth/windowIconSize/glifo via
// FontMetrics) — nunca a partir do tamanho dos Loaders internos. Isso evita
// qualquer "pulo" de layout no resto da barra, inclusive no primeiro frame
// em que um Loader ainda não terminou de instanciar seu item.
//
// Sem janela ativa (área de trabalho vazia) → mostra emptyText, sempre.
// Vertical: espaço é curto demais pro título — mostra sempre o ícone
// (windowIcon se configurado, senão o glifo fixo).
//
// Tooltip (hover): classe/tags/tipo de conteúdo/pid via DmenuTooltip.qml
// (singleton próprio, vizinho deste arquivo — mesmo padrão do
// MediaTooltip.qml, não o BarTooltip genérico de uma linha)
//
// Indicador de workspace (opcional, showWorkspace): um selo com o
// número/ícone da workspace da janela focada, antes ou depois do
// conteúdo principal — igual ao que dá pra fazer no módulo "window" do
// waybar combinando com um indicador de workspace ao lado. workspaceFormat
// escolhe número/ícone/os dois; workspaceIconMap customiza o glifo por
// workspace ("1:,2:,default:").
//
// Clique esquerdo → panelRequested() — o tema (Dock.qml etc.) conecta isso
// a um sinal próprio (dmenuRequested()) que o Bar.qml escuta e usa pra
// chamar DmenuIpc.openNative(openMode). openNative() JÁ é toggle (fecha se
// clicado de novo no mesmo modo com o painel aberto) e a navegação com
// Backspace já é herdada de graça do MESMO DmenuPanel usado pelo atalho de
// teclado — nada disso precisa de código extra aqui.
//
// Clique direito → menu de contexto da janela focada: fechar, ou mover
// para outra workspace.

Item {
  id: root

  property bool isHorizontal: true
  property int  barPosition:  2

  property color textColor:   "white"
  property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
  property color accentColor: "white"

  property string displayMode:   "title"   // "title" | "icon" | "windowIcon"
  property string iconGlyph:     "\uf00a"  // glifo Nerd Font — trocável pelo usuário
  property string emptyText:     "Desktop"
  property int    titleMaxWidth: 180
  property real   fontScale:     1.0

  // ── Scroll/carretel do título — mesmo padrão do MediaPlayer.qml ────────
  property bool textStatic:    false   // true = elide, sem carretel
  property int  scrollSpeed:   40
  property int  scrollPauseMs: 1800

  // ── Ícone da janela (displayMode: "windowIcon") ─────────────────────────
  property int windowIconSize: 18

  // ── Indicador de workspace (opcional) — igual ao "window#waybar.class"
  // do waybar: um selo com o número/ícone da workspace da janela focada,
  // antes ou depois do conteúdo principal. ─────────────────────────────
  property bool   showWorkspace:      false
  property string workspacePosition:  "before"  // "before" | "after"
  property string workspaceFormat:    "number"  // "number" | "icon" | "both"
  property int    workspaceChipWidth: 20
  // Mapa de glifo por workspace, no formato "1:,2:,www:,default:"
  // (id ou nome : glifo, separados por vírgula). "default" é usado quando
  // a workspace atual não tem entrada própria.
  property string workspaceIconMap:   ""

  signal panelRequested()

  // ── Janela ativa (reativo — Quickshell atualiza via evento do socket2) ──
  readonly property var    _activeToplevel: Hyprland.activeToplevel
  readonly property string _windowTitle:    _activeToplevel && _activeToplevel.title ? _activeToplevel.title : ""
  readonly property string _windowAppId:    _activeToplevel && _activeToplevel.appId ? _activeToplevel.appId : ""
  readonly property bool   _hasWindow:      root._activeToplevel !== null

  // ══════════════════════════════════════════════════════════════════════
  // TAMANHO — sempre fixo, calculado só a partir de config (FontMetrics
  // pro glifo, nunca lido de Loader/Row/Text já montados)
  // ══════════════════════════════════════════════════════════════════════
  FontMetrics {
    id: glyphMetrics
    font.family:    "JetBrainsMono Nerd Font"
    font.pixelSize: Math.round(13 * root.fontScale)
  }
  readonly property real _iconGlyphW: Math.ceil(glyphMetrics.advanceWidth(root.iconGlyph || " "))

  readonly property real _contentW: root.displayMode === "windowIcon" ? root.windowIconSize
                                   : root.displayMode === "icon"       ? root._iconGlyphW
                                   :                                     root.titleMaxWidth
  readonly property real _contentH: Math.round(16 * root.fontScale)
  readonly property real _wsChipW:  root.showWorkspace ? (root.workspaceChipWidth + 6) : 0

  implicitWidth:  isHorizontal ? root._contentW + root._wsChipW + 16
                                : Math.max(root.windowIconSize, root._iconGlyphW) + 8
  implicitHeight: isHorizontal ? root._contentH + 8
                                : Math.max(root.windowIconSize, root._contentH) + 16

  // ══════════════════════════════════════════════════════════════════════
  // TOOLTIP — classe / tags / tipo de conteúdo / pid
  // ══════════════════════════════════════════════════════════════════════
  // pid/tags/xwayland não existem no Toplevel genérico (só title/appId) —
  // busca via "hyprctl activewindow -j" (mesmo padrão de Process +
  // StdioCollector que o DmenuContent.qml já usa pra consultas do
  // Hyprland), disparado só no hover, não a cada troca de janela.
  property var _winInfo:  ({})
  property bool _hovering: false

  Process {
    id: activeWinProc
    running: false
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var obj = JSON.parse(this.text)
          root._winInfo = (obj && typeof obj === "object") ? obj : {}
        } catch (e) {
          root._winInfo = {}
        }
        // atualiza o texto já visível, sem reiniciar o delay de 500ms do
        // show() — só se o mouse ainda estiver sobre o widget.
        if (root._hovering) DmenuTooltip.update(root, root, root.barPosition)
      }
    }
  }

  function _refreshWindowInfo() {
    if (!activeWinProc.running) activeWinProc.running = true
  }

  // Chip de workspace precisa ficar sempre atualizado (não só no hover,
  // como o tooltip) — reusa a mesma resposta do hyprctl.
  Component.onCompleted: root._refreshWindowInfo()
  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root._refreshWindowInfo() }
  }

  // ── Workspace — parse do mapa "id:glifo,id:glifo,default:glifo" ────────
  function _parseWorkspaceIconMap(mapStr) {
    var out = {}
    if (!mapStr) return out
    var pairs = mapStr.split(",")
    for (var i = 0; i < pairs.length; i++) {
      var raw = pairs[i]
      var sep = raw.indexOf(":")
      if (sep <= 0) continue
      var k = raw.substring(0, sep).trim()
      var v = raw.substring(sep + 1).trim()
      if (k !== "") out[k] = v
    }
    return out
  }

  readonly property var    _wsIconMap:  root._parseWorkspaceIconMap(root.workspaceIconMap)
  readonly property var    _wsInfo:     (root._winInfo && root._winInfo.workspace) ? root._winInfo.workspace : null
  readonly property string _wsIdStr:    root._wsInfo ? String(root._wsInfo.id) : ""
  readonly property string _wsNameStr:  (root._wsInfo && root._wsInfo.name && root._wsInfo.name !== "") ? root._wsInfo.name : root._wsIdStr
  readonly property string _wsGlyph:    root._wsIconMap[root._wsIdStr] || root._wsIconMap[root._wsNameStr] || root._wsIconMap["default"] || ""

  function _workspaceChipText() {
    if (!root._hasWindow || !root._wsInfo) return ""
    switch (root.workspaceFormat) {
      case "icon": return root._wsGlyph || root._wsIdStr
      case "both": return (root._wsGlyph ? root._wsGlyph + " " : "") + root._wsIdStr
      default:     return root._wsIdStr   // "number"
    }
  }

  // _windowTitle / _windowAppId / _hasWindow / _winInfo (acima) são lidos
  // diretamente pelo DmenuTooltip.qml — não precisa montar texto aqui.

  // ══════════════════════════════════════════════════════════════════════
  // MENU DE CONTEXTO — clique direito: fechar janela / mover de workspace
  // ══════════════════════════════════════════════════════════════════════
  property bool contextMenuOpen: false

  function _closeContextMenu() { root.contextMenuOpen = false }

  function _closeWindow() {
    if (root._activeToplevel) root._activeToplevel.close()
    root._closeContextMenu()
  }

  function _moveToWorkspace(wsId) {
    Hyprland.dispatch("movetoworkspace " + wsId)
    root._closeContextMenu()
  }

  readonly property var _workspaceList: {
    var out = []
    var all = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < all.length; i++) {
      var w = all[i]
      out.push({ id: w.id, name: (w.name && w.name !== "") ? w.name : String(w.id) })
    }
    return out
  }

  // ══════════════════════════════════════════════════════════════════════
  // Ícone da janela — fallback em camadas (mesma lógica do artworkComp do
  // MediaPlayer.qml, sem a camada de capa de álbum)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: windowIconComp
    Item {
      id: wIcon
      width: root.windowIconSize; height: root.windowIconSize

      readonly property string appId: (root._windowAppId || "").toLowerCase()

      readonly property var desktopEntry: {
        var _l = DesktopEntries.applications.values.length
        if (!appId) return null
        return DesktopEntries.byId(appId)
            || DesktopEntries.byId(appId.replace(/-/g, ""))
            || DesktopEntries.heuristicLookup(appId)
            || null
      }

      readonly property string iconName: desktopEntry ? (desktopEntry.icon || "") : ""

      readonly property string iconSource: {
        if (iconName === "") return ""
        if (iconName.startsWith("/") || iconName.startsWith("file://")) return iconName
        // mesmo image provider que o DmenuContent.qml usa pra ícone dos
        // apps no drun — resolve pelo tema de ícones instalado no sistema,
        // bem mais confiável que sondar caminhos manualmente.
        return "image://icon/" + iconName
      }

      // camada 1 — ícone do app, resolvido pelo tema de ícones do sistema
      IconImage {
        id: appIconImg
        anchors.fill: parent
        source:  wIcon.iconSource
        smooth:  true
        opacity: (wIcon.iconSource !== "" && status === Image.Ready) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
      }

      // camada 2 — glifo Nerd Font (fallback final, só quando o tema de
      // ícones realmente não tem nada pra esse app)
      Text {
        anchors.centerIn: parent
        visible:        appIconImg.opacity < 1.0
        text:           root.iconGlyph
        color:          root._hasWindow ? root.textColor : root.dimColor
        font.pixelSize: Math.round(root.windowIconSize * 0.72)
        font.family:    "JetBrainsMono Nerd Font"
        Behavior on color { ColorAnimation { duration: 200 } }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Carretel horizontal do título — igual ao hScrollComp do MediaPlayer.qml
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: hScrollComp
    Item {
      id: hScroll
      width: root.titleMaxWidth; height: Math.round(16 * root.fontScale); clip: !root.textStatic

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
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Math.round(12 * root.fontScale)
        text: root._hasWindow ? root._windowTitle : root.emptyText
        x: 0
        width:  root.textStatic ? hScroll.width : implicitWidth
        elide:  root.textStatic ? Text.ElideRight : Text.ElideNone
        color: root._hasWindow ? root.textColor : root.dimColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      onNeedsScrollChanged: hScroll.restart()
      Connections {
        target: root
        function onDisplayModeChanged()   { hScroll.restart() }
        function onTitleMaxWidthChanged() { hScroll.restart() }
        function onTextStaticChanged()    { hScroll.restart() }
      }
      Connections {
        target: Hyprland
        function onActiveToplevelChanged() { hScroll.restart() }
      }
      Component.onCompleted: hScroll.restart()
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HORIZONTAL
  // ══════════════════════════════════════════════════════════════════════
  Row {
    id: hRow
    visible:          root.isHorizontal
    anchors.centerIn: parent
    spacing:          6

    Rectangle {
      id: wsChipBefore
      visible: root.showWorkspace && root.workspacePosition === "before" && root._hasWindow
      anchors.verticalCenter: parent.verticalCenter
      width:  root.workspaceChipWidth
      height: Math.round(16 * root.fontScale)
      radius: 4
      color:  Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
      Text {
        anchors.centerIn: parent
        text:  root._workspaceChipText()
        color: root.accentColor
        font.pixelSize: Math.round(10 * root.fontScale)
        font.family:    "JetBrainsMono Nerd Font"
        elide: Text.ElideRight
        width: parent.width - 4
        horizontalAlignment: Text.AlignHCenter
      }
    }

    Loader {
      anchors.verticalCenter: parent.verticalCenter
      active:          root.displayMode === "windowIcon"
      visible:         active
      sourceComponent: windowIconComp
    }

    Text {
      visible:                 root.displayMode === "icon"
      anchors.verticalCenter:  parent.verticalCenter
      text:                    root.iconGlyph
      color:                   root._hasWindow ? root.textColor : root.dimColor
      font.pixelSize:          Math.round(13 * root.fontScale)
      font.family:             "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    Loader {
      anchors.verticalCenter: parent.verticalCenter
      active:          root.displayMode === "title"
      visible:         active
      sourceComponent: hScrollComp
    }

    Rectangle {
      id: wsChipAfter
      visible: root.showWorkspace && root.workspacePosition === "after" && root._hasWindow
      anchors.verticalCenter: parent.verticalCenter
      width:  root.workspaceChipWidth
      height: Math.round(16 * root.fontScale)
      radius: 4
      color:  Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
      Text {
        anchors.centerIn: parent
        text:  root._workspaceChipText()
        color: root.accentColor
        font.pixelSize: Math.round(10 * root.fontScale)
        font.family:    "JetBrainsMono Nerd Font"
        elide: Text.ElideRight
        width: parent.width - 4
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VERTICAL — sempre ícone (não há espaço pro título empilhado)
  // ══════════════════════════════════════════════════════════════════════
  Column {
    id: vCol
    visible:          !root.isHorizontal
    anchors.centerIn: parent

    Loader {
      anchors.horizontalCenter: parent.horizontalCenter
      active:          root.displayMode === "windowIcon"
      visible:         active
      sourceComponent: windowIconComp
    }

    Text {
      visible:                  root.displayMode !== "windowIcon"
      anchors.horizontalCenter: parent.horizontalCenter
      text:                     root.iconGlyph
      color:                    root._hasWindow ? root.textColor : root.dimColor
      font.pixelSize:           Math.round(14 * root.fontScale)
      font.family:              "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ── Interação ────────────────────────────────────────────────────────
  // Esquerdo → abre/fecha o dmenu (toggle já vem de DmenuIpc.openNative).
  // Direito  → menu de contexto (fechar / mover de workspace), só se há
  //            janela focada.
  MouseArea {
    anchors.fill:    parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled:    true
    cursorShape:     Qt.PointingHandCursor
    onEntered: { root._hovering = true; root._refreshWindowInfo(); DmenuTooltip.show(root, root, root.barPosition) }
    onExited:  { root._hovering = false; DmenuTooltip.hide() }
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        if (root._hasWindow) {
          DmenuTooltip.hide()
          root._refreshWindowInfo()
          root.contextMenuOpen = true
        }
      } else {
        root.panelRequested()
      }
    }
  }

  // ── Popup do menu de contexto ───────────────────────────────────────────
  PopupWindow {
    id: ctxMenu
    visible: root.contextMenuOpen && root._hasWindow
    color:   "transparent"

    anchor.item: root
    anchor.edges: {
      switch (root.barPosition) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.gravity: {
      switch (root.barPosition) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    implicitWidth:  menuCol.implicitWidth  + 12
    implicitHeight: menuCol.implicitHeight + 12

    Rectangle {
      anchors.fill: parent
      radius:       8
      color:        Qt.rgba(0.05, 0.05, 0.05, 0.96)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      Column {
        id: menuCol
        anchors.centerIn: parent
        spacing: 2

        Rectangle {
          width: 190; height: 28; radius: 5
          color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
          Row {
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
              text: "\uf00d"; color: "#ff6b6b"; font.pixelSize: 11
              font.family: "JetBrainsMono Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "Fechar janela"; color: "#e2e2e2"; font.pixelSize: 11
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          MouseArea {
            id: closeMouse
            anchors.fill: parent; hoverEnabled: true
            onClicked: root._closeWindow()
          }
        }

        Rectangle { width: 190; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        Text {
          text: "MOVER PARA WORKSPACE"
          color: Qt.rgba(1, 1, 1, 0.4)
          font.pixelSize: 9
          leftPadding: 8; topPadding: 5; bottomPadding: 3
        }

        Flow {
          id: wsFlow
          width: 190; height: implicitHeight; spacing: 4
          leftPadding: 4; rightPadding: 4; bottomPadding: 4

          Repeater {
            model: root._workspaceList
            delegate: Rectangle {
              id: wsChip
              required property var modelData
              // largura fixa estourava com nomes longos (workspaces
              // especiais nomeadas, ex: "special:scratch") — o texto
              // vazava pra cima dos chips vizinhos. Agora cada chip se
              // ajusta ao próprio texto, com teto + elide pros extremos.
              width:  Math.max(28, Math.min(90, wsLabel.implicitWidth + 14))
              height: 24; radius: 5
              color: wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
              Text {
                id: wsLabel
                anchors.centerIn: parent
                text:  wsChip.modelData.name
                color: "#e2e2e2"
                font.pixelSize: 10
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 76)
              }
              MouseArea {
                id: wsMouse
                anchors.fill: parent; hoverEnabled: true
                onClicked: root._moveToWorkspace(wsChip.modelData.id)
              }
            }
          }
        }
      }
    }
  }

  HyprlandFocusGrab {
    id: ctxFocusGrab
    windows:   [ctxMenu]
    active:    root.contextMenuOpen
    onCleared: root.contextMenuOpen = false
  }
}
