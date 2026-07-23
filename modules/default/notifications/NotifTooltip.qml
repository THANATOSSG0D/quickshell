pragma Singleton
import Quickshell
import QtQuick
import qs

// NotifTooltip — singleton de tooltip rico para o módulo de notificações
// (o sino na barra). Mesma filosofia do WsTooltip/QsTooltip/MediaTooltip:
// PopupWindow leve, anexado ao item da barra, aparece com delay no hover,
// mesma paleta e radius:10.
//
// Mostra o estado de DND e as últimas notificações do histórico (até 3),
// igual a lista de janelas do WsTooltip — sem precisar abrir o painel.
//
// API:
//   show(item, service, barPosition) → mostra após 500ms de hover
//   hide()                           → esconde com pequeno delay
//
// "service" é o NotificationService — lido diretamente, então a lista
// atualiza em tempo real (nova notificação chegando) enquanto visível.

Singleton {
  id: root

  // Antes eram cores hardcoded num esquema Catppuccin desconectado da
  // paleta matugen (mesmo problema que o NotificationToast.qml tinha,
  // já corrigido lá) — esse tooltip tinha ficado de fora daquela limpeza.
  // Agora usa os mesmos tokens (Colors.*) que o resto do módulo.
  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Colors.on_surface_variant
  property color accentColor:  Colors.primary
  property color mutedColor:   Colors.error

  property var _anchorItem: null
  property var _service:    null
  property int _barPos:     2

  // Quantas notificações mostrar na pré-visualização
  property int maxPreview: 3

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, service, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem = item
    _service    = service
    _barPos     = barPosition
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
    onTriggered: { if (root._anchorItem && root._service) popup.visible = true }
  }
  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do service ─────────────────────────────────
  readonly property bool _dnd:    root._service ? root._service.doNotDisturb : false
  readonly property int  _unread: root._service ? root._service.unreadCount  : 0

  readonly property var _items: {
    if (!root._service || !root._service.notifications) return []
    var out = []
    var n   = Math.min(root.maxPreview, root._service.notifications.count)
    for (var i = 0; i < n; i++) out.push(root._service.notifications.get(i))
    return out
  }

  function _summaryFor(n) {
    if (!n) return ""
    var s = n.summary || n.appName || "Notificação"
    return s.length > 38 ? s.slice(0, 37) + "…" : s
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
    implicitHeight: content.implicitHeight + 16 + (_barVertical ? 0 : _touchOffset)

    anchor.item: root._resolveAnchor()
    anchor.edges: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
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

        // Largura comum das linhas de preview, derivada de minWidth — antes
        // os 70px (appName) e 160px (resumo) eram fixos e ignoravam
        // completamente o slider "Largura mínima" da UI.
        readonly property int rowWidth: Math.min(
          root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth) - TooltipSettings.contentPadding,
          Math.max(root._cfg(root._anchorItem, "MinWidth", TooltipSettings.minWidth) - TooltipSettings.contentPadding, headerRow.implicitWidth)
        )

        // ── Cabeçalho: estado DND + não-lidas ───────────────────────────
        Row {
          id: headerRow
          spacing: 6

          Text {
            id: headerIcon
            text:           root._dnd ? "\uf1f6" : "\uf0f3"
            color:          root._dnd ? root.mutedColor : root.accentColor
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root._dnd
              ? "Não perturbe"
              : (root._unread > 0 ? root._unread + " não lida" + (root._unread > 1 ? "s" : "") : "Notificações")
            color:          root._dnd ? root.mutedColor : root.fgColor
            font.pixelSize: 11
            font.weight:    Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: content.rowWidth - headerIcon.implicitWidth - headerRow.spacing
          }
        }

        Rectangle {
          visible: root._items.length > 0
          width: parent.width; height: 1
          color: Qt.rgba(root.fgDimColor.r, root.fgDimColor.g, root.fgDimColor.b, 0.25)
        }

        // ── Pré-visualização das últimas notificações ───────────────────
        Repeater {
          model: root._items
          delegate: Row {
            required property var modelData
            spacing: 7

            Text {
              id: bulletText
              text:           "\uf111"   // bolinha
              color:          modelData.urgency >= 2 ? root.mutedColor : root.fgDimColor
              font.pixelSize: 6
              font.family:    "JetBrainsMono Nerd Font"
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: appNameText
              text:           modelData.appName || "—"
              color:          root.fgDimColor
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(content.rowWidth * 0.28)
              elide: Text.ElideRight
            }
            Text {
              text:           root._summaryFor(modelData)
              color:          root.fgColor
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              width: content.rowWidth - appNameText.width - bulletText.implicitWidth - parent.spacing * 2
            }
          }
        }

        Text {
          visible: root._items.length === 0
          text: "Sem notificações recentes"
          color: root.fgDimColor
          font.pixelSize: 10
        }
      }
    }
  }
}
