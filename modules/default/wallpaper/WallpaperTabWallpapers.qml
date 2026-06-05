import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  property color  colorText:        "#e2e2e2"
  property color  colorTextDim:     "#888888"
  property color  colorAccent:      "#ffb4a9"
  property color  colorDivider:     "#333333"
  property bool   panelOpen:        false
  property string mlScripts:        ""
  property string wallSh:           ""
  property string wpRun:            ""
  property string effectsDir:       ""
  property string currentWallpaper: ""
  property string currentEngine:    "swww"
  // Estado atual do sistema (vindo do WallpaperContent via _refreshState)
  property string currentEffect:    "off"
  property string currentPalette:   "scheme-fidelity"
  property string currentSource:    "base"
  property int    currentIndex:     0

  signal wallpaperApplied(string src)
  signal engineSelected(string engine)
  signal refreshState()
  signal wallpaperPicked(string path)
  signal wallpaperRightClicked(string path, real mouseX, real mouseY)

  // ── Estado interno ────────────────────────────────────────────────────────
  property var    allEntries:    []
  property bool   loading:       false
  property bool   applying:      false
  property string applyingPath:  ""

  // ── Filtro de hue (igual ao Schedule) ────────────────────────────────────
  property real   hueFilter:  -1    // -1=todos, -2=P&B, 0..359=hue central
  readonly property real hueWindow: 35

  function _hueDist(a, b) {
    var d = Math.abs(a - b) % 360
    return d > 180 ? 360 - d : d
  }

  readonly property var filteredEntries: {
    if (hueFilter < 0) {
      if (hueFilter === -2) {
        var mono = []
        for (var i = 0; i < allEntries.length; i++) {
          if ((allEntries[i].hue !== undefined ? allEntries[i].hue : -1) < 0) mono.push(allEntries[i])
        }
        return mono
      }
      return allEntries
    }
    var out = []
    for (var j = 0; j < allEntries.length; j++) {
      var h = allEntries[j].hue !== undefined ? allEntries[j].hue : -1
      if (h >= 0 && _hueDist(h, hueFilter) <= hueWindow) out.push(allEntries[j])
    }
    return out
  }

  // ── Painel de configuração colapsável ─────────────────────────────────────
  property bool   configOpen:        false

  // Cópia local dos campos editáveis (para edição antes de aplicar)
  property string editEffect:   "off"
  property string editPalette:  "scheme-fidelity"
  property string editSource:   "base"
  property int    editIndex:    0

  // Sincroniza os campos locais quando o estado global muda
  onCurrentEffectChanged:  { if (!configOpen) editEffect  = currentEffect  }
  onCurrentPaletteChanged: { if (!configOpen) editPalette = currentPalette }
  onCurrentSourceChanged:  { if (!configOpen) editSource  = currentSource  }
  onCurrentIndexChanged:   { if (!configOpen) editIndex   = currentIndex   }

  // Swatches de cor do wallpaper atual
  property var    swatchColors:    []
  property bool   loadingSwatches: false

  // Previews de efeito do wallpaper atual
  property var    effectPreviews:       ({})
  property bool   generatingEffectPrev: false
  property int    effectPrevVersion:    0

  // Lista de efeitos disponíveis
  property var    effectList: ["off"]

  readonly property var allPalettes: [
    "scheme-content", "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow", "scheme-tonal-spot"
  ]

  readonly property var matugenSources: [
    { id: "base",  label: "base"  },
    { id: "final", label: "final" }
  ]

  // ── Engines ───────────────────────────────────────────────────────────────
  readonly property var engines: [
    { id: "swww",      icon: "\uf0ac", label: "swww"      },
    { id: "hyprpaper", icon: "\uf2db", label: "hyprpaper" },
    { id: "mpvpaper",  icon: "\uf03d", label: "mpvpaper"  },
    { id: "awww",      icon: "\uf185", label: "awww"      }
  ]

  // ═══════════════════════════════════════════════════════════════════════════
  // Processos
  // ═══════════════════════════════════════════════════════════════════════════

  Process {
    id: loadProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { loadProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        root.loading = false
        var raw = loadProc._buf.trim(); loadProc._buf = ""
        if (!raw) return
        try {
          var data = JSON.parse(raw)
          var arr = []
          for (var i = 0; i < data.length; i++) {
            var e = data[i]
            arr.push({ label: e.label || "", value: e.value || "", thumb: e.thumb || "", hue: -1 })
          }
          root.allEntries = arr
          hueQueue._idx = 0; hueQueue._run()
        } catch(ex) {}
      }
    }
  }

  QtObject {
    id: hueQueue
    property int _idx: 0
    function _run() {
      if (_idx >= root.allEntries.length) return
      var e = root.allEntries[_idx]
      if (!e.thumb || e.thumb === "") { _idx++; _run(); return }
      hueProc.command = ["bash", "-c",
        "magick '" + e.thumb + "' -resize 1x1! -format '%[fx:hue*360]\\n%[fx:saturation]' info: 2>/dev/null || printf -- '-1\\n0'"]
      hueProc.running = true
    }
  }

  Process {
    id: hueProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { hueProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      var lines = hueProc._buf.trim().split("\n"); hueProc._buf = ""
      var h = parseFloat(lines[0]) || -1
      var s = parseFloat(lines[1]) || 0
      if (s < 0.12) h = -1
      var idx = hueQueue._idx
      if (idx < root.allEntries.length) {
        var arr = root.allEntries.slice()
        var e = arr[idx]
        arr[idx] = { label: e.label, value: e.value, thumb: e.thumb, hue: h }
        root.allEntries = arr
      }
      hueQueue._idx++; hueQueue._run()
    }
  }

  // Carrega lista de efeitos disponíveis
  Process {
    id: efxListProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { efxListProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      var raw = efxListProc._buf.trim(); efxListProc._buf = ""
      var list = ["off"]
      raw.split("\n").forEach(function(l) { var t = l.trim(); if (t) list.push(t) })
      root.effectList = list
    }
  }

  function _loadEffectList() {
    if (efxListProc.running) return
    efxListProc.command = ["bash", "-c",
      "ls '" + root.effectsDir + "' 2>/dev/null | sort"
    ]
    efxListProc.running = true
  }

  // Swatches do wallpaper atual
  Process {
    id: swatchProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { swatchProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.loadingSwatches = false
      var raw = swatchProc._buf.trim(); swatchProc._buf = ""
      var colors = []
      raw.split("\n").forEach(function(l) {
        var c = l.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(c)) colors.push(c)
      })
      root.swatchColors = colors
    }
  }

  function _loadSwatches(wallpaperPath, msrc) {
    if (swatchProc.running) return
    if (!wallpaperPath || wallpaperPath === "") return
    root.loadingSwatches = true
    root.swatchColors = []
    var script = root.mlScripts + "/slot-matugen-colors"
    swatchProc.command = ["bash", script, wallpaperPath, msrc || "base"]
    swatchProc.running = true
  }

  // Previews de efeito do wallpaper atual
  Process {
    id: efxPreviewProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { efxPreviewProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.generatingEffectPrev = false
      var raw = efxPreviewProc._buf.trim(); efxPreviewProc._buf = ""
      var map = {}
      raw.split("\n").forEach(function(l) {
        var m = l.match(/^([^=]+)=(.+)$/)
        if (m) map[m[1].trim()] = m[2].trim()
      })
      root.effectPreviews = map
      root.effectPrevVersion++
    }
  }

  function _loadEffectPreviews(wallpaperPath) {
    if (efxPreviewProc.running || !wallpaperPath || wallpaperPath === "") return
    root.generatingEffectPrev = true
    root.effectPreviews = {}
    // slot "0" como chave de cache (wallpaper atual usa slot fictício 0)
    var script = root.mlScripts + "/slot-effect-previews"
    efxPreviewProc.command = ["bash", script, "current", wallpaperPath]
    efxPreviewProc.running = true
  }

  // Processo de aplicação rápida (engine)
  Process {
    id: fastApplyProc
    property string _pendingPath: ""
    stdout: SplitParser { onRead: function(l) {} }
    onRunningChanged: {
      if (!running) {
        root.currentWallpaper = fastApplyProc._pendingPath
        root.wallpaperApplied(fastApplyProc._pendingPath)
        root.applying = false
        bgPipelineProc.command = [root.wpRun, "--bg-pipeline", fastApplyProc._pendingPath]
        bgPipelineProc.running = true
      }
    }
  }

  Process {
    id: bgPipelineProc
    stdout: SplitParser { onRead: function(l) {} }
    onRunningChanged: {
      if (!running) bgRefreshDelay.restart()
    }
  }

  Timer {
    id: bgRefreshDelay; interval: 2500; repeat: false
    onTriggered: root.refreshState()
  }

  function _engineCmd(path) {
    var e = root.currentEngine
    if (e === "swww")
      return "swww img '" + path + "' --transition-type any --transition-duration 0.8 2>/dev/null || swww img '" + path + "' --transition-type none 2>/dev/null"
    if (e === "hyprpaper")
      return "hyprctl hyprpaper wallpaper '," + path + "' 2>/dev/null"
    if (e === "mpvpaper")
      return "pkill -x mpvpaper 2>/dev/null || true; sleep 0.1; mpvpaper -o 'no-audio loop-file=inf' '*' '" + path + "' &"
    return "swww img '" + path + "' --transition-type none 2>/dev/null"
  }

  function _apply(path) {
    if (fastApplyProc.running || root.applying) return
    root.applying = true
    root.applyingPath = path
    fastApplyProc._pendingPath = path
    fastApplyProc.command = ["bash", "-c", root._engineCmd(path)]
    fastApplyProc.running = true
  }

  // Processo de troca de engine
  Process {
    id: engineProc
    stdout: SplitParser { onRead: function(l) {} }
    onRunningChanged: {
      if (!running) root.refreshState()
    }
  }

  function _setEngine(e) {
    if (engineProc.running) return
    root.currentEngine = e
    root.engineSelected(e)
    engineProc.command = ["bash", "-c",
      "pkill -x awww-daemon 2>/dev/null; pkill -x hyprpaper 2>/dev/null; pkill -x mpvpaper 2>/dev/null; pkill -x swww-daemon 2>/dev/null; sleep 0.4;" +
      "echo '" + e + "' > ~/.config/ml4w/settings/wallpaper-engine.sh;" +
      "case '" + e + "' in swww) swww-daemon &; sleep 0.4;; hyprpaper) hyprpaper &; sleep 0.4;; awww) awww-daemon &; sleep 0.4;; esac;" +
      "exec '" + root.wpRun + "' --quiet"
    ]
    engineProc.running = true
  }

  // Processo de save de configuração (palette/efeito/fonte/índice)
  Process {
    id: saveConfigProc
    stdout: SplitParser { onRead: function(l) {} }
    onRunningChanged: {
      if (!running) root.refreshState()
    }
  }

  function _saveConfig() {
    if (saveConfigProc.running) return
    var cacheDir = root.mlScripts.replace(/\/scripts$/, "/cache")
    saveConfigProc.command = ["bash", "-c",
      "echo '" + root.editEffect  + "' > ~/.config/ml4w/settings/wallpaper-effect.sh\n" +
      "echo '" + root.editPalette + "' > ~/.config/ml4w/settings/matugen-pallete.sh\n" +
      "echo '" + root.editSource  + "' > " + cacheDir + "/matugen-source\n" +
      "echo '" + root.editIndex   + "' > " + cacheDir + "/matugen-color\n" +
      "exec '" + root.wpRun + "' --quiet 2>/dev/null"
    ]
    saveConfigProc.running = true
  }

  onPanelOpenChanged: {
    if (panelOpen && allEntries.length === 0 && !loading) {
      loading = true
      loadProc.command = ["bash", "-c",
        "qs_wp=\"$(dirname '" + root.mlScripts + "')/../quickshell/modules/default/wallpaper/wp-dmenu-entries\";" +
        "ml_wp='" + root.mlScripts + "/wp-dmenu-entries';" +
        "if [ -f \"$qs_wp\" ]; then python3 \"$qs_wp\" folder;" +
        "elif [ -f \"$ml_wp\" ]; then python3 \"$ml_wp\" folder; fi 2>/dev/null"
      ]
      if (!loadProc.running) loadProc.running = true
    }
    if (panelOpen) {
      _loadEffectList()
      editEffect  = currentEffect
      editPalette = currentPalette
      editSource  = currentSource
      editIndex   = currentIndex
    }
  }

  // Quando o wallpaper muda, abre o painel e recarrega swatches/previews
  onCurrentWallpaperChanged: {
    if (currentWallpaper !== "") {
      root.configOpen = true
      _loadSwatches(currentWallpaper, editSource)
      _loadEffectPreviews(currentWallpaper)
    }
  }

  // Recarrega swatches ao mudar fonte
  onEditSourceChanged: {
    if (currentWallpaper !== "") _loadSwatches(currentWallpaper, editSource)
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  ColumnLayout {
    anchors.fill: parent; spacing: 0

    // ── Toolbar: engines + status + config toggle ─────────────────────────
    Item {
      Layout.fillWidth: true; height: 42

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 6

        Repeater {
          model: root.engines
          delegate: Item {
            width: ec.implicitWidth; height: 28
            readonly property bool isCurr: root.currentEngine === modelData.id
            Rectangle {
              id: ec; anchors.fill: parent; radius: 14
              implicitWidth: er.implicitWidth + 20
              color: isCurr ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                            : (ema.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
              border.color: isCurr ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: isCurr ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 110 } }
              Row {
                id: er; anchors.centerIn: parent; spacing: 4
                Text {
                  text: modelData.icon
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                  color: isCurr ? root.colorAccent : root.colorTextDim
                  Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                  text: modelData.label; font.pixelSize: 10
                  color: isCurr ? root.colorText : root.colorTextDim
                  Behavior on color { ColorAnimation { duration: 110 } }
                }
              }
            }
            MouseArea {
              id: ema; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._setEngine(modelData.id)
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Spinner aplicando
        Row {
          spacing: 5; visible: root.applying
          Text {
            text: "\uf110"; anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            color: root.colorAccent; opacity: 0.8
            RotationAnimator on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.applying }
          }
          Text { text: "aplicando..."; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 10; color: root.colorTextDim }
        }


        // Reload wallpapers
        Item {
          width: 26; height: 26; visible: !root.applying
          Text {
            anchors.centerIn: parent; text: "\uf021"
            font.pixelSize: 12
            color: root.loading
              ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.4)
              : root.colorAccent
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.loading) {
                root.allEntries = []; root.loading = true
                if (!loadProc.running) loadProc.running = true
              }
            }
          }
        }
      }

      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.colorDivider; opacity: 0.3 }
    }

    // ── Filtro de hue: botões + slider ────────────────────────────────────
    Item {
      Layout.fillWidth: true; height: 44

      Row {
        id: wallFilterBtns
        anchors.left: parent.left; anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Rectangle {
          width: wallTodosT.implicitWidth + 14; height: 22; radius: 11
          color: root.hueFilter < 0 && root.hueFilter !== -2
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
            : (wallTodosMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))
          border.color: (root.hueFilter < 0 && root.hueFilter !== -2) ? root.colorAccent : Qt.rgba(1,1,1,0.12)
          border.width: (root.hueFilter < 0 && root.hueFilter !== -2) ? 1.5 : 1
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            id: wallTodosT; anchors.centerIn: parent; text: "Todos"; font.pixelSize: 9
            color: (root.hueFilter < 0 && root.hueFilter !== -2) ? root.colorAccent : root.colorTextDim
          }
          MouseArea { id: wallTodosMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.hueFilter = -1 }
        }

        Rectangle {
          width: wallPbT.implicitWidth + 14; height: 22; radius: 11
          color: root.hueFilter === -2
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
            : (wallPbMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))
          border.color: root.hueFilter === -2 ? root.colorAccent : Qt.rgba(1,1,1,0.12)
          border.width: root.hueFilter === -2 ? 1.5 : 1
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            id: wallPbT; anchors.centerIn: parent; text: "P&B"; font.pixelSize: 9
            color: root.hueFilter === -2 ? root.colorAccent : root.colorTextDim
          }
          MouseArea { id: wallPbMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.hueFilter = -2 }
        }
      }

      Item {
        anchors.left: wallFilterBtns.right; anchors.leftMargin: 10
        anchors.right: parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 22

        Rectangle {
          id: wallHueTrack
          anchors.left: parent.left; anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 12; radius: 6
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "#e05555" }
            GradientStop { position: 0.08; color: "#e07d30" }
            GradientStop { position: 0.17; color: "#d4c840" }
            GradientStop { position: 0.33; color: "#4caf6f" }
            GradientStop { position: 0.50; color: "#3aabb8" }
            GradientStop { position: 0.61; color: "#4a78d4" }
            GradientStop { position: 0.75; color: "#8b4fd4" }
            GradientStop { position: 0.89; color: "#d44f9a" }
            GradientStop { position: 1.00; color: "#e05555" }
          }
          opacity: root.hueFilter >= 0 ? 1.0 : 0.35
          Behavior on opacity { NumberAnimation { duration: 150 } }

          MouseArea {
            anchors.fill: parent
            onPressed:         function(e) { _pick(e.x) }
            onPositionChanged: function(e) { if (pressed) _pick(e.x) }
            function _pick(x) {
              root.hueFilter = Math.max(0, Math.min(359, (x / wallHueTrack.width) * 359))
            }
          }

          Rectangle {
            visible: root.hueFilter >= 0
            width: 18; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: root.hueFilter >= 0
               ? Math.max(-4, Math.min(wallHueTrack.width - 14, (root.hueFilter / 359) * wallHueTrack.width - 9))
               : -20
            color: "white"
            border.color: Qt.rgba(0,0,0,0.4); border.width: 2
            Behavior on x { NumberAnimation { duration: 60 } }
            Rectangle {
              anchors.centerIn: parent; width: 10; height: 10; radius: 5
              color: Qt.hsla(root.hueFilter >= 0 ? root.hueFilter / 360 : 0, 0.75, 0.55, 1.0)
            }
          }
        }
      }

      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.colorDivider; opacity: 0.2 }
    }

    // ── Grid de wallpapers ────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true; Layout.fillHeight: true

      Text {
        anchors.centerIn: parent; visible: root.loading
        text: "\uf110  carregando..."
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
        color: root.colorTextDim; opacity: 0.6
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.loading }
      }

      GridView {
        id: wallpaperGrid
        anchors { fill: parent; margins: 10 }
        visible: !root.loading; clip: true
        cellWidth:  Math.floor((width - 4) / 3)
        cellHeight: cellWidth * 9 / 16 + 24
        model: root.filteredEntries
        property int hoveredIdx: -1
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
          width:  wallpaperGrid.cellWidth
          height: wallpaperGrid.cellHeight
          readonly property bool isHovered: wallpaperGrid.hoveredIdx === index
          readonly property bool isCurrent: modelData.value === ("file:" + root.currentWallpaper)
          readonly property string thumbPath: modelData.thumb || ""

          Rectangle {
            anchors { fill: parent; margins: 3 }
            radius: 8; clip: true
            color: isCurrent ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12) : Qt.rgba(1,1,1,0.04)
            border.color: isCurrent ? root.colorAccent : isHovered ? Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.25) : "transparent"
            border.width: isCurrent ? 1.5 : 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Image {
              id: thumbImg
              anchors { top: parent.top; left: parent.left; right: parent.right }
              height: parent.width * 9 / 16
              fillMode: Image.PreserveAspectCrop
              source: thumbPath !== "" ? ("file://" + thumbPath) : ""
              asynchronous: true; cache: true; smooth: true

              Rectangle { anchors.fill: parent; visible: thumbImg.status !== Image.Ready; color: Qt.rgba(1,1,1,0.04); radius: parent.radius }

              Rectangle {
                visible: isCurrent
                anchors { top: parent.top; right: parent.right; margins: 4 }
                width: 18; height: 18; radius: 9; color: root.colorAccent
                Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; color: "#1f1f1f" }
              }

              Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; margins: 3 }
                visible: tileArea.containsMouse && !isCurrent
                radius: 4; color: Qt.rgba(0,0,0,0.60)
                width: rcHint.implicitWidth + 8; height: 14
                Text {
                  id: rcHint; anchors.centerIn: parent
                  text: "⏰ slot"
                  font.pixelSize: 8
                  color: root.colorAccent
                }
              }
            }

            Text {
              anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 4 }
              height: 20; text: modelData.label || ""; font.pixelSize: 9
              color: isHovered ? root.colorText : root.colorTextDim
              elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
              Behavior on color { ColorAnimation { duration: 100 } }
            }
          }

          MouseArea {
            id: tileArea
            anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: wallpaperGrid.hoveredIdx = index
            onExited:  if (wallpaperGrid.hoveredIdx === index) wallpaperGrid.hoveredIdx = -1
            onClicked: function(mouse) {
              var path = modelData.value.replace(/^file:/, "")
              if (mouse.button === Qt.RightButton) {
                var gpos = tileArea.mapToGlobal(mouse.x, mouse.y)
                root.wallpaperRightClicked(path, gpos.x, gpos.y)
              } else {
                root.wallpaperPicked(path)
                root._apply(path)
              }
            }
          }
        }
      }
    }

    // ── Painel de configuração colapsável ─────────────────────────────────
    Item {
      Layout.fillWidth: true
      height: root.configOpen ? configColumn.height + 16 : 0
      clip: true
      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
        border.width: 1
      }

      // Linha superior
      Rectangle { width: parent.width; height: 1; color: root.colorDivider; opacity: 0.5 }

      Column {
        id: configColumn
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 10
        spacing: 10

        // ── Cabeçalho ──────────────────────────────────────────────────────
        Row {
          width: parent.width; spacing: 8
          Text {
            text: "▾  Matugen / Efeitos"
            font.pixelSize: 10
            color: root.colorAccent; opacity: 0.9
            anchors.verticalCenter: parent.verticalCenter
          }
          Item { width: parent.width - 260 - 8; height: 1 }
          // Botão Aplicar
          Rectangle {
            height: 24; radius: 7; width: applyRow.implicitWidth + 18
            opacity: saveConfigProc.running ? 0.4 : 1.0
            color: applyMA.containsMouse
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
              : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
            border.color: root.colorAccent; border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              id: applyRow; anchors.centerIn: parent; spacing: 5
              Text { text: "✓"; font.pixelSize: 10; color: root.colorAccent }
              Text { text: "Aplicar"; font.pixelSize: 9; color: root.colorAccent }
            }
            MouseArea {
              id: applyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: if (!saveConfigProc.running) root._saveConfig()
            }
          }
        }

        // ── Fonte matugen (base / final) ───────────────────────────────────
        Text { text: "FONTE MATUGEN"; font.pixelSize: 7; font.letterSpacing: 1.2; color: root.colorTextDim; opacity: 0.6 }
        Row {
          spacing: 5
          Repeater {
            model: root.matugenSources
            delegate: Item {
              width: srcChipW.implicitWidth; height: 24
              readonly property bool isSel: root.editSource === modelData.id
              Rectangle {
                id: srcChipW; anchors.fill: parent; radius: 14
                implicitWidth: srcLblW.implicitWidth + 24
                color: isSel ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18) : (srcMAW.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.06))
                border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.10); border.width: isSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { id: srcLblW; anchors.centerIn: parent; text: modelData.label; font.pixelSize: 10
                       color: isSel ? root.colorAccent : root.colorText
                       Behavior on color { ColorAnimation { duration: 100 } } }
              }
              MouseArea { id: srcMAW; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.editSource = modelData.id }
            }
          }
        }

        // ── Palette ────────────────────────────────────────────────────────
        Text { text: "PALETTE"; font.pixelSize: 7; font.letterSpacing: 1.2; color: root.colorTextDim; opacity: 0.6 }
        Flow {
          width: parent.width; spacing: 4
          Repeater {
            model: root.allPalettes
            delegate: Item {
              width: palChipW.implicitWidth; height: 20
              readonly property bool isPSel: root.editPalette === modelData
              Rectangle {
                id: palChipW; anchors.fill: parent; radius: 10
                implicitWidth: palChipTW.implicitWidth + 14
                color: isPSel ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2) : (palMAW.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isPSel ? root.colorAccent : Qt.rgba(1,1,1,0.09); border.width: isPSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }
                Text { id: palChipTW; anchors.centerIn: parent; text: modelData.replace("scheme-",""); font.pixelSize: 8
                       color: isPSel ? root.colorAccent : root.colorText }
              }
              MouseArea { id: palMAW; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.editPalette = modelData }
            }
          }
        }

        // ── Cor da fonte (swatches) ────────────────────────────────────────
        Row {
          spacing: 6
          Text { text: "COR DA FONTE"; font.pixelSize: 7; font.letterSpacing: 1.2; color: root.colorTextDim; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
          Item {
            width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
            Text {
              anchors.centerIn: parent; text: "↻"; font.pixelSize: 14
              color: root.loadingSwatches ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3) : root.colorTextDim
              RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.loadingSwatches }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!swatchProc.running && root.currentWallpaper !== "")
                  root._loadSwatches(root.currentWallpaper, root.editSource)
              }
            }
          }
        }

        Text { visible: root.loadingSwatches; text: "carregando paleta…"; font.pixelSize: 9; color: root.colorTextDim; opacity: 0.5 }
        Text { visible: !root.loadingSwatches && root.swatchColors.length === 0 && root.currentWallpaper !== ""
               text: "Nenhuma paleta — clique em ↻ para carregar"; font.pixelSize: 9; color: root.colorTextDim; opacity: 0.45 }

        Flow {
          width: parent.width; spacing: 5
          visible: !root.loadingSwatches && root.swatchColors.length > 0
          Repeater {
            model: root.swatchColors
            delegate: Item {
              width: 30; height: 30
              readonly property int swIdx: index
              readonly property bool isSwAct: root.editIndex === swIdx
              Rectangle {
                anchors.fill: parent; radius: 6; color: modelData
                border.color: isSwAct ? "white" : Qt.rgba(0,0,0,0.35); border.width: isSwAct ? 2 : 1
                Text { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.bottomMargin: 2; anchors.rightMargin: 2; text: swIdx; font.pixelSize: 6; color: "white"; style: Text.Outline; styleColor: "#80000000" }
                Text { anchors.centerIn: parent; visible: isSwAct; text: "✓"; font.pixelSize: 14; color: "white"; style: Text.Outline; styleColor: "#80000000" }
                scale: swMAW.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
              }
              MouseArea { id: swMAW; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.editIndex = swIdx }
            }
          }
        }

        // ── Efeitos (GridView 3 colunas + scroll) ──────────────────────────
        Text { text: "EFEITO"; font.pixelSize: 7; font.letterSpacing: 1.2; color: root.colorTextDim; opacity: 0.6; visible: root.effectList.length > 1 }
        Row {
          spacing: 6; visible: root.generatingEffectPrev
          Text { text: "↻"; font.pixelSize: 13; color: root.colorTextDim; opacity: 0.6
                 RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.generatingEffectPrev } }
          Text { text: "gerando previews..."; font.pixelSize: 9; color: root.colorTextDim; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
        }

        Item {
          width: parent.width
          height: root.effectList.length > 1 ? Math.min(wallEfxGrid.contentHeight + 2, 160) : 0
          visible: root.effectList.length > 1
          clip: true

          GridView {
            id: wallEfxGrid
            anchors.fill: parent; clip: true
            cellWidth:  Math.max(1, Math.floor((width - 2) / 3))
            cellHeight: Math.round(cellWidth * 9 / 16) + 20
            model: root.effectList
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
              width:  wallEfxGrid.cellWidth
              height: wallEfxGrid.cellHeight
              readonly property bool isEfxSel: root.editEffect === modelData
              readonly property string prevPath: {
                var v = root.effectPrevVersion
                return root.effectPreviews[modelData] || ""
              }

              Rectangle {
                anchors { fill: parent; margins: 3 }
                radius: 7; clip: true
                color: isEfxSel ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18) : (efxHovW.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05))
                border.color: isEfxSel ? root.colorAccent : Qt.rgba(1,1,1,0.10); border.width: isEfxSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }

                Image {
                  id: efxImgW
                  anchors { top: parent.top; left: parent.left; right: parent.right }
                  height: parent.height - 18
                  fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
                  source: prevPath !== "" ? ("file://" + prevPath + "?v=" + root.effectPrevVersion) : ""

                  Rectangle {
                    anchors.fill: parent; visible: efxImgW.status !== Image.Ready; color: Qt.rgba(1,1,1,0.04)
                    Text { anchors.centerIn: parent; text: root.generatingEffectPrev ? "↻" : "🖼"
                           font.pixelSize: 12; color: root.colorAccent; opacity: 0.4
                           RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.generatingEffectPrev } }
                  }

                  Rectangle {
                    visible: isEfxSel; anchors { top: parent.top; right: parent.right; margins: 3 }
                    width: 16; height: 16; radius: 8; color: root.colorAccent
                    Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 9; color: "#1f1f1f" }
                  }
                }

                Text {
                  anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 18
                  horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                  text: modelData === "off" ? "desligado" : modelData; font.pixelSize: 7; elide: Text.ElideRight
                  color: isEfxSel ? root.colorAccent : root.colorTextDim
                }
              }
              MouseArea { id: efxHovW; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.editEffect = modelData }
            }
          }
        }

        Item { height: 4 }
      }
    }
  }
}
