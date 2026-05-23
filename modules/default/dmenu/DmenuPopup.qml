import Quickshell
import QtQuick
import "../bar" as Bar

Bar.BarPopup {
  id: popup

  property string mode:      "drun"
  property string launchCmd: "uwsm app -- {exec}"
  property bool   showIcons: true

  popupW: 320
  popupH: 460

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
    launchCmd:    popup.launchCmd
    showIcons:    popup.showIcons
    colorPanelBg: popup.colorPanelBg
    colorText:    popup.colorText
    colorTextDim: popup.colorTextDim
    colorAccent:  popup.colorAccent
    colorDivider: popup.colorDivider
    colorInputBg: popup.colorInputBg
    // selected é null em todos os modos nativos (drun/run/window executam direto)
    onCloseRequested: popup.closeRequested()
  }
}
