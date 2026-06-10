import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../bar" as Bar

Bar.BarPopup {
  id: panel

  property string mode:       "drun"   // drun | run | window | script
  property string launchCmd:  "uwsm app -- {exec}"
  property bool   showIcons:   true
  property int    maxVisible:  12       // ← agora passado por DmenuIpc._showTop()
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

  // popupW/popupH injetados por DmenuIpc._showTop() a partir do DmenuConfig.
  // Mantemos o fallback via barRef para o caso de uso standalone (ex: testes).
  popupW: barRef ? barRef.parent.themePanelWidth : 320
  popupH: barRef ? barRef.parent.popupHDmenu     : 460

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
    if (panelOpen) content.activate()
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

    mode:       panel.mode
    launchCmd:  panel.launchCmd
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
        panel._callbackFired = true
        panel.panelOpen = false
        if (panel.scriptCallback) panel.scriptCallback(selected, key || "")
      }
    }
  }
}
