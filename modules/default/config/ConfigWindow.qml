import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import './tabs' as Tabs

// ── ConfigWindow ──────────────────────────────────────────────────────────────
// Janela de configuração global do shell.
//
// API mínima no shell.qml:
//   ConfigModule.ConfigWindow {
//     panelOpen:        configOpen
//     config:           bar.configRef   // BarConfig instance
//     colors:           Colors
//     onCloseRequested: configOpen = false
//   }
//
// Os tabs recebem `config` e `colors` diretamente e usam config.get/set.
// Não há estado local de módulos — cada tab lê e escreve diretamente.

PanelWindow {
  id: win

  // ── API pública ───────────────────────────────────────────────────────
  property bool panelOpen: false
  property var  config:    null
  property var  colors:    null

  readonly property var _effectiveColors: colors

  // Cores do painel — lidas do config quando disponível, fallback hardcoded
  readonly property color colorBg:         config ? config.palettePanelBg                            : "#1e1e2e"
  readonly property color colorSidebar:    config ? Qt.darker(config.palettePanelBg, 1.18)           : "#181825"
  readonly property color colorSubbar:     config ? Qt.darker(config.palettePanelBg, 1.08)           : "#1a1a2a"
  readonly property color colorText:       config ? config.paletteText                               : "#cdd6f4"
  readonly property color colorTextDim:    config ? config.paletteTextDim                            : "#6c7086"
  readonly property color colorAccent:     config ? config.paletteAccent                             : "#cba6f7"
  readonly property color colorDivider:    config ? config.paletteDivider                            : "#313244"
  readonly property color colorProgressBg: config ? config.paletteProgressBg                         : "#313244"
  readonly property color colorSuccess:    _effectiveColors ? _effectiveColors.tertiary              : "#a6e3a1"
  readonly property color colorError:      _effectiveColors ? _effectiveColors.error                 : "#f38ba8"
  readonly property color colorSideline:   config ? config.paletteAccent                             : "#cba6f7"

  signal closeRequested()

  // ── Geometria ─────────────────────────────────────────────────────────
  readonly property int winW: 920
  readonly property int winH: 640

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

  // ── Animação ──────────────────────────────────────────────────────────
  property real _anim:    0.0
  property bool _alive:   false
  property bool _closing: false

  onPanelOpenChanged: {
    if (panelOpen) {
      _closing = false; _alive = true
      _unmapTimer.stop(); _safetyTimer.stop(); closeAnim.stop()
      openAnim.from = _anim; openAnim.to = 1.0; openAnim.start()
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

  HyprlandFocusGrab {
    windows: [win]; active: win.panelOpen
    onCleared: win.closeRequested()
  }

  // ── Navegação ─────────────────────────────────────────────────────────
  property int activeModule: 0
  property var subtabState:  ({})

  function subtab(mod) { return subtabState[mod] !== undefined ? subtabState[mod] : 0 }
  function setSubtab(mod, idx) {
    var o = {}
    for (var k in subtabState) o[k] = subtabState[k]
    o[mod] = idx
    subtabState = o
  }

  // Definição dos módulos e suas subabas
  readonly property var modules: [
    { id: "bar",        icon: "\uf0c9", label: "Barra",
      subtabs: ["Geral", "Módulos", "Workspaces", "Mídia", "Relógio", "Volume", "Config Rápida", "Notificações", "Paleta"] },
    { id: "wallpaper",  icon: "\uf03e", label: "Wallpaper",
      subtabs: ["Wallpaper", "Matugen", "Perfis", "Histórico", "Schedule"] },
    { id: "widgets",    icon: "\uf2d2", label: "Widgets",    subtabs: [] },
    { id: "dmenu",      icon: "\uf0ca", label: "Dmenu",      subtabs: [] },
    { id: "screenlock", icon: "\uf023", label: "Screenlock", subtabs: [] },
  ]

  // ── Flash de salvo ────────────────────────────────────────────────────
  property bool _savedFlash: false
  Timer { id: _savedTimer; interval: 1800; repeat: false; onTriggered: win._savedFlash = false }

  // Chamado pelos tabs ao mudar qualquer prop de módulo
  function applyChange(opts) {
    if (!config) return
    config.set(opts.moduleId, opts.key, opts.value, opts.style || null)
    _savedFlash = true; _savedTimer.restart()
  }

  // Chamado pelos tabs ao mudar props estruturais (tema, posição, módulos)
  function applyStructural(opts) {
    if (!config) return
    config.saveAll(opts)
    _savedFlash = true; _savedTimer.restart()
  }

  // Props comuns passadas a todos os tabs
  readonly property var _tabProps: ({
    config:          win.config,
    overlay:         popupOverlay,
    colors:          win._effectiveColors,
    colorAccent:     win.colorAccent,
    colorTextDim:    win.colorTextDim,
    colorText:       win.colorText,
    colorDivider:    win.colorDivider,
    colorSidebar:    win.colorSidebar,
    colorProgressBg: win.colorProgressBg,
    colorError:      win.colorError,
  })

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════
  Rectangle {
    id: mainRect
    anchors.fill: parent; radius: 16; clip: true
    opacity:   Math.min(1.0, win._anim * 1.4)
    transform: Translate { y: 12 * (1.0 - win._anim) }
    color:     Qt.rgba(win.colorBg.r, win.colorBg.g, win.colorBg.b, 0.97)
    border.color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.5)
    border.width: 1

    RowLayout {
      anchors.fill: parent; spacing: 0

      // ── Sidebar ──────────────────────────────────────────────────────
      Rectangle {
        Layout.preferredWidth: 148
        Layout.fillHeight:     true
        color:                 win.colorSidebar

        // Canto direito quadrado para colar no conteúdo
        Rectangle {
          anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
          width: 12; color: parent.color
        }

        ColumnLayout {
          anchors { fill: parent; topMargin: 16; bottomMargin: 12 }
          spacing: 0

          // Logo / título
          Row {
            Layout.leftMargin: 16; Layout.bottomMargin: 16; spacing: 8
            Text { text: "\uf013"; color: win.colorAccent; font.pixelSize: 16
              font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Configurações"; color: win.colorText; font.pixelSize: 12
              font.weight: Font.SemiBold; anchors.verticalCenter: parent.verticalCenter }
          }

          // Divisor
          Rectangle { Layout.fillWidth: true; height: 1; Layout.leftMargin: 12; Layout.rightMargin: 12
            color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.5)
            Layout.bottomMargin: 8 }

          // Itens de módulo
          Repeater {
            model: win.modules
            delegate: Item {
              required property var modelData
              required property int index
              Layout.fillWidth: true; height: 38
              readonly property bool active: win.activeModule === index

              Rectangle {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 2; bottomMargin: 2 }
                radius: 8
                color: parent.active
                  ? Qt.rgba(win.colorAccent.r, win.colorAccent.g, win.colorAccent.b, 0.15)
                  : mhov.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                // Linha lateral de acento
                Rectangle {
                  anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
                  width: 3; radius: 2
                  color: win.colorAccent
                  opacity: parent.parent.active ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Row {
                  anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                  spacing: 10
                  Text {
                    text: parent.parent.parent.modelData.icon
                    color: parent.parent.parent.active ? win.colorAccent : win.colorTextDim
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                  Text {
                    text: parent.parent.parent.modelData.label
                    color: parent.parent.parent.active ? win.colorText : win.colorTextDim
                    font.pixelSize: 11; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                }
              }
              MouseArea { id: mhov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: win.activeModule = index }
            }
          }

          Item { Layout.fillHeight: true }

          // Indicador de salvo
          Rectangle {
            Layout.fillWidth: true; height: 28
            Layout.leftMargin: 8; Layout.rightMargin: 8; radius: 8
            visible: win._savedFlash
            color:   Qt.rgba(win.colorSuccess.r, win.colorSuccess.g, win.colorSuccess.b, 0.12)
            border.color: Qt.rgba(win.colorSuccess.r, win.colorSuccess.g, win.colorSuccess.b, 0.3)
            border.width: 1
            Row { anchors.centerIn: parent; spacing: 6
              Text { text: "\uf00c"; color: win.colorSuccess; font.pixelSize: 9
                font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Salvo"; color: win.colorSuccess; font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter }
            }
          }

          // Botão fechar
          Item {
            Layout.fillWidth: true; height: 34; Layout.topMargin: 4

            Rectangle {
              anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
              radius: 8
              color: closeHov.containsMouse ? Qt.rgba(win.colorError.r, win.colorError.g, win.colorError.b, 0.15)
                                            : Qt.rgba(1,1,1,0.03)
              border.color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.4)
              border.width: 1
              Behavior on color { ColorAnimation { duration: 100 } }

              Row { anchors.centerIn: parent; spacing: 8
                Text { text: "\uf00d"; color: closeHov.containsMouse ? win.colorError : win.colorTextDim
                  font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter
                  Behavior on color { ColorAnimation { duration: 100 } } }
                Text { text: "Fechar"; color: closeHov.containsMouse ? win.colorError : win.colorTextDim
                  font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                  Behavior on color { ColorAnimation { duration: 100 } } }
              }
            }
            MouseArea { id: closeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: win.closeRequested() }
          }
        }
      }

      // ── Área principal ────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

        // Barra de subabas
        Rectangle {
          Layout.fillWidth: true; height: 44
          color: win.colorSubbar

          // Canto superior direito arredondado
          Rectangle {
            anchors { top: parent.top; right: parent.right }
            width: 16; height: 16; color: win.colorSubbar
            Rectangle { anchors.fill: parent; radius: 16; color: win.colorBg }
          }

          RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
            spacing: 0

            // Subabas do módulo ativo
            Repeater {
              model: win.activeModule < win.modules.length
                     ? win.modules[win.activeModule].subtabs : []
              delegate: Item {
                required property string modelData
                required property int    index
                readonly property bool   active: win.subtab(win.activeModule) === index
                height: 44
                width:  stLbl.implicitWidth + 24

                // Underline de acento
                Rectangle {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                  height: 2; radius: 1; color: win.colorAccent
                  opacity: parent.active ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                  id: stLbl; anchors.centerIn: parent; text: parent.modelData
                  font.pixelSize: 11; font.weight: parent.active ? Font.SemiBold : Font.Normal
                  color: parent.active ? win.colorText : win.colorTextDim
                  Behavior on color { ColorAnimation { duration: 80 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: win.setSubtab(win.activeModule, index) }
              }
            }

            Item { Layout.fillWidth: true }

            // Botão Padrão (só para barra)
            Rectangle {
              visible: win.activeModule === 0
              height: 28; width: rstLbl.implicitWidth + 18; radius: 6
              color: rstHov.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
              border.color: Qt.rgba(1,1,1,0.1); border.width: 1
              Behavior on color { ColorAnimation { duration: 80 } }
              Row { anchors.centerIn: parent; spacing: 6
                Text { text: "\uf0e2"; color: win.colorTextDim; font.pixelSize: 10
                  font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                Text { id: rstLbl; text: "Padrão"; color: win.colorTextDim; font.pixelSize: 10
                  anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: rstHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!win.config) return
                  win.config.saveAll({
                    theme: "Pill", position: 3, autoHide: true, silence: false,
                    barSize: 30, barMargin: 3, pillWidth: 400, pillMinSpacing: 20,
                    modulesLeft:   ["mediaplayer","separator","quicksettings"],
                    modulesCenter: ["workspaces"],
                    modulesRight:  ["clock","separator","volume","separator","notifications"],
                    modulesTop:    ["mediaplayer","separator","quicksettings"],
                    modulesMiddle: ["workspaces"],
                    modulesBottom: ["clock","separator","volume","separator","notifications"],
                  })
                  win._savedFlash = true; _savedTimer.restart()
                }
              }
            }
          }

          // Divisor inferior
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1
            color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.4) }
        }

        // ── Conteúdo dos tabs ───────────────────────────────────────────
        Item {
          Layout.fillWidth: true; Layout.fillHeight: true

          // ── BARRA ───────────────────────────────────────────────────
          // Subtab 0: Geral
          Loader {
            id: loaderGeral
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 0
            sourceComponent: Component {
              Tabs.BarTabGeral {
                id: tabGeral
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderGeral.item
              function onStructuralChange(opts) { win.applyStructural(opts) }
            }
          }

          // Subtab 1: Módulos
          Loader {
            id: loaderModulos
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 1
            sourceComponent: Component {
              Tabs.BarTabModulos {
                id: tabModulos
                isH: win.config ? (win.config["position"] === 1 || win.config["position"] === 3) : true
                slotLeft:   win.config ? (win.config["modulesLeft"]   || []) : []
                slotCenter: win.config ? (win.config["modulesCenter"] || []) : []
                slotRight:  win.config ? (win.config["modulesRight"]  || []) : []
                slotTop:    win.config ? (win.config["modulesTop"]    || []) : []
                slotMiddle: win.config ? (win.config["modulesMiddle"] || []) : []
                slotBottom: win.config ? (win.config["modulesBottom"] || []) : []
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
              }
            }
            Connections {
              target: loaderModulos.item
              function onSlotChanged(slot, arr) {
                var opts = {}
                var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
                opts[key] = arr
                win.applyStructural(opts)
              }
              function onModuleAdded(slot, id) {
                if (!win.config) return
                var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
                var opts = {}
                opts[key] = (win.config[key] || []).concat([id])
                win.applyStructural(opts)
              }
            }
          }

          // Subtab 2: Workspaces
          Loader {
            id: loaderWorkspaces
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 2
            sourceComponent: Component {
              Tabs.BarTabWorkspaces {
                id: tabWorkspaces
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderWorkspaces.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 3: Mídia
          Loader {
            id: loaderMidia
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 3
            sourceComponent: Component {
              Tabs.BarTabMidia {
                id: tabMidia
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderMidia.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 4: Relógio
          Loader {
            id: loaderClock
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 4
            sourceComponent: Component {
              Tabs.BarTabClock {
                id: tabClock
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderClock.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 5: Volume
          Loader {
            id: loaderVolume
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 5
            sourceComponent: Component {
              Tabs.BarTabVolume {
                id: tabVolume
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderVolume.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 6: Config Rápida
          Loader {
            id: loaderQuickSettings
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 6
            sourceComponent: Component {
              Tabs.BarTabQuickSettings {
                id: tabQuickSettings
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderQuickSettings.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 7: Notificações
          Loader {
            id: loaderNotifications
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 7
            sourceComponent: Component {
              Tabs.BarTabNotifications {
                id: tabNotifications
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderNotifications.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // Subtab 8: Paleta
          Loader {
            id: loaderPaleta
            anchors.fill: parent
            active: win.activeModule === 0 && win.subtab(0) === 8
            sourceComponent: Component {
              Tabs.BarTabPaleta {
                id: tabPaleta
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderPaleta.item
              function onChanged(opts) { win.applyChange(opts) }
            }
          }

          // ── WALLPAPER ────────────────────────────────────────────────
          Loader {
            id: loaderWallpaper
            anchors.fill: parent
            active: win.activeModule === 1
            sourceComponent: Component {
              Tabs.TabWallpaper {
                panelOpen:       win.panelOpen && win.activeModule === 1
                activeSubtab:    win.subtab(1)
                colorAccent:     win.colorAccent
                colorTextDim:    win.colorTextDim
                colorText:       win.colorText
                colorDivider:    win.colorDivider
              }
            }
          }

          // ── Placeholder para módulos ainda não implementados ─────────
          Loader {
            anchors.fill: parent
            active: win.activeModule > 1
            sourceComponent: Item {
              Column {
                anchors.centerIn: parent; spacing: 14
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: win.activeModule < win.modules.length
                        ? win.modules[win.activeModule].icon : "\uf013"
                  color: Qt.rgba(win.colorTextDim.r, win.colorTextDim.g, win.colorTextDim.b, 0.18)
                  font.pixelSize: 48; font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: win.activeModule < win.modules.length
                        ? win.modules[win.activeModule].label + " — Em desenvolvimento"
                        : "Em desenvolvimento"
                  color: Qt.rgba(win.colorTextDim.r, win.colorTextDim.g, win.colorTextDim.b, 0.3)
                  font.pixelSize: 13
                }
              }
            }
          }
        }
      }
    }
  }

  // Overlay para CfgPalette e outros popups que precisam escapar do clip
  Item {
    id: popupOverlay
    anchors.fill: parent
    z: 100
  }
}
