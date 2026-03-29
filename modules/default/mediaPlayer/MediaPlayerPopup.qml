import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── MediaPlayerPopup ──────────────────────────────────────────────────────
// PopupWindow para o conteúdo do media player.
// Mesmo padrão do VolumePopup — filho QML do PanelWindow da barra.

PopupWindow {
  id: popup

  property var barMediaPlayer: null

  property int popupW: 280
  property int popupH: 420

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorProgressBg: "#474747"
  property color colorProgressFg: "#ffb4a9"
  property color colorAccent:     "#ffb4a9"

  color:         "transparent"
  implicitWidth:  popupW
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
    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  Rectangle {
    anchors.fill: parent
    radius:  12
    opacity: Math.min(1.0, popup.slideProgress * 2)
    color:   Qt.rgba(popup.colorPanelBg.r, popup.colorPanelBg.g, popup.colorPanelBg.b, 0.95)

    MediaPlayerContent {
      anchors.fill:    parent
      barMediaPlayer:  popup.barMediaPlayer
      colorPanelBg:    popup.colorPanelBg
      colorText:       popup.colorText
      colorTextDim:    popup.colorTextDim
      colorProgressBg: popup.colorProgressBg
      colorProgressFg: popup.colorProgressFg
      colorAccent:     popup.colorAccent
      onCloseRequested: popup.closeRequested()
    }
  }
}
