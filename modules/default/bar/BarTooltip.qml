pragma Singleton
import Quickshell
import QtQuick
import qs

// BarTooltip — singleton de tooltip global para a barra.
//
// API:
//   show(item, text, barPosition)   → mostra após 500ms de hover
//   update(item, text, barPosition) → mostra imediatamente (scroll), some após 1.5s
//   hide()                          → esconde com pequeno delay (evita piscar)

Singleton {
  id: root

  property color bgColor: Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor: "#e2e2e2"

  property var    _anchorItem: null
  property string _text:       ""
  property int    _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  // hover: mostra com delay
  function show(item, text, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem = item
    _text       = text
    _barPos     = barPosition
    hideTimer.stop()
    scrollHideTimer.stop()
    showTimer.restart()
  }

  // scroll: mostra imediatamente, some 1.5s após o último scroll
  function update(item, text, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    showTimer.stop()
    hideTimer.stop()
    _anchorItem   = item
    _text         = text
    _barPos       = barPosition
    popup.visible = true
    scrollHideTimer.restart()
  }

  // sai do hover: esconde com delay curto para não piscar entre ícones
  function hide() {
    showTimer.stop()
    // só agenda hide se não há scroll ativo
    if (!scrollHideTimer.running)
      hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: {
      if (root._anchorItem && root._text !== "")
        popup.visible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // some automaticamente após 1.5s de inatividade no scroll
  Timer {
    id: scrollHideTimer
    interval: 1500; repeat: false
    onTriggered: popup.visible = false
  }

  // Resolve o item de ancoragem conforme TooltipSettings.align:
  //  "module" (padrão) → o próprio item hoverado
  //  "bar"             → sobe a árvore de pais até achar o container raiz
  //                      da barra (objectName "barContentRoot"), pra o
  //                      tooltip aparecer sempre no mesmo lugar da barra
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

    // offset extra: soma na largura se a barra for vertical (esq/dir,
    // tooltip se abre na horizontal) ou na altura se a barra for
    // horizontal (topo/baixo, tooltip se abre na vertical)
    readonly property int  _touchOffset: root._cfg(root._anchorItem, "Offset", TooltipSettings.offset)
    readonly property bool _barVertical:  root._barPos === 2 || root._barPos === 4

    implicitWidth:  Math.max(root._cfg(root._anchorItem, "MinWidth", TooltipSettings.minWidth), label.implicitWidth  + TooltipSettings.contentPadding) + (_barVertical ? _touchOffset : 0)
    implicitHeight: label.implicitHeight + 10 + (_barVertical ? 0 : _touchOffset)

    anchor.item: root._resolveAnchor()

    // salta para fora da barra — lado oposto à borda
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
      // insere o offset só do lado que encosta na barra, deixando o
      // restante do popup (transparente) como respiro
      anchors.leftMargin:   root._barPos === 4 ? popup._touchOffset : 0
      anchors.rightMargin:  (root._barPos !== 1 && root._barPos !== 3 && root._barPos !== 4) ? popup._touchOffset : 0
      anchors.topMargin:    root._barPos === 1 ? popup._touchOffset : 0
      anchors.bottomMargin: root._barPos === 3 ? popup._touchOffset : 0
      radius: 5
      color:  root.bgColor

      Text {
        id: label
        anchors.centerIn: parent
        // binding reativo — atualiza automaticamente quando _text muda
        text:           root._text
        color:          root.fgColor
        font.pixelSize: 11
        font.family:    "JetBrainsMono Nerd Font"
      }
    }
  }
}
