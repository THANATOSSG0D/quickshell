import Quickshell
import QtQuick
import "../bar" as Bar

// ── MediaPlayerPopup ──────────────────────────────────────────────────────
// Popup do media player. Filho QML do PanelWindow da barra.
// Posicionamento via anchor.window/rect/edges definido em Bar.qml.

Bar.BarPopup {
  id: popup

  property var barMediaPlayer: null

  popupW:      280
  popupH:      420
  animDuration: 320   // um pouco mais suave que os outros por ser maior

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorProgressBg: "#474747"
  property color colorProgressFg: "#ffb4a9"

  MediaPlayerContent {
    anchors.fill:    parent
    barMediaPlayer:  popup.barMediaPlayer
    panelOpen:       popup.panelOpen
    colorPanelBg:    popup.colorPanelBg
    colorText:       popup.colorText
    colorTextDim:    popup.colorTextDim
    colorAccent:     popup.colorAccent
    colorProgressBg: popup.colorProgressBg
    colorProgressFg: popup.colorProgressFg
    onCloseRequested: popup.closeRequested()
  }
}
