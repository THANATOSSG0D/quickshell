import Quickshell
import QtQuick
import "../bar" as Bar

// ── MediaPlayerPopup ──────────────────────────────────────────────────────
// Popup do media player. Filho QML do PanelWindow da barra.
// Posicionamento via anchor.window/rect/edges definido em Bar.qml.

Bar.BarPopup {
  id: popup
  objectName: "MediaPlayerPopup"

  property var barMediaPlayer: null

  popupW:      280
  popupH:      420
  animDuration: 320   // um pouco mais suave que os outros por ser maior

  // Cores herdadas do Bar.BarPopup — ver nota em VolumePopupTabbed.qml

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
