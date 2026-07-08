pragma Singleton
import Quickshell
import QtQuick
import qs

// VolumeTooltip — singleton de tooltip rico para o módulo de volume (sink/source).
//
// Mesma filosofia do MediaTooltip/ClockTooltip/QsTooltip (PopupWindow leve,
// anexado ao item da barra, aparece com delay no hover, mesma paleta e
// mesmo radius:10) — em vez do texto simples de uma linha que o BarTooltip
// genérico mostrava, agora exibe ícone + nome do dispositivo + barra de
// volume, no mesmo estilo da linha de volume do MediaTooltip.
//
// API:
//   show(item, volumeRoot, isSink, barPosition)   → mostra após 500ms de hover
//   update(item, volumeRoot, isSink, barPosition) → mostra imediatamente (scroll),
//                                                    some após 1.5s
//   hide()                                        → esconde com pequeno delay
//
// "volumeRoot" é a referência ao Volume.qml (root.volumeWidget) — lida
// diretamente, então o tooltip atualiza em tempo real (volume mudando,
// dispositivo trocando, mute) enquanto estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"
  property color mutedColor:   "#cf6679"

  property var    _anchorItem: null
  property var    _volumeRoot: null
  property bool   _isSink:     true
  property int    _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, volumeRoot, isSink, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem = item
    _volumeRoot = volumeRoot
    _isSink     = isSink
    _barPos     = barPosition
    hideTimer.stop()
    scrollHideTimer.stop()
    showTimer.restart()
  }

  // scroll: mostra imediatamente, some 1.5s após o último scroll
  function update(item, volumeRoot, isSink, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    showTimer.stop()
    hideTimer.stop()
    _anchorItem   = item
    _volumeRoot   = volumeRoot
    _isSink       = isSink
    _barPos       = barPosition
    popup.visible = true
    scrollHideTimer.restart()
  }

  function hide() {
    showTimer.stop()
    if (!scrollHideTimer.running)
      hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: { if (root._anchorItem && root._volumeRoot) popup.visible = true }
  }
  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }
  Timer {
    id: scrollHideTimer
    interval: 1500; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do volumeRoot ──────────────────────────────
  readonly property var    _device: {
    if (!_volumeRoot) return null
    return _isSink ? _volumeRoot.sink : _volumeRoot.source
  }
  readonly property string _name: {
    if (!_device) return _isSink ? "Saída" : "Microfone"
    return _device.nickname || _device.description || _device.name || (_isSink ? "Saída" : "Microfone")
  }
  readonly property real _volume: {
    if (!_volumeRoot) return 0
    return _isSink ? _volumeRoot.sinkVolume : _volumeRoot.sourceVolume
  }
  readonly property bool _muted: {
    if (!_volumeRoot) return false
    return _isSink ? _volumeRoot.sinkMuted : _volumeRoot.sourceMuted
  }
  readonly property string _icon: {
    if (_isSink) return (_muted || _volume <= 0) ? "\uf026" : "\uf028"
    return (_muted || _volume <= 0) ? "\uf131" : "\uf130"
  }

  // Resolve o item de ancoragem conforme TooltipSettings.align — ver
  // comentário completo em BarTooltip.qml.
  function _resolveAnchor() {
    if (!root._anchorItem) return root._anchorItem
    // "bar"     → sobe até o container raiz da barra inteira (objectName
    //             "barContentRoot", setado em Bar.qml — comum a todos os temas)
    // "section" → sobe até o container da seção do módulo hoverado
    //             (objectName "barSectionLeft/Center/Right/Top/Middle/Bottom",
    //             marcado em cada tema — ver comentário em TooltipSettings.qml)
    // "module"  → o próprio item hoverado (comportamento padrão, sem loop)
    if (root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "bar" && root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "section")
      return root._anchorItem
    var wantPrefix = root._cfg(root._anchorItem, "Align", TooltipSettings.align) === "bar" ? "barContentRoot" : "barSection"
    var it = root._anchorItem, guard = 0
    while (it && it.objectName.indexOf(wantPrefix) !== 0 && guard < 40) { it = it.parent; guard++ }
    return it || root._anchorItem
  }

  // Resolve a config de tooltip do PAINEL a que o item hoverado pertence
  // (bar ou dock — cada Loader "barContentRoot" expõe a própria config,
  // ver Bar.qml). Cai no default (TooltipSettings.*) se não achar nenhum
  // barContentRoot acima do item, ou se a propriedade não existir nele.
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

    implicitWidth:  Math.min(
      root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth),
      Math.max(root._cfg(root._anchorItem, "MinWidth", TooltipSettings.minWidth), content.implicitWidth + TooltipSettings.contentPadding)
    ) + (_barVertical ? _touchOffset : 0)
    implicitHeight: content.implicitHeight + 14 + (_barVertical ? 0 : _touchOffset)

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

      Column {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // contentRowWidth: largura comum para título e barra — garante que
        // a barra de volume sempre estique até o final do tooltip, em vez
        // de ficar limitada à largura (curta) do título.
        readonly property int contentRowWidth: Math.min(
          root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth) - TooltipSettings.contentPadding,
          Math.max(root._cfg(root._anchorItem, "MinWidth", TooltipSettings.minWidth) - TooltipSettings.contentPadding, titleRow.implicitWidth)
        )

        // ── Nome do dispositivo ────────────────────────────────────────
        Row {
          id: titleRow
          spacing: 6

          Text {
            id: volDeviceIcon
            anchors.verticalCenter: parent.verticalCenter
            text:           root._icon
            color:          root._muted ? root.mutedColor : root.accentColor
            font.pixelSize: 12
            font.family:    "JetBrainsMono Nerd Font"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root._name
            color:          root.fgColor
            font.pixelSize: 11
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
            // nome do dispositivo pode ser grande (bluetooth, etc) — elide
            // + largura vinda do container já resolvido (contentRowWidth),
            // nunca do próprio implicitWidth deste Text (loop).
            elide: Text.ElideRight
            width: content.contentRowWidth - volDeviceIcon.implicitWidth - titleRow.spacing
          }
        }

        // ── Barra de volume — mesmo estilo do MediaTooltip/QsTooltip ───
        Row {
          spacing: 5
          width:   content.contentRowWidth

          Rectangle {
            id: volTrack
            width:  content.contentRowWidth - volPct.implicitWidth - parent.spacing
            height: 4; radius: 2
            color:  Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width:  parent.width * Math.min(1.0, root._volume)
              height: parent.height
              radius: parent.radius
              color:  root._muted ? root.mutedColor : root.accentColor
              Behavior on width { NumberAnimation { duration: 120 } }
            }
          }
          Text {
            id: volPct
            text:           (root._muted ? "mudo · " : "") + Math.round(root._volume * 100) + "%"
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
