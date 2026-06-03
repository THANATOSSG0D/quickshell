import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root

  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string mlScripts:    ""
  property string wallSh:       ""
  property string effectsDir:   ""
  property string previewDir:   ""
  property string wpRun:        ""

  // ── Picker ────────────────────────────────────────────────────────────────
  property var    pickerEntries: []
  property bool   pickerLoading: false
  property string pickerFilter:  "all"

  readonly property var pickerColorFilters: [
    { id: "all",    label: "Todos",    swatch: ""        },
    { id: "red",    label: "Verm.",    swatch: "#e05555" },
    { id: "orange", label: "Laran.",   swatch: "#e07d30" },
    { id: "yellow", label: "Amar.",    swatch: "#d4b84a" },
    { id: "green",  label: "Verde",    swatch: "#4caf6f" },
    { id: "cyan",   label: "Ciano",    swatch: "#3aabb8" },
    { id: "blue",   label: "Azul",     swatch: "#4a78d4" },
    { id: "purple", label: "Roxo",     swatch: "#8b4fd4" },
    { id: "pink",   label: "Rosa",     swatch: "#d44f9a" },
    { id: "mono",   label: "P&B",      swatch: "#aaaaaa" }
  ]

  function _pickerHueCat(h) {
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

  readonly property var pickerFiltered: {
    if (pickerFilter === "all") return pickerEntries
    var out = []
    for (var i = 0; i < pickerEntries.length; i++) {
      var e = pickerEntries[i]
      if (_pickerHueCat(e.hue !== undefined ? e.hue : -1) === pickerFilter)
        out.push(e)
    }
    return out
  }

  // ── Estado ────────────────────────────────────────────────────────────────
  property bool   schedEnabled: false
  property bool   timerActive:  false
  property bool   loading:      false
  property bool   running:      false
  property var    slots:        []
  property var    effectList:   ["off"]
  property var    profileList:  []

  property int    editingIdx:   -1
  readonly property bool hasActiveSlot: editingIdx >= 0

  property string ed_name:      ""
  property int    ed_start:     6
  property string ed_file:      ""
  property string ed_folder:    ""
  property string ed_profile:   ""
  property string ed_effect:    "off"
  property string ed_palette:   "scheme-fidelity"
  property string ed_msrc:      "base"
  property int    ed_midx:      0
  property bool   ed_random:    true
  property bool   ed_quiet:     false
  property string ed_thumbPath: ""

  property bool   showAddSlot:  false
  property string newSlotName:  ""
  property int    newSlotHour:  0

  readonly property var allPalettes: [
    "scheme-content", "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow", "scheme-tonal-spot"
  ]

  // ── Layout ────────────────────────────────────────────────────────────────
  readonly property bool editorOpen: editingIdx >= 0
  readonly property int  listW:  editorOpen ? Math.floor(width * 0.42) : width
  readonly property int  rightW: width - listW - 1

  // Calcula o path do thumb de um slot sem Qt.md5 (não existe em QML).
  // Usa o path que o wallpaper manager já grava em previewDir:
  //   ~/.config/ml4w/cache/wallpaper-previews/<basename_sem_ext>.png
  function _slotThumbPath(md) {
    if (!md) return ""
    var f = md.file || ""
    if (f === "") return ""
    // basename sem extensão
    var base = f.split("/").pop().replace(/\.[^.]+$/, "")
    var cacheDir = root.mlScripts.replace(/\/scripts$/, "/cache")
    return cacheDir + "/wallpaper-previews/" + base + ".png"
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API pública
  // ═══════════════════════════════════════════════════════════════════════════

  function assignWallpaperToSlot(slotIndex, wallpaperPath) {
    if (slotIndex < 0 || slotIndex >= root.slots.length) return
    if (!wallpaperPath || wallpaperPath === "") return
    var slot = root.slots[slotIndex]
    if (!slot || root.running) return
    root.running = true
    var origStart = slot.start
    var patch = JSON.stringify({ file: wallpaperPath, folder: "", profile: "" })
    assignProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys, json\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == " + origStart + ":\n" +
      "        sl.update(" + patch + "); break\n" +
      "S._save_config(cfg)\n" +
      "import subprocess, os\n" +
      "lib = '" + root.mlScripts + "/wallpaper-lib.sh'\n" +
      "if os.path.isfile(lib):\n" +
      "    subprocess.Popen(['bash','-c',\n" +
      "        'source ' + repr(lib) + ' && generate_wall_thumb ' + repr('" + wallpaperPath + "')],\n" +
      "        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
      "PYEOF\n"
    ]
    assignProc.running = true
    // feedback imediato
    var arr = root.slots.slice()
    var sl = {}
    for (var k in arr[slotIndex]) sl[k] = arr[slotIndex][k]
    sl.file = wallpaperPath; sl.folder = ""; sl.profile = ""
    arr[slotIndex] = sl
    root.slots = arr
    if (root.editingIdx === slotIndex) {
      root.ed_file = wallpaperPath; root.ed_folder = ""; root.ed_profile = ""
    }
  }

  function getSlotsList()          { return root.slots }
  function selectFileForSlot(path) { if (root.editingIdx >= 0) assignWallpaperToSlot(root.editingIdx, path) }

  // ═══════════════════════════════════════════════════════════════════════════
  // Processos
  // ═══════════════════════════════════════════════════════════════════════════

  Process {
    id: loadProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { loadProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.loading = false
      var raw = loadProc._buf.trim(); loadProc._buf = ""
      if (!raw) return
      try {
        var d = JSON.parse(raw)
        root.schedEnabled = d.json_enabled !== undefined ? d.json_enabled : true
        root.timerActive  = d.timer_active || false
        root.slots        = d.slots    || []
        root.effectList   = d.effects  || ["off"]
        root.profileList  = d.profiles || []
      } catch(e) {}
    }
  }

  function _reload() {
    if (loadProc.running) return
    root.loading = true
    loadProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys, json, os, subprocess\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S, profile as P\n" +
      "cfg = S.load_config()\n" +
      "json_enabled = bool(cfg.get('enabled', True))\n" +
      "r = subprocess.run(['systemctl','--user','is-active','wallpaper-schedule.timer'],\n" +
      "    capture_output=True, text=True)\n" +
      "timer_active = r.stdout.strip() == 'active'\n" +
      "slots = S.slots_list()\n" +
      "effects = ['off']\n" +
      "ed = '" + root.effectsDir + "'\n" +
      "if os.path.isdir(ed):\n" +
      "    effects += sorted(e for e in os.listdir(ed) if not e.startswith('.'))\n" +
      "profiles = list(P.load_all().keys())\n" +
      "print(json.dumps({'json_enabled': json_enabled, 'timer_active': timer_active,\n" +
      "    'slots': slots, 'effects': effects, 'profiles': profiles}))\n" +
      "PYEOF\n"
    ]
    loadProc.running = true
  }

  Process {
    id: actionProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { actionProc._buf += l } }
    onRunningChanged: {
      if (running) return
      actionProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: saveSlotProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { saveSlotProc._buf += l } }
    onRunningChanged: {
      if (running) return
      saveSlotProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: mutateProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { mutateProc._buf += l } }
    onRunningChanged: {
      if (running) return
      mutateProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: assignProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { assignProc._buf += l } }
    onRunningChanged: {
      if (running) return
      assignProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: pickerLoadProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { pickerLoadProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.pickerLoading = false
      var raw = pickerLoadProc._buf.trim(); pickerLoadProc._buf = ""
      if (!raw) return
      try {
        var data = JSON.parse(raw)
        var arr = []
        for (var i = 0; i < data.length; i++) {
          var e = data[i]
          arr.push({ label: e.label || "", value: e.value || "", thumb: e.thumb || "", hue: -1 })
        }
        root.pickerEntries = arr
        pickerHueQueue._idx = 0
        pickerHueQueue._run()
      } catch(ex) {}
    }
  }

  function _pickerLoad() {
    if (pickerLoadProc.running || root.pickerEntries.length > 0) return
    root.pickerLoading = true
    pickerLoadProc.command = ["bash", "-c",
      "qs_wp=\"$(dirname '" + root.mlScripts + "')/../quickshell/modules/default/wallpaper/wp-dmenu-entries\";" +
      "ml_wp='" + root.mlScripts + "/wp-dmenu-entries';" +
      "if [ -f \"$qs_wp\" ]; then python3 \"$qs_wp\" folder;" +
      "elif [ -f \"$ml_wp\" ]; then python3 \"$ml_wp\" folder; fi 2>/dev/null"
    ]
    pickerLoadProc.running = true
  }

  QtObject {
    id: pickerHueQueue
    property int _idx: 0
    function _run() {
      if (_idx >= root.pickerEntries.length) return
      var e = root.pickerEntries[_idx]
      if (!e.thumb || e.thumb === "") { _idx++; _run(); return }
      pickerHueProc.command = ["bash", "-c",
        "magick '" + e.thumb + "' -resize 1x1! " +
        "-format '%[fx:hue*360]\\n%[fx:saturation]' info: 2>/dev/null || printf -- '-1\\n0'"]
      pickerHueProc.running = true
    }
  }

  Process {
    id: pickerHueProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { pickerHueProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      var lines = pickerHueProc._buf.trim().split("\n"); pickerHueProc._buf = ""
      var h = parseFloat(lines[0]) || -1
      var s = parseFloat(lines[1]) || 0
      if (s < 0.12) h = -1
      var idx = pickerHueQueue._idx
      if (idx < root.pickerEntries.length) {
        var arr = root.pickerEntries.slice()
        var e = arr[idx]
        arr[idx] = { label: e.label, value: e.value, thumb: e.thumb, hue: h }
        root.pickerEntries = arr
      }
      pickerHueQueue._idx++
      pickerHueQueue._run()
    }
  }

  function _toggle() {
    if (root.running) return
    root.running = true
    actionProc.command = ["bash", "-c",
      "bash '" + root.mlScripts + "/wallpaper-schedule.sh' " +
      (root.timerActive ? "disable" : "enable") + " 2>/dev/null"
    ]
    actionProc.running = true
  }

  function _runNow() {
    if (root.running) return
    root.running = true
    actionProc.command = ["bash", "-c",
      "bash '" + root.mlScripts + "/wallpaper-schedule.sh' run 2>/dev/null"
    ]
    actionProc.running = true
  }

  function _addSlot(name, hour) {
    if (root.running || !name || name.trim() === "") return
    root.running = true; root.showAddSlot = false
    mutateProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "try: S.add_slot('" + name.trim().replace(/'/g, "\\'") + "', " + hour + ")\n" +
      "except ValueError as e: print('ERR:', e)\n" +
      "PYEOF\n"
    ]
    mutateProc.running = true
  }

  function _addSlotWithWallpaper(name, hour, wallpaperPath) {
    if (root.running || !name || name.trim() === "") return
    root.running = true; root.showAddSlot = false
    var safeName = name.trim().replace(/'/g, "\\'")
    var safePath = wallpaperPath.replace(/'/g, "\\'")
    mutateProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys, json\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "try: S.add_slot('" + safeName + "', " + hour + ")\n" +
      "except ValueError: pass\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == " + hour + " and sl.get('name') == '" + safeName + "':\n" +
      "        sl['file'] = '" + safePath + "'; sl['folder'] = ''; sl['profile'] = ''\n" +
      "        break\n" +
      "S._save_config(cfg)\n" +
      "import subprocess, os\n" +
      "lib = '" + root.mlScripts + "/wallpaper-lib.sh'\n" +
      "if os.path.isfile(lib):\n" +
      "    subprocess.Popen(['bash','-c',\n" +
      "        'source ' + repr(lib) + ' && generate_wall_thumb ' + repr('" + safePath + "')],\n" +
      "        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
      "PYEOF\n"
    ]
    mutateProc.running = true
  }

  function _removeSlot(start) {
    if (root.running) return
    root.running = true; root.editingIdx = -1
    mutateProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "try: S.remove_slot(" + start + ")\n" +
      "except ValueError: pass\n" +
      "PYEOF\n"
    ]
    mutateProc.running = true
  }

  function _openEditor(idx) {
    var s = root.slots[idx]
    if (!s) return
    root.editingIdx  = idx
    root.ed_name     = s.name           || ""
    root.ed_start    = s.start          !== undefined ? s.start : 0
    root.ed_file     = s.file           || ""
    root.ed_folder   = s.folder         || ""
    root.ed_profile  = s.profile        || ""
    root.ed_effect   = s.effect         || "off"
    root.ed_palette  = s.palette        || "scheme-fidelity"
    root.ed_msrc     = s.matugen_source || "base"
    root.ed_midx     = s.matugen_index  !== undefined ? s.matugen_index : 0
    root.ed_random   = s.random         !== undefined ? s.random : true
    root.ed_quiet    = s.quiet          !== undefined ? s.quiet  : false
    root._pickerLoad()
  }

  function _saveSlot() {
    if (root.running || root.editingIdx < 0) return
    var slot = root.slots[root.editingIdx]
    if (!slot) return
    root.running = true
    var origStart = slot.start
    var patch = JSON.stringify({
      name: root.ed_name, start: root.ed_start,
      file: root.ed_file, folder: root.ed_folder, profile: root.ed_profile,
      effect: root.ed_effect, palette: root.ed_palette,
      matugen_source: root.ed_msrc, matugen_index: root.ed_midx,
      random: root.ed_random, quiet: root.ed_quiet
    })
    saveSlotProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys, json\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "patch = " + patch + "\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == " + origStart + ":\n" +
      "        sl.update(patch); break\n" +
      "S._save_config(cfg)\n" +
      "PYEOF\n"
    ]
    saveSlotProc.running = true
  }

  onPanelOpenChanged: { if (panelOpen) root._reload() }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI — RowLayout raiz divide esquerdo/direito
  // ═══════════════════════════════════════════════════════════════════════════

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ── PAINEL ESQUERDO ───────────────────────────────────────────────────────
    Item {
      id: listPanel
      Layout.preferredWidth: root.listW
      Layout.fillHeight: true
      clip: true
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      // Flickable ocupa o painel inteiro
      Flickable {
        id: listFlick
        anchors.fill: parent
        clip: true
        contentWidth: width
        // contentHeight rastreado pelo Column interno
        contentHeight: listColumn.height
        boundsMovement: Flickable.StopAtBounds

        // Column (não ColumnLayout) — height = sum of children
        Column {
          id: listColumn
          width: listFlick.width
          spacing: 0

          // Padding top
          Item { width: 1; height: 10 }

          // ── Status card ────────────────────────────────────────────────
          Rectangle {
            width: listColumn.width - 20
            x: 10
            height: 58
            radius: 10
            color: root.timerActive
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.09)
              : Qt.rgba(1,1,1,0.04)
            border.color: root.timerActive
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
              : Qt.rgba(1,1,1,0.09)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              Text {
                text: root.loading ? "\uf110" : "\uf017"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: root.timerActive ? root.colorAccent : root.colorTextDim
                opacity: root.timerActive ? 1.0 : 0.3
                Behavior on color   { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                RotationAnimator on rotation {
                  from: 0; to: 360; duration: 900
                  loops: Animation.Infinite; running: root.loading
                }
              }

              Column {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  text: root.timerActive ? "Timer ativo" : "Timer inativo"
                  font.pixelSize: 10
                  color: root.colorText
                }
                Text {
                  text: (root.schedEnabled ? "on" : "off") + "  ·  " + root.slots.length + " slot(s)"
                  font.pixelSize: 8
                  color: root.colorTextDim
                }
              }

              // Rodar agora
              Rectangle {
                width: 26; height: 26; radius: 6
                color: rnma.containsMouse
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                  : Qt.rgba(1,1,1,0.06)
                border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
                border.width: 1
                opacity: root.running ? 0.4 : 1.0
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                  anchors.centerIn: parent; text: "\uf04b"
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                  color: root.colorAccent
                }
                MouseArea {
                  id: rnma; anchors.fill: parent; hoverEnabled: true
                  cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onClicked: if (!root.running) root._runNow()
                }
              }

              // Toggle
              Rectangle {
                width: 44; height: 22; radius: 11
                color: root.timerActive
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.28)
                  : Qt.rgba(1,1,1,0.08)
                Behavior on color { ColorAnimation { duration: 200 } }
                Rectangle {
                  width: 16; height: 16; radius: 8
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.timerActive ? parent.width - 20 : 4
                  color: root.timerActive ? root.colorAccent : root.colorTextDim
                  Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation  { duration: 200 } }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root._toggle()
                }
              }
            }
          }

          Item { width: 1; height: 8 }

          // ── Cabeçalho SLOTS + botão + ──────────────────────────────────
          Item {
            width: listColumn.width - 20
            x: 10
            height: 24

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "SLOTS"
              font.pixelSize: 8
              font.letterSpacing: 1.4
              color: root.colorTextDim
              opacity: 0.65
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: 20; height: 20; radius: 5
              color: addma.containsMouse
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                : Qt.rgba(1,1,1,0.06)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
              border.width: 1
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent; text: "+"
                font.pixelSize: 13; color: root.colorAccent
              }
              MouseArea {
                id: addma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.showAddSlot = !root.showAddSlot; root.newSlotName = ""; root.newSlotHour = 0 }
              }
            }
          }

          Item { width: 1; height: 4 }

          // ── Formulário novo slot ───────────────────────────────────────
          Item {
            width: listColumn.width - 20
            x: 10
            // Altura real do conteúdo: calculada pelo Column interno + padding
            height: root.showAddSlot ? addFormCol.height + 16 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
              anchors.fill: parent
              radius: 8
              color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.06)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
              border.width: 1
            }

            Column {
              id: addFormCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.topMargin: 8
              spacing: 8

              Text { text: "Novo slot"; font.pixelSize: 10; color: root.colorAccent }

              Row {
                width: parent.width
                spacing: 6
                Rectangle {
                  width: parent.width - 66; height: 28; radius: 6
                  color: Qt.rgba(1,1,1,0.05)
                  border.color: addNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                  border.width: 1
                  Behavior on border.color { ColorAnimation { duration: 120 } }
                  TextInput {
                    id: addNameIn
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 10; color: root.colorText
                    text: root.newSlotName
                    onTextChanged: root.newSlotName = text
                    Text {
                      anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                      text: "nome do slot"; color: root.colorTextDim; font: parent.font; opacity: 0.4
                      visible: parent.text.length === 0 && !parent.activeFocus
                    }
                  }
                }
                Rectangle {
                  width: 60; height: 28; radius: 6
                  color: Qt.rgba(1,1,1,0.05)
                  border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 4
                    Text {
                      width: parent.width - 14; height: parent.height
                      text: root.newSlotHour.toString().padStart(2,"0") + "h"
                      font.pixelSize: 11; color: root.colorText
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }
                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 0
                      Text {
                        text: "\uf077"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7
                        color: root.colorTextDim; opacity: 0.6
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.newSlotHour = (root.newSlotHour+1)%24 }
                      }
                      Text {
                        text: "\uf078"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7
                        color: root.colorTextDim; opacity: 0.6
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.newSlotHour = (root.newSlotHour+23)%24 }
                      }
                    }
                  }
                }
              }

              Row {
                width: parent.width
                spacing: 6
                layoutDirection: Qt.RightToLeft
                Rectangle {
                  width: 64; height: 24; radius: 6
                  color: confma2.containsMouse
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32)
                    : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  border.color: root.colorAccent; border.width: 1
                  Behavior on color { ColorAnimation { duration: 100 } }
                  Text { anchors.centerIn: parent; text: "Adicionar"; font.pixelSize: 9; color: root.colorAccent }
                  MouseArea { id: confma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root._addSlot(root.newSlotName, root.newSlotHour) }
                }
                Rectangle {
                  width: 60; height: 24; radius: 6
                  color: cncma2.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                  border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                  Behavior on color { ColorAnimation { duration: 100 } }
                  Text { anchors.centerIn: parent; text: "Cancelar"; font.pixelSize: 9; color: root.colorTextDim }
                  MouseArea { id: cncma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root.showAddSlot = false }
                }
              }
              Item { width: 1; height: 2 }
            }
          }

          Item { width: 1; height: 4 }

          // ── Cards dos slots ────────────────────────────────────────────
          Repeater {
            id: slotsRepeater
            model: root.slots

            // Cada delegate é um Item de altura calculada: card(68) + editor(variável)
            delegate: Item {
              id: slotDelegate
              width: listColumn.width - 20
              x: 10

              property bool isEditing: root.editingIdx === index
              // editorHeight: altura real do editor quando aberto.
              // Usamos um Column interno para medir o conteúdo.
              property int  editorContentH: editorMeasure.height
              property int  editorH: isEditing ? editorContentH + 20 : 0
              height: 72 + editorH   // card fixo 72px + editor colapsável

              Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

              // ── Card ──────────────────────────────────────────────────
              Rectangle {
                id: cardRect
                width: parent.width
                height: 72
                radius: 8
                color: isEditing
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.11)
                  : (cHov.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04))
                border.color: isEditing ? root.colorAccent : Qt.rgba(1,1,1,0.08)
                border.width: isEditing ? 1.5 : 1
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Row {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 10

                  // Thumb preview do wallpaper associado ao slot
                  Rectangle {
                    width: 82; height: 52
                    radius: 6; clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)

                    Image {
                      id: slotThumb
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      cache: false
                      smooth: true
                      source: {
                        var tp = root._slotThumbPath(modelData)
                        return tp !== "" ? ("file://" + tp) : ""
                      }
                    }

                    // Fallback quando não há imagem
                    Column {
                      anchors.centerIn: parent
                      spacing: 2
                      visible: slotThumb.status !== Image.Ready
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData && modelData.profile ? "\uf007"
                            : modelData && modelData.folder  ? "\uf07c" : "\uf03e"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                        color: root.colorAccent; opacity: 0.6
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (modelData && modelData.start !== undefined
                               ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                        font.pixelSize: 10; font.bold: true
                        color: root.colorAccent
                      }
                    }

                    // Badge de hora sobre o thumb
                    Rectangle {
                      visible: slotThumb.status === Image.Ready
                      anchors.bottom: parent.bottom; anchors.left: parent.left
                      anchors.margins: 4
                      radius: 4; color: Qt.rgba(0,0,0,0.70)
                      width: hbadgeTxt.implicitWidth + 8; height: 16
                      Text {
                        id: hbadgeTxt
                        anchors.centerIn: parent
                        text: (modelData && modelData.start !== undefined
                               ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                        font.pixelSize: 8; font.bold: true
                        color: root.colorAccent
                      }
                    }
                  }

                  // Info textual
                  Column {
                    width: parent.width - 82 - 30 - 20  // total - thumb - lixeira - spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                      width: parent.width
                      text: modelData.name || "(sem nome)"
                      font.pixelSize: 10; color: root.colorText
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: {
                        if (modelData.profile) return "\uf007 " + modelData.profile
                        if (modelData.file)    return "\uf15b " + modelData.file.split("/").pop()
                        if (modelData.folder)  return "\uf07c " + modelData.folder.split("/").pop()
                        return "\uf128 sem fonte"
                      }
                      font.pixelSize: 8; color: root.colorTextDim
                      elide: Text.ElideRight
                    }
                    Row {
                      spacing: 4
                      Text {
                        visible: modelData.palette && modelData.palette !== ""
                        text: (modelData.palette || "").replace("scheme-","")
                        font.pixelSize: 7; color: root.colorAccent; opacity: 0.85
                      }
                      Rectangle {
                        visible: modelData.effect && modelData.effect !== "off"
                        height: 13; radius: 6; width: efxL.implicitWidth + 8
                        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                        Text {
                          id: efxL; anchors.centerIn: parent
                          text: modelData.effect || ""; font.pixelSize: 7; color: root.colorAccent
                        }
                      }
                    }
                  }

                  // Lixeira
                  Rectangle {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6; color: delma.containsMouse ? Qt.rgba(1,0.25,0.25,0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                      anchors.centerIn: parent; text: "\uf1f8"
                      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                      color: delma.containsMouse ? "#ff7070" : root.colorTextDim
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                      id: delma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: if (!root.running) root._removeSlot(modelData.start)
                    }
                  }
                }

                MouseArea {
                  id: cHov
                  anchors.fill: parent; hoverEnabled: true; z: -1
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.editingIdx === index) root.editingIdx = -1
                    else root._openEditor(index)
                  }
                }
              }

              // ── Editor colapsável ──────────────────────────────────────
              // Fica logo abaixo do card. height = editorH (animado no delegate pai).
              Item {
                id: editorPanel
                anchors.top: cardRect.bottom
                anchors.topMargin: 2
                width: parent.width
                height: parent.height - cardRect.height - 2
                clip: true

                Rectangle {
                  anchors.fill: parent
                  radius: 8
                  color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.05)
                  border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  border.width: 1
                }

                // Coluna de medição do conteúdo (para calcular editorContentH)
                Column {
                  id: editorMeasure
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.leftMargin: 12; anchors.rightMargin: 12
                  anchors.top: parent.top; anchors.topMargin: 10
                  spacing: 8
                  visible: isEditing

                  // Nome + hora
                  Row {
                    width: parent.width
                    spacing: 6
                    Rectangle {
                      width: parent.width - 62; height: 26; radius: 5
                      color: Qt.rgba(1,1,1,0.05)
                      border.color: edNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                      border.width: 1
                      Behavior on border.color { ColorAnimation { duration: 120 } }
                      TextInput {
                        id: edNameIn
                        anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 10; color: root.colorText
                        text: root.editingIdx === index ? root.ed_name : ""
                        onTextChanged: if (root.editingIdx === index) root.ed_name = text
                      }
                    }
                    Rectangle {
                      width: 56; height: 26; radius: 5
                      color: Qt.rgba(1,1,1,0.05)
                      border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                      Row {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 4
                        Text {
                          width: parent.width - 14; height: parent.height
                          text: (root.editingIdx === index ? root.ed_start : 0).toString().padStart(2,"0") + "h"
                          font.pixelSize: 11; color: root.colorText
                          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        Column {
                          anchors.verticalCenter: parent.verticalCenter; spacing: 0
                          Text { text: "\uf077"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7
                                 color: root.colorTextDim; opacity: 0.7
                                 MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                             onClicked: if (root.editingIdx === index) root.ed_start = (root.ed_start+1)%24 } }
                          Text { text: "\uf078"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7
                                 color: root.colorTextDim; opacity: 0.7
                                 MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                             onClicked: if (root.editingIdx === index) root.ed_start = (root.ed_start+23)%24 } }
                        }
                      }
                    }
                  }

                  // Label palette
                  Text {
                    text: "PALETTE"
                    font.pixelSize: 7; font.letterSpacing: 1.2
                    color: root.colorTextDim; opacity: 0.6
                  }

                  // Chips de palette
                  Flow {
                    width: parent.width; spacing: 4
                    Repeater {
                      model: root.allPalettes
                      delegate: Item {
                        width: pchip.implicitWidth; height: 20
                        property bool isPSel: (root.editingIdx === index) && root.ed_palette === modelData
                        Rectangle {
                          id: pchip; anchors.fill: parent; radius: 10
                          implicitWidth: pchipT.implicitWidth + 14
                          color: isPSel
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                            : (pchipH.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                          border.color: isPSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                          border.width: isPSel ? 1.5 : 1
                          Behavior on color { ColorAnimation { duration: 110 } }
                          Text {
                            id: pchipT; anchors.centerIn: parent
                            text: modelData.replace("scheme-",""); font.pixelSize: 8
                            color: isPSel ? root.colorAccent : root.colorText
                          }
                        }
                        MouseArea {
                          id: pchipH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: if (root.editingIdx === index) root.ed_palette = modelData
                        }
                      }
                    }
                  }

                  // Quiet + Salvar
                  Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                      height: 26; radius: 5; width: qrowInner.implicitWidth + 16
                      color: (root.ed_quiet && root.editingIdx === index)
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                        : (qmaC.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                      border.color: (root.ed_quiet && root.editingIdx === index) ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 110 } }
                      Row {
                        id: qrowInner; anchors.centerIn: parent; spacing: 4
                        Text {
                          text: "\uf026"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                          color: (root.ed_quiet && root.editingIdx === index) ? root.colorAccent : root.colorTextDim
                        }
                        Text {
                          text: "quiet"; font.pixelSize: 8
                          color: (root.ed_quiet && root.editingIdx === index) ? root.colorText : root.colorTextDim
                        }
                      }
                      MouseArea {
                        id: qmaC; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.editingIdx === index) root.ed_quiet = !root.ed_quiet
                      }
                    }

                    Item { width: parent.width - (qrowInner.implicitWidth + 16) - (saveRow.implicitWidth + 18) - 12; height: 1 }

                    Rectangle {
                      id: saveBtnRect
                      height: 26; radius: 5; width: saveRow.implicitWidth + 18
                      opacity: root.running ? 0.4 : 1.0
                      color: savemaC.containsMouse
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32)
                        : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                      border.color: root.colorAccent; border.width: 1
                      Behavior on color { ColorAnimation { duration: 100 } }
                      Row {
                        id: saveRow; anchors.centerIn: parent; spacing: 5
                        Text {
                          text: "\uf00c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                          color: root.colorAccent
                        }
                        Text { text: "Salvar"; font.pixelSize: 9; color: root.colorAccent }
                      }
                      MouseArea {
                        id: savemaC; anchors.fill: parent; hoverEnabled: true
                        cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!root.running && root.editingIdx === index) root._saveSlot()
                      }
                    }
                  }

                  Item { width: 1; height: 4 }
                }
              }
            } // delegate Item
          } // Repeater

          Item { width: 1; height: 10 }
        } // Column listColumn
      } // Flickable
    } // listPanel

    // ── Divisor ────────────────────────────────────────────────────────────
    Rectangle {
      Layout.preferredWidth: 1
      Layout.fillHeight: true
      color: root.colorDivider
      opacity: root.editorOpen ? 0.4 : 0
      Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    // ── PAINEL DIREITO: grade de wallpapers ───────────────────────────────
    Item {
      id: rightPanel
      Layout.preferredWidth: root.editorOpen ? root.rightW : 0
      Layout.fillHeight: true
      clip: true
      visible: root.editorOpen
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Cabeçalho
        Item {
          Layout.fillWidth: true; height: 40

          Row {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
              text: "\uf03e  Wallpapers"
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
              color: root.colorAccent; opacity: 0.85
            }

            Rectangle {
              visible: root.editingIdx >= 0 && root.slots[root.editingIdx] !== undefined
              height: 20; radius: 10; anchors.verticalCenter: parent.verticalCenter
              implicitWidth: slotBadge.implicitWidth + 16
              color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
              border.color: root.colorAccent; border.width: 1
              Text {
                id: slotBadge; anchors.centerIn: parent
                text: root.editingIdx >= 0 && root.slots[root.editingIdx]
                      ? (root.slots[root.editingIdx].name || "") : ""
                font.pixelSize: 9; color: root.colorAccent
              }
            }
          }

          // Filtros de cor
          Flickable {
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(filterRow.implicitWidth, rightPanel.width - 180)
            height: 28
            contentWidth: filterRow.implicitWidth; contentHeight: height
            clip: true; flickableDirection: Flickable.HorizontalFlick
            boundsMovement: Flickable.StopAtBounds

            Row {
              id: filterRow
              anchors.verticalCenter: parent.verticalCenter; spacing: 4
              Repeater {
                model: root.pickerColorFilters
                delegate: Item {
                  width: frc.implicitWidth; height: 22
                  readonly property bool isAct: root.pickerFilter === modelData.id
                  Rectangle {
                    id: frc; anchors.fill: parent; radius: 11
                    implicitWidth: frrow.implicitWidth + 12
                    color: isAct
                      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                      : (frma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                    border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                    border.width: isAct ? 1.5 : 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Row {
                      id: frrow; anchors.centerIn: parent; spacing: 4
                      Rectangle {
                        visible: modelData.swatch !== ""
                        width: 7; height: 7; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.swatch || "transparent"
                        border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                      }
                      Text {
                        text: modelData.label; font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: isAct ? root.colorText : root.colorTextDim
                        Behavior on color { ColorAnimation { duration: 100 } }
                      }
                    }
                  }
                  MouseArea {
                    id: frma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickerFilter = modelData.id
                  }
                }
              }
            }
          }

          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.colorDivider; opacity: 0.25 }
        }

        // Grade de wallpapers
        Item {
          Layout.fillWidth: true; Layout.fillHeight: true

          Text {
            anchors.centerIn: parent; visible: root.pickerLoading
            text: "\uf110  carregando…"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
            color: root.colorTextDim; opacity: 0.6
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.pickerLoading }
          }
          Text {
            anchors.centerIn: parent
            visible: !root.pickerLoading && root.pickerEntries.length === 0
            text: "\uf03e  nenhum wallpaper"
            font.pixelSize: 11; color: root.colorTextDim; opacity: 0.4
          }

          GridView {
            id: wpGrid
            anchors { fill: parent; margins: 8 }
            visible: !root.pickerLoading; clip: true
            cellWidth:  Math.max(1, Math.floor((width - 4) / 3))
            cellHeight: cellWidth * 9 / 16 + 24
            model: root.pickerFiltered
            property int hoveredIdx: -1

            delegate: Item {
              width: wpGrid.cellWidth; height: wpGrid.cellHeight

              readonly property bool isHov:     wpGrid.hoveredIdx === index
              readonly property bool isCurSlot: {
                if (root.editingIdx < 0) return false
                var s = root.slots[root.editingIdx]
                if (!s) return false
                return (s.file || "") === modelData.value.replace(/^file:\/\//, "").replace(/^file:/, "")
              }

              Rectangle {
                anchors { fill: parent; margins: 3 }
                radius: 7; clip: true
                color: isCurSlot
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                  : Qt.rgba(1,1,1,0.04)
                border.color: isCurSlot ? root.colorAccent
                             : isHov    ? Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.25)
                             : "transparent"
                border.width: isCurSlot ? 1.5 : 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Image {
                  id: wpThumb
                  anchors { top: parent.top; left: parent.left; right: parent.right }
                  height: parent.width * 9 / 16
                  fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true
                  source: modelData.thumb !== "" ? ("file://" + modelData.thumb) : ""

                  Rectangle {
                    anchors.fill: parent; visible: wpThumb.status !== Image.Ready
                    color: Qt.rgba(1,1,1,0.04); radius: parent.radius
                  }
                  Rectangle {
                    visible: isCurSlot
                    anchors { top: parent.top; right: parent.right; margins: 4 }
                    width: 18; height: 18; radius: 9; color: root.colorAccent
                    Text {
                      anchors.centerIn: parent; text: "\uf00c"
                      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: "#1f1f1f"
                    }
                  }
                  Rectangle {
                    anchors.fill: parent; visible: isHov
                    color: Qt.rgba(0,0,0,0.42)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                      anchors.centerIn: parent; spacing: 3
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter; text: "\uf017"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: root.colorAccent
                      }
                      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "atribuir"; font.pixelSize: 8; color: "white" }
                    }
                  }
                }

                Text {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 3 }
                  height: 18; text: modelData.label || ""; font.pixelSize: 8
                  color: isHov ? root.colorText : root.colorTextDim
                  elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
              }

              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: wpGrid.hoveredIdx = index
                onExited:  if (wpGrid.hoveredIdx === index) wpGrid.hoveredIdx = -1
                onClicked: {
                  if (root.editingIdx < 0) return
                  var path = modelData.value.replace(/^file:\/\//, "").replace(/^file:/, "")
                  root.assignWallpaperToSlot(root.editingIdx, path)
                }
              }
            }

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          }
        }
      }
    }
  } // RowLayout raiz
}
