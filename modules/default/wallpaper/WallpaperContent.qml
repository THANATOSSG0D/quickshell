import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property color  colorBg:      "#1e1e2e"
  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string activeTab:    "wallpaper"

  // ← CORRIGIDO: nome consistente com WallpaperWindow
  signal closeRequested()

  property string mlScripts: "/home/antonio/.config/ml4w/scripts"
  property string wallSh:    mlScripts + "/wallpaper.sh"
  property string wpRun:     mlScripts + "/wp-run"
  readonly property string effectsDir:  "/home/antonio/.config/hypr/effects/wallpaper"
  readonly property string previewDir:  "/home/antonio/.config/ml4w/cache/effect-previews"

  property string currentEffect:    "off"
  property string currentPalette:   "scheme-fidelity"
  property string currentSource:    "base"
  property int    currentIndex:     0
  property string currentWallpaper: ""
  property string currentEngine:    "swww"

  readonly property var tabs: [
    { id: "wallpaper", icon: "\uf03e", label: "Wallpaper" },
    { id: "matugen",   icon: "\uf53f", label: "Matugen"   },
    { id: "profiles",  icon: "\uf097", label: "Perfis"    },
    { id: "history",   icon: "\uf1da", label: "Histórico" },
    { id: "schedule",  icon: "\uf017", label: "Schedule"  }
  ]

  ColumnLayout {
    anchors.fill: parent; spacing: 0

    Item {
      Layout.fillWidth: true; height: 50

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 12
        spacing: 0

        Text {
          text: "\uf03e  Wallpaper"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
          color: root.colorAccent; opacity: 0.9
        }

        Item { Layout.fillWidth: true }

        Repeater {
          model: root.tabs
          delegate: Item {
            width: tabRow.implicitWidth + 24; height: 34
            readonly property bool isActive: root.activeTab === modelData.id

            Rectangle {
              anchors.fill: parent; radius: 8
              color: isActive
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                : (tma.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }
            }

            RowLayout {
              id: tabRow
              anchors.centerIn: parent; spacing: 5
              Text {
                text: modelData.icon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                color: isActive ? root.colorAccent : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
              Text {
                text: modelData.label; font.pixelSize: 11
                color: isActive ? root.colorText : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
            }

            Rectangle {
              anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 4 }
              height: 2; radius: 1; color: root.colorAccent
              opacity: isActive ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            MouseArea {
              id: tma; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = modelData.id
            }
          }
        }

        Item {
          width: 34; height: 34
          Rectangle {
            anchors.fill: parent; radius: 8
            color: cma.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
              anchors.centerIn: parent; text: "\uf00d"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
              color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g,
                             root.colorTextDim.b, cma.containsMouse ? 1.0 : 0.5)
            }
          }
          MouseArea {
            id: cma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
          }
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: root.colorDivider; opacity: 0.5
      }
    }

    Item {
      Layout.fillWidth: true; Layout.fillHeight: true

      WallpaperTabWallpapers {
        anchors.fill: parent
        visible:          root.activeTab === "wallpaper"
        panelOpen:        root.panelOpen && root.activeTab === "wallpaper"
        colorText:        root.colorText
        colorTextDim:     root.colorTextDim
        colorAccent:      root.colorAccent
        colorDivider:     root.colorDivider
        mlScripts:        root.mlScripts
        wallSh:           root.wallSh
        wpRun:            root.wpRun
        currentWallpaper: root.currentWallpaper
        currentEngine:    root.currentEngine
        onWallpaperApplied: function(src) { root.currentWallpaper = src }
        onEngineSelected:   function(e)   { root.currentEngine = e }
        onRefreshState:     function()    { _refreshState() }
      }

      WallpaperTabMatugen {
        anchors.fill: parent
        visible:         root.activeTab === "matugen"
        panelOpen:       root.panelOpen && root.activeTab === "matugen"
        colorText:       root.colorText
        colorTextDim:    root.colorTextDim
        colorAccent:     root.colorAccent
        colorDivider:    root.colorDivider
        mlScripts:       root.mlScripts
        wallSh:          root.wallSh
        wpRun:           root.wpRun
        effectsDir:      root.effectsDir
        previewDir:      root.previewDir
        currentEffect:   root.currentEffect
        currentPalette:  root.currentPalette
        currentSource:   root.currentSource
        currentIndex:    root.currentIndex
        onEffectSelected:         function(e) { root.currentEffect  = e }
        onPaletteSelected:        function(p) { root.currentPalette = p }
        onMatugenSourceSelected:  function(s) { root.currentSource  = s }
        onIndexSelected:          function(i) { root.currentIndex   = i }
        onRefreshState:           function()  { _refreshState() }
      }

      WallpaperTabProfiles {
        anchors.fill: parent
        visible:      root.activeTab === "profiles"
        panelOpen:    root.panelOpen && root.activeTab === "profiles"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        wallSh:       root.wallSh
        wpRun:        root.wpRun
        onRefreshState: function() { _refreshState() }
      }

      WallpaperTabHistory {
        anchors.fill: parent
        visible:      root.activeTab === "history"
        panelOpen:    root.panelOpen && root.activeTab === "history"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        wpRun:        root.wpRun
        onRefreshState: function() { _refreshState() }
      }

      WallpaperTabSchedule {
        anchors.fill: parent
        visible:      root.activeTab === "schedule"
        panelOpen:    root.panelOpen && root.activeTab === "schedule"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        effectsDir:   root.effectsDir
        previewDir:   root.previewDir
        wpRun:        root.wpRun
      }
    }
  }

  function _refreshState() {
    if (!stateProc.running) stateProc.running = true
  }

  Process {
    id: stateProc
    command: ["bash", "-c",
      "PYTHONPATH='" + root.mlScripts + "' " +
      "python3 -c \"\n" +
      "import sys; sys.path.insert(0,'" + root.mlScripts + "')\n" +
      "from wp import state as S\n" +
      "d = S.read_all()\n" +
      "import os\n" +
      "print(d.get('effect','off'))\n" +
      "print(d.get('palette','scheme-fidelity'))\n" +
      "print(d.get('matugen_source','base'))\n" +
      "print(d.get('matugen_index',0))\n" +
      "print(d.get('source',''))\n" +
      "print(open(os.path.expanduser('~/.config/ml4w/settings/wallpaper-engine.sh')).read().strip() if os.path.isfile(os.path.expanduser('~/.config/ml4w/settings/wallpaper-engine.sh')) else 'swww')\n" +
      "\""
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { stateProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        var lines = stateProc._buf.trim().split("\n")
        stateProc._buf = ""
        if (lines.length >= 6) {
          root.currentEffect    = lines[0].trim() || "off"
          root.currentPalette   = lines[1].trim() || "scheme-fidelity"
          root.currentSource    = lines[2].trim() || "base"
          root.currentIndex     = parseInt(lines[3].trim()) || 0
          root.currentWallpaper = lines[4].trim()
          root.currentEngine    = lines[5].trim() || "swww"
        }
      }
    }
  }

  onPanelOpenChanged: { if (panelOpen) _refreshState() }
}
