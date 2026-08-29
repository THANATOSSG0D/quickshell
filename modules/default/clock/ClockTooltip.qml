pragma Singleton
import Quickshell
import QtQuick
import qs

// ClockTooltip — singleton de tooltip rico para o módulo de relógio.
//
// Mesma filosofia do MediaTooltip (PopupWindow leve, anexado ao item da
// barra, aparece com delay no hover): mostra a data completa e a hora com
// segundos (a barra só mostra HH:MM), e, se houver um timer/pomodoro
// ativo, a fase atual + tempo restante + barra de progresso.
//
// API:
//   show(item, clockContent, barPosition)  → mostra após 500ms de hover
//   hide()                                 → esconde com pequeno delay
//
// "clockContent" é a referência ao ClockContent.qml (root.clockContent em
// Clock.qml) — lida diretamente, então o tooltip atualiza em tempo real
// (segundo a segundo, e quando o timer muda de fase) enquanto visível.

Singleton {
  id: root

  property color bgColor:        Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:        "#e2e2e2"
  property color fgDimColor:     Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:    "#ffb4a9"
  property color progressBgColor: Qt.rgba(1, 1, 1, 0.12)

  property var _anchorItem:   null
  property var _clockContent: null
  property int _barPos:       2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, clockContent, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem   = item
    _clockContent = clockContent
    _barPos       = barPosition
    hideTimer.stop()
    showTimer.restart()
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
      if (root._anchorItem)
        popup.visible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do ClockContent ──────────────────────────
  readonly property string _date: _clockContent ? _clockContent.currentDate : ""
  readonly property string _time: _clockContent ? _clockContent.currentTime : ""

  readonly property bool   _timerActive: {
    if (!_clockContent) return false
    if (_clockContent.timerDismissed) return false
    return _clockContent.remaining > 0 || _clockContent.running || _clockContent.expired
  }
  readonly property string _phaseLabel:    _clockContent ? _clockContent.phaseLabel    : ""
  readonly property int    _remaining:     _clockContent ? _clockContent.remaining     : 0
  readonly property int    _phaseDuration: _clockContent ? _clockContent.phaseDuration : 0
  readonly property bool   _running:       _clockContent ? _clockContent.running       : false
  readonly property bool   _expired:       _clockContent ? _clockContent.expired       : false

  readonly property string _remainingFmt: {
    var s = Math.max(0, _remaining)
    var mm = Math.floor(s / 60)
    var ss = s % 60
    return (mm < 10 ? "0" : "") + mm + ":" + (ss < 10 ? "0" : "") + ss
  }
  readonly property real _progress: _phaseDuration > 0
    ? Math.min(1.0, Math.max(0.0, (_phaseDuration - _remaining) / _phaseDuration))
    : 0.0

  // Resolve o item de ancoragem conforme TooltipSettings.align — ver
  // comentário completo em BarTooltip.qml (mesma lógica, repetida aqui
  // porque cada tooltip é um singleton independente).
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

      Column {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // ── Data + hora completa ──────────────────────────────────────
        Text {
          text:           root._date
          color:          root.fgColor
          font.pixelSize: 12
          font.weight:    Font.Medium
          font.family:    "JetBrainsMono Nerd Font"
        }
        Text {
          text:           root._time
          color:          root.fgDimColor
          font.pixelSize: 11
          font.family:    "JetBrainsMono Nerd Font"
        }

        // ── Separador + timer (só quando ativo) ───────────────────────
        Item { width: 1; height: 2; visible: root._timerActive }
        Rectangle {
          visible: root._timerActive
          width:   parent.width
          height:  1
          color:   root.fgDimColor
          opacity: 0.2
        }

        Column {
          visible: root._timerActive
          spacing: 4
          topPadding: 4
          width: TooltipSettings.resolveWidth(
            root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
            root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth) - TooltipSettings.contentPadding,
            root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth) - TooltipSettings.contentPadding,
            titleRow.implicitWidth
          )

          Row {
            id: titleRow
            spacing: 5

            Text {
              id: phaseIcon
              anchors.verticalCenter: parent.verticalCenter
              text:    root._expired ? "\uf017" : (root._running ? "\uf017" : "\uf28b")
              color:   root._expired ? root.accentColor : (root._running ? root.accentColor : root.fgDimColor)
              font.pixelSize: 10
              font.family:    "JetBrainsMono Nerd Font"
            }
            Text {
              id: remainingText
              anchors.verticalCenter: parent.verticalCenter
              text:           root._remainingFmt
              color:          root._expired ? root.accentColor : root.fgDimColor
              font.pixelSize: 11
              font.family:    "JetBrainsMono Nerd Font"
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text:           root._phaseLabel
              color:          root.fgColor
              font.pixelSize: 11
              font.weight:    Font.Medium
              font.family:    "JetBrainsMono Nerd Font"
              // fase pode ter nome customizado longo — elide defensivo,
              // largura vinda do teto externo (não do próprio implicitWidth).
              elide: Text.ElideRight
              width: TooltipSettings.resolveWidth(
                root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
                root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth),
                root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth),
                Infinity
              ) - TooltipSettings.contentPadding - phaseIcon.implicitWidth - remainingText.implicitWidth - titleRow.spacing * 2
            }
          }

          // Barra de progresso da fase atual
          Rectangle {
            width:  titleRow.implicitWidth
            height: 4
            radius: 2
            color:  root.progressBgColor

            Rectangle {
              width:  parent.width * root._progress
              height: parent.height
              radius: parent.radius
              color:  root.accentColor
              Behavior on width { NumberAnimation { duration: 200 } }
            }
          }
        }
      }
    }
  }
}
