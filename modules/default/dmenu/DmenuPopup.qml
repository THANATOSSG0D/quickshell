import Quickshell
import QtQuick
import "../bar" as Bar
import "../dmenu" as DmenuModule

Bar.BarPopup {
  id: popup

  property string mode:      "drun"
  property string launchCmd: "uwsm app -- {exec}"
  property bool   showIcons: true

  // Dimensões lidas do DmenuConfig — mesma fonte que o DmenuPanel/IPC.
  // onCompleted seta os valores iniciais; Connections mantém em sync se mudar.
  Component.onCompleted: {
    popup.popupW = _cfg.dmenuPanelWidth
    popup.popupH = _cfg.dmenuPanelHeight
  }

  DmenuModule.DmenuConfig { id: _cfg }

  Connections {
    target: _cfg
    function onDmenuPanelWidthChanged()  { popup.popupW = _cfg.dmenuPanelWidth  }
    function onDmenuPanelHeightChanged() { popup.popupH = _cfg.dmenuPanelHeight }
  }

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
