import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── ClockPopup ────────────────────────────────────────────────────────────
// PopupWindow para o relógio e timer/pomodoro.
// Mesmo padrão de VolumePopup e MediaPlayerPopup:
//   • Deve ser filho QML do PanelWindow da barra
//   • anchor.window/rect/edges/gravity definidos no caller (Bar.qml ou tema)
//   • clockContentRef expõe o ClockContent para Clock.qml injetar clockContent

PopupWindow {
  id: popup

  property int popupW: 280
  property int popupH: 480

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  color:         "transparent"
  implicitWidth:  popupW
  implicitHeight: popupH

  property bool panelOpen: false
  property real slideProgress: 0.0

  visible: slideProgress > 0.0

  signal closeRequested()

  // Expõe o ClockContent para ser referenciado pelo widget Clock
  readonly property var clockContentRef: content

  HyprlandFocusGrab {
    windows: [ popup ]
    active:  popup.panelOpen
    onCleared: popup.closeRequested()
  }

  Behavior on slideProgress {
    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  Rectangle {
    anchors.fill: parent
    radius:  12
    opacity: Math.min(1.0, popup.slideProgress * 2)
    color:   Qt.rgba(popup.colorPanelBg.r, popup.colorPanelBg.g, popup.colorPanelBg.b, 0.95)

    ClockContent {
      id: content
      anchors.fill:    parent
      colorPanelBg:    popup.colorPanelBg
      colorText:       popup.colorText
      colorTextDim:    popup.colorTextDim
      colorAccent:     popup.colorAccent
      colorProgressBg: popup.colorProgressBg
      colorDivider:    popup.colorDivider
      onCloseRequested: popup.closeRequested()
    }
  }
}
