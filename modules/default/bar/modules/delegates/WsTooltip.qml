pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "IconLookup.js" as IconLookup

// WsTooltip — singleton de tooltip rico para os delegates de workspace
// (Dot, Number, Hybrid, Icons). Mostra o nome/número do workspace e a lista
// de janelas abertas nele (ícone + título), igual ao MediaTooltip/QsTooltip
// já usados na barra e no QuickSettings.
//
// API:
//   show(item, workspace, barPosition) → mostra após 500ms de hover
//   hide()                             → esconde com pequeno delay
//
// "workspace" é o modelData do Hyprland (objeto com .id, .name, .urgent,
// .toplevels.values) — lido diretamente, então a lista de janelas atualiza
// em tempo real (abrir/fechar app) enquanto o tooltip estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"
  property color urgentColor:  "#f38ba8"

  readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + Quickshell.env("USER"))

  property var _anchorItem: null
  property var _ws:         null
  property int _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, workspace, barPosition) {
    _anchorItem = item
    _ws         = workspace
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
    onTriggered: { if (root._anchorItem && root._ws) popup.visible = true }
  }
  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do workspace ───────────────────────────────
  readonly property string _name:   root._ws ? (root._ws.name || "") : ""
  readonly property int    _id:     root._ws ? (root._ws.id   || 0)  : 0
  readonly property bool   _urgent: root._ws ? root._ws.urgent : false

  readonly property string _label: _name.length > 0 ? _name : (_id > 0 ? String(_id) : "")

  // Força reavaliação quando o Hyprland muda algo (toplevels não emite
  // sinal próprio de forma confiável — mesmo cuidado que o Icons.qml tem).
  property int _dep: 0
  Connections {
    target: Hyprland
    function onRawEvent(event) { root._dep++ }
  }

  readonly property var _windows: {
    var _d = root._dep   // dependência intencional, ver comentário acima
    if (!root._ws || !root._ws.toplevels) return []
    return root._ws.toplevels.values.slice()
  }

  function _iconFor(win) {
    if (!win || !win.wayland) return ""
    return IconLookup.firstIconPath(win.wayland.appId, DesktopEntries, root.homeDir)
  }

  function _titleFor(win) {
    if (!win) return ""
    return win.title || (win.wayland ? win.wayland.appId : "") || "—"
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    implicitWidth:  Math.max(140, content.implicitWidth  + 24)
    implicitHeight: content.implicitHeight + 16

    anchor.item: root._anchorItem
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
    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.FlipY

    Rectangle {
      anchors.fill: parent
      radius: 10
      color:  root.bgColor

      Column {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // ── Cabeçalho: nome/número do workspace ──────────────────────────
        Row {
          id: headerRow
          spacing: 6
          Text {
            visible: root._urgent
            text: "\uf06a"   // exclamation-circle
            color: root.urgentColor
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
          }
          Text {
            text: "Workspace " + root._label
            color: root._urgent ? root.urgentColor : root.fgColor
            font.pixelSize: 11
            font.weight: Font.Medium
          }
        }

        Rectangle {
          visible: root._windows.length > 0
          width: parent.width; height: 1
          color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Lista de janelas ─────────────────────────────────────────────
        Repeater {
          model: root._windows
          delegate: Row {
            required property var modelData
            spacing: 7

            Image {
              id: winIcon
              width: 14; height: 14
              anchors.verticalCenter: parent.verticalCenter
              fillMode: Image.PreserveAspectFit
              source: root._iconFor(modelData)
              visible: status === Image.Ready
            }
            Text {
              visible: winIcon.status !== Image.Ready
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf2d0"   // window outline genérico
              color: root.fgDimColor
              font.pixelSize: 10
              font.family: "JetBrainsMono Nerd Font"
              width: 14
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root._titleFor(modelData)
              color: modelData.activated ? root.fgColor : root.fgDimColor
              font.pixelSize: 10
              elide: Text.ElideRight
              // Largura fixa (não calculada a partir de implicitWidth) —
              // width:Math.min(implicitWidth, N) cria um binding circular
              // que impede o Column pai de calcular uma largura estável,
              // causando o corte visual. Largura fixa resolve isso, no
              // mesmo espírito do MediaTooltip (que usa textColWidth, uma
              // largura externa pré-calculada, nunca implicitWidth de si
              // mesmo).
              width: 220
            }
          }
        }

        Text {
          visible: root._windows.length === 0
          text: "Vazio"
          color: root.fgDimColor
          font.pixelSize: 10
        }
      }
    }
  }
}
