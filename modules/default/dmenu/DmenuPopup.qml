import Quickshell
import QtQuick
import "../bar" as Bar
import "../dmenu" as DmenuModule

Bar.BarPopup {
  id: popup

  // Necessário pro _applyConfig() do BarPopup encontrar o override certo em
  // PopupConfig.json/DockPopupConfig.json (overrides["DmenuPopup"]). Sem
  // isso, configName||objectName cai em "" e _applyConfig() retorna cedo —
  // cornerMode, bgRadius, animationStyle etc. nunca são lidos do JSON,
  // ficando presos nos defaults hardcoded do BarPopup.qml.
  objectName: "DmenuPopup"

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

  // colorText/colorTextDim/colorAccent/colorDivider herdadas do Bar.BarPopup
  // — ver nota em VolumePopupTabbed.qml. colorInputBg fica local porque não
  // existe no conjunto de cores do BarPopup (é específica do Dmenu).
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
