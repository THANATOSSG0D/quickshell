import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: win

  property bool   panelOpen:    false
  property color  colorBg:      "#1e1e2e"
  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property string initialTab:   "wallpaper"

  signal closeRequested()

  readonly property int winW: 860
  readonly property int winH: 640

  property real _animProg: 0.0
  property bool _alive:    false
  property bool _closing:  false

  visible: _alive

  onPanelOpenChanged: {
    if (panelOpen) {
      _closing = false; _alive = true
      _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
      openAnim.from = _animProg; openAnim.to = 1.0; openAnim.start()
      content.activeTab = initialTab
    } else {
      _closing = true; openAnim.stop()
      closeAnim.from = _animProg; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.restart()
    }
  }

  NumberAnimation {
    id: openAnim; target: win; property: "_animProg"
    duration: 220; easing.type: Easing.OutCubic
  }
  NumberAnimation {
    id: closeAnim; target: win; property: "_animProg"
    duration: 220; easing.type: Easing.OutCubic
    onStopped: { if (win._closing) _unmapTimer.restart() }
  }
  Timer {
    id: _unmapTimer; interval: 17
    onTriggered: { if (win._closing) { win._alive = false; win._closing = false } }
  }
  Timer {
    id: _safetyTimer; interval: 440
    onTriggered: { if (!win.panelOpen) { win._alive = false; win._closing = false; _unmapTimer.stop() } }
  }

  color: "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0

  anchors.top:    true
  anchors.bottom: true
  anchors.left:   true
  anchors.right:  true

  margins.top:    screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.bottom: screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.left:   screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0
  margins.right:  screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0

  HyprlandFocusGrab {
    windows:   [win]
    active:    win.panelOpen
    onCleared: win.closeRequested()
  }

  Rectangle {
    anchors.fill: parent
    radius: 16; clip: true
    opacity: Math.min(1.0, win._animProg * 1.4)
    transform: Translate { y: 12 * (1.0 - win._animProg) }
    color: Qt.rgba(win.colorBg.r, win.colorBg.g, win.colorBg.b, 0.97)
    layer.enabled: true

    WallpaperContent {
      id: content
      anchors.fill: parent
      panelOpen:    win.panelOpen
      colorBg:      win.colorBg
      colorText:    win.colorText
      colorTextDim: win.colorTextDim
      colorAccent:  win.colorAccent
      colorDivider: win.colorDivider
      // ← CORRIGIDO: conecta o sinal do content ao sinal da janela
      onCloseRequested: win.closeRequested()
    }
  }
}
