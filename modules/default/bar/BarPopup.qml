import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── BarPopup ────────────────────────────────────────────────────────────────
// Wrapper reutilizável para todos os popups da barra. Encapsula:
//   • PopupWindow transparente (anchor gerenciado pelo caller em Bar.qml)
//   • HyprlandFocusGrab com auto-close ao perder foco
//   • Animação slideProgress (OutCubic, duração configurável)
//   • Fundo com radius + opacidade animada
//
// USO — declare o conteúdo como filho QML direto:
//
//   BarPopup {
//     id: clockPopup
//     popupW: 280; popupH: 480
//     panelOpen:    bar.clockPanelOpen
//     colorPanelBg: barState.config.palettePanelBg
//     onCloseRequested: bar.closeAllPanels()
//
//     ClockContent {
//       anchors.fill:    parent
//       colorPanelBg:    clockPopup.colorPanelBg
//       colorText:       clockPopup.colorText
//       onCloseRequested: clockPopup.closeRequested()
//     }
//   }
//
// NOTA: `parent` dentro do filho aponta para o Rectangle interno (bg),
// não para o PopupWindow — isso é intencional e permite anchors.fill: parent
// funcionar corretamente contra o fundo visível.

PopupWindow {
  id: popup

  // ── Dimensões ──────────────────────────────────────────────────────────
  property int popupW: 300
  property int popupH: 400

  // ── Estado ────────────────────────────────────────────────────────────
  property bool panelOpen:      false
  property real slideProgress:  0.0

  // ── Aparência ─────────────────────────────────────────────────────────
  property color colorPanelBg:  "#1f1f1f"
  property int   animDuration:  280
  property int   bgRadius:      12
  property real  bgOpacity:     0.95

  signal closeRequested()

  // ── PopupWindow base ──────────────────────────────────────────────────
  color:          "transparent"
  implicitWidth:  popupW
  implicitHeight: popupH
  visible:        slideProgress > 0.0

  HyprlandFocusGrab {
    windows:   [popup]
    active:    popup.panelOpen
    onCleared: popup.closeRequested()
  }

  Behavior on slideProgress {
    NumberAnimation { duration: popup.animDuration; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  // ── Fundo ─────────────────────────────────────────────────────────────
  // Os filhos QML declarados em BarPopup { ... } aterram aqui via `default`.
  // Isso faz com que `parent` dentro do filho seja este Rectangle,
  // permitindo `anchors.fill: parent` funcionar contra o fundo visível.
  Rectangle {
    id: bg
    anchors.fill: parent
    radius:  popup.bgRadius
    opacity: Math.min(1.0, popup.slideProgress * 2)
    color:   Qt.rgba(
      popup.colorPanelBg.r,
      popup.colorPanelBg.g,
      popup.colorPanelBg.b,
      popup.bgOpacity
    )

    default property alias content: bg.data
  }
}
