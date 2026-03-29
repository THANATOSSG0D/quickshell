import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── VolumePopup ───────────────────────────────────────────────────────────
// PopupWindow para o conteúdo de volume.
// Deve ser declarado como filho QML de um PanelWindow (a barra), que se
// torna automaticamente o parentWindow da superfície Wayland do popup.
// O posicionamento é feito via anchor.window/rect/edges no caller (Bar.qml).

PopupWindow {
  id: popup

  property bool showOnlySink:   false
  property bool showOnlySource: false

  property int popupW: 280
  property int popupH: 380

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorMuted:      "#cf6679"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  color:         "transparent"
  implicitWidth:  popupW   // 'width' é deprecated em PopupWindow
  implicitHeight: popupH

  property bool panelOpen: false
  property real slideProgress: 0.0

  visible: slideProgress > 0.0

  signal closeRequested()

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

    VolumeContent {
      anchors.fill:    parent
      showOnlySink:    popup.showOnlySink
      showOnlySource:  popup.showOnlySource
      colorPanelBg:    popup.colorPanelBg
      colorText:       popup.colorText
      colorTextDim:    popup.colorTextDim
      colorAccent:     popup.colorAccent
      colorMuted:      popup.colorMuted
      colorProgressBg: popup.colorProgressBg
      colorDivider:    popup.colorDivider
      onCloseRequested: popup.closeRequested()
    }
  }
}
