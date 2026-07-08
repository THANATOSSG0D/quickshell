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
//     configBar:        bar.configRef       // BarConfig da barra
//     configDock:       dockBar.configRef   // BarConfig da dock (opcional)
//     colors:           Colors
//     onCloseRequested: configOpen = false
//   }
//
// Um seletor "Barra/Dock" aparece na seção "Barra" sempre que configDock
// for passado — ele só troca qual BarConfig está "ativo" (win.config).
// Os tabs continuam recebendo `config` (= win.config) e `colors` como
// antes e usam config.get/set — nenhum tab precisou mudar.

PanelWindow {
  id: win

  // ── API pública ───────────────────────────────────────────────────────
  property bool panelOpen: false
  // Duas configs independentes — uma por instância (Bar / Dock). Cada uma
  // é um BarConfig próprio (ver Bar.qml/BarState.qml), então editar uma
  // NUNCA mexe na outra. `config` (usado por todos os tabs abaixo, sem
  // precisar mudar nada neles) é sempre a config do alvo ativo.
  property var  configBar:   null
  property var  configDock:  null
  // Config dos POPUPS (PopupConfig) — uma por instância, separada da Bar/Dock
  // acima (config). Repassada direto pra aba "Painéis", que tem seu próprio
  // seletor Barra/Dock interno (não usa win.activeTarget — são telas
  // diferentes, editar módulos da Dock não deveria forçar a olhar pros
  // popups da Dock também, e vice-versa).
  property var  popupConfigBar:  null
  property var  popupConfigDock: null
  property var  colors:      null
  property var  dmenuConfig: null   // DmenuConfig instanciado em DmenuIpc

  // "bar" ou "dock" — qual das duas está sendo editada agora
  property string activeTarget: "bar"
  readonly property var config: activeTarget === "dock" ? configDock : configBar

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

  // ── SISTEMA DE CONTRATO ──────────────────────────────────────────────────
  // Cada tema declara o que suporta num JSON de contrato em:
  //   bar/themes/<Tema>.contract.json
  // Carregado via FileView+JsonAdapter (XHR local é bloqueado pelo Qt).
  // Fail-open: se o arquivo não existir ou falhar, _contract fica {} e
  // tudo fica visível — nunca esconde algo por engano.
  property var _contract: ({})

  FileView {
    id: contractFile
    path: win.config
          ? (Quickshell.shellDir + "/modules/default/bar/themes/"
             + (win.config["theme"] || "") + ".contract.json")
          : ""
    watchChanges: false
    onLoaded: {
      try { win._contract = JSON.parse(text()) }
      catch(e) { win._contract = {} }
    }
    onLoadFailed: { win._contract = {} }
  }

  function _loadContract(themeName) {
    // Só atualiza o path — o FileView reage automaticamente via onPathChanged
    // (não precisa fazer nada aqui, mantido por compatibilidade com onConfigChanged)
    if (!themeName) win._contract = {}
  }

  function contractBar(key)     { var c = win._contract; return !c.bar     || !!c.bar[key] }
  function contractPalette(key) { var c = win._contract; return !c.palette || !!c.palette[key] }
  function contractModule(id)   {
    if (!id) return true          // null = sub-aba estrutural (Geral/Barra/Módulos) → sempre visível
    var c = win._contract
    if (!c.modules) return true   // sem contrato carregado → fail-open
    return c.modules.indexOf(id) !== -1
  }
  function subtab(mod) { return subtabState[mod] !== undefined ? subtabState[mod] : 0 }
  function setSubtab(mod, idx) {
    var o = {}
    for (var k in subtabState) o[k] = subtabState[k]
    o[mod] = idx
    subtabState = o
  }

  // Definição dos módulos e suas subabas
  readonly property var _allModules: [
    { id: "bar",        icon: "\uf0c9", label: "Barra",
      subtabs: ["Geral", "Barra", "Módulos", "Workspaces", "Mídia", "Relógio", "Volume", "Config Rápida", "Notificações"] },
    { id: "dock",       icon: "\uf2d1", label: "Dock",
      subtabs: ["Geral", "Barra", "Módulos", "Workspaces", "Mídia", "Relógio", "Volume", "Config Rápida", "Notificações"] },
    { id: "wallpaper",  icon: "\uf03e", label: "Wallpaper",
      subtabs: ["Wallpaper", "Matugen", "Perfis", "Histórico", "Schedule"] },
    { id: "paineis",    icon: "\uf2d2", label: "Painéis",
      subtabs: ["Global", "Volume", "Config Rápida", "Mídia", "Relógio", "Notificações", "Dmenu", "Editor"] },
    { id: "widgets",    icon: "\uf521", label: "Widgets",    subtabs: ["Relógio"] },
    { id: "screenlock", icon: "\uf023", label: "Screenlock", subtabs: [] },
  ]

  // A aba "Dock" só existe quando o shell.qml de fato passou uma config de
  // Dock (configDock !== null) — do contrário, fica igual a antes.
  readonly property var modules: win.configDock !== null
    ? win._allModules
    : win._allModules.filter(function(m) { return m.id !== "dock" })

  // Se o Dock desaparecer (ex: configDock virou null em runtime) enquanto
  // estava selecionado, ou o índice ficar fora da faixa, volta pra "Barra".
  onModulesChanged: {
    if (win.activeModule >= win.modules.length) win.activeModule = 0
  }

  // id do módulo atualmente selecionado — usar isto em vez de comparar
  // "activeModule === <índice fixo>" em qualquer lugar, já que a posição
  // de cada módulo na lista pode mudar (ex: Dock aparecendo/sumindo).
  readonly property string _activeId: win.activeModule < win.modules.length
    ? win.modules[win.activeModule].id : ""

  // "bar" e "dock" compartilham exatamente as mesmas sub-abas/telas — a
  // diferença entre eles é só qual BarConfig (`config`) está ativo.
  readonly property bool _isBarSection: win._activeId === "bar" || win._activeId === "dock"

  // ── Sub-abas condicionais (seção Barra/Dock) ────────────────────────────
  // Cada sub-aba abaixo de índice 3 (Workspaces em diante) só faz sentido
  // se o TEMA ATIVO de fato usa aquele módulo em algum dos 6 slots
  // (left/center/right/top/middle/bottom). Sub-abas estruturais (Geral,
  // Barra, Módulos) sempre aparecem — null = sempre visível.
  readonly property var _barSubtabModule: [
    null,              // 0 Geral         → sempre visível
    null,              // 1 Barra+Paleta  → sempre visível
    null,              // 2 Módulos       → sempre visível
    "workspaces",      // 3 Workspaces
    "mediaplayer",     // 4 Mídia
    "clock",           // 5 Relógio
    "volume",          // 6 Volume
    "quicksettings",   // 7 Config Rápida
    "notifications",   // 8 Notificações
  ]

  // Delega ao contrato do tema ativo
  function _barModuleInUse(moduleId) {
    return win.contractModule(moduleId)
  }

  // true/false por índice de sub-aba do módulo "bar" — usado tanto pelo
  // Repeater que desenha os botões quanto pelo botão "Padrão/Limpar override"
  function barSubtabVisible(idx) {
    return _barModuleInUse(_barSubtabModule[idx])
  }

  // Se a sub-aba selecionada ficar oculta (ex: trocou de tema e o módulo
  // sumiu de todos os slots), redireciona pra "Geral" pra não deixar o
  // usuário olhando pra um painel em branco.
  onConfigChanged: {
    contractFile.reload()
    if (win._isBarSection && !win.barSubtabVisible(win.subtab(win.activeModule))) {
      win.setSubtab(win.activeModule, 0)
    }
  }

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
              font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
          }

          // Divisor
          Rectangle { Layout.fillWidth: true; height: 1; Layout.leftMargin: 12; Layout.rightMargin: 12
            color: Qt.rgba(win.colorDivider.r, win.colorDivider.g, win.colorDivider.b, 0.5)
            Layout.bottomMargin: 8 }

          // Itens de módulo
          Repeater {
            model: win.modules
            delegate: Item {
              id: modDel
              required property var modelData
              required property int index
              Layout.fillWidth: true; height: 38
              readonly property bool active: win.activeModule === index

              Rectangle {
                id: modBg
                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 2; bottomMargin: 2 }
                radius: 8
                color: modDel.active
                  ? Qt.rgba(win.colorAccent.r, win.colorAccent.g, win.colorAccent.b, 0.15)
                  : mhov.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                // Linha lateral de acento
                Rectangle {
                  anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
                  width: 3; radius: 2
                  color: win.colorAccent
                  opacity: modDel.active ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Row {
                  anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                  spacing: 10
                  Text {
                    text: modDel.modelData.icon
                    color: modDel.active ? win.colorAccent : win.colorTextDim
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                  Text {
                    text: modDel.modelData.label
                    color: modDel.active ? win.colorText : win.colorTextDim
                    font.pixelSize: 11; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                }
              }
              MouseArea { id: mhov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  win.activeModule = index
                  if (modDel.modelData.id === "bar")  win.activeTarget = "bar"
                  if (modDel.modelData.id === "dock") win.activeTarget = "dock"
                }
              }
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
                id: stDel
                required property string modelData
                required property int    index
                readonly property bool   active: win.subtab(win.activeModule) === index
                // Só a seção Barra/Dock tem sub-abas condicionais por tema;
                // os outros módulos (Wallpaper, Painéis...) sempre mostram tudo.
                visible: !win._isBarSection || win.barSubtabVisible(index)
                height: visible ? 44 : 0
                width:  visible ? (stLbl.implicitWidth + 24) : 0

                // Underline de acento
                Rectangle {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                  height: 2; radius: 1; color: win.colorAccent
                  opacity: stDel.active ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                  id: stLbl; anchors.centerIn: parent; text: stDel.modelData
                  font.pixelSize: 11; font.weight: stDel.active ? Font.DemiBold : Font.Normal
                  color: stDel.active ? win.colorText : win.colorTextDim
                  Behavior on color { ColorAnimation { duration: 80 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: win.setSubtab(win.activeModule, index) }
              }
            }

            Item { Layout.fillWidth: true }

            // Botão Padrão — comportamento por subtab
            Rectangle {
              id: rstBtn
              // "estrutural"  → subtabs Geral/Barra/Módulos: o saveAll() de reset faz sentido
              // <moduleId>    → módulo real (clearModule isolado por aba)
              readonly property string _mode: {
                if (!win._isBarSection) return ""
                var st = win.subtab(win.activeModule)
                var m = win._barSubtabModule[st]
                return (m !== undefined && m !== null) ? m : "estrutural"
              }
              readonly property string _moduleId: (_mode !== "estrutural") ? _mode : ""
              readonly property string _label: (_mode === "estrutural") ? "Padrão" : "Limpar override"

              visible: win._isBarSection
              height: 28; width: rstLbl.implicitWidth + 18; radius: 6
              color: rstHov.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
              border.color: Qt.rgba(1,1,1,0.1); border.width: 1
              Behavior on color { ColorAnimation { duration: 80 } }
              Row { anchors.centerIn: parent; spacing: 6
                Text { text: "\uf0e2"; color: win.colorTextDim; font.pixelSize: 10
                  font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                Text { id: rstLbl; text: rstBtn._label; color: win.colorTextDim; font.pixelSize: 10
                  anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: rstHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!win.config) return
                  var modId = rstBtn._moduleId
                  if (modId !== "") {
                    // Limpa overrides do módulo desta aba → paleta global volta a valer
                    win.config.clearModule(modId)
                  } else {
                    // Geral / Módulos → reset estrutural. Defaults diferentes
                    // conforme o alvo ativo (Barra cheia vs Dock flutuante).
                    // (Paleta nunca chega aqui: o botão fica oculto nessa aba)
                    if (win.activeTarget === "dock") {
                      win.config.saveAll({
                        theme: "Dock", position: 3, autoHide: true, silence: false, alwaysVisible: false, pinned: false, floating: false,
                        tooltipEnabled: true, tooltipMinWidth: 160, tooltipMaxWidth: 320, tooltipAlign: "module", tooltipOffset: 0,
                        barSize: 30, barMargin: 8, pillWidth: 400, pillMinSpacing: 20,
                        modulesLeft:   [],
                        modulesCenter: ["workspaces"],
                        modulesRight:  [],
                        modulesTop:    [],
                        modulesMiddle: ["workspaces"],
                        modulesBottom: [],
                      })
                    } else {
                      win.config.saveAll({
                        theme: "Pill", position: 3, autoHide: true, silence: false, alwaysVisible: false, pinned: false, floating: false,
                        tooltipEnabled: true, tooltipMinWidth: 160, tooltipMaxWidth: 320, tooltipAlign: "module", tooltipOffset: 0,
                        barSize: 30, barMargin: 3, pillWidth: 400, pillMinSpacing: 20,
                        modulesLeft:   ["mediaplayer","separator","quicksettings"],
                        modulesCenter: ["workspaces"],
                        modulesRight:  ["clock","separator","volume","separator","notifications"],
                        modulesTop:    ["mediaplayer","separator","quicksettings"],
                        modulesMiddle: ["workspaces"],
                        modulesBottom: ["clock","separator","volume","separator","notifications"],
                      })
                    }
                  }
                  win._savedFlash = true; _savedTimer.restart()
                }
              }
            }

            // Botão Limpar (só para painéis, subtabs 0–7)
            Rectangle {
              visible: win._activeId === "paineis" && win.subtab(win.activeModule) <= 7
              height: 28; width: clrLbl.implicitWidth + 18; radius: 6
              color: clrHov.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
              border.color: Qt.rgba(1,1,1,0.1); border.width: 1
              Behavior on color { ColorAnimation { duration: 80 } }
              Row { anchors.centerIn: parent; spacing: 6
                Text { text: "\uf0e2"; color: win.colorTextDim; font.pixelSize: 10
                  font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                Text { id: clrLbl
                  text: win.subtab(win.activeModule) === 0 ? "Limpar global" : "Limpar override"
                  color: win.colorTextDim; font.pixelSize: 10
                  anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: clrHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (loaderPaineis.item) loaderPaineis.item.resetCurrent()
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
            active: win._isBarSection && win.subtab(win.activeModule) === 0
            sourceComponent: Component {
              Tabs.BarTabGeral {
                id: tabGeral
                config: win.config; 
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderGeral.item
              // BarTabGeral emite "changed", não "structuralChange" — rotear para applyStructural
              function onChanged(opts) { win.applyStructural(opts) }
            }
          }

          // Subtab 1: Barra (dimensões: barSize, barMargin, pillWidth,
          // pillMinSpacing) + Paleta (fundida na mesma aba/scroll — eram
          // duas abas separadas antes, mas o conteúdo é sempre editado
          // junto na prática, então faz mais sentido viver no mesmo lugar)
          Loader {
            id: loaderBarTabBar
            anchors.fill: parent
            active: win._isBarSection && win.subtab(win.activeModule) === 1
            sourceComponent: Component {
              Tabs.BarTabBar {
                id: tabBar
                config: win.config; overlay: popupOverlay; colors: win._effectiveColors
                contract: win._contract
                colorAccent: win.colorAccent; colorTextDim: win.colorTextDim
                colorText: win.colorText; colorDivider: win.colorDivider
                colorSidebar: win.colorSidebar; colorProgressBg: win.colorProgressBg
              }
            }
            Connections {
              target: loaderBarTabBar.item
              // BarTabBar agora emite dois formatos de opts: campos soltos
              // de "bar" (ex: {barSize:v}) vão por applyStructural; campos
              // de "palette" (ex: {moduleId:"palette",key,value}) vão por
              // applyChange — distinguimos pela presença de moduleId.
              function onChanged(opts) {
                if (opts.moduleId) win.applyChange(opts)
                else win.applyStructural(opts)
              }
            }
          }

          // Subtab 2: Módulos
          Loader {
            id: loaderModulos
            anchors.fill: parent
            active: win._isBarSection && win.subtab(win.activeModule) === 2
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
            active: win._isBarSection && win.subtab(win.activeModule) === 3
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
            active: win._isBarSection && win.subtab(win.activeModule) === 4
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
            active: win._isBarSection && win.subtab(win.activeModule) === 5
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
            active: win._isBarSection && win.subtab(win.activeModule) === 6
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
            active: win._isBarSection && win.subtab(win.activeModule) === 7
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
            active: win._isBarSection && win.subtab(win.activeModule) === 8
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

          // ── WALLPAPER ────────────────────────────────────────────────
          Loader {
            id: loaderWallpaper
            anchors.fill: parent
            active: win._activeId === "wallpaper"
            sourceComponent: Component {
              Tabs.TabWallpaper {
                panelOpen:       win.panelOpen && win._activeId === "wallpaper"
                activeSubtab:    win.subtab(win.activeModule)
                colorAccent:     win.colorAccent
                colorTextDim:    win.colorTextDim
                colorText:       win.colorText
                colorDivider:    win.colorDivider
              }
            }
          }

          // ── PAINÉIS ──────────────────────────────────────────────────
          Loader {
            id: loaderPaineis
            anchors.fill: parent
            active: win._activeId === "paineis"
            sourceComponent: Component {
              Tabs.PanelTab {
                activeSubtab:    win.subtab(win.activeModule)
                overlay:         popupOverlay
                colors:          win._effectiveColors
                colorAccent:     win.colorAccent
                colorTextDim:    win.colorTextDim
                colorText:       win.colorText
                colorDivider:    win.colorDivider
                colorSidebar:    win.colorSidebar
                colorProgressBg: win.colorProgressBg
                dmenuConfig:     win.dmenuConfig
                popupConfigBar:  win.popupConfigBar
                popupConfigDock: win.popupConfigDock
              }
            }
          }

          // ── WIDGETS ──────────────────────────────────────────────────
          Loader {
            id: loaderWidgets
            anchors.fill: parent
            active: win._activeId === "widgets"
            sourceComponent: Component {
              Tabs.WidgetsTab {
                activeSubtab:    win.subtab(win.activeModule)
                overlay:         popupOverlay
                colors:          win._effectiveColors
                colorAccent:     win.colorAccent
                colorTextDim:    win.colorTextDim
                colorText:       win.colorText
                colorDivider:    win.colorDivider
                colorSidebar:    win.colorSidebar
                colorProgressBg: win.colorProgressBg
              }
            }
          }

          // ── Placeholder para módulos ainda não implementados ─────────
          Loader {
            anchors.fill: parent
            active: win._activeId === "screenlock"
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
