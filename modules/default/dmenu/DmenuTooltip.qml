pragma Singleton
import Quickshell
import Quickshell.Widgets
import QtQuick
import qs

// DmenuTooltip — singleton de tooltip rico pro módulo dmenu, mesmo padrão
// do MediaTooltip.qml: PopupWindow leve anexado ao item da barra, aparece
// com delay no hover, layout próprio (ícone do app + título/classe/tags/
// conteúdo/pid) em vez de uma linha de texto solta genérica.
//
// API:
//   show(item, widget, barPosition)   → mostra após 500ms de hover
//   update(item, widget, barPosition) → atualiza o conteúdo já visível,
//                                       sem reiniciar o delay (usado quando
//                                       o hyprctl responde depois do hover)
//   hide()                            → esconde com pequeno delay
//
// Mostra: título, classe, workspace + estado (mosaico/flutuante/tela
// cheia/fixada), tags, tamanho + monitor, tipo de conteúdo (Xwayland ou
// Wayland nativo) e PID.
//
// "widget" é a instância do Dmenu.qml (root do módulo) — lida diretamente
// (_windowTitle/_windowAppId/_winInfo/_hasWindow), então o conteúdo do
// tooltip atualiza em tempo real enquanto ele estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"

  property int iconSize: 40

  property var _anchorItem: null
  property var _widget:     null
  property int _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, widget, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem = item
    _widget     = widget
    _barPos     = barPosition
    hideTimer.stop()
    showTimer.restart()
  }

  function update(item, widget, barPosition) {
    _anchorItem = item
    _widget     = widget
    _barPos     = barPosition
    if (!popup.visible) return
    hideTimer.stop()
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
      if (root._anchorItem && root._widget)
        popup.visible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do widget (Dmenu.qml) ──────────────────────
  readonly property string _title:     root._widget ? (root._widget._windowTitle  || "") : ""
  readonly property string _class:     root._widget ? (root._widget._windowAppId  || "") : ""
  readonly property bool   _hasWindow: root._widget ? root._widget._hasWindow          : false
  readonly property string _emptyText: root._widget ? (root._widget.emptyText || "Desktop") : "Desktop"
  readonly property var    _winInfo:   (root._widget && root._widget._winInfo) ? root._widget._winInfo : ({})
  readonly property string _tags:      (root._winInfo.tags && root._winInfo.tags.length > 0) ? root._winInfo.tags.join(", ") : ""
  readonly property string _content:   root._winInfo.xwayland === true ? "Xwayland (X11)" : "Wayland nativo"
  readonly property string _pid:       root._winInfo.pid !== undefined ? String(root._winInfo.pid) : ""

  readonly property var    _ws:        root._winInfo.workspace || null
  readonly property string _wsLabel:   root._ws ? ((root._ws.name && root._ws.name !== "") ? root._ws.name : String(root._ws.id)) : ""

  readonly property var    _size:      (root._winInfo.size && root._winInfo.size.length === 2) ? root._winInfo.size : null
  readonly property string _sizeLabel: root._size ? (root._size[0] + " × " + root._size[1] + " px") : ""

  readonly property int    _monitor:   root._winInfo.monitor !== undefined ? root._winInfo.monitor : -1

  readonly property string _stateLabel: {
    var flags = []
    if (root._winInfo.fullscreen)        flags.push("Tela cheia")
    if (root._winInfo.floating === true) flags.push("Flutuante")
    if (root._winInfo.pinned === true)   flags.push("Fixada")
    if (root._winInfo.pseudo === true)   flags.push("Pseudo-tiled")
    return flags.length > 0 ? flags.join(", ") : "Em mosaico"
  }

  // Resolve o item de ancoragem conforme TooltipSettings.align — mesmo
  // mecanismo do BarTooltip.qml/MediaTooltip.qml.
  function _resolveAnchor() {
    if (!root._anchorItem) return root._anchorItem
    if (root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "bar" && root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "section")
      return root._anchorItem
    var wantPrefix = root._cfg(root._anchorItem, "Align", TooltipSettings.align) === "bar" ? "barContentRoot" : "barSection"
    var it = root._anchorItem, guard = 0
    while (it && it.objectName.indexOf(wantPrefix) !== 0 && guard < 40) { it = it.parent; guard++ }
    return it || root._anchorItem
  }

  // Resolve a config de tooltip do painel a que o item hoverado pertence
  // (bar ou dock), caindo no default global (TooltipSettings.*) se não
  // achar — mesmo mecanismo do BarTooltip.qml/MediaTooltip.qml.
  function _cfg(startItem, key, dflt) {
    var it = startItem, guard = 0
    while (it && it.objectName !== "barContentRoot" && guard < 40) { it = it.parent; guard++ }
    var propName = "cfgTooltip" + key
    if (it && it[propName] !== undefined) return it[propName]
    return dflt
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    readonly property int  _touchOffset: root._cfg(root._anchorItem, "Offset", TooltipSettings.offset)
    readonly property bool _barVertical: root._barPos === 2 || root._barPos === 4

    implicitWidth: TooltipSettings.resolveWidth(
      root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
      root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth),
      root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth),
      content.implicitWidth + TooltipSettings.contentPadding
    ) + (_barVertical ? _touchOffset : 0)
    implicitHeight: content.implicitHeight + 20 + (_barVertical ? 0 : _touchOffset)

    anchor.item: root._resolveAnchor()

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
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin:   root._barPos === 4 ? popup._touchOffset : 0
      anchors.rightMargin:  (root._barPos !== 1 && root._barPos !== 3 && root._barPos !== 4) ? popup._touchOffset : 0
      anchors.topMargin:    root._barPos === 1 ? popup._touchOffset : 0
      anchors.bottomMargin: root._barPos === 3 ? popup._touchOffset : 0
      radius: 10
      color:  root.bgColor

      Row {
        id: content
        anchors.centerIn: parent
        spacing: 10

        // ── Ícone do app (mesmo image://icon/ que o Dmenu.qml usa) ────────
        Item {
          id: tooltipIconBox
          width: root.iconSize; height: root.iconSize
          anchors.verticalCenter: parent.verticalCenter

          readonly property string _appId: root._class.toLowerCase()
          readonly property var _desktopEntry: {
            var _l = DesktopEntries.applications.values.length
            if (!_appId) return null
            return DesktopEntries.byId(_appId)
                || DesktopEntries.byId(_appId.replace(/-/g, ""))
                || DesktopEntries.heuristicLookup(_appId)
                || null
          }
          readonly property string _iconSrc: {
            if (!_desktopEntry || !_desktopEntry.icon) return ""
            var n = _desktopEntry.icon
            if (n.startsWith("/") || n.startsWith("file://")) return n
            return "image://icon/" + n
          }

          IconImage {
            id: tooltipIcon
            anchors.fill: parent
            source:  tooltipIconBox._iconSrc
            smooth:  true
            opacity: (tooltipIconBox._iconSrc !== "" && status === Image.Ready) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
          }
          Text {
            anchors.centerIn: parent
            visible:        tooltipIcon.opacity < 1.0
            text:           "\uf2d0"   // janela genérica — só quando não achou o ícone real
            color:          root.fgDimColor
            font.pixelSize: Math.round(root.iconSize * 0.5)
            font.family:    "JetBrainsMono Nerd Font"
          }
        }

        // ── Textos ───────────────────────────────────────────────────────
        Column {
          id: textCol
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          readonly property int textColWidth: TooltipSettings.resolveWidth(
            root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
            root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth) - root.iconSize - content.spacing - TooltipSettings.contentPadding,
            root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth) - root.iconSize - content.spacing - TooltipSettings.contentPadding,
            Math.max(
              titleText.implicitWidth,
              classText.implicitWidth,
              wsStateText.implicitWidth,
              tagsText.implicitWidth,
              sizeText.implicitWidth,
              metaText.implicitWidth
            )
          )

          Text {
            id: titleText
            text:           root._hasWindow ? (root._title || root._emptyText) : root._emptyText
            color:          root.fgColor
            font.pixelSize: 12
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: classText
            visible:        root._hasWindow && root._class.length > 0
            text:           "Classe: " + root._class
            color:          root.accentColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: wsStateText
            visible:        root._hasWindow && (root._wsLabel !== "" || root._stateLabel !== "")
            text: {
              var parts = []
              if (root._wsLabel !== "")   parts.push("Workspace " + root._wsLabel)
              if (root._stateLabel !== "") parts.push(root._stateLabel)
              return parts.join("  •  ")
            }
            color:          root.fgDimColor
            font.pixelSize: 10
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: tagsText
            visible:        root._hasWindow && root._tags.length > 0
            text:           "Tags: " + root._tags
            color:          root.fgDimColor
            font.pixelSize: 10
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: sizeText
            visible:        root._hasWindow && (root._sizeLabel !== "" || root._monitor >= 0)
            text: {
              var parts = []
              if (root._sizeLabel !== "") parts.push(root._sizeLabel)
              if (root._monitor >= 0)     parts.push("Monitor " + root._monitor)
              return parts.join("  •  ")
            }
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
          Text {
            id: metaText
            visible:        root._hasWindow
            text:           root._content + (root._pid !== "" ? ("  •  PID " + root._pid) : "")
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
            width:          textCol.textColWidth
          }
        }
      }
    }
  }
}
