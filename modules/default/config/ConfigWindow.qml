import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import './tabs' as Tabs
import '../../../' as Root  // Para acessar Colors singleton diretamente

// ── ConfigWindow ──────────────────────────────────────────────────────────────
// Janela de configuração global do shell.
//
// shell.qml:
//   import './modules/default/config' as ConfigModule
//   property bool configOpen: false
//   ConfigModule.ConfigWindow {
//     panelOpen:        configOpen
//     config:           bar.configRef
//     colors:           Colors
//     colorBg:          bar.popupColorBg
//     colorText:        bar.popupColorText
//     colorTextDim:     bar.popupColorTextDim
//     colorAccent:      bar.popupColorAccent
//     colorDivider:     bar.popupColorDivider
//     onCloseRequested: configOpen = false
//     onSaveRequested:  (opts) => bar.configRef.saveAll(opts)
//   }
//   IpcHandler { target: "config"
//     function toggle() { configOpen = !configOpen }
//   }

PanelWindow {
  id: win

  // ── API pública ───────────────────────────────────────────────────────
  property bool panelOpen: false
  property var  config:    null
  property var  colors:    null   // Colors singleton — pode ser passado pelo shell.qml
  // Resolve colors: usa o passado externamente ou importa direto
  readonly property var _effectiveColors: colors !== null ? colors : (Root.Colors !== undefined ? Root.Colors : null)

  property color colorBg:         "#1e1e2e"
  property color colorSidebar:    "#181825"
  property color colorSubbar:     "#1a1a2a"
  property color colorText:       "#cdd6f4"
  property color colorTextDim:    "#6c7086"
  property color colorAccent:     "#cba6f7"
  property color colorDivider:    "#313244"
  property color colorProgressBg: "#313244"
  property color colorSuccess:    "#a6e3a1"
  property color colorError:      "#f38ba8"

  signal closeRequested()
  signal saveRequested(var opts)

  // ── Geometria / animação ──────────────────────────────────────────────
  readonly property int winW: 920
  readonly property int winH: 640

  property real _anim:    0.0
  property bool _alive:   false
  property bool _closing: false

  visible:        _alive
  color:          "transparent"
  implicitWidth:  winW
  implicitHeight: winH

  WlrLayershell.layer:         WlrLayershell.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: 0
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  margins.top:    screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.bottom: screen ? Math.max(0, Math.floor((screen.height - winH) / 2)) : 0
  margins.left:   screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0
  margins.right:  screen ? Math.max(0, Math.floor((screen.width  - winW) / 2)) : 0

  onPanelOpenChanged: {
    if (panelOpen) {
      _closing = false; _alive = true
      _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
      openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
      if (config && config.configLoaded) _reload()
    } else {
      _closing = true; openAnim.stop()
      closeAnim.from = _anim; closeAnim.to = 0.0; closeAnim.start()
      _safetyTimer.restart()
    }
  }

  NumberAnimation { id: openAnim;  target: win; property: "_anim"; duration: 220; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: win; property: "_anim"; duration: 200; easing.type: Easing.OutCubic
    onStopped: { if (win._closing) _unmapTimer.restart() } }
  Timer { id: _unmapTimer;  interval: 17;  onTriggered: { if (win._closing) { win._alive = false; win._closing = false } } }
  Timer { id: _safetyTimer; interval: 440; onTriggered: { if (!win.panelOpen) { win._alive = false; win._closing = false; _unmapTimer.stop() } } }

  Component.onCompleted: {
    console.log("[ConfigWindow] colors prop:", win.colors)
    console.log("[ConfigWindow] _effectiveColors:", win._effectiveColors)
    Qt.callLater(function() {
      console.log("[ConfigWindow] delayed colors:", win.colors, "| effective:", win._effectiveColors)
      if (win._effectiveColors)
        console.log("[ConfigWindow] colors.primary:", win._effectiveColors.primary)
    })
  }

  HyprlandFocusGrab {
    windows: [win]; active: win.panelOpen
    onCleared: win.closeRequested()
  }

  // ── Módulo / subaba ───────────────────────────────────────────────────
  property int activeModule: 0
  property var subtabState:  ({})

  function subtab(mod) { return subtabState[mod] !== undefined ? subtabState[mod] : 0 }
  function setSubtab(mod, idx) {
    var o = {} for (var k in subtabState) o[k] = subtabState[k]; o[mod] = idx; subtabState = o
  }

  readonly property var modules: [
    { id: "bar",        icon: "\uf0c9", label: "Barra",
      subtabs: ["Geral","Módulos","Workspaces","Clock","Volume","Mídia","Paleta"] },
    { id: "wallpaper",  icon: "\uf03e", label: "Wallpaper",  subtabs: [] },
    { id: "widgets",    icon: "\uf2d2", label: "Widgets",    subtabs: [] },
    { id: "dmenu",      icon: "\uf0ca", label: "Dmenu",      subtabs: [] },
    { id: "screenlock", icon: "\uf023", label: "Screenlock", subtabs: [] },
  ]

  // ══════════════════════════════════════════════════════════════════════
  // Estado local — Barra
  // ══════════════════════════════════════════════════════════════════════
  property string localTheme:          "Pill"
  property int    localPosition:       3
  property bool   localAutoHide:       true
  property bool   localSilence:        false
  property int    localBarSize:        30
  property int    localBarMargin:      3
  property int    localPillWidth:      800
  property int    localPillMinSpacing: 20

  property var slotLeft:   []
  property var slotCenter: []
  property var slotRight:  []
  property var slotTop:    []
  property var slotMiddle: []
  property var slotBottom: []

  property string localWsStyle:   "icons"
  property string localWsSort:    "position"
  property bool   localWsMono:    true
  property int    localWsSpacing: 4
  property bool   localWsAddBtn:  true

  property string pkClkText:       "on_surface"
  property string pkClkDim:        "on_surface_variant"
  property string pkClkAccent:     "primary"
  property int    localClkDismiss: 8000

  property bool   localShowSink:   true
  property bool   localShowSource: true
  property string pkVolMuted:      "error"

  property string localMpTextMode:    "artistAndTitle"
  property int    localMpScrollSpeed: 40
  property int    localMpScrollWidth: 140
  property bool   localMpBgEnabled:   false
  property string pkMpBgColor:       "surface_variant"
  property string pkMpBgActive:      "primary_container"
  property string pkMpText:          "on_surface"
  property string pkMpDim:           "on_surface_variant"
  property string pkMpTextActive:    "on_primary_container"
  property string pkMpDimActive:     "on_surface_variant"

  property string pkBarBg:      "surface_container_lowest"
  property string pkBarBgPill:  "background"
  property string pkText:       "on_surface"
  property string pkTextDim:    "on_surface_variant"
  property string pkAccent:     "primary"
  property string pkAccentBg:   "primary_container"
  property string pkPanelBg:    "surface_container"
  property string pkProgressBg: "outline_variant"
  property string pkProgressFg: "primary"
  property string pkDivider:    "outline_variant"

  property bool _savedFlash: false
  property var  _savedTimer: Timer {
    interval: 1800; repeat: false; onTriggered: win._savedFlash = false
  }

  // ── _reload ───────────────────────────────────────────────────────────
  function _reload() {
    if (!config) return
    localTheme          = config.theme          || "Pill"
    localPosition       = config.position       || 3
    localAutoHide       = config.autoHide       !== undefined ? config.autoHide    : true
    localSilence        = config.silenceMode    !== undefined ? config.silenceMode : false
    localBarSize        = config.barSize        || 30
    localBarMargin      = config.barMargin      !== undefined ? config.barMargin   : 3
    localPillWidth      = config.pillWidth      || 800
    localPillMinSpacing = config.pillMinSpacing !== undefined ? config.pillMinSpacing : 20
    slotLeft   = (config.modulesLeft   || []).slice()
    slotCenter = (config.modulesCenter || []).slice()
    slotRight  = (config.modulesRight  || []).slice()
    slotTop    = (config.modulesTop    || []).slice()
    slotMiddle = (config.modulesMiddle || []).slice()
    slotBottom = (config.modulesBottom || []).slice()
    localWsStyle   = config.wsStyle          || "icons"
    localWsSort    = config.wsIconsSort      || "position"
    localWsMono    = config.wsIconMonochrome !== undefined ? config.wsIconMonochrome : true
    localWsSpacing = config.wsIconSpacing    || 4
    localWsAddBtn  = config.wsShowAddButton  !== undefined ? config.wsShowAddButton  : true
    pkClkText       = config.pkClkTextColor   || "on_surface"
    pkClkDim        = config.pkClkDimColor    || "on_surface_variant"
    pkClkAccent     = config.pkClkAccentColor || "primary"
    localClkDismiss = config.clkDismissDelayMs || 8000
    localShowSink   = config.volShowSink   !== undefined ? config.volShowSink   : true
    localShowSource = config.volShowSource !== undefined ? config.volShowSource : true
    pkVolMuted      = config.pkVolMuted    || "error"
    localMpTextMode    = config.mpTextMode    || "artistAndTitle"
    localMpScrollSpeed = config.mpScrollSpeed || 40
    localMpScrollWidth = config.mpScrollWidth || 140
    localMpBgEnabled   = config.mpBgEnabled   !== undefined ? config.mpBgEnabled : false
    pkMpBgColor    = config.pkMpBgColor        || "surface_variant"
    pkMpBgActive   = config.pkMpBgColorActive  || "primary_container"
    pkMpText       = config.pkMpTextColor       || "on_surface"
    pkMpDim        = config.pkMpDimColor        || "on_surface_variant"
    pkMpTextActive = config.pkMpTextColorActive || "on_primary_container"
    pkMpDimActive  = config.pkMpDimColorActive  || "on_surface_variant"
    pkBarBg      = config.pkBarBg      || "surface_container_lowest"
    pkBarBgPill  = config.pkBarBgPill  || "background"
    pkText       = config.pkText       || "on_surface"
    pkTextDim    = config.pkTextDim    || "on_surface_variant"
    pkAccent     = config.pkAccent     || "primary"
    pkAccentBg   = config.pkAccentBg   || "primary_container"
    pkPanelBg    = config.pkPanelBg    || "surface_container"
    pkProgressBg = config.pkProgressBg || "outline_variant"
    pkProgressFg = config.pkProgressFg || "primary"
    pkDivider    = config.pkDivider    || "outline_variant"
  }

  // ── _applyOpts — chamado pelos filhos via onChanged ───────────────────
  function _applyOpts(opts) {
    for (var k in opts) {
      // slots
      if (k === "modulesLeft")   { slotLeft   = opts[k]; continue }
      if (k === "modulesCenter") { slotCenter = opts[k]; continue }
      if (k === "modulesRight")  { slotRight  = opts[k]; continue }
      if (k === "modulesTop")    { slotTop    = opts[k]; continue }
      if (k === "modulesMiddle") { slotMiddle = opts[k]; continue }
      if (k === "modulesBottom") { slotBottom = opts[k]; continue }
      // restante via mapeamento direto
      var map = {
        theme:"localTheme", position:"localPosition", autoHide:"localAutoHide",
        silence:"localSilence", barSize:"localBarSize", barMargin:"localBarMargin",
        pillWidth:"localPillWidth", pillMinSpacing:"localPillMinSpacing",
        wsStyle:"localWsStyle", wsIconsSort:"localWsSort",
        wsIconMonochrome:"localWsMono", wsIconSpacing:"localWsSpacing",
        wsShowAddButton:"localWsAddBtn",
        pkClkText:"pkClkText", pkClkDim:"pkClkDim", pkClkAccent:"pkClkAccent",
        clkDismissDelayMs:"localClkDismiss",
        volShowSink:"localShowSink", volShowSource:"localShowSource", pkVolMuted:"pkVolMuted",
        mpTextMode:"localMpTextMode", mpScrollSpeed:"localMpScrollSpeed",
        mpScrollWidth:"localMpScrollWidth", mpBgEnabled:"localMpBgEnabled",
        pkMpBgColor:"pkMpBgColor", pkMpBgActive:"pkMpBgActive",
        pkMpText:"pkMpText", pkMpDim:"pkMpDim",
        pkMpTextActive:"pkMpTextActive", pkMpDimActive:"pkMpDimActive",
        pkBarBg:"pkBarBg", pkBarBgPill:"pkBarBgPill",
        pkText:"pkText", pkTextDim:"pkTextDim",
        pkAccent:"pkAccent", pkAccentBg:"pkAccentBg",
        pkPanelBg:"pkPanelBg", pkProgressBg:"pkProgressBg",
        pkProgressFg:"pkProgressFg", pkDivider:"pkDivider",
      }
      if (map[k]) win[map[k]] = opts[k]
    }
    _save()
  }

  // ── _save ─────────────────────────────────────────────────────────────
  function _save() {
    if (!config) return
    var isH = localPosition === 1 || localPosition === 3
    win.saveRequested({
      theme: localTheme, position: localPosition,
      autoHide: localAutoHide, silence: localSilence,
      barSize: localBarSize, barMargin: localBarMargin,
      pillWidth: localPillWidth, pillMinSpacing: localPillMinSpacing,
      modulesLeft:   isH ? slotLeft   : (config.modulesLeft   || []).slice(),
      modulesCenter: isH ? slotCenter : (config.modulesCenter || []).slice(),
      modulesRight:  isH ? slotRight  : (config.modulesRight  || []).slice(),
      modulesTop:    isH ? (config.modulesTop    || []).slice() : slotTop,
      modulesMiddle: isH ? (config.modulesMiddle || []).slice() : slotMiddle,
      modulesBottom: isH ? (config.modulesBottom || []).slice() : slotBottom,
      wsStyle: localWsStyle, wsIconsSort: localWsSort,
      wsIconMonochrome: localWsMono, wsIconSpacing: localWsSpacing,
      wsShowAddButton: localWsAddBtn,
      pkClkTextColor: pkClkText, pkClkDimColor: pkClkDim,
      pkClkAccentColor: pkClkAccent, clkDismissDelayMs: localClkDismiss,
      volShowSink: localShowSink, volShowSource: localShowSource, pkVolMuted: pkVolMuted,
      mpTextMode: localMpTextMode, mpScrollSpeed: localMpScrollSpeed,
      mpScrollWidth: localMpScrollWidth, mpBgEnabled: localMpBgEnabled,
      pkMpBgColor: pkMpBgColor, pkMpBgActive: pkMpBgActive,
      pkMpText: pkMpText, pkMpDim: pkMpDim,
      pkMpTextActive: pkMpTextActive, pkMpDimActive: pkMpDimActive,
      pkBarBg: pkBarBg, pkBarBgPill: pkBarBgPill,
      pkText: pkText, pkTextDim: pkTextDim,
      pkAccent: pkAccent, pkAccentBg: pkAccentBg,
      pkPanelBg: pkPanelBg, pkProgressBg: pkProgressBg,
      pkProgressFg: pkProgressFg, pkDivider: pkDivider,
    })
    _savedFlash = true; _savedTimer.restart()
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════
  Rectangle {
    id: mainRect
    anchors.fill: parent; radius: 16; clip: true
    opacity:      Math.min(1.0, win._anim * 1.4)
    transform:    Translate { y: 12 * (1.0 - win._anim) }
    color:        Qt.rgba(win.colorBg.r, win.colorBg.g, win.colorBg.b, 0.97)
    border.color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.5)
    border.width: 1
    layer.enabled: true

    RowLayout {
      anchors.fill: parent
      spacing: 0

      // ── Sidebar ────────────────────────────────────────────────────
      Rectangle {
        Layout.preferredWidth: 158; Layout.fillHeight: true
        color: win.colorSidebar; radius: 16
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
          width: 16; color: win.colorSidebar }

        ColumnLayout {
          anchors { fill: parent; margins: 12 }
          spacing: 2

          // Título
          RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "\uf085"; color: win.colorAccent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
            Text { text: "Shell Config"; color: win.colorText; font.pixelSize: 11; font.weight: Font.Medium }
            Item { Layout.fillWidth: true }
            Rectangle { width: 18; height: 18; radius: 9
              color: xhov.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : "transparent"
              Text { anchors.centerIn: parent; text: "\uf00d"; color: win.colorTextDim; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
              MouseArea { id: xhov; anchors.fill: parent; hoverEnabled: true; onClicked: win.closeRequested() }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1
            color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.5)
            Layout.topMargin: 4; Layout.bottomMargin: 6 }

          // Módulos
          Repeater {
            model: win.modules
            delegate: Rectangle {
              required property var modelData; required property int index
              readonly property bool active: win.activeModule === index
              Layout.fillWidth: true; height: 36; radius: 7
              color: active ? Qt.rgba(win.colorAccent.r,win.colorAccent.g,win.colorAccent.b,0.15)
                   : (mhov.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
              border.color: active ? Qt.rgba(win.colorAccent.r,win.colorAccent.g,win.colorAccent.b,0.35) : "transparent"
              border.width: 1
              Behavior on color        { ColorAnimation { duration: 80 } }
              Behavior on border.color { ColorAnimation { duration: 80 } }
              Row { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } spacing: 9
                Text { text: modelData.icon; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                  color: parent.parent.active ? win.colorAccent : win.colorTextDim
                  Behavior on color { ColorAnimation { duration: 80 } }
                  anchors.verticalCenter: parent.verticalCenter }
                Text { text: modelData.label; font.pixelSize: 11
                  color: parent.parent.active ? win.colorText : win.colorTextDim
                  Behavior on color { ColorAnimation { duration: 80 } }
                  anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: mhov; anchors.fill: parent; hoverEnabled: true; onClicked: win.activeModule = index }
            }
          }

          Item { Layout.fillHeight: true }

          // Salvo
          Rectangle {
            Layout.fillWidth: true; height: 24; radius: 6; visible: win._savedFlash
            color:        Qt.rgba(win.colorSuccess.r,win.colorSuccess.g,win.colorSuccess.b,0.12)
            border.color: Qt.rgba(win.colorSuccess.r,win.colorSuccess.g,win.colorSuccess.b,0.35)
            border.width: 1
            Row { anchors.centerIn: parent; spacing: 5
              Text { text: "\uf00c"; color: win.colorSuccess; font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
              Text { text: "Salvo"; color: win.colorSuccess; font.pixelSize: 10 }
            }
          }
        }
      }

      // ── Área direita ───────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

        // Barra de subabas
        Rectangle {
          Layout.fillWidth: true; height: 42; color: win.colorSubbar
          Rectangle { anchors { top: parent.top; right: parent.right } width: 16; height: 16; color: win.colorSubbar
            Rectangle { anchors.fill: parent; radius: 16; color: win.colorBg } }

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 12 } spacing: 0

            Repeater {
              model: win.activeModule < win.modules.length ? win.modules[win.activeModule].subtabs : []
              delegate: Item {
                required property string modelData; required property int index
                readonly property bool active: win.subtab(win.activeModule) === index
                height: 42; width: stLbl.implicitWidth + 22
                Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                  height: 2; radius: 1; color: win.colorAccent
                  opacity: parent.active ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }
                Text { id: stLbl; anchors.centerIn: parent; text: modelData; font.pixelSize: 11
                  color: parent.active ? win.colorText : win.colorTextDim
                  Behavior on color { ColorAnimation { duration: 80 } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: win.setSubtab(win.activeModule, index) }
              }
            }

            Item { Layout.fillWidth: true }

            // Reset (só barra)
            Rectangle {
              visible: win.activeModule === 0
              height: 26; width: rstLbl.implicitWidth + 16; radius: 6
              color: rstHov.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
              border.color: Qt.rgba(1,1,1,0.1); border.width: 1
              Behavior on color { ColorAnimation { duration: 80 } }
              Text { id: rstLbl; anchors.centerIn: parent; text: "\uf0e2  Padrão"
                color: win.colorTextDim; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
              MouseArea { id: rstHov; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  win.localTheme = "Pill"; win.localPosition = 3
                  win.localAutoHide = true; win.localSilence = false
                  win.localBarSize = 30; win.localBarMargin = 3
                  win.localPillWidth = 800; win.localPillMinSpacing = 20
                  win.slotLeft = ["mediaplayer"]; win.slotCenter = ["workspaces"]
                  win.slotRight = ["quicksettings","separator","clock","separator","volume"]
                  win.slotTop = ["mediaplayer"]; win.slotMiddle = ["workspaces"]
                  win.slotBottom = ["quicksettings","separator","clock","separator","volume"]
                  win._save()
                }
              }
            }
          }

          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1
            color: Qt.rgba(win.colorDivider.r,win.colorDivider.g,win.colorDivider.b,0.4) }
        }

        // Conteúdo
        Item {
          Layout.fillWidth: true; Layout.fillHeight: true

          // Barra
          Loader {
            anchors.fill: parent; active: win.activeModule === 0
            sourceComponent: Tabs.BarTab {
              activeSubtab: win.subtab(0)
              // cores
              colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
              colorText: win.colorText; colorProgressBg: win.colorProgressBg
              colorSidebar: win.colorSidebar; colorDivider: win.colorDivider
              colorError: win.colorError; colors: win._effectiveColors
              // geral
              localTheme: win.localTheme; localPosition: win.localPosition
              localAutoHide: win.localAutoHide; localSilence: win.localSilence
              localBarSize: win.localBarSize; localBarMargin: win.localBarMargin
              localPillWidth: win.localPillWidth; localPillMinSpacing: win.localPillMinSpacing
              // módulos
              slotLeft: win.slotLeft; slotCenter: win.slotCenter; slotRight: win.slotRight
              slotTop: win.slotTop; slotMiddle: win.slotMiddle; slotBottom: win.slotBottom
              // workspaces
              localWsStyle: win.localWsStyle; localWsSort: win.localWsSort
              localWsMono: win.localWsMono; localWsSpacing: win.localWsSpacing; localWsAddBtn: win.localWsAddBtn
              // clock
              pkClkText: win.pkClkText; pkClkDim: win.pkClkDim; pkClkAccent: win.pkClkAccent
              localClkDismiss: win.localClkDismiss
              // volume
              localShowSink: win.localShowSink; localShowSource: win.localShowSource; pkVolMuted: win.pkVolMuted
              // midia
              localMpTextMode: win.localMpTextMode; localMpScrollSpeed: win.localMpScrollSpeed
              localMpScrollWidth: win.localMpScrollWidth; localMpBgEnabled: win.localMpBgEnabled
              pkMpBgColor: win.pkMpBgColor; pkMpBgActive: win.pkMpBgActive
              pkMpText: win.pkMpText; pkMpDim: win.pkMpDim
              pkMpTextActive: win.pkMpTextActive; pkMpDimActive: win.pkMpDimActive
              // paleta
              pkBarBg: win.pkBarBg; pkBarBgPill: win.pkBarBgPill
              pkText: win.pkText; pkTextDim: win.pkTextDim
              pkAccent: win.pkAccent; pkAccentBg: win.pkAccentBg
              pkPanelBg: win.pkPanelBg; pkProgressBg: win.pkProgressBg
              pkProgressFg: win.pkProgressFg; pkDivider: win.pkDivider

              overlay: popupOverlay
              onChanged: (opts) => win._applyOpts(opts)
            }
          }

          // Placeholder
          Loader {
            anchors.fill: parent; active: win.activeModule > 0
            sourceComponent: Item {
              Column { anchors.centerIn: parent; spacing: 10
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf013"
                  color: Qt.rgba(win.colorTextDim.r,win.colorTextDim.g,win.colorTextDim.b,0.2)
                  font.pixelSize: 40; font.family: "JetBrainsMono Nerd Font" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Em desenvolvimento"
                  color: Qt.rgba(win.colorTextDim.r,win.colorTextDim.g,win.colorTextDim.b,0.35); font.pixelSize: 12 }
              }
            }
          }
        }
      }
    }
  }

  // Overlay para popups que precisam escapar do layer.enabled/clip do mainRect
  Item {
    id: popupOverlay
    anchors.fill: parent
    z: 100
  }
}
