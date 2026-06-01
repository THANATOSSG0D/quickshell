import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── WallpaperConfigContent ────────────────────────────────────────────────────
// Painel de configuração de wallpaper com 3 abas:
//   "wallpaper" → grid de wallpapers + wallpaper por cor predominante
//   "matugen"   → palette, source, efeito, cor da fonte (swatches)
//   "profiles"  → carregar/salvar/deletar perfis
//
// Processo de dados: todos os dados vêm de `wp` via Process+SplitParser.
// Nunca usa stdout direto — segue o padrão do projeto.

Item {
  id: root

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#888888"
  property color colorAccent:     "#ffb4a9"
  property color colorDivider:    "#333333"

  property bool  panelOpen: false
  signal closeRequested()

  readonly property string scriptsDir:  "/home/antonio/.config/ml4w/scripts"
  readonly property string wallpaperSh: "/home/antonio/.config/ml4w/scripts/wallpaper.sh"
  // wp-run: double-fork launcher — garante que wallpaper.sh sobrevive
  // ao fechamento do painel (desacopla do process group do Quickshell)
  readonly property string wpRun:       "/home/antonio/.config/ml4w/scripts/wp-run"
  readonly property string wallpaperDir: Quickshell.shellDir + "/modules/default/wallpaper"

  // ── Aba activa ─────────────────────────────────────────────────────────────
  property string activeTab: "wallpaper"

  // ── Estado do sistema (lido ao abrir) ──────────────────────────────────────
  property string currentEffect:  "off"
  property string currentPalette: "scheme-fidelity"
  property string currentSource:  "base"
  property int    currentIndex:   0
  property string currentWallpaper: ""   // wallpaper activo em tela (com efeito)
  property string baseWallpaper:    ""   // ~/Imagens/wallpaper.png — usado no preview de efeitos

  // ── Dados carregados ───────────────────────────────────────────────────────
  property var wallpaperEntries: []   // [{label,sub,value,thumb,dominantColor}]
  property var profileEntries:   []   // [{label,sub,value,thumb}]
  property var swatchColors:     []   // ["#rrggbb", ...]
  property bool loadingWallpapers: false
  property bool loadingSwatches:   false

  // ── Palettes disponíveis ───────────────────────────────────────────────────
  readonly property var allPalettes: [
    "scheme-content",     "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow",     "scheme-tonal-spot"
  ]

  // ── Efeitos disponíveis ────────────────────────────────────────────────────
  property var effectList: []   // ["off", "blur", ...]

  // ═══════════════════════════════════════════════════════════════════════════
  // Processos de dados
  // ═══════════════════════════════════════════════════════════════════════════

  // Lê estado atual (effect, palette, source, index, current wallpaper)
  Process {
    id: stateProc
    // Lê: effect, palette, matugen_source, matugen_index, source, current, base
    command: ["bash", "-c",
      "cd " + root.scriptsDir + " && " +
      "python3 -m wp state read effect && " +
      "python3 -m wp state read palette && " +
      "python3 -m wp state read matugen_source && " +
      "python3 -m wp state read matugen_index && " +
      "python3 -m wp state read source && " +
      "python3 -m wp state read current && " +
      "python3 -m wp state read base"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => stateProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        var lines = stateProc._buf.trim().split("\n")
        stateProc._buf = ""
        if (lines.length >= 7) {
          root.currentEffect    = lines[0].trim() || "off"
          root.currentPalette   = lines[1].trim() || "scheme-fidelity"
          root.currentSource    = lines[2].trim() || "base"
          root.currentIndex     = parseInt(lines[3].trim()) || 0
          // lines[4] = source (wallpaper original — usado para marcar "atual" no grid)
          root.currentWallpaper = lines[4].trim()
          // lines[5] = current (wallpaper activo em tela, possivelmente com efeito)
          // lines[6] = base    (~/Imagens/wallpaper.png — preview de efeitos)
          root.baseWallpaper    = lines[6].trim()
        }
      }
    }
  }

  // Carrega lista de wallpapers com thumbnails e cores dominantes
  Process {
    id: wallpapersProc
    command: ["python3", root.wallpaperDir + "/wp-dmenu-entries", "folder"]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => wallpapersProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        root.loadingWallpapers = false
        var raw = wallpapersProc._buf.trim()
        wallpapersProc._buf = ""
        if (!raw) return
        try {
          var data = JSON.parse(raw)
          root.wallpaperEntries = data
        } catch(e) {}
      }
    }
  }

  // Carrega lista de perfis
  Process {
    id: profilesProc
    command: ["python3", root.wallpaperDir + "/wp-dmenu-entries", "profiles"]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => profilesProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        var raw = profilesProc._buf.trim()
        profilesProc._buf = ""
        if (!raw) return
        try { root.profileEntries = JSON.parse(raw) } catch(e) {}
      }
    }
  }

  // Carrega swatches do matugen
  Process {
    id: swatchProc
    command: ["bash", "-c",
      "cd " + root.scriptsDir + " && python3 -m wp matugen colors 2>/dev/null"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => swatchProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        root.loadingSwatches = false
        var raw = swatchProc._buf.trim()
        swatchProc._buf = ""
        if (!raw) return
        var colors = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var c = lines[i].trim()
          if (c.match(/^#[0-9a-fA-F]{6}$/)) colors.push(c)
        }
        root.swatchColors = colors
      }
    }
  }

  // Carrega lista de efeitos
  Process {
    id: effectsProc
    command: ["bash", "-c",
      "echo off; ls /home/antonio/.config/hypr/effects/wallpaper/ 2>/dev/null | sort"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => effectsProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        var raw = effectsProc._buf.trim()
        effectsProc._buf = ""
        var effects = []
        raw.split("\n").forEach(function(l) {
          var t = l.trim(); if (t) effects.push(t)
        })
        root.effectList = effects
      }
    }
  }

  // ── Aplica wallpaper ───────────────────────────────────────────────────────
  // wp-run faz double-fork + setsid antes de chamar wallpaper.sh.
  // O Process do QML retorna em ~50ms; wallpaper.sh continua rodando
  // independente mesmo que o painel seja fechado.
  Process {
    id: applyProc
    property string _pendingPath: ""
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => applyProc._buf += l }
    onRunningChanged: {
      if (!running) {
        applyProc._buf = ""
        // wp-run confirmou lançamento — atualiza badge imediatamente
        root.currentWallpaper = applyProc._pendingPath
        // Aguarda wallpaper.sh escrever state.json antes de reler.
        // Ordem: cache files → state → matugen(~4s) → lock → previews.
        stateRefreshTimer.restart()
      }
    }
  }

  Timer {
    id: stateRefreshTimer
    interval: 3000
    repeat: false
    onTriggered: { if (!stateProc.running) stateProc.running = true }
  }

  function _applyWallpaper(path) {
    if (applyProc.running) return
    applyProc._pendingPath = path
    // wp-run: lança wallpaper.sh desacoplado, retorna em ~50ms
    applyProc.command = [root.wpRun, "--quiet", path]
    applyProc.running = true
  }

  // Aplica configurações matugen
  Process {
    id: matugenProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => matugenProc._buf += l }
    onRunningChanged: {
      if (!running) {
        matugenProc._buf = ""
        if (!stateProc.running) stateProc.running = true
      }
    }
  }

  function _applyMatugen(idx) {
    if (matugenProc.running) return
    matugenProc.command = [
      "bash", "-c",
      "cd " + root.scriptsDir + " && python3 -m wp matugen apply --index " + idx
    ]
    matugenProc.running = true
  }

  function _setEffect(effect) {
    root.currentEffect = effect
    // Escreve configuração e lança wallpaper.sh via wp-run (desacoplado)
    settingEffectProc.command = [
      "bash", "-c",
      "echo '" + effect + "' > /home/antonio/.config/ml4w/settings/wallpaper-effect.sh && " +
      "'" + root.wpRun + "' --quiet"
    ]
    if (!settingEffectProc.running) settingEffectProc.running = true
  }

  function _setPalette(palette) {
    root.currentPalette = palette
    settingPaletteProc.command = [
      "bash", "-c",
      "echo '" + palette + "' > /home/antonio/.config/ml4w/settings/matugen-pallete.sh && " +
      "cd " + root.scriptsDir + " && python3 -m wp matugen apply --quiet"
    ]
    if (!settingPaletteProc.running) settingPaletteProc.running = true
  }

  function _setSource(src) {
    root.currentSource = src
    settingSourceProc.command = [
      "bash", "-c",
      "echo '" + src + "' > /home/antonio/.config/ml4w/cache/matugen-source && " +
      "cd " + root.scriptsDir + " && python3 -m wp matugen apply --quiet"
    ]
    if (!settingSourceProc.running) settingSourceProc.running = true
  }

  Process {
    id: settingEffectProc;  property string _buf: ""
    stdout: SplitParser { onRead: (l) => settingEffectProc._buf += l }
    onRunningChanged: { if (!running) { settingEffectProc._buf = ""; if (!stateProc.running) stateProc.running = true } }
  }
  Process {
    id: settingPaletteProc; property string _buf: ""
    stdout: SplitParser { onRead: (l) => settingPaletteProc._buf += l }
    onRunningChanged: { if (!running) { settingPaletteProc._buf = ""; if (!stateProc.running) stateProc.running = true } }
  }
  Process {
    id: settingSourceProc;  property string _buf: ""
    stdout: SplitParser { onRead: (l) => settingSourceProc._buf += l }
    onRunningChanged: { if (!running) { settingSourceProc._buf = ""; if (!stateProc.running) stateProc.running = true } }
  }

  // Salvar / deletar perfil
  Process {
    id: profileActionProc; property string _buf: ""
    stdout: SplitParser { onRead: (l) => profileActionProc._buf += l }
    onRunningChanged: {
      if (!running) {
        profileActionProc._buf = ""
        if (!profilesProc.running) profilesProc.running = true
      }
    }
  }

  function _loadProfile(value) {
    var name = value.replace(/^profile:/, "")
    // Obtém o path do wallpaper do perfil, depois lança via wp-run
    profileActionProc.command = [
      "bash", "-c",
      "cd '" + root.scriptsDir + "' && " +
      "src=$(python3 -m wp profile apply '" + name + "') && " +
      "exec '" + root.wpRun + "' --quiet \"$src\""
    ]
    if (!profileActionProc.running) profileActionProc.running = true
  }

  function _deleteProfile(value) {
    var name = value.replace(/^profile:/, "")
    profileActionProc.command = [
      "bash", "-c",
      "cd " + root.scriptsDir + " && python3 -m wp profile delete '" + name + "'"
    ]
    if (!profileActionProc.running) profileActionProc.running = true
  }

  property string _saveProfileName: ""

  Process {
    id: saveProfileProc; property string _buf: ""
    stdout: SplitParser { onRead: (l) => saveProfileProc._buf += l }
    onRunningChanged: {
      if (!running) {
        saveProfileProc._buf = ""
        root._saveProfileName = ""
        if (!profilesProc.running) profilesProc.running = true
      }
    }
  }

  function _saveProfile(name) {
    if (!name || name.trim() === "") return
    saveProfileProc.command = [
      "bash", "-c",
      "cd " + root.scriptsDir + " && python3 -m wp profile save '" + name.trim() + "'"
    ]
    if (!saveProfileProc.running) saveProfileProc.running = true
  }

  // ── Inicialização ──────────────────────────────────────────────────────────
  onPanelOpenChanged: {
    if (panelOpen) {
      if (!stateProc.running)    stateProc.running    = true
      if (!effectsProc.running)  effectsProc.running  = true
      if (!wallpapersProc.running) {
        root.loadingWallpapers = true
        wallpapersProc.running = true
      }
      if (!profilesProc.running) profilesProc.running = true
    }
  }

  onActiveTabChanged: {
    if (activeTab === "matugen" && swatchColors.length === 0 && !loadingSwatches) {
      root.loadingSwatches = true
      if (!swatchProc.running) swatchProc.running = true
    }
    if (activeTab === "profiles" && profileEntries.length === 0) {
      if (!profilesProc.running) profilesProc.running = true
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // ── Tab bar ──────────────────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true
      height: 44

      RowLayout {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        anchors.leftMargin: 14; anchors.rightMargin: 14
        spacing: 4

        Repeater {
          model: [
            { id: "wallpaper", icon: "\uf03e", label: "Wallpaper" },
            { id: "matugen",   icon: "\uf53f", label: "Matugen"   },
            { id: "profiles",  icon: "\uf097", label: "Perfis"    }
          ]

          delegate: Item {
            Layout.fillWidth: true
            height: 32

            readonly property bool isActive: root.activeTab === modelData.id

            Rectangle {
              anchors.fill: parent
              radius: 6
              color: isActive
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                : (tabMA.containsMouse
                    ? Qt.rgba(1,1,1,0.05)
                    : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.leftMargin:  4; anchors.rightMargin: 4
                height: 2; radius: 1
                color: root.colorAccent
                opacity: isActive ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
              }
            }

            RowLayout {
              anchors.centerIn: parent
              spacing: 5

              Text {
                text: modelData.icon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                color: isActive ? root.colorAccent : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
              Text {
                text: modelData.label
                font { pixelSize: 11 }
                color: isActive ? root.colorText : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
            }

            MouseArea {
              id: tabMA; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = modelData.id
            }
          }
        }
      }

      // Linha divisória sob as tabs
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.colorDivider; opacity: 0.5
      }
    }

    // ── Conteúdo das abas ────────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // ── Aba: Wallpaper ───────────────────────────────────────────────────
      Item {
        anchors.fill: parent
        visible: root.activeTab === "wallpaper"
        clip: true

        // Placeholder de loading
        Text {
          anchors.centerIn: parent
          visible: root.loadingWallpapers
          text: "\uf110  carregando..."
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
          color: root.colorTextDim; opacity: 0.6
        }

        // Grid de wallpapers
        GridView {
          id: wallpaperGrid
          anchors { fill: parent; margins: 10 }
          visible: !root.loadingWallpapers
          clip: true

          cellWidth:  Math.floor((width - 4) / 3)
          cellHeight: cellWidth * 9 / 16 + 24   // aspect 16:9 + label

          model: root.wallpaperEntries

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
              radius: 8
              clip: true
              color: isCurrent
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
                : Qt.rgba(1, 1, 1, 0.04)

              border.color: isCurrent ? root.colorAccent
                           : isHovered ? Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.25)
                           : "transparent"
              border.width: isCurrent ? 1.5 : 1

              Behavior on border.color { ColorAnimation { duration: 120 } }

              // Thumbnail
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

              // Nome
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
              onClicked: root._applyWallpaper(modelData.value.replace(/^file:/, ""))
            }
          }

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }
        }
      }

      // ── Aba: Matugen ─────────────────────────────────────────────────────
      Flickable {
        anchors.fill: parent
        visible: root.activeTab === "matugen"
        contentWidth: width
        contentHeight: matugenCol.implicitHeight + 20
        clip: true
        boundsMovement: Flickable.StopAtBounds

        ColumnLayout {
          id: matugenCol
          x: 14; y: 12
          width: parent.width - 28
          spacing: 16

          // ── Efeito ────────────────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
              text: "\uf5aa  EFEITO"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
              color: root.colorTextDim; opacity: 0.7
            }

            Flow {
              Layout.fillWidth: true; spacing: 6

              Repeater {
                model: root.effectList

                delegate: Item {
                  id: effectDelegate
                  width: chip.implicitWidth + 24; height: 28

                  readonly property bool isActive: root.currentEffect === modelData
                  readonly property bool isHovered: effectHoverMA.containsMouse

                  // Preview tooltip ao hover
                  Rectangle {
                    visible: effectDelegate.isHovered && root.baseWallpaper !== ""
                    z: 999
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 6
                    width: 160; height: 90; radius: 6
                    color: "#111111"
                    border.color: root.colorAccent; border.width: 1
                    clip: true

                    Image {
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      source: root.baseWallpaper !== "" ? ("file://" + root.baseWallpaper) : ""
                      asynchronous: true; smooth: true
                    }

                    Rectangle {
                      anchors.bottom: parent.bottom
                      anchors.left: parent.left; anchors.right: parent.right
                      height: 18
                      color: Qt.rgba(0, 0, 0, 0.65)

                      Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 9; color: "white"
                      }
                    }
                  }

                  Rectangle {
                    id: chip
                    anchors.fill: parent
                    radius: 14
                    color: isActive
                      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                      : Qt.rgba(1,1,1,0.06)
                    border.color: isActive ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                    border.width: isActive ? 1.5 : 1
                    implicitWidth: effectLabel.implicitWidth + 24

                    Text {
                      id: effectLabel
                      anchors.centerIn: parent
                      text: modelData
                      font.pixelSize: 10
                      color: isActive ? root.colorAccent : root.colorText
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Behavior on color { ColorAnimation { duration: 120 } }
                  }

                  MouseArea {
                    id: effectHoverMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._setEffect(modelData)
                  }
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

          // ── Palette ───────────────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
              text: "\uf53f  PALETTE"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
              color: root.colorTextDim; opacity: 0.7
            }

            Flow {
              Layout.fillWidth: true; spacing: 6

              Repeater {
                model: root.allPalettes

                delegate: Item {
                  width: pChip.implicitWidth + 24; height: 28

                  readonly property bool isActive: root.currentPalette === modelData

                  Rectangle {
                    id: pChip
                    anchors.fill: parent
                    radius: 14
                    color: isActive
                      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                      : Qt.rgba(1,1,1,0.06)
                    border.color: isActive ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                    border.width: isActive ? 1.5 : 1
                    implicitWidth: pLabel.implicitWidth + 24

                    Text {
                      id: pLabel
                      anchors.centerIn: parent
                      text: modelData.replace("scheme-", "")
                      font.pixelSize: 10
                      color: isActive ? root.colorAccent : root.colorText
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Behavior on color { ColorAnimation { duration: 120 } }
                  }

                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root._setPalette(modelData)
                  }
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

          // ── Source ─────────────────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true; spacing: 8

            Text {
              text: "\uf03e  FONTE"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
              color: root.colorTextDim; opacity: 0.7
              Layout.fillWidth: true
            }

            Repeater {
              model: [
                { id: "base",  label: "base"  },
                { id: "final", label: "final" }
              ]

              delegate: Item {
                width: srcChip.implicitWidth + 24; height: 28
                readonly property bool isActive: root.currentSource === modelData.id

                Rectangle {
                  id: srcChip
                  anchors.fill: parent; radius: 14
                  implicitWidth: srcLabel.implicitWidth + 24
                  color: isActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                    : Qt.rgba(1,1,1,0.06)
                  border.color: isActive ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                  border.width: isActive ? 1.5 : 1
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Text {
                    id: srcLabel
                    anchors.centerIn: parent
                    text: modelData.label; font.pixelSize: 10
                    color: isActive ? root.colorAccent : root.colorText
                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root._setSource(modelData.id)
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

          // ── Swatches de cor ────────────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true; spacing: 8

            RowLayout {
              Layout.fillWidth: true

              Text {
                text: "\uf111  COR DA FONTE"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
                color: root.colorTextDim; opacity: 0.7
                Layout.fillWidth: true
              }

              // Botão recarregar swatches
              Item {
                width: 24; height: 24
                Text {
                  anchors.centerIn: parent
                  text: "\uf021"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                  color: root.colorTextDim
                  opacity: root.loadingSwatches ? 0.4 : 0.7
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!swatchProc.running) {
                      root.swatchColors = []
                      root.loadingSwatches = true
                      swatchProc.running = true
                    }
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: root.loadingSwatches
              text: "carregando cores..."
              font.pixelSize: 10; color: root.colorTextDim; opacity: 0.5
            }

            Flow {
              Layout.fillWidth: true; spacing: 5
              visible: !root.loadingSwatches && root.swatchColors.length > 0

              Repeater {
                model: root.swatchColors

                delegate: Item {
                  width:  32; height: 32
                  readonly property int colorIdx: index
                  readonly property bool isActive: root.currentIndex === index

                  Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: modelData
                    border.color: isActive ? "white" : Qt.rgba(1,1,1,0.15)
                    border.width: isActive ? 2 : 1

                    Text {
                      anchors { bottom: parent.bottom; right: parent.right; margins: 2 }
                      text: colorIdx
                      font.pixelSize: 7
                      color: "white"
                      style: Text.Outline; styleColor: "#00000080"
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: isActive
                      text: "\uf00c"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                      color: "white"
                      style: Text.Outline; styleColor: "#00000080"
                    }

                    scale: swMA.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                  }

                  MouseArea {
                    id: swMA; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.currentIndex = colorIdx
                      root._applyMatugen(colorIdx)
                    }
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: !root.loadingSwatches && root.swatchColors.length === 0
              text: "Nenhuma cor disponível — troque de aba e volte."
              font.pixelSize: 10; color: root.colorTextDim; opacity: 0.5
              wrapMode: Text.WordWrap
            }
          }

          Item { height: 4 }
        }
      }

      // ── Aba: Perfis ──────────────────────────────────────────────────────
      Item {
        anchors.fill: parent
        visible: root.activeTab === "profiles"
        clip: true

        ColumnLayout {
          anchors { fill: parent; margins: 12 }
          spacing: 8

          // Botão "Salvar estado atual"
          Item {
            Layout.fillWidth: true; height: 36
            visible: root._saveProfileName === ""

            Rectangle {
              anchors.fill: parent; radius: 8
              color: saveMA.containsMouse
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                : Qt.rgba(1,1,1,0.05)
              border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
              border.width: 1
              Behavior on color { ColorAnimation { duration: 100 } }

              RowLayout {
                anchors.centerIn: parent; spacing: 6
                Text {
                  text: "\uf0c7"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                  color: root.colorAccent
                }
                Text {
                  text: "Salvar estado atual como perfil"
                  font.pixelSize: 10; color: root.colorText
                }
              }
            }

            MouseArea {
              id: saveMA; anchors.fill: parent
              hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._saveProfileName = " "
            }
          }

          // Input para nome do perfil (aparece ao clicar em Salvar)
          Item {
            Layout.fillWidth: true; height: 36
            visible: root._saveProfileName !== ""

            Rectangle {
              anchors.fill: parent; radius: 8
              color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.08)
              border.color: root.colorAccent; border.width: 1

              RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                spacing: 6

                TextInput {
                  id: profileNameInput
                  Layout.fillWidth: true
                  font.pixelSize: 11
                  color: text.length === 0 ? root.colorTextDim : root.colorText
                  selectedTextColor: "#1f1f1f"
                  selectionColor: root.colorAccent
                  focus: visible
                  Component.onCompleted: if (visible) forceActiveFocus()
                  onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }

                  Keys.onReturnPressed: root._saveProfile(text)
                  Keys.onEscapePressed: root._saveProfileName = ""

                  // Placeholder manual
                  Text {
                    anchors.fill: parent
                    text: "nome do perfil..."
                    color: root.colorTextDim
                    font: parent.font
                    visible: parent.text.length === 0 && !parent.activeFocus
                    verticalAlignment: Text.AlignVCenter
                  }
                }

                // Confirmar
                Item {
                  width: 28; height: 28
                  Rectangle {
                    anchors.fill: parent; radius: 6
                    color: confirmMA.containsMouse
                      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
                      : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "\uf00c"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                      color: root.colorAccent
                    }
                  }
                  MouseArea {
                    id: confirmMA; anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._saveProfile(profileNameInput.text)
                  }
                }

                // Cancelar
                Item {
                  width: 28; height: 28
                  Rectangle {
                    anchors.fill: parent; radius: 6
                    color: cancelMA.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "\uf00d"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                      color: root.colorTextDim
                    }
                  }
                  MouseArea {
                    id: cancelMA; anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._saveProfileName = ""
                  }
                }
              }
            }
          }

          // Linha divisória
          Rectangle {
            Layout.fillWidth: true; height: 1
            color: root.colorDivider; opacity: 0.4
          }

          // Lista de perfis
          ListView {
            id: profileList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true; spacing: 6

            model: root.profileEntries

            property int deleteConfirmIdx: -1

            delegate: Item {
              width: profileList.width
              height: 58

              readonly property bool isDeleting: profileList.deleteConfirmIdx === index

              Rectangle {
                anchors.fill: parent; radius: 8
                color: cardMA.containsMouse
                  ? Qt.rgba(1,1,1,0.06)
                  : Qt.rgba(1,1,1,0.03)
                border.color: isDeleting
                  ? Qt.rgba(1, 0.3, 0.3, 0.5)
                  : Qt.rgba(1,1,1,0.07)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                  anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                  spacing: 8

                  Rectangle {
                    width: 72; height: 40; radius: 5; clip: true
                    color: Qt.rgba(1,1,1,0.04)
                    Image {
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      source: (modelData.thumb && modelData.thumb !== "")
                        ? ("file://" + modelData.thumb) : ""
                      asynchronous: true; cache: true; smooth: true
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text {
                      text: (modelData.label || "").split("  ·  ")[0]
                      font.pixelSize: 11; color: root.colorText
                      elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                      text: modelData.sub || ""
                      font.pixelSize: 9; color: root.colorTextDim
                      elide: Text.ElideRight; Layout.fillWidth: true
                    }
                  }

                  RowLayout {
                    spacing: 4
                    visible: !isDeleting

                    Item {
                      width: 28; height: 28
                      Rectangle {
                        anchors.fill: parent; radius: 6
                        color: loadMA.containsMouse
                          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                          : Qt.rgba(1,1,1,0.05)
                        Text {
                          anchors.centerIn: parent
                          text: "\uf144"
                          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                          color: root.colorAccent
                        }
                      }
                      MouseArea {
                        id: loadMA; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._loadProfile(modelData.value)
                      }
                    }

                    Item {
                      width: 28; height: 28
                      Rectangle {
                        anchors.fill: parent; radius: 6
                        color: delMA.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : Qt.rgba(1,1,1,0.05)
                        Text {
                          anchors.centerIn: parent
                          text: "\uf1f8"
                          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                          color: "#cf6679"
                        }
                      }
                      MouseArea {
                        id: delMA; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: profileList.deleteConfirmIdx = index
                      }
                    }
                  }

                  RowLayout {
                    spacing: 4
                    visible: isDeleting

                    Text {
                      text: "confirmar?"
                      font.pixelSize: 9; color: "#cf6679"
                    }

                    Item {
                      width: 28; height: 28
                      Rectangle {
                        anchors.fill: parent; radius: 6
                        color: yesMA.containsMouse ? Qt.rgba(1,0.3,0.3,0.3) : Qt.rgba(1,0.3,0.3,0.15)
                        Text {
                          anchors.centerIn: parent; text: "\uf00c"
                          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                          color: "#cf6679"
                        }
                      }
                      MouseArea {
                        id: yesMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root._deleteProfile(modelData.value)
                          profileList.deleteConfirmIdx = -1
                        }
                      }
                    }

                    Item {
                      width: 28; height: 28
                      Rectangle {
                        anchors.fill: parent; radius: 6
                        color: noMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                        Text {
                          anchors.centerIn: parent; text: "\uf00d"
                          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                          color: root.colorTextDim
                        }
                      }
                      MouseArea {
                        id: noMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: profileList.deleteConfirmIdx = -1
                      }
                    }
                  }
                }
              }

              MouseArea {
                id: cardMA
                anchors.fill: parent; hoverEnabled: true
                z: -1
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.profileEntries.length === 0
              text: "Nenhum perfil salvo ainda."
              font.pixelSize: 11; color: root.colorTextDim; opacity: 0.5
            }

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          }
        }
      }
    }
  }
}
