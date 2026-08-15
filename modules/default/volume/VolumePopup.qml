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

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorMuted:      "#cf6679"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

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
