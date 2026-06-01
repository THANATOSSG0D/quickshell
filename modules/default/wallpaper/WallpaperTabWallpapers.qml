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
  property string currentWallpaper: ""   // path do source (sem file:)
  property string currentEngine:    "swww"

  signal wallpaperApplied(string src)
  signal engineSelected(string engine)
  signal refreshState()

  // ── Estado interno ────────────────────────────────────────────────────────
  property var    allEntries:    []
  property bool   loading:       false
  property string activeFilter:  "all"
  property string applyingPath:  ""    // path sendo aplicado agora
  property bool   applying:      false // true enquanto wallpaper.sh roda

  // ── Engines ───────────────────────────────────────────────────────────────
  readonly property var engines: [
    { id: "swww",      icon: "\uf0ac", label: "swww"      },
    { id: "hyprpaper", icon: "\uf2db", label: "hyprpaper" },
    { id: "mpvpaper",  icon: "\uf03d", label: "mpvpaper"  },
    { id: "awww",      icon: "\uf185", label: "awww"      }
  ]

  // ── Filtros ───────────────────────────────────────────────────────────────
  readonly property var colorFilters: [
    { id: "all",    label: "Todos",    swatch: ""        },
    { id: "red",    label: "Vermelho", swatch: "#e05555" },
    { id: "orange", label: "Laranja",  swatch: "#e07d30" },
    { id: "yellow", label: "Amarelo",  swatch: "#d4b84a" },
    { id: "green",  label: "Verde",    swatch: "#4caf6f" },
    { id: "cyan",   label: "Ciano",    swatch: "#3aabb8" },
    { id: "blue",   label: "Azul",     swatch: "#4a78d4" },
    { id: "purple", label: "Roxo",     swatch: "#8b4fd4" },
    { id: "pink",   label: "Rosa",     swatch: "#d44f9a" },
    { id: "mono",   label: "P&B",      swatch: "#aaaaaa" }
  ]

  function _hueToCategory(h) {
    if (h < 0)   return "mono"
    if (h < 15)  return "red"
    if (h < 45)  return "orange"
    if (h < 70)  return "yellow"
    if (h < 150) return "green"
    if (h < 195) return "cyan"
    if (h < 255) return "blue"
    if (h < 295) return "purple"
    if (h < 345) return "pink"
    return "red"
  }

  readonly property var filteredEntries: {
    if (activeFilter === "all") return allEntries
    var out = []
    for (var i = 0; i < allEntries.length; i++) {
      var e = allEntries[i]
      if (_hueToCategory(e.hue !== undefined ? e.hue : -1) === activeFilter)
        out.push(e)
    }
    return out
  }

  // ── Processos ─────────────────────────────────────────────────────────────

  Process {
    id: loadProc
    command: ["bash", "-c",
      // Tenta path relativo ao shell primeiro, fallback para ml4w/scripts
      "qs_wp=\"$(dirname '" + root.mlScripts + "')/../quickshell/modules/default/wallpaper/wp-dmenu-entries\";" +
      "ml_wp='" + root.mlScripts + "/wp-dmenu-entries';" +
      "if [ -f \"$qs_wp\" ]; then python3 \"$qs_wp\" folder;" +
      "elif [ -f \"$ml_wp\" ]; then python3 \"$ml_wp\" folder; fi 2>/dev/null"
    ]
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
            arr.push({ label: e.label || "", sub: e.sub || "",
                       value: e.value || "", thumb: e.thumb || "", hue: -1 })
          }
          root.allEntries = arr
          hueQueue._idx = 0
          hueQueue._run()
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
        "magick '" + e.thumb + "' -resize 1x1! " +
        "-format '%[fx:hue*360]\\n%[fx:saturation]' info: 2>/dev/null " +
        "|| printf -- '-1\\n0'"]
      hueProc.running = true
    }
  }

  Process {
    id: hueProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { hueProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        var lines = hueProc._buf.trim().split("\n"); hueProc._buf = ""
        var h = parseFloat(lines[0]) || -1
        var s = parseFloat(lines[1]) || 0
        if (s < 0.12) h = -1
        var idx = hueQueue._idx
        if (idx < root.allEntries.length) {
          var arr = root.allEntries.slice()
          var e = arr[idx]
          arr[idx] = { label: e.label, sub: e.sub, value: e.value, thumb: e.thumb, hue: h }
          root.allEntries = arr
        }
        hueQueue._idx++
        hueQueue._run()
      }
    }
  }

  // ── Aplicar wallpaper em 2 fases ──────────────────────────────────────────
  // Fase 1: aplica VISUALMENTE (engine apenas) → feedback imediato ao usuário
  // Fase 2: pipeline completo via --bg-pipeline → state.json, matugen, history,
  //         effect previews, lock, blur — tudo correto e sem corrida com o guard

  Process {
    id: fastApplyProc
    property string _pendingPath: ""
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { fastApplyProc._buf += l } }
    onRunningChanged: {
      if (!running) {
        fastApplyProc._buf = ""
        // Fase 1 concluída: atualiza badge imediatamente
        root.currentWallpaper = fastApplyProc._pendingPath
        root.wallpaperApplied(fastApplyProc._pendingPath)
        root.applying = false
        // Fase 2: pipeline completo em background via --bg-pipeline
        // --bg-pipeline: pula o guard waypaperrunning e pula a Fase 4 (apply)
        // garante que state.json, matugen e effect previews sejam escritos
        // wp-run: double-fork python — sobrevive ao fechar painel
        bgPipelineProc.command = [
          root.wpRun, "--bg-pipeline", fastApplyProc._pendingPath
        ]
        bgPipelineProc.running = true
      }
    }
  }

  // Fase 2: dispara o background pipeline e aguarda lançamento
  // O processo real roda desacoplado (setsid + &), então este proc termina rápido
  Process {
    id: bgPipelineProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { bgPipelineProc._buf += l } }
    onRunningChanged: {
      if (!running) {
        bgPipelineProc._buf = ""
        // Aguarda o pipeline de background escrever o state antes de relê-lo.
        // O pipeline faz matugen+state-and-history sequencialmente antes de sair.
        // ~2.5s é suficiente para matugen+state na prática; aumentar se necessário.
        bgRefreshDelay.restart()
      }
    }
  }

  // Timer: dá tempo ao --bg-pipeline de escrever state.json antes do refreshState
  Timer {
    id: bgRefreshDelay
    interval: 2500
    repeat: false
    onTriggered: root.refreshState()
  }

  // Lê a engine atual e aplica visualmente via engine direta
  function _engineCmd(path) {
    var e = root.currentEngine
    if (e === "swww")
      return "swww img '" + path + "' --transition-type any --transition-duration 0.8 2>/dev/null || " +
             "swww img '" + path + "' --transition-type none 2>/dev/null"
    if (e === "hyprpaper")
      return "hyprctl hyprpaper wallpaper '," + path + "' 2>/dev/null"
    if (e === "mpvpaper")
      return "pkill -x mpvpaper 2>/dev/null || true; sleep 0.1; " +
             "mpvpaper -o 'no-audio loop-file=inf' '*' '" + path + "' &"
    // fallback swww
    return "swww img '" + path + "' --transition-type none 2>/dev/null"
  }

  function _apply(path) {
    if (fastApplyProc.running || root.applying) return
    root.applying = true
    root.applyingPath = path
    fastApplyProc._pendingPath = path
    // Fase 1: só aplica visualmente
    fastApplyProc.command = ["bash", "-c", root._engineCmd(path)]
    fastApplyProc.running = true
  }

  // ── Engine switch ─────────────────────────────────────────────────────────
  Process {
    id: engineProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { engineProc._buf += l } }
    onRunningChanged: {
      if (!running) { engineProc._buf = ""; root.refreshState() }
    }
  }

  function _setEngine(e) {
    if (engineProc.running) return
    root.currentEngine = e
    root.engineSelected(e)
    engineProc.command = ["bash", "-c",
      "pkill -x awww-daemon 2>/dev/null || true;" +
      "pkill -x hyprpaper   2>/dev/null || true;" +
      "pkill -x mpvpaper    2>/dev/null || true;" +
      "pkill -x swww-daemon 2>/dev/null || true;" +
      "sleep 0.4;" +
      "echo '" + e + "' > ~/.config/ml4w/settings/wallpaper-engine.sh;" +
      "cfg=~/.config/waypaper/config.ini;" +
      "[ -f \"$cfg\" ] && sed -i 's|^backend[[:space:]]*=.*|backend = " + e + "|' \"$cfg\";" +
      "case '" + e + "' in" +
      "  swww)      swww-daemon &; sleep 0.4;;" +
      "  hyprpaper) hyprpaper &; sleep 0.4;;" +
      "  awww)      awww-daemon &; sleep 0.4;;" +
      "esac;" +
      "exec '" + root.wpRun + "' --quiet"
    ]
    engineProc.running = true
  }

  onPanelOpenChanged: {
    if (panelOpen && allEntries.length === 0 && !loading) {
      loading = true
      if (!loadProc.running) loadProc.running = true
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  ColumnLayout {
    anchors.fill: parent; spacing: 0

    // ── Toolbar: engines + status ──────────────────────────────────────────
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
              color: isCurr
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                : (ema.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
              border.color: isCurr ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: isCurr ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 110 } }

              Row {
                id: er; anchors.centerIn: parent; spacing: 4
                Text {
                  text: modelData.icon
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
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
              id: ema; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root._setEngine(modelData.id)
            }
          }
        }

        Item { Layout.fillWidth: true }

        // ── Indicador "aplicando" ──────────────────────────────────────────
        Row {
          spacing: 5
          visible: root.applying
          Text {
            text: "\uf110"; anchors.verticalCenter: parent.verticalCenter
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            color: root.colorAccent; opacity: 0.8
            RotationAnimator on rotation {
              from: 0; to: 360; duration: 1000
              loops: Animation.Infinite; running: root.applying
            }
          }
          Text {
            text: "aplicando..."
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 10; color: root.colorTextDim
          }
        }

        // ── Reload ────────────────────────────────────────────────────────
        Item {
          width: 26; height: 26
          visible: !root.applying
          Text {
            anchors.centerIn: parent; text: "\uf021"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
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

      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: root.colorDivider; opacity: 0.3
      }
    }

    // ── Filtros de cor ────────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true; height: 36

      Flickable {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        contentWidth: fr.implicitWidth; contentHeight: height
        clip: true; flickableDirection: Flickable.HorizontalFlick
        boundsMovement: Flickable.StopAtBounds

        Row {
          id: fr; anchors.verticalCenter: parent.verticalCenter; spacing: 5

          Repeater {
            model: root.colorFilters
            delegate: Item {
              width: fc.implicitWidth; height: 26
              readonly property bool isAct: root.activeFilter === modelData.id

              Rectangle {
                id: fc; anchors.fill: parent; radius: 13
                implicitWidth: frow.implicitWidth + 18
                color: isAct
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  : (fma.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04))
                border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isAct ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }

                Row {
                  id: frow; anchors.centerIn: parent; spacing: 5
                  Rectangle {
                    visible: modelData.swatch !== ""
                    width: 9; height: 9; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.swatch || "transparent"
                    border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                  }
                  Text {
                    text: modelData.label; font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: isAct ? root.colorText : root.colorTextDim
                    Behavior on color { ColorAnimation { duration: 110 } }
                  }
                }
              }

              MouseArea {
                id: fma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeFilter = modelData.id
              }
            }
          }
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: root.colorDivider; opacity: 0.2
      }
    }

    // ── Grid de wallpapers ────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true; Layout.fillHeight: true

      Text {
        anchors.centerIn: parent
        visible: root.loading
        text: "\uf110  carregando..."
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
        color: root.colorTextDim; opacity: 0.6
      }

      GridView {
        id: wallpaperGrid
        anchors { fill: parent; margins: 10 }
        visible: !root.loading
        clip: true

        cellWidth:  Math.floor((width - 4) / 3)
        cellHeight: cellWidth * 9 / 16 + 24

        model: root.filteredEntries

        property int hoveredIdx: -1

        delegate: Item {
          width:  wallpaperGrid.cellWidth
          height: wallpaperGrid.cellHeight

          readonly property bool isHovered: wallpaperGrid.hoveredIdx === index
          readonly property bool isCurrent: modelData.value === ("file:" + root.currentWallpaper)
          readonly property string thumbPath: modelData.thumb || ""

          Rectangle {
            id: card
            anchors { fill: parent; margins: 3 }
            radius: 8; clip: true
            color: isCurrent
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
              : Qt.rgba(1, 1, 1, 0.04)

            border.color: isCurrent ? root.colorAccent
                         : isHovered ? Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.25)
                         : "transparent"
            border.width: isCurrent ? 1.5 : 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Image {
              id: thumbImg
              anchors { top: parent.top; left: parent.left; right: parent.right }
              height: parent.width * 9 / 16
              fillMode: Image.PreserveAspectCrop
              source: thumbPath !== "" ? ("file://" + thumbPath) : ""
              asynchronous: true; cache: true; smooth: true

              Rectangle {
                anchors.fill: parent
                visible: thumbImg.status !== Image.Ready
                color: Qt.rgba(1,1,1,0.04)
                radius: parent.radius
              }

              Rectangle {
                visible: isCurrent
                anchors { top: parent.top; right: parent.right; margins: 4 }
                width: 18; height: 18; radius: 9
                color: root.colorAccent

                Text {
                  anchors.centerIn: parent
                  text: "\uf00c"; font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                  color: "#1f1f1f"
                }
              }
            }

            Text {
              anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
              anchors.margins: 4
              height: 20
              text: modelData.label || ""
              font.pixelSize: 9
              color: isHovered ? root.colorText : root.colorTextDim
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignHCenter
              Behavior on color { ColorAnimation { duration: 100 } }
            }
          }

          MouseArea {
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: wallpaperGrid.hoveredIdx = index
            onExited:  if (wallpaperGrid.hoveredIdx === index) wallpaperGrid.hoveredIdx = -1
            onClicked: root._apply(modelData.value.replace(/^file:/, ""))
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }
    }
  }
}
