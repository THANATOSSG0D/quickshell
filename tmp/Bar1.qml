import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
  id: barRoot

  BarState { id: barState }
  BarConfig { id: barConfig }

  readonly property int edgeThreshold: 5
  readonly property int hideDelayMs: 300

  property int cursorX: 0
  property int cursorY: 0
  property bool autoHide: true

  property string currentTheme: "Default"

  Connections {
    target: barConfig
    function onThemeChanged() {
      barRoot.currentTheme = barConfig.theme
    }
  }

  onCurrentThemeChanged: barConfig.theme = currentTheme

  GlobalShortcut {
    name: "toggleBar"
    description: "Toggle auto-hide da barra"
    onPressed: barRoot.autoHide = !barRoot.autoHide
  }

  GlobalShortcut {
    name: "nextTheme"
    description: "Next Theme for Bar"
    onPressed: {
      var themes = ["Default", "Minimal"]
      var idx = themes.indexOf(barRoot.currentTheme)
      barRoot.currentTheme = themes[(idx + 1) % themes.length]
    }
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: SplitParser {
      onRead: data => {
        var parts = data.split(",")
        if (parts.length === 2) {
          barRoot.cursorX = parseInt(parts[0].trim())
          barRoot.cursorY = parseInt(parts[1].trim())
        }
      }
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: cursorProc.running = true
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      id: bar

      color: 'transparent'

      // aboveWindows: true
      exclusionMode: ExclusionMode.Ignore

      // 1=topo  2=direita  3=baixo  4=esquerda
      property int position: 1
      property int barSize: 30
      property int barMargin: 0
      property bool pill: false 
      property int pillWidth: 600

      property int pillSideMargin: pill ? Math.max(0, Math.floor((screen.width - pillWidth) / 2)) : 0

      margins {
        top:    position === 1 ? barMargin - marginOffset : barMargin
        bottom: position === 3 ? barMargin - marginOffset : barMargin
        left:   position === 4 ? barMargin - marginOffset : (pill ? pillSideMargin : barMargin)
        right:  position === 2 ? barMargin - marginOffset : (pill ? pillSideMargin : barMargin)
      }

      anchors {
        top:    position === 1 || position === 2 || position === 4
        bottom: position === 3 || position === 2 || position === 4
        left:   position === 1 || position === 3 || position === 4
        right:  position === 1 || position === 3 || position === 2
      }

      implicitHeight: (position === 1 || position === 3) ? barSize : 0
      implicitWidth:  (position === 2 || position === 4) ? barSize : 0

      property bool animating: true
      property real marginOffset: 0 
      Behavior on marginOffset {
        enabled: bar.animating
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
      }

      onBarShowChanged: marginOffset = barShow ? 0 : barSize + barMargin + 1

      Loader {
        id: loader 
        anchors.fill: parent
        source: 'themes/' + barRoot.currentTheme + '.qml'

        onLoaded: {
          bar.position = item.position
          bar.barSize = item.barSize
          bar.barMargin = item.barMargin
          bar.pill = item.pill 
          bar.pillWidth = item.pillWidth

          bar.animating = false
          bar.marginOffset = barShow ? 0 : bar.barSize + bar.barMargin + 1
          bar.animating = true
        }
      }

      property var hyprMonitor: null
      Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
          for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (m.name === bar.screen.name) {
              bar.hyprMonitor = m
              return
            }
          }
          bar.hyprMonitor = null
        }
      }

      property bool hasWindows: {
        if (!hyprMonitor) return false
        var ws = hyprMonitor.activeWorkspace
        if (!ws) return false
        return ws.toplevels.values.length > 0
      }

      property bool cursorAtEdge: {
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barRoot.cursorX / scaleX
        var cy = barRoot.cursorY / scaleY

        var inScreen = cx >= screen.x
                    && cx <= screen.x + screen.width
                    && cy >= screen.y
                    && cy <= screen.y + screen.height
        if (!inScreen) return false

        var lx = cx - screen.x
        var ly = cy - screen.y

        // tolerância horizontal para pill — metade do barSize além da borda da pill
        var tolerance = barSize / 2

        if (position === 1 || position === 3) {
          // verifica borda vertical
          var atVertical = position === 1
            ? ly <= barRoot.edgeThreshold
            : ly >= screen.height - barRoot.edgeThreshold

          if (!atVertical) return false

          // se pill, verifica também se está dentro da área horizontal
          if (pill) {
            var pillLeft  = pillSideMargin - tolerance
            var pillRight = screen.width - pillSideMargin + tolerance
            return lx >= pillLeft && lx <= pillRight
          }
          return true
        }

        if (position === 4 || position === 2) {
          // verifica borda horizontal
          var atHorizontal = position === 4
            ? lx <= barRoot.edgeThreshold
            : lx >= screen.width - barRoot.edgeThreshold

          if (!atHorizontal) return false

          // se pill, verifica também se está dentro da área vertical
          if (pill) {
            var pillTop    = pillSideMargin - tolerance
            var pillBottom = screen.height - pillSideMargin + tolerance
            return ly >= pillTop && ly <= pillBottom
          }
          return true
        }

        return false
      }

      property bool barVisible: barRoot.autoHide ? (cursorAtEdge || !hasWindows) : true
      property bool barShow: true

      onBarVisibleChanged: {
        if (barVisible) {
          hideTimer.stop()
          barShow = true
        } else {
          hideTimer.restart()
        }
      }

      Timer {
        id: hideTimer
        interval: barRoot.hideDelayMs
        repeat: false
        onTriggered: bar.barShow = false
      }

      Component.onCompleted: { 
        // força hyprMonitor imediatamente sem esperar onValuesChanged
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
          var m = Hyprland.monitors.values[i]
          if (m.name === bar.screen.name) {
            bar.hyprMonitor = m
            break
          }
        }

        barShow = barVisible
        if (!barVisible) marginOffset = barSize + barMargin + 1
      }
    }
  }
}
