import Quickshell
import QtQuick
import "../bar" as Bar

// ── VolumePopup ───────────────────────────────────────────────────────────
// Popup de volume (sink ou source). Filho QML do PanelWindow da barra.
// Posicionamento via anchor.window/rect/edges definido em Bar.qml.

Bar.BarPopup {
  id: popup
  objectName: "VolumePopupTabbed"

  property bool showOnlySink:   false
  property bool showOnlySource: false

  popupW: 280
  popupH: 380

  // Cores herdadas do Bar.BarPopup — ver nota em VolumePopupTabbed.qml

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
