import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── VolumePanel ───────────────────────────────────────────────────────────
// PanelWindow que exibe o VolumeContent.
// Use apenas quando precisar de ancoragem permanente com exclusiveZone.
// Para painéis que abrem/fecham na barra, use VolumePopup.

PanelWindow {
  id: panel

  required property var barScreen
  required property int barPosition
  required property int barSize
  required property int barMargin
  required property int panelWidth

  property bool showOnlySink:   false
  property bool showOnlySource: false

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorMuted:      "#cf6679"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  screen:        barScreen
  color:         "transparent"
  exclusionMode: ExclusionMode.Ignore

  readonly property bool barIsHorizontal: barPosition === 1 || barPosition === 3
  readonly property int  panelH: 380

  anchors.top:    barPosition === 1 || barPosition === 2 || barPosition === 4
  anchors.bottom: barPosition === 3 || barPosition === 2 || barPosition === 4
  anchors.left:   barPosition === 4 || barPosition === 1 || barPosition === 3
  anchors.right:  barPosition === 2 || barPosition === 1 || barPosition === 3

  implicitWidth:  barIsHorizontal ? 1      : panelWidth
  implicitHeight: barIsHorizontal ? panelH : 1

  property int sidePad: barIsHorizontal
    ? Math.max(0, Math.floor((barScreen.width  - panelWidth) / 2))
    : Math.max(0, Math.floor((barScreen.height - panelH)     / 2))

  margins.top:    barPosition === 1 ? barMargin + barSize : sidePad
  margins.bottom: barPosition === 3 ? barMargin + barSize : sidePad
  margins.left:   barPosition === 4 ? barMargin + barSize : sidePad
  margins.right:  barPosition === 2 ? barMargin + barSize : sidePad

  property bool panelOpen: false
  property real slideProgress: 0.0

  visible: slideProgress > 0.0

  signal closeRequested()

  HyprlandFocusGrab {
    windows: [ panel ]
    active:  panel.panelOpen
    onCleared: panel.closeRequested()
  }

  Behavior on slideProgress {
    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  Item {
    id: clipContainer
    clip:    true
    opacity: Math.min(1.0, panel.slideProgress * 2)

    anchors.top:    barPosition === 1 ? parent.top    : undefined
    anchors.bottom: barPosition === 3 ? parent.bottom : undefined
    anchors.left:   barPosition === 4 ? parent.left   : undefined
    anchors.right:  barPosition === 2 ? parent.right  : undefined

    width: {
      if (barPosition === 2 || barPosition === 4) return parent.width * panel.slideProgress
      return parent.width
    }
    height: {
      if (barPosition === 1 || barPosition === 3) return parent.height * panel.slideProgress
      return parent.height
    }

    Rectangle {
      anchors.fill: parent; radius: 12
      color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g, panel.colorPanelBg.b, 0.95)
    }
    Rectangle {
      color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g, panel.colorPanelBg.b, 0.95)
      anchors.top:    barPosition === 1 ? parent.top    : panel.barIsHorizontal ? parent.top    : undefined
      anchors.bottom: barPosition === 3 ? parent.bottom : panel.barIsHorizontal ? parent.bottom : undefined
      anchors.left:   barPosition === 4 ? parent.left   : !panel.barIsHorizontal ? parent.left  : undefined
      anchors.right:  barPosition === 2 ? parent.right  : !panel.barIsHorizontal ? parent.right : undefined
      width:  barPosition === 2 || barPosition === 4 ? 12 : parent.width
      height: barPosition === 1 || barPosition === 3 ? 12 : parent.height
    }

    VolumeContent {
      anchors.fill:    parent
      showOnlySink:    panel.showOnlySink
      showOnlySource:  panel.showOnlySource
      colorPanelBg:    panel.colorPanelBg
      colorText:       panel.colorText
      colorTextDim:    panel.colorTextDim
      colorAccent:     panel.colorAccent
      colorMuted:      panel.colorMuted
      colorProgressBg: panel.colorProgressBg
      colorDivider:    panel.colorDivider
      onCloseRequested: panel.closeRequested()
    }
  }
}
