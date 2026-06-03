import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── WallpaperTabSchedule ──────────────────────────────────────────────────────
// Layout: dois painéis lado a lado quando um slot está em edição.
// Esquerda: lista de slots (sempre visível, scrollável).
// Direita: editor do slot selecionado (Flickable independente).
// Quando nenhum slot está em edição, a lista ocupa toda a largura.

Item {
  id: root

  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string mlScripts:    ""
  property string effectsDir:   ""
  property string previewDir:   ""   // ~/.config/ml4w/cache/effect-previews
  property string wpRun:        ""   // ml4w/scripts/wp-run (para thumb gen)

  // Versão incrementada após gerar effect-previews para forçar reload das Image
  property int    previewVersion: 0

  // ── Estado ────────────────────────────────────────────────────────────────
  property bool   schedEnabled: false
  property bool   timerActive:  false   // estado real do systemd timer
  property bool   loading:      false
  property bool   running:      false
  property var    slots:        []
  property var    effectList:   ["off"]
  property var    profileList:  []

  // ── Editor ────────────────────────────────────────────────────────────────
  property int    editingIdx:     -1
  property string ed_name:        ""
  property int    ed_start:       6
  property string ed_file:        ""
  property string ed_folder:      ""
  property string ed_profile:     ""
  property string ed_effect:      "off"
  property string ed_palette:     "scheme-fidelity"
  property string ed_msrc:        "base"
  property int    ed_midx:        0
  property bool   ed_random:      true
  property bool   ed_quiet:       false

  // ── Adicionar slot ────────────────────────────────────────────────────────
  property bool   showAddSlot:  false
  property string newSlotName:  ""
  property int    newSlotHour:  0

  readonly property var allPalettes: [
    "scheme-content", "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow", "scheme-tonal-spot"
  ]

  // ── Layout helpers ────────────────────────────────────────────────────────
  readonly property bool editorOpen: editingIdx >= 0
  readonly property int  listW:      editorOpen ? Math.floor(width * 0.42) : width
  readonly property int  editorW:    width - listW

  // ═══════════════════════════════════════════════════════════════════════════
  // Processos
  // ═══════════════════════════════════════════════════════════════════════════

  Process {
    id: loadProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => loadProc._buf += l + "\n" }
    onRunningChanged: {
      if (running) return
      root.loading = false
      var raw = loadProc._buf.trim(); loadProc._buf = ""
      if (!raw) return
      try {
        var d = JSON.parse(raw)
        // enabled vem do schedule.json; timerActive vem do systemd
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
    // Lê json_enabled do schedule.json E timer_active do systemd separadamente
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
    stdout: SplitParser { onRead: (l) => actionProc._buf += l }
    onRunningChanged: {
      if (running) return
      actionProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: saveSlotProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => saveSlotProc._buf += l }
    onRunningChanged: {
      if (running) return
      saveSlotProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  Process {
    id: mutateProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => mutateProc._buf += l }
    onRunningChanged: {
      if (running) return
      mutateProc._buf = ""; root.running = false
      Qt.callLater(function() { root._reload() })
    }
  }

  // ── Thumb do arquivo selecionado no editor ───────────────────────────────
  // Gera thumbnail 320x180 via wallpaper-lib generate_wall_thumb e guarda o path.
  property string ed_thumbPath: ""   // path do thumb gerado ou "" se não disponível

  Process {
    id: thumbProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => thumbProc._buf += l }
    onRunningChanged: {
      if (running) return
      var p = thumbProc._buf.trim(); thumbProc._buf = ""
      root.ed_thumbPath = (p && p !== "") ? p : ""
    }
  }

  function _loadThumb(filePath) {
    root.ed_thumbPath = ""
    if (!filePath || filePath === "") return
    thumbProc.command = ["bash", "-c",
      "source '" + root.mlScripts + "/wallpaper-lib.sh' 2>/dev/null && " +
      "generate_wall_thumb '" + filePath.replace(/'/g, "'\\''") + "'"
    ]
    if (!thumbProc.running) thumbProc.running = true
  }

  function _toggle() {
    if (root.running) return
    root.running = true
    // Alterna com base no estado REAL do timer systemd
    var cmd = root.timerActive ? "disable" : "enable"
    actionProc.command = ["bash", "-c",
      "bash '" + root.mlScripts + "/wallpaper-schedule.sh' " + cmd + " 2>/dev/null"
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
      "import sys; sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import schedule as S\n" +
      "try:\n" +
      "    S.add_slot('" + name.trim().replace(/'/g, "\\'") + "', " + hour + ")\n" +
      "except ValueError as e:\n" +
      "    print('ERR:', e)\n" +
      "PYEOF\n"
    ]
    mutateProc.running = true
  }

  function _removeSlot(start) {
    if (root.running) return
    root.running = true; root.editingIdx = -1
    mutateProc.command = ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys; sys.path.insert(0, '" + root.mlScripts + "')\n" +
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
    root.ed_name     = s.name            || ""
    root.ed_start    = s.start           !== undefined ? s.start : 0
    root.ed_file     = s.file            || ""
    root.ed_folder   = s.folder          || ""
    root.ed_profile  = s.profile         || ""
    root.ed_effect   = s.effect          || "off"
    root.ed_palette  = s.palette         || "scheme-fidelity"
    root.ed_msrc     = s.matugen_source  || "base"
    root.ed_midx     = s.matugen_index   !== undefined ? s.matugen_index : 0
    root.ed_random   = s.random          !== undefined ? s.random : true
    root.ed_quiet    = s.quiet           !== undefined ? s.quiet  : false
    // Carrega thumbnail do arquivo se modo "file"
    root._loadThumb(root.ed_profile === "" && root.ed_folder === "" ? root.ed_file : "")
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

  onEd_fileChanged: {
    if (root.ed_profile === "" && root.ed_folder === "")
      root._loadThumb(root.ed_file)
    else
      root.ed_thumbPath = ""
  }

  onEd_profileChanged: { if (root.ed_profile !== "") root.ed_thumbPath = "" }
  onEd_folderChanged:  { if (root.ed_folder  !== "") root.ed_thumbPath = "" }

  onPanelOpenChanged: { if (panelOpen) root._reload() }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI — painel esquerdo (lista) + painel direito (editor)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── PAINEL ESQUERDO: lista ────────────────────────────────────────────────
  Item {
    id: listPanel
    x: 0; y: 0; width: root.listW; height: parent.height
    clip: true
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Flickable {
      anchors.fill: parent; clip: true
      contentWidth: width
      contentHeight: listCol.implicitHeight + 24
      boundsMovement: Flickable.StopAtBounds

      ColumnLayout {
        id: listCol
        x: 12; y: 12
        width: listPanel.width - 24
        spacing: 10

        // ── Status card ──────────────────────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true; height: 60; radius: 10
          color: root.timerActive
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.09)
            : Qt.rgba(1,1,1,0.04)
          border.color: root.timerActive
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
            : Qt.rgba(1,1,1,0.09)
          border.width: 1
          Behavior on color       { ColorAnimation { duration: 200 } }
          Behavior on border.color{ ColorAnimation { duration: 200 } }

          RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 10

            // Ícone / spinner
            Text {
              text: root.loading ? "\uf110" : (root.timerActive ? "\uf017" : "\uf017")
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
              color: root.timerActive ? root.colorAccent : root.colorTextDim
              opacity: root.timerActive ? 1.0 : 0.3
              Behavior on color   { ColorAnimation { duration: 200 } }
              Behavior on opacity { NumberAnimation { duration: 200 } }
              RotationAnimator on rotation {
                from: 0; to: 360; duration: 900
                loops: Animation.Infinite; running: root.loading
              }
            }

            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text {
                text: root.timerActive ? "Timer ativo" : "Timer inativo"
                font.pixelSize: 11; color: root.colorText
                Behavior on color { ColorAnimation { duration: 200 } }
              }
              Text {
                text: (root.schedEnabled ? "schedule: on" : "schedule: off") +
                      "  ·  " + root.slots.length + " slot(s)"
                font.pixelSize: 9; color: root.colorTextDim
              }
            }

            // Botão rodar agora
            Rectangle {
              width: 28; height: 28; radius: 7
              color: rnma.containsMouse
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                : Qt.rgba(1,1,1,0.06)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
              border.width: 1; opacity: root.running ? 0.4 : 1.0
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent; text: "\uf04b"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                color: root.colorAccent
              }
              MouseArea {
                id: rnma; anchors.fill: parent; hoverEnabled: true
                cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!root.running) root._runNow()
              }
            }

            // Toggle on/off
            Rectangle {
              width: 48; height: 24; radius: 12
              color: root.timerActive
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.28)
                : Qt.rgba(1,1,1,0.08)
              Behavior on color { ColorAnimation { duration: 200 } }
              Rectangle {
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: root.timerActive ? parent.width - 22 : 4
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

        // ── Cabeçalho SLOTS + botão + ────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "SLOTS"
            font { pixelSize: 8; letterSpacing: 1.4 }
            color: root.colorTextDim; opacity: 0.65
            Layout.fillWidth: true
          }

          Rectangle {
            width: 22; height: 22; radius: 6
            color: addma.containsMouse
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
              : Qt.rgba(1,1,1,0.06)
            border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
              anchors.centerIn: parent; text: "+"
              font { pixelSize: 14 }
              color: root.colorAccent
            }
            MouseArea {
              id: addma; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.showAddSlot = !root.showAddSlot
                root.newSlotName = ""; root.newSlotHour = 0
              }
            }
          }
        }

        // ── Formulário adicionar slot ─────────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          height: root.showAddSlot ? addForm.implicitHeight + 16 : 0
          opacity: root.showAddSlot ? 1 : 0
          visible: height > 0
          radius: 8
          color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.06)
          border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
          border.width: 1; clip: true
          Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 180 } }

          ColumnLayout {
            id: addForm; x: 10; y: 8; width: parent.width - 20; spacing: 8

            Text { text: "Novo slot"; font.pixelSize: 10; color: root.colorAccent }

            RowLayout { spacing: 6; Layout.fillWidth: true
              // Nome
              Rectangle {
                Layout.fillWidth: true; height: 30; radius: 6
                color: Qt.rgba(1,1,1,0.05)
                border.color: addNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                TextInput {
                  id: addNameIn
                  anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                  verticalAlignment: TextInput.AlignVCenter
                  font.pixelSize: 10; color: root.colorText
                  text: root.newSlotName
                  onTextChanged: root.newSlotName = text
                  Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    text: "nome do slot"; color: root.colorTextDim
                    font: parent.font; opacity: 0.4
                    visible: parent.text.length === 0 && !parent.activeFocus
                  }
                }
              }
              // Hora spinner compacto
              Rectangle {
                width: 64; height: 30; radius: 6
                color: Qt.rgba(1,1,1,0.05)
                border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                RowLayout {
                  anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: root.newSlotHour.toString().padStart(2,"0") + "h"
                    font.pixelSize: 11; color: root.colorText
                    horizontalAlignment: Text.AlignHCenter
                  }
                  ColumnLayout {
                    spacing: 0
                    Text {
                      text: "\uf077"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 7 }
                      color: root.colorTextDim; opacity: 0.6
                      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                  onClicked: root.newSlotHour = (root.newSlotHour+1)%24 }
                    }
                    Text {
                      text: "\uf078"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 7 }
                      color: root.colorTextDim; opacity: 0.6
                      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                  onClicked: root.newSlotHour = (root.newSlotHour+23)%24 }
                    }
                  }
                }
              }
            }

            RowLayout { Layout.fillWidth: true; spacing: 6
              Item { Layout.fillWidth: true }
              Rectangle {
                width: 64; height: 26; radius: 6
                color: cncma.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Cancelar"; font.pixelSize: 9; color: root.colorTextDim }
                MouseArea { id: cncma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showAddSlot = false }
              }
              Rectangle {
                width: 68; height: 26; radius: 6
                color: confma.containsMouse
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32)
                  : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                border.color: root.colorAccent; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Adicionar"; font.pixelSize: 9; color: root.colorAccent }
                MouseArea {
                  id: confma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root._addSlot(root.newSlotName, root.newSlotHour)
                }
              }
            }
          }
        }

        // ── Cards dos slots ───────────────────────────────────────────────────
        Repeater {
          model: root.slots
          delegate: Rectangle {
            Layout.fillWidth: true; height: 60; radius: 8
            property bool isSel: root.editingIdx === index

            // Thumb path do slot: usa wallpaper-previews cache (mesma chave sha256 do lib)
            // Só disponível se source for "file" com thumb já gerado
            readonly property string slotThumb: {
              var md = modelData
              if (md && md.file && md.file !== "") {
                // Tenta ler do WP_WALL_PREVIEWS_DIR via sha256 do path — calculamos
                // o caminho esperado localmente: previewDir/../wallpaper-previews/<hash>.png
                // Não executamos processo por card; apenas tentamos carregar a Image.
                // Se o thumb não existir ainda, Image fica em estado NotReady (fallback exibido).
                var cacheDir = root.mlScripts.replace(/\/scripts$/, "/cache")
                return cacheDir + "/wallpaper-previews/" + md.file
              }
              return ""
            }

            color: isSel
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.11)
              : (cma.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04))
            border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.08)
            border.width: isSel ? 1.5 : 1
            Behavior on color        { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }

            RowLayout {
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              spacing: 8

              // Thumb ou badge de hora
              Rectangle {
                width: 64; height: 44; radius: 6; clip: true
                color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)

                // Thumb do wallpaper (modo file)
                Image {
                  id: slotThumbImg
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true; cache: true; smooth: true
                  source: {
                    var md = modelData
                    if (!md || !md.file || md.file === "") return ""
                    var hash = Qt.md5(md.file)
                    var cacheDir = root.mlScripts.replace(/\/scripts$/, "/cache")
                    return "file://" + cacheDir + "/wallpaper-previews/" + hash + ".png"
                  }
                  visible: status === Image.Ready
                }

                // Fallback: ícone de tipo quando sem thumb
                ColumnLayout {
                  anchors.centerIn: parent; spacing: 1
                  visible: slotThumbImg.status !== Image.Ready
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData && modelData.profile ? "\uf007"
                        : modelData && modelData.folder  ? "\uf07c"
                        : "\uf03e"
                    font.pixelSize: 14; color: root.colorAccent; opacity: 0.7
                  }
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (modelData && modelData.start !== undefined
                      ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                    font { pixelSize: 10; bold: true }
                    color: root.colorAccent
                  }
                }

                // Badge de hora sobre o thumb (visível apenas quando thumb carregado)
                Rectangle {
                  visible: slotThumbImg.status === Image.Ready
                  anchors { bottom: parent.bottom; left: parent.left; margins: 3 }
                  radius: 4; color: Qt.rgba(0,0,0,0.65)
                  width: hourBadge.implicitWidth + 6; height: 16
                  Text {
                    id: hourBadge; anchors.centerIn: parent
                    text: (modelData && modelData.start !== undefined
                      ? modelData.start.toString().padStart(2,"0") : "??") + "h"
                    font { pixelSize: 9; bold: true }
                    color: root.colorAccent
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                  text: modelData.name || "(sem nome)"
                  font.pixelSize: 10; color: root.colorText
                  elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                  property string _src: {
                    if (modelData.profile) return "\uf007 " + modelData.profile
                    if (modelData.file)    return "\uf15b " + modelData.file.split("/").pop()
                    if (modelData.folder)  return "\uf07c " + modelData.folder.split("/").pop()
                    return "? sem fonte"
                  }
                  text: _src + "  \u00b7  " +
                        (modelData.palette || "?").replace("scheme-","")
                  font { pixelSize: 8 }
                  color: root.colorTextDim
                  elide: Text.ElideRight; Layout.fillWidth: true
                }
                // Tags de efeito e opções
                Row { spacing: 4
                  visible: (modelData.effect && modelData.effect !== "off") || modelData.quiet || modelData.random === false
                  Rectangle {
                    visible: modelData.effect && modelData.effect !== "off"
                    height: 14; radius: 7
                    width: efxLbl.implicitWidth + 10
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                    Text { id: efxLbl; anchors.centerIn: parent
                           text: modelData.effect || ""; font.pixelSize: 7; color: root.colorAccent }
                  }
                  Rectangle {
                    visible: modelData.quiet === true
                    height: 14; radius: 7; width: 38
                    color: Qt.rgba(1,1,1,0.06)
                    Text { anchors.centerIn: parent; text: "quiet"; font.pixelSize: 7; color: root.colorTextDim }
                  }
                  Rectangle {
                    visible: modelData.folder && modelData.random === false
                    height: 14; radius: 7; width: 28
                    color: Qt.rgba(1,1,1,0.06)
                    Text { anchors.centerIn: parent; text: "seq"; font.pixelSize: 7; color: root.colorTextDim }
                  }
                }
              }

              // Botão lixeira
              Item {
                width: 24; height: 24
                Rectangle {
                  anchors.fill: parent; radius: 6
                  color: delma.containsMouse ? Qt.rgba(1,0.25,0.25,0.18) : "transparent"
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text {
                  anchors.centerIn: parent; text: "\uf1f8"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                  color: delma.containsMouse ? "#ff7070" : root.colorTextDim
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea {
                  id: delma; anchors.fill: parent; hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (!root.running) root._removeSlot(modelData.start)
                }
              }
            }

            MouseArea {
              id: cma; anchors.fill: parent; hoverEnabled: true; z: -1
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.editingIdx === index) root.editingIdx = -1
                else                           root._openEditor(index)
              }
            }
          }
        }

        Item { height: 8 }
      }
    }
  }

  // ── Divisor vertical ─────────────────────────────────────────────────────
  Rectangle {
    x: root.listW; y: 0; width: 1; height: parent.height
    color: root.colorDivider; opacity: root.editorOpen ? 0.4 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
  }

  // ── PAINEL DIREITO: editor ────────────────────────────────────────────────
  Item {
    id: editorPanel
    x: root.listW + 1
    y: 0
    width: root.editorOpen ? root.editorW - 1 : 0
    height: parent.height
    clip: true
    visible: root.editorOpen
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Flickable {
      anchors.fill: parent; clip: true
      contentWidth: width
      contentHeight: edCol.implicitHeight + 24
      boundsMovement: Flickable.StopAtBounds

      ColumnLayout {
        id: edCol
        x: 12; y: 12
        width: editorPanel.width - 24
        spacing: 12

        // ── Cabeçalho do editor ────────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "\uf044  " + (root.editingIdx >= 0 && root.slots[root.editingIdx]
              ? root.slots[root.editingIdx].name : "")
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; letterSpacing: 0.5 }
            color: root.colorAccent; Layout.fillWidth: true
            elide: Text.ElideRight
          }

          // Fechar editor
          Rectangle {
            width: 22; height: 22; radius: 6
            color: closema.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
              anchors.centerIn: parent; text: "\uf00d"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
              color: root.colorTextDim
            }
            MouseArea {
              id: closema; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.editingIdx = -1
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.3 }

        // ── Nome ──────────────────────────────────────────────────────────
        Text {
          text: "NOME"
          font { pixelSize: 8; letterSpacing: 1.3 }
          color: root.colorTextDim; opacity: 0.65
        }
        Rectangle {
          Layout.fillWidth: true; height: 30; radius: 6
          color: Qt.rgba(1,1,1,0.05)
          border.color: enameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
          border.width: 1
          Behavior on border.color { ColorAnimation { duration: 120 } }
          TextInput {
            id: enameIn
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: 10; color: root.colorText
            text: root.ed_name
            onTextChanged: root.ed_name = text
          }
        }

        // ── Horário ───────────────────────────────────────────────────────
        Text {
          text: "IN\u00cdCIO"
          font { pixelSize: 8; letterSpacing: 1.3 }
          color: root.colorTextDim; opacity: 0.65
        }
        RowLayout { spacing: 6
          Rectangle {
            width: 80; height: 30; radius: 6
            color: Qt.rgba(1,1,1,0.05)
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1
            RowLayout {
              anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
              spacing: 0
              Text {
                Layout.fillWidth: true
                text: root.ed_start.toString().padStart(2,"0") + ":00"
                font.pixelSize: 12; color: root.colorText
                horizontalAlignment: Text.AlignHCenter
              }
              ColumnLayout {
                spacing: 0
                Text {
                  text: "\uf077"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 7 }
                  color: root.colorTextDim; opacity: 0.7
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: root.ed_start = (root.ed_start+1)%24 }
                }
                Text {
                  text: "\uf078"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 7 }
                  color: root.colorTextDim; opacity: 0.7
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: root.ed_start = (root.ed_start+23)%24 }
                }
              }
            }
          }
          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.25 }

        // ── Fonte do wallpaper ────────────────────────────────────────────
        Text {
          text: "\uf03e  WALLPAPER"
          font { pixelSize: 8; letterSpacing: 1.3 }
          color: root.colorTextDim; opacity: 0.65
        }

        // Seletor tipo
        RowLayout { Layout.fillWidth: true; spacing: 5
          Repeater {
            model: [
              { id: "file",    icon: "\uf15b", label: "Arquivo"  },
              { id: "folder",  icon: "\uf07b", label: "Pasta"    },
              { id: "profile", icon: "\uf007", label: "Perfil"   }
            ]
            delegate: Item {
              Layout.fillWidth: true; height: 28
              property string tid: modelData.id
              property bool   isSel: {
                if (tid === "profile") return root.ed_profile !== ""
                if (tid === "folder")  return root.ed_folder  !== "" && root.ed_profile === ""
                return root.ed_file !== "" && root.ed_folder === "" && root.ed_profile === ""
              }
              Rectangle {
                anchors.fill: parent; radius: 6
                color: isSel
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  : (tma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }
                RowLayout {
                  anchors.centerIn: parent; spacing: 4
                  Text {
                    text: modelData.icon
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                    color: isSel ? root.colorAccent : root.colorTextDim
                  }
                  Text { text: modelData.label; font.pixelSize: 9; color: isSel ? root.colorText : root.colorTextDim }
                }
              }
              MouseArea {
                id: tma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (tid === "profile") {
                    root.ed_file = ""; root.ed_folder = ""
                    if (root.ed_profile === "" && root.profileList.length > 0)
                      root.ed_profile = root.profileList[0]
                    else if (root.ed_profile === "")
                      root.ed_profile = " " // forçar visibilidade
                  } else if (tid === "folder") {
                    root.ed_profile = ""; root.ed_file = ""
                    if (root.ed_folder === "") root.ed_folder = ""
                  } else {
                    root.ed_profile = ""; root.ed_folder = ""
                  }
                }
              }
            }
          }
        }

        // Input path (arquivo ou pasta)
        Rectangle {
          Layout.fillWidth: true; height: 30; radius: 6
          visible: root.ed_profile === ""
          color: Qt.rgba(1,1,1,0.05)
          border.color: pathIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.1)
          border.width: 1
          Behavior on border.color { ColorAnimation { duration: 120 } }
          RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 5
            Text {
              text: root.ed_folder !== "" ? "\uf07c" : "\uf15b"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
              color: root.colorTextDim; opacity: 0.5
            }
            TextInput {
              id: pathIn
              Layout.fillWidth: true; font.pixelSize: 9; color: root.colorText
              text: root.ed_folder !== "" ? root.ed_folder : root.ed_file
              onTextChanged: {
                if (root.ed_folder !== "") root.ed_folder = text
                else                       root.ed_file   = text
              }
              Text {
                anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                text: root.ed_folder !== "" ? "caminho da pasta…" : "caminho do arquivo…"
                color: root.colorTextDim; font: parent.font; opacity: 0.35
                visible: parent.text.length === 0 && !parent.activeFocus
              }
            }
            // Toggle random — só aparece para pasta
            Rectangle {
              visible: root.ed_folder !== ""; width: 56; height: 20; radius: 10
              color: root.ed_random
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                : Qt.rgba(1,1,1,0.06)
              border.color: root.ed_random ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: 1
              Behavior on color { ColorAnimation { duration: 110 } }
              Text {
                anchors.centerIn: parent
                text: root.ed_random ? "rand" : "seq"
                font { pixelSize: 8 }
                color: root.ed_random ? root.colorAccent : root.colorTextDim
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.ed_random = !root.ed_random
              }
            }
          }
        }

        // Preview do arquivo selecionado (modo file)
        Rectangle {
          Layout.fillWidth: true
          height: root.ed_file !== "" && root.ed_profile === "" && root.ed_folder === "" ? Math.floor((width) * 9 / 16) : 0
          visible: height > 0
          radius: 8; clip: true
          color: Qt.rgba(1,1,1,0.04)
          border.color: Qt.rgba(1,1,1,0.08); border.width: 1
          Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

          Image {
            id: edFilePreview
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; cache: false; smooth: true
            source: root.ed_thumbPath !== "" ? ("file://" + root.ed_thumbPath) : ""

            Rectangle {
              anchors.fill: parent
              visible: edFilePreview.status !== Image.Ready
              color: "transparent"
              Text {
                anchors.centerIn: parent; text: "\uf03e"
                font.pixelSize: 22; color: root.colorTextDim; opacity: 0.2
              }
            }
          }
        }

        // Chips de perfil
        Flow {
          Layout.fillWidth: true; spacing: 4
          visible: root.ed_profile !== ""
          Repeater {
            model: root.profileList
            delegate: Item {
              width: prc.implicitWidth; height: 24
              property bool isSel: root.ed_profile === modelData
              Rectangle {
                id: prc; anchors.fill: parent; radius: 12
                implicitWidth: prt.implicitWidth + 18
                color: isSel
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                  : (prma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }
                Text { id: prt; anchors.centerIn: parent; text: modelData; font.pixelSize: 9
                       color: isSel ? root.colorAccent : root.colorText }
              }
              MouseArea {
                id: prma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.ed_profile = modelData; root.ed_file = ""; root.ed_folder = "" }
              }
            }
          }
          Text {
            visible: root.profileList.length === 0
            text: "(nenhum perfil salvo)"; font.pixelSize: 9; color: root.colorTextDim; opacity: 0.5
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.25 }

        // ── Efeito ────────────────────────────────────────────────────────
        Text {
          text: "EFEITO"
          font { pixelSize: 8; letterSpacing: 1.3 }
          color: root.colorTextDim; opacity: 0.65
        }
        Flow { Layout.fillWidth: true; spacing: 6
          Repeater {
            model: root.effectList
            delegate: Item {
              id: efxCard
              width: 90; height: 68
              readonly property bool isSel: root.ed_effect === modelData
              readonly property string pvPath: root.previewDir !== ""
                ? (root.previewDir + "/" + modelData + ".png") : ""

              Rectangle {
                anchors.fill: parent; radius: 7; clip: true
                color: isSel
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.20)
                  : (efxma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }

                Image {
                  id: efxPv
                  anchors { top: parent.top; left: parent.left; right: parent.right }
                  height: 50
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true; cache: false; smooth: true
                  source: (root.previewVersion >= 0 && efxCard.pvPath !== "")
                    ? ("file://" + efxCard.pvPath) : ""

                  Rectangle {
                    anchors.fill: parent
                    visible: efxPv.status !== Image.Ready
                    color: Qt.rgba(1,1,1,0.05)
                    Text {
                      anchors.centerIn: parent; text: "\uf03e"
                      font.pixelSize: 13; color: root.colorTextDim; opacity: 0.25
                    }
                  }
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left; anchors.right: parent.right
                  height: 18; color: Qt.rgba(0,0,0,0.55)
                  RowLayout {
                    anchors { fill: parent; leftMargin: 5; rightMargin: 3 }
                    Text {
                      Layout.fillWidth: true
                      text: modelData; font.pixelSize: 8
                      color: isSel ? root.colorAccent : "white"
                      elide: Text.ElideRight
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                      visible: isSel; text: "\uf00c"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                      color: root.colorAccent
                    }
                  }
                }
              }
              MouseArea {
                id: efxma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.ed_effect = modelData
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.25 }

        // ── Palette ───────────────────────────────────────────────────────
        Text {
          text: "\uf53f  PALETTE"
          font { pixelSize: 8; letterSpacing: 1.3 }
          color: root.colorTextDim; opacity: 0.65
        }
        Flow { Layout.fillWidth: true; spacing: 4
          Repeater {
            model: root.allPalettes
            delegate: Item {
              width: palc.implicitWidth; height: 24
              property bool isSel: root.ed_palette === modelData
              Rectangle {
                id: palc; anchors.fill: parent; radius: 12
                implicitWidth: palt.implicitWidth + 18
                color: isSel
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                  : (palma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isSel ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }
                Text { id: palt; anchors.centerIn: parent
                       text: modelData.replace("scheme-",""); font.pixelSize: 9
                       color: isSel ? root.colorAccent : root.colorText }
              }
              MouseArea { id: palma; anchors.fill: parent; hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.ed_palette = modelData }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.25 }

        // ── Matugen source + índice ───────────────────────────────────────
        RowLayout { Layout.fillWidth: true; spacing: 12

          ColumnLayout { Layout.fillWidth: true; spacing: 6
            Text {
              text: "FONTE MAT."
              font { pixelSize: 8; letterSpacing: 1.3 }
              color: root.colorTextDim; opacity: 0.65
            }
            RowLayout { spacing: 4
              Repeater {
                model: [{ id: "base", label: "base" }, { id: "final", label: "final" }]
                delegate: Item {
                  width: msc.implicitWidth; height: 24
                  property bool isSel: root.ed_msrc === modelData.id
                  Rectangle {
                    id: msc; anchors.fill: parent; radius: 12
                    implicitWidth: mst.implicitWidth + 18
                    color: isSel
                      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                      : (msma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                    border.color: isSel ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                    border.width: isSel ? 1.5 : 1
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { id: mst; anchors.centerIn: parent; text: modelData.label; font.pixelSize: 9
                           color: isSel ? root.colorAccent : root.colorText }
                  }
                  MouseArea { id: msma; anchors.fill: parent; hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: root.ed_msrc = modelData.id }
                }
              }
            }
          }

          ColumnLayout { width: 100; spacing: 6
            Text {
              text: "COR IDX"
              font { pixelSize: 8; letterSpacing: 1.3 }
              color: root.colorTextDim; opacity: 0.65
            }
            Rectangle {
              width: 100; height: 30; radius: 6
              color: Qt.rgba(1,1,1,0.05)
              border.color: Qt.rgba(1,1,1,0.1); border.width: 1
              RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 0
                Text {
                  text: "\u2212"
                  font { pixelSize: 12 }
                  color: root.colorTextDim; opacity: 0.6
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: if (root.ed_midx > 0) root.ed_midx-- }
                }
                Text {
                  Layout.fillWidth: true; text: root.ed_midx
                  font.pixelSize: 13; color: root.colorText
                  horizontalAlignment: Text.AlignHCenter
                }
                Text {
                  text: "+"
                  font { pixelSize: 12 }
                  color: root.colorTextDim; opacity: 0.6
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: root.ed_midx++ }
                }
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.25 }

        // ── Opções ────────────────────────────────────────────────────────
        RowLayout { Layout.fillWidth: true; spacing: 8

          // Quiet toggle
          Rectangle {
            height: 30; radius: 6
            implicitWidth: qrow.implicitWidth + 20
            color: root.ed_quiet
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
              : (qma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
            border.color: root.ed_quiet ? root.colorAccent : Qt.rgba(1,1,1,0.09)
            border.width: root.ed_quiet ? 1.5 : 1
            Behavior on color { ColorAnimation { duration: 110 } }
            RowLayout {
              id: qrow; anchors.centerIn: parent; spacing: 5
              Text {
                text: "\uf026"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                color: root.ed_quiet ? root.colorAccent : root.colorTextDim
              }
              Text { text: "quiet"; font.pixelSize: 9; color: root.ed_quiet ? root.colorText : root.colorTextDim }
            }
            MouseArea {
              id: qma; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.ed_quiet = !root.ed_quiet
            }
          }

          Item { Layout.fillWidth: true }

          // Botão salvar
          Rectangle {
            height: 30; radius: 6; opacity: root.running ? 0.4 : 1.0
            implicitWidth: srow.implicitWidth + 22
            color: savema.containsMouse
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.32)
              : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
            border.color: root.colorAccent; border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            RowLayout {
              id: srow; anchors.centerIn: parent; spacing: 6
              Text {
                text: "\uf00c"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                color: root.colorAccent
              }
              Text { text: "Salvar"; font.pixelSize: 10; color: root.colorAccent }
            }
            MouseArea {
              id: savema; anchors.fill: parent; hoverEnabled: true
              cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: if (!root.running) root._saveSlot()
            }
          }
        }

        Item { height: 8 }
      }
    }
  }
}
