import Quickshell
import QtQuick
import "../bar" as Bar

Bar.BarPopup {
  id: popup

  property string mode: "drun"

  popupW: 300
  popupH: 420

  property color colorText:    "#e2e2e2"
  property color colorTextDim: "#c6c6c6"
  property color colorAccent:  "#ffb4a9"
  property color colorDivider: "#474747"
  property color colorInputBg: "#131313"

  onPanelOpenChanged: {
    if (panelOpen) content.activate()
  }

  DmenuContent {
    id:           content
    anchors.fill: parent
    mode:         popup.mode
    colorPanelBg: popup.colorPanelBg
    colorText:    popup.colorText
    colorTextDim: popup.colorTextDim
    colorAccent:  popup.colorAccent
    colorDivider: popup.colorDivider
    colorInputBg: popup.colorInputBg
    onCloseRequested: popup.closeRequested()
  }
}
