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
  // -1 = todos, 0..359 = hue central do filtro
  property real   pickerHueFilter: -1

  // Lookup thumb por path (preenchido ao carregar o picker)
  property var    _thumbByPath: ({})

  // Janela de tolerância da roda de matiz para o slider
  readonly property real hueWindow: 35

  readonly property var hueStops: [
    { hue: -1,  label: "Todos", color: "#888888" },
    { hue: 0,   label: "Verm.",  color: "#e05555" },
    { hue: 30,  label: "Laran.", color: "#e07d30" },
    { hue: 60,  label: "Amar.",  color: "#d4b84a" },
    { hue: 120, label: "Verde",  color: "#4caf6f" },
    { hue: 180, label: "Ciano",  color: "#3aabb8" },
    { hue: 220, label: "Azul",   color: "#4a78d4" },
    { hue: 270, label: "Roxo",   color: "#8b4fd4" },
    { hue: 320, label: "Rosa",   color: "#d44f9a" },
    { hue: 200, label: "P&B",    color: "#aaaaaa" }   // mono tratado à parte
  ]

  function _hueDist(a, b) {
    var d = Math.abs(a - b) % 360
    return d > 180 ? 360 - d : d
  }

  readonly property var pickerFiltered: {
    if (pickerHueFilter < 0) return pickerEntries
    var out = []
    for (var i = 0; i < pickerEntries.length; i++) {
      var e = pickerEntries[i]
      var h = e.hue !== undefined ? e.hue : -1
      if (h < 0) continue   // mono/sem cor — excluir quando há filtro de hue
      if (_hueDist(h, pickerHueFilter) <= hueWindow) out.push(e)
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

  property bool   showAddSlot:  false
  property string newSlotName:  ""
  property int    newSlotHour:  0

  readonly property var allPalettes: [
    "scheme-content", "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow", "scheme-tonal-spot"
  ]

  // fonte matugen — igual ao WallpaperTabMatugen
  readonly property var matugenSources: [
    { id: "base",  label: "base"  },
    { id: "final", label: "final" }
  ]

  // swatches de cor da fonte (carregados sob demanda ao abrir editor)
  property var    swatchColors:    []
  property bool   loadingSwatches: false

  // ── Layout ────────────────────────────────────────────────────────────────
  readonly property bool editorOpen: editingIdx >= 0
  readonly property int  listW:  editorOpen ? Math.floor(width * 0.42) : width
  readonly property int  rightW: width - listW - 1

  // Path do preview de um slot.
  // Tenta 1: thumb do picker (indexado por path)
  // Tenta 2: cache/<basename>.png
  function _slotThumbPath(md) {
    if (!md) return ""
    var f = md.file || ""
    if (f === "") return ""
    // 1 — do picker
    if (root._thumbByPath[f] !== undefined) return root._thumbByPath[f]
    // 2 — cache por basename
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
    var patch = JSON.stringify({
      file: wallpaperPath, folder: "", profile: "",
      effect:         root.ed_effect,
      palette:        root.ed_palette,
      matugen_source: root.ed_msrc,
      matugen_index:  root.ed_midx,
      random:         root.ed_random,
      quiet:          root.ed_quiet
    })
    var assignScript =
      "import sys, json, os, subprocess\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S\n" +
      "patch = json.loads(os.environ['WP_PATCH'])\n" +
      "orig  = int(os.environ['WP_START'])\n" +
      "lib   = os.environ['WP_LIB']\n" +
      "wp    = os.environ['WP_PATH']\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == orig:\n" +
      "        sl.update(patch); break\n" +
      "S._save_config(cfg)\n" +
      "if os.path.isfile(lib):\n" +
      "    subprocess.Popen(['bash','-c','source '+repr(lib)+' && generate_wall_thumb '+repr(wp)],\n" +
      "        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
    assignProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + assignScript + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_PATCH=" + JSON.stringify(patch) +
      " WP_START=" + JSON.stringify(String(origStart)) +
      " WP_LIB=" + JSON.stringify(root.mlScripts + "/wallpaper-lib.sh") +
      " WP_PATH=" + JSON.stringify(wallpaperPath) +
      " python3 \"$tmp\""
    ]
    if (!assignProc.running) {
      // processo não iniciou — reseta imediatamente
      root.running = false
      return
    }
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
    var reloadScript =
      "import sys, json, os\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S, profile as P\n" +
      "cfg = S.load_config()\n" +
      "json_enabled = bool(cfg.get('enabled', True))\n" +
      "timer_active = os.environ.get('WP_TIMER_ACTIVE', '0') == '1'\n" +
      "slots = S.slots_list()\n" +
      "effects = ['off']\n" +
      "ed = os.environ['WP_EFFECTS']\n" +
      "if os.path.isdir(ed):\n" +
      "    effects += sorted(e for e in os.listdir(ed) if not e.startswith('.'))\n" +
      "profiles = list(P.load_all().keys())\n" +
      "print(json.dumps({'json_enabled': json_enabled, 'timer_active': timer_active,\n" +
      "    'slots': slots, 'effects': effects, 'profiles': profiles}))\n"
    loadProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + reloadScript + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_EFFECTS=" + JSON.stringify(root.effectsDir) +
      " WP_TIMER_ACTIVE=$(systemctl --user is-active wallpaper-schedule.timer 2>/dev/null | grep -c '^active$' || echo 0)" +
      " python3 \"$tmp\""
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
    property int    _savedStart: -1
    stdout: SplitParser { onRead: function(l) { saveSlotProc._buf += l } }
    onRunningChanged: {
      if (running) return
      saveSlotProc._buf = ""
      // Atualiza root.slots localmente com os valores do editor,
      // sem precisar de _reload() (que fecharia o editor e perderia seleção)
      if (root.editingIdx >= 0 && root.editingIdx < root.slots.length) {
        var arr = root.slots.slice()
        var sl = {}
        for (var k in arr[root.editingIdx]) sl[k] = arr[root.editingIdx][k]
        sl.name           = root.ed_name
        sl.start          = root.ed_start
        sl.file           = root.ed_file
        sl.folder         = root.ed_folder
        sl.profile        = root.ed_profile
        sl.effect         = root.ed_effect
        sl.palette        = root.ed_palette
        sl.matugen_source = root.ed_msrc
        sl.matugen_index  = root.ed_midx
        sl.random         = root.ed_random
        sl.quiet          = root.ed_quiet
        arr[root.editingIdx] = sl
        root.slots = arr
      }
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

  // ── Swatches de cor matugen do slot ──────────────────────────────────────────
  // Usa slot-matugen-colors que faz cache em WP_CACHE_DIR/slot-colors/<hash>-<src>.txt
  // Não re-executa matugen se o cache existir.

  Process {
    id: slotSwatchProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { slotSwatchProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.loadingSwatches = false
      var raw = slotSwatchProc._buf.trim(); slotSwatchProc._buf = ""
      var colors = []
      raw.split("\n").forEach(function(l) {
        var c = l.trim()
        if (/^#[0-9a-fA-F]{6}$/.test(c)) colors.push(c)
      })
      root.swatchColors = colors
    }
  }

  // wallpaperPath = ed_file do slot; msrc = ed_msrc ("base" ou "final")
  function _loadSlotSwatches(wallpaperPath, msrc) {
    if (!wallpaperPath || wallpaperPath === "") {
      root.swatchColors = []
      root.loadingSwatches = false
      return
    }
    if (slotSwatchProc.running) return
    root.loadingSwatches = true
    root.swatchColors = []
    var src = msrc || "base"
    var script = root.mlScripts + "/slot-matugen-colors"
    slotSwatchProc.command = [
      "bash", script,
      wallpaperPath,
      src
    ]
    slotSwatchProc.running = true
  }

  // ── Previews de efeitos do slot ───────────────────────────────────────────
  // Usa slot-effect-previews que espelha _slot_effect_picker do wallpaper-schedule.sh.
  // Persiste em WP_CACHE_DIR/effect-previews-slot-{start}/ com cache hash-based.

  property var    effectPreviews:       ({})
  property bool   generatingEffectPrev: false
  property int    effectPrevVersion:    0

  Process {
    id: effectPreviewProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { effectPreviewProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      root.generatingEffectPrev = false
      var raw = effectPreviewProc._buf.trim(); effectPreviewProc._buf = ""
      var map = {}
      raw.split("\n").forEach(function(l) {
        var m = l.match(/^([^=]+)=(.+)$/)
        if (m) map[m[1].trim()] = m[2].trim()
      })
      root.effectPreviews = map
      root.effectPrevVersion++
    }
  }

  function _generateSlotEffectPreviews(slotStart, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath === "") return
    if (effectPreviewProc.running) return
    root.generatingEffectPrev = true
    root.effectPreviews = {}
    var script = root.mlScripts + "/slot-effect-previews"
    effectPreviewProc.command = [
      "bash", script,
      String(slotStart),
      wallpaperPath
    ]
    effectPreviewProc.running = true
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
        var byPath = {}
        for (var i = 0; i < data.length; i++) {
          var e = data[i]
          var path = (e.value || "").replace(/^file:\/\//, "").replace(/^file:/, "")
          if (e.thumb && e.thumb !== "") byPath[path] = e.thumb
          arr.push({ label: e.label || "", value: e.value || "", thumb: e.thumb || "", hue: -1 })
        }
        root._thumbByPath = byPath
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
        // actualiza byPath com hue não é necessário — já temos o thumb
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
      "rm -f \"$HOME/.config/ml4w/cache/schedule-state.json\" && " +
      "bash '" + root.mlScripts + "/wallpaper-schedule.sh' run 2>/dev/null"
    ]
    actionProc.running = true
  }

  function _addSlot(name, hour) {
    if (root.running || !name || name.trim() === "") return
    root.running = true; root.showAddSlot = false
    var addScript =
      "import sys, os\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S\n" +
      "try: S.add_slot(os.environ['WP_NAME'], int(os.environ['WP_HOUR']))\n" +
      "except ValueError as e: print('ERR:', e)\n"
    mutateProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + addScript + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_NAME=" + JSON.stringify(name.trim()) +
      " WP_HOUR=" + JSON.stringify(String(hour)) +
      " python3 \"$tmp\""
    ]
    mutateProc.running = true
  }

  function _addSlotWithWallpaper(name, hour, wallpaperPath) {
    if (root.running || !name || name.trim() === "") return
    root.running = true; root.showAddSlot = false
    var addWpScript =
      "import sys, os, subprocess\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S\n" +
      "name = os.environ['WP_NAME']\n" +
      "hour = int(os.environ['WP_HOUR'])\n" +
      "wp   = os.environ['WP_PATH']\n" +
      "lib  = os.environ['WP_LIB']\n" +
      "try: S.add_slot(name, hour)\n" +
      "except ValueError: pass\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == hour and sl.get('name') == name:\n" +
      "        sl['file'] = wp; sl['folder'] = ''; sl['profile'] = ''\n" +
      "        break\n" +
      "S._save_config(cfg)\n" +
      "if os.path.isfile(lib):\n" +
      "    subprocess.Popen(['bash','-c','source '+repr(lib)+' && generate_wall_thumb '+repr(wp)],\n" +
      "        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
    mutateProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + addWpScript + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_NAME=" + JSON.stringify(name.trim()) +
      " WP_HOUR=" + JSON.stringify(String(hour)) +
      " WP_PATH=" + JSON.stringify(wallpaperPath) +
      " WP_LIB=" + JSON.stringify(root.mlScripts + "/wallpaper-lib.sh") +
      " python3 \"$tmp\""
    ]
    mutateProc.running = true
  }

  function _removeSlot(start) {
    if (root.running) return
    root.running = true; root.editingIdx = -1
    var rmScript =
      "import sys, os\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S\n" +
      "try: S.remove_slot(int(os.environ['WP_START']))\n" +
      "except ValueError: pass\n"
    mutateProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + rmScript + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_START=" + JSON.stringify(String(start)) +
      " python3 \"$tmp\""
    ]
    mutateProc.running = true
  }

  function _openEditor(idx) {
    var s = root.slots[idx]
    if (!s) return
    root._openingEditor = true   // bloqueia auto-save durante atribuição dos campos
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
    root._openingEditor = false   // libera auto-save
    root._pickerLoad()
    // swatches e previews de efeito baseados no wallpaper do slot
    var slotFile = s.file || ""
    var slotStart = s.start !== undefined ? s.start : 0
    root.swatchColors = []
    root._loadSlotSwatches(slotFile, root.ed_msrc)
    root._generateSlotEffectPreviews(slotStart, slotFile)
  }

  function _saveSlot() {
    if (root.editingIdx < 0) return
    var slot = root.slots[root.editingIdx]
    if (!slot) return
    // Não bloqueia em root.running — save de campos leves (palette/efeito/etc)
    // deve sempre passar. Se saveSlotProc já estiver rodando, reagenda em vez
    // de descartar silenciosamente (o timer já disparou e não reinicia sozinho).
    if (saveSlotProc.running) { autoSaveTimer.restart(); return }
    var origStart = slot.start
    var patch = JSON.stringify({
      name: root.ed_name, start: root.ed_start,
      file: root.ed_file, folder: root.ed_folder, profile: root.ed_profile,
      effect: root.ed_effect, palette: root.ed_palette,
      matugen_source: root.ed_msrc, matugen_index: root.ed_midx,
      random: root.ed_random, quiet: root.ed_quiet
    })
    var script =
      "import sys, json, os\n" +
      "sys.path.insert(0, os.environ['WP_SCRIPTS'])\n" +
      "from wp import schedule as S\n" +
      "patch = json.loads(os.environ['WP_PATCH'])\n" +
      "orig  = int(os.environ['WP_START'])\n" +
      "cfg = S.load_config()\n" +
      "for sl in cfg['slots']:\n" +
      "    if sl['start'] == orig:\n" +
      "        sl.update(patch); break\n" +
      "S._save_config(cfg)\n"
    saveSlotProc.command = [
      "bash", "-c",
      "tmp=$(mktemp /tmp/qs_wp_XXXXXX.py);" +
      "trap 'rm -f $tmp' EXIT;" +
      "cat > \"$tmp\" << 'PYEOF'\n" + script + "PYEOF\n" +
      "WP_SCRIPTS=" + JSON.stringify(root.mlScripts) +
      " WP_PATCH=" + JSON.stringify(patch) +
      " WP_START=" + JSON.stringify(String(origStart)) +
      " python3 \"$tmp\""
    ]
    saveSlotProc.running = true
  }

  // Guard: reseta root.running se algum processo travar por mais de 15s
  Timer {
    id: runningWatchdog
    interval: 15000
    repeat: false
    running: root.running
    onTriggered: {
      root.running = false
      console.warn("WallpaperTabSchedule: running watchdog triggered — resetting")
    }
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      root._reload()
      root._pickerLoad()
    }
  }

  onEd_fileChanged: {
    if (root.editingIdx < 0 || root.ed_file === "") return
    var slot = root.slots[root.editingIdx]
    var slotStart = slot ? (slot.start !== undefined ? slot.start : 0) : 0
    root.swatchColors = []
    root._loadSlotSwatches(root.ed_file, root.ed_msrc)
    root._generateSlotEffectPreviews(slotStart, root.ed_file)
  }

  onEd_msrcChanged: {
    // Recarrega swatches quando a fonte matugen muda (base vs final)
    if (root.editingIdx < 0 || root.ed_file === "") return
    root.swatchColors = []
    root._loadSlotSwatches(root.ed_file, root.ed_msrc)
    root._autoSave()
  }

  // Impede auto-save de disparar enquanto _openEditor seta os campos
  property bool _openingEditor: false

  Timer {
    id: autoSaveTimer
    interval: 800
    repeat: false
    onTriggered: root._saveSlot()
  }

  function _autoSave() {
    if (root.editingIdx < 0) return
    if (root._openingEditor) return   // não salva durante abertura do editor
    autoSaveTimer.restart()
  }

  onEd_paletteChanged: root._autoSave()
  onEd_midxChanged:    root._autoSave()
  onEd_effectChanged:  root._autoSave()

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ────────────────────────────────────────────────────────────────────────
    // PAINEL ESQUERDO: lista de slots
    // ────────────────────────────────────────────────────────────────────────
    Item {
      id: listPanel
      Layout.preferredWidth: root.listW
      Layout.fillHeight: true
      clip: true
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      Flickable {
        id: listFlick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: listColumn.height
        boundsMovement: Flickable.StopAtBounds

        Column {
          id: listColumn
          width: listFlick.width
          spacing: 0

          Item { width: 1; height: 10 }

          // ── Status card ──────────────────────────────────────────────────
          Rectangle {
            width: listColumn.width - 20; x: 10; height: 58; radius: 10
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
              anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
              Text {
                text: root.loading ? "\uf110" : "\uf017"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                color: root.timerActive ? root.colorAccent : root.colorTextDim
                opacity: root.timerActive ? 1.0 : 0.3
                Behavior on color   { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                RotationAnimator on rotation {
                  from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.loading
                }
              }
              Column {
                Layout.fillWidth: true; spacing: 2
                Text { text: root.timerActive ? "Timer ativo" : "Timer inativo"; font.pixelSize: 10; color: root.colorText }
                Text { text: (root.schedEnabled ? "on" : "off") + "  ·  " + root.slots.length + " slot(s)"; font.pixelSize: 8; color: root.colorTextDim }
              }
              Rectangle {
                width: 26; height: 26; radius: 6; opacity: root.running ? 0.4 : 1.0
                color: rnma.containsMouse ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22) : Qt.rgba(1,1,1,0.06)
                border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3); border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "\uf04b"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: root.colorAccent }
                MouseArea { id: rnma; anchors.fill: parent; hoverEnabled: true; cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!root.running) root._runNow() }
              }
              Rectangle {
                width: 44; height: 22; radius: 11
                color: root.timerActive ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.28) : Qt.rgba(1,1,1,0.08)
                Behavior on color { ColorAnimation { duration: 200 } }
                Rectangle {
                  width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                  x: root.timerActive ? parent.width - 20 : 4
                  color: root.timerActive ? root.colorAccent : root.colorTextDim
                  Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation  { duration: 200 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root._toggle() }
              }
            }
          }

          Item { width: 1; height: 8 }

          // ── Cabeçalho SLOTS + botão ──────────────────────────────────────
          Item {
            width: listColumn.width - 20; x: 10; height: 24
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "SLOTS"; font.pixelSize: 8; font.letterSpacing: 1.4
              color: root.colorTextDim; opacity: 0.65
            }
            Rectangle {
              anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
              width: 20; height: 20; radius: 5
              color: addma.containsMouse ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22) : Qt.rgba(1,1,1,0.06)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3); border.width: 1
              Behavior on color { ColorAnimation { duration: 100 } }
              Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; color: root.colorAccent }
              MouseArea { id: addma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: { root.showAddSlot = !root.showAddSlot; root.newSlotName = ""; root.newSlotHour = 0 } }
            }
          }

          Item { width: 1; height: 4 }

          // ── Formulário novo slot ─────────────────────────────────────────
          Item {
            width: listColumn.width - 20; x: 10
            height: root.showAddSlot ? addFormCol.height + 16 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; radius: 8
              color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.06)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22); border.width: 1 }
            Column {
              id: addFormCol
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.topMargin: 8
              spacing: 8
              Text { text: "Novo slot"; font.pixelSize: 10; color: root.colorAccent }
              Row {
                width: parent.width; spacing: 6
                Rectangle {
                  width: parent.width - 66; height: 28; radius: 6
                  color: Qt.rgba(1,1,1,0.05)
                  border.color: addNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1); border.width: 1
                  Behavior on border.color { ColorAnimation { duration: 120 } }
                  TextInput {
                    id: addNameIn; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter; font.pixelSize: 10; color: root.colorText
                    text: root.newSlotName; onTextChanged: root.newSlotName = text
                    Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                           text: "nome do slot"; color: root.colorTextDim; font: parent.font; opacity: 0.4
                           visible: parent.text.length === 0 && !parent.activeFocus }
                  }
                }
                Rectangle {
                  width: 60; height: 28; radius: 6; color: Qt.rgba(1,1,1,0.05)
                  border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                  Row {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 4
                    Text { width: parent.width - 14; height: parent.height; text: root.newSlotHour.toString().padStart(2,"0") + "h"
                           font.pixelSize: 11; color: root.colorText; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    Column {
                      anchors.verticalCenter: parent.verticalCenter; spacing: 0
                      Text { text: "\uf077"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7; color: root.colorTextDim; opacity: 0.6
                             MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.newSlotHour = (root.newSlotHour+1)%24 } }
                      Text { text: "\uf078"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7; color: root.colorTextDim; opacity: 0.6
                             MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.newSlotHour = (root.newSlotHour+23)%24 } }
                    }
                  }
                }
              }
              Row {
                width: parent.width; spacing: 6; layoutDirection: Qt.RightToLeft
                Rectangle { width: 64; height: 24; radius: 6
                  color: confma2.containsMouse ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32) : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  border.color: root.colorAccent; border.width: 1
                  Behavior on color { ColorAnimation { duration: 100 } }
                  Text { anchors.centerIn: parent; text: "Adicionar"; font.pixelSize: 9; color: root.colorAccent }
                  MouseArea { id: confma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                              onClicked: root._addSlot(root.newSlotName, root.newSlotHour) }
                }
                Rectangle { width: 60; height: 24; radius: 6
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

          // ── Cards dos slots ──────────────────────────────────────────────
          Repeater {
            model: root.slots
            delegate: Item {
              id: slotDelegate
              width: listColumn.width - 20; x: 10
              readonly property int slotIndex: index   // captura antes de Repeaters internos sobrescreverem
              property bool isEditing: root.editingIdx === slotIndex
              property int  editorContentH: isEditing ? editorMeasure.height : 0
              property int  editorH: isEditing ? editorContentH + 20 : 0
              height: 76 + editorH
              Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

              // ── Card (altura fixa 76px) ──────────────────────────────────
              Rectangle {
                id: cardRect; width: parent.width; height: 76; radius: 8
                color: isEditing
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.11)
                  : (cHov.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04))
                border.color: isEditing ? root.colorAccent : Qt.rgba(1,1,1,0.08)
                border.width: isEditing ? 1.5 : 1
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Row {
                  anchors.fill: parent; anchors.margins: 10; spacing: 10

                  // ── Thumb ────────────────────────────────────────────────
                  Rectangle {
                    width: 88; height: 56; radius: 6; clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)

                    Image {
                      id: slotThumb; anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true; cache: false; smooth: true
                      source: {
                        var tp = root._slotThumbPath(modelData)
                        return tp !== "" ? ("file://" + tp) : ""
                      }
                    }

                    // Fallback
                    Column {
                      anchors.centerIn: parent; spacing: 2
                      visible: slotThumb.status !== Image.Ready
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.profile ? "\uf007" : modelData.folder ? "\uf07c" : "\uf03e"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                        color: root.colorAccent; opacity: 0.55
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (modelData.start !== undefined ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                        font.pixelSize: 11; font.bold: true; color: root.colorAccent
                      }
                    }

                    // Badge hora
                    Rectangle {
                      visible: slotThumb.status === Image.Ready
                      anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 4
                      radius: 4; color: Qt.rgba(0,0,0,0.72); width: hbTxt.implicitWidth + 8; height: 16
                      Text {
                        id: hbTxt; anchors.centerIn: parent
                        text: (modelData.start !== undefined ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                        font.pixelSize: 8; font.bold: true; color: root.colorAccent
                      }
                    }

                    // Cor do palette (badge topo-direito)
                    Rectangle {
                      visible: slotThumb.status === Image.Ready && modelData.palette && modelData.palette !== ""
                      anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                      radius: 4; color: Qt.rgba(0,0,0,0.65); width: palBadge.implicitWidth + 8; height: 14
                      Text {
                        id: palBadge; anchors.centerIn: parent
                        text: (modelData.palette || "").replace("scheme-","")
                        font.pixelSize: 7; color: "#ccc"
                      }
                    }
                  }

                  // ── Info textual ─────────────────────────────────────────
                  Column {
                    width: parent.width - 88 - 30 - 20
                    anchors.verticalCenter: parent.verticalCenter; spacing: 4

                    Text {
                      width: parent.width
                      text: modelData.name || "(sem nome)"
                      font.pixelSize: 10; color: root.colorText; elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: {
                        if (modelData.profile) return "\uf007 " + modelData.profile
                        if (modelData.file)    return "\uf15b " + modelData.file.split("/").pop()
                        if (modelData.folder)  return "\uf07c " + modelData.folder.split("/").pop()
                        return "\uf128 sem fonte"
                      }
                      font.pixelSize: 8; color: root.colorTextDim; elide: Text.ElideRight
                    }
                    Row {
                      spacing: 4
                      // Palette chip
                      Rectangle {
                        visible: modelData.palette && modelData.palette !== ""
                        height: 14; radius: 7; width: palChipTxt.implicitWidth + 10
                        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                        Text { id: palChipTxt; anchors.centerIn: parent
                               text: (modelData.palette || "").replace("scheme-","")
                               font.pixelSize: 7; color: root.colorAccent }
                      }
                      // Efeito chip
                      Rectangle {
                        visible: modelData.effect && modelData.effect !== "off"
                        height: 14; radius: 7; width: efxChipTxt.implicitWidth + 10
                        color: Qt.rgba(0.5, 0.7, 1.0, 0.18)
                        Text { id: efxChipTxt; anchors.centerIn: parent
                               text: modelData.effect || ""; font.pixelSize: 7; color: "#aad4ff" }
                      }
                      // Fonte chip
                      Rectangle {
                        visible: modelData.matugen_source && modelData.matugen_source !== "base"
                        height: 14; radius: 7; width: srcChipTxt.implicitWidth + 10
                        color: Qt.rgba(0.7, 1.0, 0.5, 0.15)
                        Text { id: srcChipTxt; anchors.centerIn: parent
                               text: modelData.matugen_source || ""; font.pixelSize: 7; color: "#bbeebb" }
                      }
                    }
                  }

                  // ── Lixeira ───────────────────────────────────────────────
                  Rectangle {
                    width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter
                    radius: 6; color: delma.containsMouse ? Qt.rgba(1,0.25,0.25,0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "\uf1f8"
                           font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                           color: delma.containsMouse ? "#ff7070" : root.colorTextDim
                           Behavior on color { ColorAnimation { duration: 100 } } }
                    MouseArea { id: delma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!root.running) { root.editingIdx = -1; root._removeSlot(modelData.start) } }
                  }
                }

                MouseArea {
                  id: cHov; anchors.fill: parent; hoverEnabled: true; z: -1; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.editingIdx === slotIndex) root.editingIdx = -1
                    else root._openEditor(slotIndex)
                  }
                }
              }

              // ── Editor colapsável ──────────────────────────────────────────
              Item {
                anchors.top: cardRect.bottom; anchors.topMargin: 2
                width: parent.width
                height: parent.height - cardRect.height - 2
                clip: true

                Rectangle {
                  anchors.fill: parent; radius: 8
                  color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.05)
                  border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  border.width: 1
                }

                Column {
                  id: editorMeasure
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 10
                  spacing: 8
                  visible: isEditing

                  // Nome + hora
                  Row {
                    width: parent.width; spacing: 6
                    Rectangle {
                      width: parent.width - 62; height: 26; radius: 5
                      color: Qt.rgba(1,1,1,0.05)
                      border.color: edNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                      border.width: 1
                      Behavior on border.color { ColorAnimation { duration: 120 } }
                      TextInput {
                        id: edNameIn; anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7
                        verticalAlignment: TextInput.AlignVCenter; font.pixelSize: 10; color: root.colorText
                        text: root.editingIdx === slotIndex ? root.ed_name : ""
                        onTextChanged: if (root.editingIdx === slotIndex) root.ed_name = text
                      }
                    }
                    Rectangle {
                      width: 56; height: 26; radius: 5; color: Qt.rgba(1,1,1,0.05)
                      border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                      Row {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 4
                        Text { width: parent.width - 14; height: parent.height
                               text: (root.editingIdx === slotIndex ? root.ed_start : 0).toString().padStart(2,"0") + "h"
                               font.pixelSize: 11; color: root.colorText
                               horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        Column {
                          anchors.verticalCenter: parent.verticalCenter; spacing: 0
                          Text { text: "\uf077"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7; color: root.colorTextDim; opacity: 0.7
                                 MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                             onClicked: if (root.editingIdx === slotIndex) root.ed_start = (root.ed_start+1)%24 } }
                          Text { text: "\uf078"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7; color: root.colorTextDim; opacity: 0.7
                                 MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                             onClicked: if (root.editingIdx === slotIndex) root.ed_start = (root.ed_start+23)%24 } }
                        }
                      }
                    }
                  }

                  // ── Fonte matugen (base / final) ───────────────────────────
                  Text {
                    text: "FONTE MATUGEN"
                    font.pixelSize: 7; font.letterSpacing: 1.2
                    color: root.colorTextDim; opacity: 0.6
                  }
                  Row {
                    width: parent.width; spacing: 5
                    Repeater {
                      model: root.matugenSources
                      delegate: Item {
                        width: srcChip.implicitWidth; height: 24
                        property bool isMSel: (root.editingIdx === slotIndex) && root.ed_msrc === modelData.id
                        Rectangle {
                          id: srcChip; anchors.fill: parent; radius: 14
                          implicitWidth: srcLabel.implicitWidth + 24
                          color: isMSel
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                            : (srcMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.06))
                          border.color: isMSel ? root.colorAccent : Qt.rgba(1,1,1,0.10)
                          border.width: isMSel ? 1.5 : 1
                          Behavior on color { ColorAnimation { duration: 120 } }
                          Text {
                            id: srcLabel; anchors.centerIn: parent
                            text: modelData.label; font.pixelSize: 10
                            color: isMSel ? root.colorAccent : root.colorText
                            Behavior on color { ColorAnimation { duration: 100 } }
                          }
                        }
                        MouseArea {
                          id: srcMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: if (root.editingIdx === slotIndex) root.ed_msrc = modelData.id
                        }
                      }
                    }
                  }

                  // ── Cor da fonte (swatches) ────────────────────────────────
                  Row {
                    width: parent.width
                    spacing: 6
                    Text {
                      text: "COR DA FONTE"
                      font.pixelSize: 7; font.letterSpacing: 1.2
                      color: root.colorTextDim; opacity: 0.6
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    // Reload swatches
                    Item {
                      width: 18; height: 18
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        anchors.centerIn: parent; text: "\uf021"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        color: root.loadingSwatches
                          ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
                          : root.colorTextDim
                        opacity: 0.7
                        RotationAnimator on rotation {
                          from: 0; to: 360; duration: 900
                          loops: Animation.Infinite; running: root.loadingSwatches
                        }
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (!slotSwatchProc.running && root.editingIdx >= 0) {
                            root.swatchColors = []
                            root._loadSlotSwatches(root.ed_file, root.ed_msrc)
                          }
                        }
                      }
                    }
                  }

                  Text {
                    visible: root.loadingSwatches
                    text: "carregando paleta…"
                    font.pixelSize: 9; color: root.colorTextDim; opacity: 0.5
                  }

                  // Grade de swatches — idêntica ao WallpaperTabMatugen
                  Flow {
                    width: parent.width; spacing: 5
                    visible: !root.loadingSwatches && root.swatchColors.length > 0
                    Repeater {
                      model: root.swatchColors
                      delegate: Item {
                        width: 30; height: 30
                        readonly property int swIdx: index
                        readonly property bool isSwAct: (root.editingIdx === slotIndex) && root.ed_midx === swIdx
                        Rectangle {
                          anchors.fill: parent; radius: 6
                          color: modelData
                          border.color: isSwAct ? "white" : Qt.rgba(0,0,0,0.35)
                          border.width: isSwAct ? 2 : 1
                          Text {
                            anchors { bottom: parent.bottom; right: parent.right; margins: 2 }
                            text: index; font.pixelSize: 6; color: "white"
                            style: Text.Outline; styleColor: "#80000000"
                          }
                          Text {
                            anchors.centerIn: parent; visible: isSwAct; text: "\uf00c"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                            color: "white"; style: Text.Outline; styleColor: "#80000000"
                          }
                          scale: swma.containsMouse ? 1.08 : 1.0
                          Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                        MouseArea {
                          id: swma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: if (root.editingIdx === slotIndex) root.ed_midx = swIdx
                        }
                      }
                    }
                  }

                  Text {
                    visible: !root.loadingSwatches && root.swatchColors.length === 0
                    text: "Nenhuma paleta — clique em ↺ para carregar"
                    font.pixelSize: 9; color: root.colorTextDim; opacity: 0.45
                  }

                  // ── Palette ────────────────────────────────────────────────
                  Text { text: "PALETTE"; font.pixelSize: 7; font.letterSpacing: 1.2; color: root.colorTextDim; opacity: 0.6 }
                  Flow {
                    width: parent.width; spacing: 4
                    Repeater {
                      model: root.allPalettes
                      delegate: Item {
                        width: pchip.implicitWidth; height: 20
                        property bool isPSel: (root.editingIdx === slotIndex) && root.ed_palette === modelData
                        Rectangle {
                          id: pchip; anchors.fill: parent; radius: 10
                          implicitWidth: pchipT.implicitWidth + 14
                          color: isPSel ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                                        : (pchipH.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                          border.color: isPSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                          border.width: isPSel ? 1.5 : 1
                          Behavior on color { ColorAnimation { duration: 110 } }
                          Text { id: pchipT; anchors.centerIn: parent; text: modelData.replace("scheme-",""); font.pixelSize: 8
                                 color: isPSel ? root.colorAccent : root.colorText }
                        }
                        MouseArea { id: pchipH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.editingIdx === slotIndex) root.ed_palette = modelData }
                      }
                    }
                  }

                  // ── Efeitos com preview ────────────────────────────────────
                  Row {
                    width: parent.width; spacing: 6
                    visible: root.effectList.length > 1
                    Text {
                      text: "EFEITO"; font.pixelSize: 7; font.letterSpacing: 1.2
                      color: root.colorTextDim; opacity: 0.6
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                      visible: root.generatingEffectPrev
                      width: 14; height: 14; radius: 7; color: "transparent"
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        anchors.centerIn: parent; text: "\uf110"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                        color: root.colorTextDim; opacity: 0.6
                        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.generatingEffectPrev }
                      }
                    }
                  }

                  // Grade de previews de efeitos — GridView 3 colunas + scroll vertical
                  Item {
                    width: parent.width
                    height: root.effectList.length > 1 ? Math.min(efxGrid.contentHeight + 2, 160) : 0
                    visible: root.effectList.length > 1
                    clip: true

                    GridView {
                      id: efxGrid
                      anchors.fill: parent
                      clip: true
                      cellWidth:  Math.max(1, Math.floor((width - 2) / 3))
                      cellHeight: Math.round(cellWidth * 9 / 16) + 20
                      model: root.effectList
                      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                      delegate: Item {
                        width:  efxGrid.cellWidth
                        height: efxGrid.cellHeight

                        property bool   isEfxSel: (root.editingIdx === slotIndex) && root.ed_effect === modelData
                        property string prevPath: {
                          var v = root.effectPrevVersion
                          return root.effectPreviews[modelData] || ""
                        }

                        Rectangle {
                          anchors { fill: parent; margins: 3 }
                          radius: 7; clip: true
                          color: isEfxSel
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                            : (efxPrevHov.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05))
                          border.color: isEfxSel ? root.colorAccent : Qt.rgba(1,1,1,0.10)
                          border.width: isEfxSel ? 1.5 : 1
                          Behavior on color { ColorAnimation { duration: 110 } }

                          Image {
                            id: efxPrevImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - 18
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: false; smooth: true
                            source: prevPath !== "" ? ("file://" + prevPath + "?v=" + root.effectPrevVersion) : ""

                            Rectangle {
                              anchors.fill: parent
                              visible: efxPrevImg.status !== Image.Ready
                              color: Qt.rgba(1,1,1,0.04)
                              Text {
                                anchors.centerIn: parent
                                text: root.generatingEffectPrev ? "\uf110" : "\uf5aa"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: root.colorAccent; opacity: 0.4
                                RotationAnimator on rotation {
                                  from: 0; to: 360; duration: 900
                                  loops: Animation.Infinite; running: root.generatingEffectPrev
                                }
                              }
                            }

                            Rectangle {
                              visible: isEfxSel
                              anchors { top: parent.top; right: parent.right; margins: 3 }
                              width: 16; height: 16; radius: 8; color: root.colorAccent
                              Text {
                                anchors.centerIn: parent; text: "\uf00c"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 7; color: "#1f1f1f"
                              }
                            }
                          }

                          Text {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 18
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: modelData === "off" ? "desligado" : modelData
                            font.pixelSize: 7; elide: Text.ElideRight
                            color: isEfxSel ? root.colorAccent : root.colorTextDim
                          }
                        }

                        MouseArea {
                          id: efxPrevHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: if (root.editingIdx === slotIndex) root.ed_effect = modelData
                        }
                      }
                    }
                  }

                  // ── Opções + Salvar ────────────────────────────────────────
                  Row {
                    width: parent.width; spacing: 6
                    // Random
                    Rectangle {
                      height: 26; radius: 5; width: randRow.implicitWidth + 16
                      color: (root.ed_random && root.editingIdx === slotIndex)
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                        : (randMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                      border.color: (root.ed_random && root.editingIdx === slotIndex) ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 110 } }
                      Row {
                        id: randRow; anchors.centerIn: parent; spacing: 4
                        Text { text: "\uf074"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                               color: (root.ed_random && root.editingIdx === slotIndex) ? root.colorAccent : root.colorTextDim }
                        Text { text: "random"; font.pixelSize: 8
                               color: (root.ed_random && root.editingIdx === slotIndex) ? root.colorText : root.colorTextDim }
                      }
                      MouseArea { id: randMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                  onClicked: if (root.editingIdx === slotIndex) root.ed_random = !root.ed_random }
                    }
                    // Quiet
                    Rectangle {
                      height: 26; radius: 5; width: qrowInner.implicitWidth + 16
                      color: (root.ed_quiet && root.editingIdx === slotIndex)
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                        : (qmaC.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                      border.color: (root.ed_quiet && root.editingIdx === slotIndex) ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 110 } }
                      Row {
                        id: qrowInner; anchors.centerIn: parent; spacing: 4
                        Text { text: "\uf026"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                               color: (root.ed_quiet && root.editingIdx === slotIndex) ? root.colorAccent : root.colorTextDim }
                        Text { text: "quiet"; font.pixelSize: 8
                               color: (root.ed_quiet && root.editingIdx === slotIndex) ? root.colorText : root.colorTextDim }
                      }
                      MouseArea { id: qmaC; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                  onClicked: if (root.editingIdx === slotIndex) root.ed_quiet = !root.ed_quiet }
                    }
                    Item { width: parent.width - (randRow.implicitWidth + 16) - (qrowInner.implicitWidth + 16) - (saveRow.implicitWidth + 18) - 18; height: 1 }
                    // Salvar
                    Rectangle {
                      height: 26; radius: 5; width: saveRow.implicitWidth + 18; opacity: root.running ? 0.4 : 1.0
                      color: savemaC.containsMouse ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32) : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                      border.color: root.colorAccent; border.width: 1
                      Behavior on color { ColorAnimation { duration: 100 } }
                      Row { id: saveRow; anchors.centerIn: parent; spacing: 5
                        Text { text: "\uf00c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: root.colorAccent }
                        Text { text: "Salvar"; font.pixelSize: 9; color: root.colorAccent }
                      }
                      MouseArea { id: savemaC; anchors.fill: parent; hoverEnabled: true
                                  cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                                  onClicked: if (!root.running && root.editingIdx === slotIndex) root._saveSlot() }
                    }
                  }

                  Item { width: 1; height: 4 }
                } // editorMeasure Column
              } // editor Item
            } // delegate Item
          } // Repeater

          Item { width: 1; height: 10 }
        } // listColumn
      } // Flickable
    } // listPanel

    // ── Divisor ──────────────────────────────────────────────────────────────
    Rectangle {
      Layout.preferredWidth: 1; Layout.fillHeight: true
      color: root.colorDivider
      opacity: root.editorOpen ? 0.4 : 0
      Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    // ────────────────────────────────────────────────────────────────────────
    // PAINEL DIREITO: grade de wallpapers
    // ────────────────────────────────────────────────────────────────────────
    Item {
      id: rightPanel
      Layout.preferredWidth: root.editorOpen ? root.rightW : 0
      Layout.fillHeight: true
      clip: true
      visible: root.editorOpen
      Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── Cabeçalho: título + badge + filtro de busca ───────────────────
        Item {
          Layout.fillWidth: true; height: 40

          Row {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter; spacing: 8
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
              Text { id: slotBadge; anchors.centerIn: parent; font.pixelSize: 9; color: root.colorAccent
                     text: root.editingIdx >= 0 && root.slots[root.editingIdx]
                           ? (root.slots[root.editingIdx].name || "") : "" }
            }
          }

          Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 1
            color: root.colorDivider; opacity: 0.25
          }
        }

        // ── Filtro de cor: botões + slider de hue ────────────────────────
        Item {
          Layout.fillWidth: true; height: 44

          Row {
            id: filterBtns
            anchors.left: parent.left; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Rectangle {
              width: todosBtn.implicitWidth + 14; height: 22; radius: 11
              color: root.pickerHueFilter < 0
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                : (todosBtnMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))
              border.color: root.pickerHueFilter < 0 ? root.colorAccent : Qt.rgba(1,1,1,0.12)
              border.width: root.pickerHueFilter < 0 ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }
              Text {
                id: todosBtn; anchors.centerIn: parent; text: "Todos"; font.pixelSize: 9
                color: root.pickerHueFilter < 0 ? root.colorAccent : root.colorTextDim
              }
              MouseArea {
                id: todosBtnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.pickerHueFilter = -1
              }
            }

            Rectangle {
              width: pbTxt.implicitWidth + 14; height: 22; radius: 11
              color: root.pickerHueFilter === -2
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                : (pbBtnMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))
              border.color: root.pickerHueFilter === -2 ? root.colorAccent : Qt.rgba(1,1,1,0.12)
              border.width: root.pickerHueFilter === -2 ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }
              Text {
                id: pbTxt; anchors.centerIn: parent; text: "P&B"; font.pixelSize: 9
                color: root.pickerHueFilter === -2 ? root.colorAccent : root.colorTextDim
              }
              MouseArea {
                id: pbBtnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.pickerHueFilter = -2
              }
            }
          }

          Item {
            anchors.left: filterBtns.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 22

            Rectangle {
              id: hueTrack
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
              opacity: root.pickerHueFilter >= 0 ? 1.0 : 0.35
              Behavior on opacity { NumberAnimation { duration: 150 } }

              MouseArea {
                anchors.fill: parent
                onPressed:         function(e) { _pick(e.x) }
                onPositionChanged: function(e) { if (pressed) _pick(e.x) }
                function _pick(x) {
                  root.pickerHueFilter = Math.max(0, Math.min(359, (x / hueTrack.width) * 359))
                }
              }

              Rectangle {
                visible: root.pickerHueFilter >= 0
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: root.pickerHueFilter >= 0
                   ? Math.max(-4, Math.min(hueTrack.width - 14, (root.pickerHueFilter / 359) * hueTrack.width - 9))
                   : -20
                color: "white"
                border.color: Qt.rgba(0,0,0,0.4); border.width: 2
                Behavior on x { NumberAnimation { duration: 60 } }
                Rectangle {
                  anchors.centerIn: parent; width: 10; height: 10; radius: 5
                  color: Qt.hsla(root.pickerHueFilter >= 0 ? root.pickerHueFilter / 360 : 0, 0.75, 0.55, 1.0)
                }
              }
            }
          }

          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.colorDivider; opacity: 0.2 }
        }

        // ── Grade de wallpapers ──────────────────────────────────────────────
        Item {
          Layout.fillWidth: true; Layout.fillHeight: true

          readonly property var displayEntries: {
            if (root.pickerHueFilter === -2) {
              // P&B: só monocromáticos
              var mono = []
              for (var i = 0; i < root.pickerEntries.length; i++) {
                var e = root.pickerEntries[i]
                if ((e.hue !== undefined ? e.hue : -1) < 0) mono.push(e)
              }
              return mono
            }
            return root.pickerFiltered
          }

          Text {
            anchors.centerIn: parent; visible: root.pickerLoading
            text: "\uf110  carregando…"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
            color: root.colorTextDim; opacity: 0.6
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.pickerLoading }
          }
          Text {
            anchors.centerIn: parent
            visible: !root.pickerLoading && parent.displayEntries.length === 0
            text: "\uf03e  nenhum resultado"
            font.pixelSize: 11; color: root.colorTextDim; opacity: 0.4
          }

          GridView {
            id: wpGrid
            anchors { fill: parent; margins: 8 }
            visible: !root.pickerLoading; clip: true
            cellWidth:  Math.max(1, Math.floor((width - 4) / 3))
            cellHeight: cellWidth * 9 / 16 + 26
            model: parent.displayEntries
            property int hoveredIdx: -1

            delegate: Item {
              width: wpGrid.cellWidth; height: wpGrid.cellHeight
              readonly property bool isHov:     wpGrid.hoveredIdx === index
              readonly property bool isCurSlot: {
                if (root.editingIdx < 0) return false
                var s = root.slots[root.editingIdx]
                if (!s) return false
                var path = modelData.value.replace(/^file:\/\//, "").replace(/^file:/, "")
                return (s.file || "") === path
              }

              Rectangle {
                anchors { fill: parent; margins: 3 }
                radius: 7; clip: true
                color: isCurSlot ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15) : Qt.rgba(1,1,1,0.04)
                border.color: isCurSlot ? root.colorAccent : isHov ? Qt.rgba(1,1,1,0.3) : "transparent"
                border.width: isCurSlot ? 1.5 : 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Image {
                  id: wpThumb
                  anchors { top: parent.top; left: parent.left; right: parent.right }
                  height: parent.width * 9 / 16
                  fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true
                  source: modelData.thumb !== "" ? ("file://" + modelData.thumb) : ""

                  Rectangle { anchors.fill: parent; visible: wpThumb.status !== Image.Ready; color: Qt.rgba(1,1,1,0.04); radius: parent.radius }

                  // Check de atribuído
                  Rectangle {
                    visible: isCurSlot
                    anchors { top: parent.top; right: parent.right; margins: 4 }
                    width: 18; height: 18; radius: 9; color: root.colorAccent
                    Text { anchors.centerIn: parent; text: "\uf00c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: "#1f1f1f" }
                  }

                  // Overlay hover
                  Rectangle {
                    anchors.fill: parent; visible: isHov; color: Qt.rgba(0,0,0,0.40)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                      anchors.centerIn: parent; spacing: 3
                      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf017"
                             font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: root.colorAccent }
                      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "atribuir"; font.pixelSize: 8; color: "white" }
                    }
                  }
                }

                Text {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 3 }
                  height: 20; text: modelData.label || ""; font.pixelSize: 8
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
  }
}
