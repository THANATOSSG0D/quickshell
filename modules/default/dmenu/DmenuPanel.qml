import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import "../bar" as Bar

Bar.BarPopup {
  id: panel
  objectName: "DmenuPopup"

  property string mode:       "drun"   // drun | run | window | script
  property string launchCmd:  "uwsm app -- {exec}"
  property bool   showIcons:   true
  property int    maxVisible:  12
  property string sortMode:    "name"
  property var    usageCount:  ({})
  property var    onRecordUsage: null

  property var    scriptEntries:  []
  property var    scriptThumbs:   []
  property string scriptPreview:  ""
  property string scriptPrompt:   ">"
  property string scriptLabel:    "SCRIPT"
  property string scriptSep:      ""
  property var    scriptKeybinds: {}
  property bool   scriptPassword: false
  property var    scriptCallback: null
  property var    backCallback:   null

  // popupW / popupH são controlados pelo PopupConfig (via BarPopup._applyConfig),
  // exatamente como todos os outros popups. O PanelTab grava em PopupConfig.set("popupW")
  // ao mover o slider, o _dep sobe, e o BarPopup reaplica automaticamente.
  // Sem necessidade de sentinels ou dmenuConfigRef aqui.

  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#1f1f1f"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#1f1f1f"

  property bool _callbackFired: false

  function open()  { _callbackFired = false; panelOpen = true  }
  function close() { panelOpen = false }

  onPanelOpenChanged: {
    if (panelOpen) {
      Qt.callLater(function() { content.activate() })
    }
  }

  onCloseRequested: {
    if (!_callbackFired) {
      _callbackFired = true
      if (scriptCallback) scriptCallback(null)
    }
  }

  property alias dmenuContent: content

  DmenuContent {
    id: content
    anchors.fill: parent

    mode:          panel.mode
    launchCmd:     panel.launchCmd
    showIcons:     panel.showIcons
    maxVisible:    panel.maxVisible
    sortMode:      panel.sortMode
    usageCount:    panel.usageCount
    onRecordUsage: panel.onRecordUsage

    scriptEntries:  panel.scriptEntries
    scriptThumbs:   panel.scriptThumbs
    scriptPreview:  panel.scriptPreview
    scriptPrompt:   panel.scriptPrompt
    scriptLabel:    panel.scriptLabel
    scriptSep:      panel.scriptSep
    scriptKeybinds: panel.scriptKeybinds
    scriptPassword: panel.scriptPassword

    colorPanelBg:  panel.colorPanelBg
    colorText:     panel.colorText
    colorTextDim:  panel.colorTextDim
    colorAccent:   panel.colorAccent
    colorSelected: panel.colorSelected
    colorDivider:  panel.colorDivider
    colorInputBg:  panel.colorInputBg

    onBackRequested: {
      if (panel.backCallback) panel.backCallback()
    }

    onCloseRequested: (selected, key) => {
      if (!panel._callbackFired) {
        var _t0 = Date.now()
        panel._callbackFired = true
        console.log("[dmenu][T+" + _t0 + "] DmenuPanel.onCloseRequested — selected:", JSON.stringify(selected), "key:", key)
        console.log("[dmenu][T+" + Date.now() + "] panelOpen = false (dt=" + (Date.now()-_t0) + "ms)")
        panel.panelOpen = false
        console.log("[dmenu][T+" + Date.now() + "] panelOpen FALSE OK — agora scriptCallback (dt=" + (Date.now()-_t0) + "ms)")
        if (panel.scriptCallback) {
          panel.scriptCallback(selected, key || "")
          console.log("[dmenu][T+" + Date.now() + "] scriptCallback RETORNOU (dt=" + (Date.now()-_t0) + "ms)")
        } else {
          console.log("[dmenu][T+" + Date.now() + "] sem scriptCallback")
        }
      }
    }
  }
}
