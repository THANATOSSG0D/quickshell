import Quickshell
import QtQuick
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
import "../../dmenu" as DmenuModule
import "../../tasks" as TasksModule
import "../../quicksettings" as QsModule
import "../../notifications" as NotifModule

// ════════════════════════════════════════════════════════════════════════
// BENTO — cada módulo, sua própria pílula.
//
// Em vez de um fundo por grupo (Dock) ou um fundo único pra barra inteira
// (Aurora/Default), aqui CADA módulo individual (workspaces, relógio,
// quicksettings, etc.) ganha a própria pílula cheia, preta, sem borda —
// flutuando com pequenos vãos entre si. Os módulos "separator"/"spacer"
// ficam nus (sem pílula), servindo só de respiro/divisor entre os chips.
//
// Inspirado em rices estilo AGS/eww onde cada informação do topbar é um
// "chip" solto — workspaces inteiros numa pílula (o destaque do workspace
// ativo já é tratado pelo próprio módulo Workspaces.qml via
// cfgWsBgColorActive/cfgWsBgRadiusActive, configurável na aba normal — o
// tema não precisa fazer nada especial pra isso), relógio em outra pílula,
// quicksettings (que já junta wifi/bluetooth/bateria) em outra.
//
// pill = false — como os outros temas não-Pill, a janela ocupa a tela
// inteira; aqui não há "ilha por slot" nem "barra única" — são N pílulas
// soltas, uma por módulo.
//
// Diferença de implementação importante: como cada módulo agora vive
// dentro de um wrapper próprio (chipWrap) em vez de ser direto o item do
// Repeater, o _findRef precisa de um pequeno ajuste — chipWrap expõe uma
// property "item" que espelha o Loader interno, então _findRef continua
// funcionando exatamente igual (sem precisar mudar a lógica em si).
//
// Como em todos os outros temas da família, toda a parte de configuração
// (cfgWs*/cfgMp*/cfgVol*/cfgQs*/cfgNotif*/cfgClk*, moduleItemComp) é
// mantida idêntica.
// ════════════════════════════════════════════════════════════════════════

Item {
  id: root
  anchors.fill: parent   // tema estático (não-pill) — ocupa toda a PanelWindow

  // ── Layout (lido pelo Bar.qml) ─────────────────────────────────────────
  property int    barSize:       32
  property int    barMargin:     6
  property bool   pill:          false
  property int    panelWidth:    400
  property string monitorName:   ""
  property bool   hasMediaPanel: true
  property int    barPosition:   2

  // ── Props de compatibilidade com o contrato do Pill (não usadas aqui —
  // ver explicação completa no Dock.qml) ─────────────────────────────────
  property int  minPillWidth:   400
  property int  pillMinSpacing: 20

  signal sinkPanelRequested()
  signal sourcePanelRequested()
  signal clockPanelRequested()
  signal dmenuRequested()
  signal tasksPanelRequested()
  signal quickSettingsPanelRequested()
  signal notificationsPanelRequested()
  signal mediaPlayerClicked()
  signal refsUpdated()

  property var mediaPlayer:   null
  property var volumeWidget:  null
  property var sinkWidget:    null
  property var sourceWidget:  null
  property var clock:         null
  property var dmenu:         null
  property var tasks:         null
  property var notifWidget:   null
  property var qsWidget:      null

  // Refs dos grupos de módulos (Row/Column por slot) — usados por
  // popupXAlign:"group"/"module" pra calcular onde os popups devem nascer.
  property var leftGroupItem:   null
  property var rightGroupItem:  null
  property var topGroupItem:    null
  property var bottomGroupItem: null

  property var notifService: null

  readonly property bool isHorizontal: barPosition === 1 || barPosition === 3

  property var cfgModulesLeft:   []
  property var cfgModulesCenter: []
  property var cfgModulesRight:  []
  property var cfgModulesTop:    []
  property var cfgModulesMiddle: []
  property var cfgModulesBottom: []

  // ── Configs workspaces ─────────────────────────────────────────────────
  property string cfgWsStyle:               "icons"
  property string cfgWsIconsSort:           "position"
  property bool   cfgWsIconMonochrome:      true
  property int    cfgWsIconSpacing:         4
  property int    cfgWsIconSize:            18
  property bool   cfgWsShowNumber:          false
  property real   cfgWsBgOpacity:           0.0
  property real   cfgWsBgPaddingH:          8
  property real   cfgWsBgPaddingV:          2
  property real   cfgWsBgBorderWidth:       0
  property int    cfgWsDotSize:             8
  property int    cfgWsFontSize:            10
  property bool   cfgWsNumberBgEnabled:     false
  property int    cfgWsNumberBgRadius:      4
  property int    cfgWsNumberBgPaddingH:    4
  property int    cfgWsNumberBgPaddingV:    2
  property int    cfgWsNumberSpacing:       4
  property bool   cfgWsShowAddButton:       true
  property bool   cfgWsShowTooltip:         true
  property int    cfgWsSpacing:             2
  property color  cfgWsBgColorActive:        Qt.rgba(1,1,1,0.12)
  property real   cfgWsBgOpacityActive:      0.85
  property color  cfgWsBgBorderColorActive:  "transparent"
  property real   cfgWsBgBorderWidthActive:  0
  property real   cfgWsBgPaddingHActive:     6
  property real   cfgWsBgPaddingVActive:     2
  property real   cfgWsBgRadiusActive:       99
  property string cfgWsRevealMode:           "hover"
  property int    cfgWsHoverRevealDelayMs:   0
  property string cfgWsClickCollapseMode:    "exit"
  property int    cfgWsClickRevealTimeoutMs: 2500
  property bool   cfgWsScrollEnabled:        false
  property string cfgWsScrollAction:         "workspace"
  property bool   cfgWsScrollInvert:         false
  // ── Configs workspaces — fundo grupo/ativo/inativo, animação, botão + ──
  property bool   cfgWsBgGroupEnabled:        false
  property bool   cfgWsBgActiveEnabled:       true
  property bool   cfgWsBgInactiveEnabled:     false
  property color  cfgWsBgColorInactive:       "transparent"
  property real   cfgWsBgOpacityInactive:     0.4
  property color  cfgWsBgBorderColorInactive: "transparent"
  property real   cfgWsBgBorderWidthInactive: 0
  property real   cfgWsBgPaddingHInactive:    6
  property real   cfgWsBgPaddingVInactive:    2
  property real   cfgWsBgRadiusInactive:      99
  property string cfgWsIndicatorAnimStyle:    "smooth"
  property int    cfgWsIndicatorAnimDuration: 140
  property bool   cfgWsAddButtonBorderEnabled: true
  property bool   cfgWsAddButtonBgEnabled:     false
  property real   cfgWsAddButtonBgOpacity:     1.0
  property color  cfgWsAddButtonColor:         Qt.rgba(1,1,1,0.6)
  property color  cfgWsAddButtonBgColor:       Qt.rgba(1,1,1,0.08)
  // Fonte do glifo "+" (não mais o diâmetro do botão) e padding
  // ajustável H/V até a borda do círculo — mesmo espírito do numberBg
  // em Ícones, mas calculado a partir do número (não das métricas do
  // Text), pra manter o glifo sempre centralizado como nos números.
  property int    cfgWsAddButtonSize:          13
  property int    cfgWsAddButtonPaddingH:      5
  property int    cfgWsAddButtonPaddingV:      5

  // ── Configs MediaPlayer ────────────────────────────────────────────────
  property bool   cfgMpShowText:        true
  property bool   cfgMpTextStatic:      false
  property string cfgMpTextMode:        "artistAndTitle"
  property int    cfgMpScrollSpeed:     40
  property real   cfgMpVolumeStep:      0.05
  property int    cfgMpScrollPauseMs:   1800
  property int    cfgMpScrollWidth:     140
  property int    cfgMpArtworkSize:     22
  property int    cfgMpArtworkRadius:   11
  property bool   cfgMpBgEnabled:       false
  property real   cfgMpBgOpacity:       0.5
  property real   cfgMpBgOpacityActive: 0.8
  property real   cfgMpBgPaddingH:      8
  property real   cfgMpBgPaddingV:      4
  property color  cfgMpBgColor:         Qt.rgba(1,1,1,0.08)
  property color  cfgMpBgColorActive:   Qt.rgba(1,1,1,0.15)
  property color  cfgMpTextColor:       Qt.rgba(1,1,1,1.0)
  property color  cfgMpDimColor:        Qt.rgba(1,1,1,0.5)
  property color  cfgMpTextColorActive: Qt.rgba(1,1,1,1.0)
  property color  cfgMpDimColorActive:  Qt.rgba(1,1,1,0.5)
  property string cfgMpPlayerPriority:  "spotify,ncspot,vivaldi,brave"
  property bool   cfgMpIdleInhibit:     true
  property real   cfgMpFontScale:       1.0

  // ── Configs Volume ─────────────────────────────────────────────────────
  property bool  cfgVolShowSink:    true
  property bool  cfgVolShowSource:  true
  property real  cfgVolMaxVol:      1.5
  property color cfgVolTextColor:   Qt.rgba(1,1,1,1.0)
  property color cfgVolDimColor:    Qt.rgba(1,1,1,0.5)
  property color cfgVolAccent:      Qt.rgba(1,1,1,1.0)
  property color cfgVolMuted:       "#cf6679"
  property color cfgVolProgress:    "#474747"
  property real  cfgVolFontScale:   1.0

  // ── Configs QuickSettings ──────────────────────────────────────────────
  property color cfgQsTextColor:    Qt.rgba(1,1,1,1.0)
  property color cfgQsDimColor:     Qt.rgba(1,1,1,0.5)
  property color cfgQsAccent:       Qt.rgba(1,1,1,1.0)
  property real  cfgQsFontScale:    1.0

  // ── Configs Notifications ──────────────────────────────────────────────
  property color cfgNotifTextColor: Qt.rgba(1,1,1,1.0)
  property color cfgNotifDimColor:  Qt.rgba(1,1,1,0.5)
  property color cfgNotifAccent:    Qt.rgba(1,1,1,1.0)
  property color cfgNotifMuted:     "#cf6679"
  property real  cfgNotifFontScale: 1.0

  // ── Configs Clock ──────────────────────────────────────────────────────
  property color cfgClkTextColor:    Qt.rgba(1,1,1,1.0)
  property color cfgClkDimColor:     Qt.rgba(1,1,1,0.5)
  property color cfgClkAccent:       Qt.rgba(1,1,1,1.0)
  property int   cfgClkDismissDelay: 8000
  property real  cfgClkFontScale:    1.0

  // ── Configs Dmenu ──────────────────────────────────────────────
  property color  cfgDmenuTextColor:    Qt.rgba(1,1,1,1.0)
  property color  cfgDmenuDimColor:     Qt.rgba(1,1,1,0.5)
  property color  cfgDmenuAccent:       Qt.rgba(1,1,1,1.0)
  property string cfgDmenuDisplayMode:  "title"
  property string cfgDmenuIconGlyph:    "\uf00a"
  property string cfgDmenuEmptyText:    "Desktop"
  property int    cfgDmenuTitleMaxWidth: 180
  property string cfgDmenuOpenMode:     "drun"
  property real   cfgDmenuFontScale:    1.0
  property int    cfgDmenuWindowIconSize: 18
  property bool   cfgDmenuTextStatic:     false
  property int    cfgDmenuScrollSpeed:    40
  property int    cfgDmenuScrollPauseMs:  1800
  property bool   cfgDmenuShowWorkspace:      false
  property string cfgDmenuWorkspacePosition:  "before"
  property string cfgDmenuWorkspaceFormat:    "number"
  property int    cfgDmenuWorkspaceChipWidth: 20
  property string cfgDmenuWorkspaceIconMap:   ""

  // ── Configs Tasks ────────────────────────────────────────────────────
  property color cfgTasksTextColor: Qt.rgba(1,1,1,1.0)
  property color cfgTasksDimColor:  Qt.rgba(1,1,1,0.5)
  property color cfgTasksAccent:    Qt.rgba(1,1,1,1.0)
  property real  cfgTasksFontScale: 1.0

  // ── Paleta ─────────────────────────────────────────────────────────────
  // Só barBgPill/accent são de fato pintados neste tema — barBg/text/
  // textDim/accentBg/accentText eram recebidas do Bar.qml (via _set()) mas
  // nunca consumidas em lugar nenhum, então o contract.json não expõe mais
  // seletor de cor pra elas (evita cor "fantasma" que o usuário edita e
  // não vê efeito nenhum na barra).
  property color colBarBgPill:      "#131313"
  property color colAccent:         "#ffb4a9"
  property color colWsDot:          "#e2e2e2"
  property color colWsDotActive:    "#e2e2e2"
  property color colWsDotOccupied:  "#e2e2e2"
  property color colWsDotUrgent:    "#ffb4ab"
  property color colWsBg:           "#474747"
  property color colWsBgActive:     "#2a2a2a"
  property color colWsBorder:       "#e2e2e2"
  property color colIconMono:       "#e2e2e2"
  property color colIconMonoActive: "#ffb4a9"
  property color colWsNumber:         "#9e9e9e"
  property color colWsNumberActive:   "#1a1a1a"
  property color colWsNumberBg:       "#2a2a2a"
  property color colWsNumberBgActive: "#ffb4a9"

  // ── Aparência específica do Bento (constantes de implementação, não
  // expostas no schema/editor) ────────────────────────────────────────────
  property int  chipRadius:        999    // pílula cheia — sempre clampada à altura/largura do chip
  property int  chipPad:           10     // padding ao longo do eixo principal de cada chip
  property int  chipGap:           5      // vão ENTRE chips — o "respiro" característico do visual
  property int  edgeInset:         10     // distância do 1º/último chip até a ponta da barra
  property real chipShadowOpacity: 0.15   // sombra bem sutil — esses chips são quase planos
  property int  chipShadowOffset:  2

  // ══════════════════════════════════════════════════════════════════════
  // Componente de módulo individual — idêntico em espírito ao do Pill.qml.
  // Instanciado por cada Repeater de cada ilha. Dado um modId (string),
  // ativa o Loader correto. Expõe mediaPlayer/volumeWidget/clock para a
  // ilha pai coletar.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: moduleItemComp

    Item {
      id: modItem
      property string modId:   ""
      property bool   isH:     true
      property string monName: ""

      // Contador "kicker": força a reavaliação do implicitWidth/Height
      // abaixo sempre que o módulo Workspaces redimensiona (adição/remoção
      // de workspace). Necessário porque a leitura indireta
      // "_activeLoader.item.implicitWidth" pode não criar uma dependência
      // reativa confiável através do encadeamento de property var — ver
      // Connections de wsLoader mais abaixo.
      property int _wsKick: 0

      // Refs expostas — só uma será não-nula por instância
      readonly property var mediaPlayer:  mpLoader.active  && mpLoader.item  ? mpLoader.item  : null
      readonly property var volumeWidget: volLoader.active && volLoader.item ? volLoader.item : null
      readonly property var sinkWidget:   skLoader.active  && skLoader.item  ? skLoader.item  : null
      readonly property var sourceWidget: srLoader.active  && srLoader.item  ? srLoader.item  : null
      readonly property var clock:        ckLoader.active  && ckLoader.item  ? ckLoader.item  : null
      readonly property var dmenu:        dmLoader.active  && dmLoader.item  ? dmLoader.item  : null
      readonly property var tasks:        tkLoader.active  && tkLoader.item  ? tkLoader.item  : null
      readonly property var notifWidget:  nfLoader.active  && nfLoader.item  ? nfLoader.item  : null
      readonly property var qsWidget:     qsLoader.active  && qsLoader.item  ? qsLoader.item  : null

      // Dimensões: lê do loader ativo ou usa tamanhos fixos para sep/spacer
      implicitWidth: {
        var _kick = _wsKick   // dependência explícita — ver comentário acima
        if (modId === "separator") return isH ? 1  : 16
        if (modId === "spacer")    return isH ? 12 : 1
        var l = _activeLoader
        return (l && l.item) ? l.item.implicitWidth : 0
      }
      implicitHeight: {
        var _kick = _wsKick
        if (modId === "separator") return isH ? 14 : 1
        if (modId === "spacer")    return isH ? 1  : 12
        var l = _activeLoader
        return (l && l.item) ? l.item.implicitHeight : 0
      }

      readonly property var _activeLoader: {
        if (modId === "mediaplayer")    return mpLoader
        if (modId === "volume")         return volLoader
        if (modId === "sink")           return skLoader
        if (modId === "source")         return srLoader
        if (modId === "clock")          return ckLoader
        if (modId === "dmenu")          return dmLoader
        if (modId === "tasks")          return tkLoader
        if (modId === "quicksettings")  return qsLoader
        if (modId === "workspaces")     return wsLoader
        if (modId === "notifications")  return nfLoader
        return null
      }

      // Separador visual
      Rectangle {
        visible:          modId === "separator"
        anchors.centerIn: parent
        width:   isH ? 1  : 16
        height:  isH ? 14 : 1
        radius:  1
        color:   root.cfgClkDimColor
        opacity: 0.3
      }

      // ── Loaders de módulo ──────────────────────────────────────────────
      // Component {} interno em cada um para que os bindings QML sejam
      // declarativos (ligados directamente a root.cfg*) — mudanças em
      // runtime propagam automaticamente, sem Connections nem timers.

      Loader {
        id: mpLoader
        active:           modId === "mediaplayer"
        anchors.centerIn: parent
        sourceComponent: Component {
          Media.MediaPlayer {
            isHorizontal:    modItem.isH
            barPosition:     root.barPosition
            showText:        root.cfgMpShowText
            textStatic:      root.cfgMpTextStatic
            textColor:       root.cfgMpTextColor
            dimColor:        root.cfgMpDimColor
            accentColor:     root.colAccent
            textMode:        root.cfgMpTextMode
            scrollSpeed:     root.cfgMpScrollSpeed
            volumeStep:      root.cfgMpVolumeStep
            scrollPauseMs:   root.cfgMpScrollPauseMs
            scrollWidth:     root.cfgMpScrollWidth
            artworkSize:     root.cfgMpArtworkSize
            artworkRadius:   root.cfgMpArtworkRadius
            bgEnabled:       root.cfgMpBgEnabled
            bgOpacity:       root.cfgMpBgOpacity
            bgOpacityActive: root.cfgMpBgOpacityActive
            bgPaddingH:      root.cfgMpBgPaddingH
            bgPaddingV:      root.cfgMpBgPaddingV
            bgColor:         root.cfgMpBgColor
            bgColorActive:   root.cfgMpBgColorActive
            textColorActive: root.cfgMpTextColorActive
            dimColorActive:  root.cfgMpDimColorActive
            playerPriority:  root.cfgMpPlayerPriority
            idleInhibit:     root.cfgMpIdleInhibit
            fontScale:       root.cfgMpFontScale
            onClicked:       root.mediaPlayerClicked()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: volLoader
        active:           modId === "volume"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal:           modItem.isH
            textColor:              root.cfgVolTextColor
            dimColor:               root.cfgVolDimColor
            accentColor:            root.cfgVolAccent
            mutedColor:             root.cfgVolMuted
            progressColor:          root.cfgVolProgress
            maxVol:                 root.cfgVolMaxVol
            showSink:               root.cfgVolShowSink
            showSource:             root.cfgVolShowSource
            barPosition:            root.barPosition
            fontScale:              root.cfgVolFontScale
            onSinkPanelRequested:   root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      // ── Som solo (sink only) ──────────────────────────────────────────
      Loader {
        id: skLoader
        active:           modId === "sink"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal:           modItem.isH
            textColor:              root.cfgVolTextColor
            dimColor:               root.cfgVolDimColor
            accentColor:            root.cfgVolAccent
            mutedColor:             root.cfgVolMuted
            progressColor:          root.cfgVolProgress
            maxVol:                 root.cfgVolMaxVol
            showSink:               true
            showSource:             false
            barPosition:            root.barPosition
            fontScale:              root.cfgVolFontScale
            onSinkPanelRequested:   root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      // ── Mic solo (source only) ────────────────────────────────────────
      Loader {
        id: srLoader
        active:           modId === "source"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal:           modItem.isH
            textColor:              root.cfgVolTextColor
            dimColor:               root.cfgVolDimColor
            accentColor:            root.cfgVolAccent
            mutedColor:             root.cfgVolMuted
            progressColor:          root.cfgVolProgress
            maxVol:                 root.cfgVolMaxVol
            showSink:               false
            showSource:             true
            barPosition:            root.barPosition
            fontScale:              root.cfgVolFontScale
            onSinkPanelRequested:   root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: ckLoader
        active:           modId === "clock"
        anchors.centerIn: parent
        sourceComponent: Component {
          ClockModule.Clock {
            isHorizontal:     modItem.isH
            barPosition:      root.barPosition
            textColor:        root.cfgClkTextColor
            dimColor:         root.cfgClkDimColor
            accentColor:      root.cfgClkAccent
            dismissDelay:     root.cfgClkDismissDelay
            fontScale:        root.cfgClkFontScale
            onPanelRequested: root.clockPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: dmLoader
        active:           modId === "dmenu"
        anchors.centerIn: parent
        sourceComponent: Component {
          DmenuModule.Dmenu {
            isHorizontal:     modItem.isH
            barPosition:      root.barPosition
            textColor:        root.cfgDmenuTextColor
            dimColor:         root.cfgDmenuDimColor
            accentColor:      root.cfgDmenuAccent
            displayMode:      root.cfgDmenuDisplayMode
            iconGlyph:        root.cfgDmenuIconGlyph
            emptyText:        root.cfgDmenuEmptyText
            titleMaxWidth:    root.cfgDmenuTitleMaxWidth
            fontScale:        root.cfgDmenuFontScale
            windowIconSize:   root.cfgDmenuWindowIconSize
            textStatic:       root.cfgDmenuTextStatic
            scrollSpeed:      root.cfgDmenuScrollSpeed
            scrollPauseMs:    root.cfgDmenuScrollPauseMs
            showWorkspace:      root.cfgDmenuShowWorkspace
            workspacePosition:  root.cfgDmenuWorkspacePosition
            workspaceFormat:    root.cfgDmenuWorkspaceFormat
            workspaceChipWidth: root.cfgDmenuWorkspaceChipWidth
            workspaceIconMap:   root.cfgDmenuWorkspaceIconMap
            onPanelRequested: root.dmenuRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: tkLoader
        active:           modId === "tasks"
        anchors.centerIn: parent
        sourceComponent: Component {
          TasksModule.Tasks {
            isHorizontal:     modItem.isH
            barPosition:      root.barPosition
            textColor:        root.cfgTasksTextColor
            dimColor:         root.cfgTasksDimColor
            accentColor:      root.cfgTasksAccent
            fontScale:        root.cfgTasksFontScale
            onPanelRequested: root.tasksPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: qsLoader
        active:           modId === "quicksettings"
        anchors.centerIn: parent
        sourceComponent: Component {
          QsModule.QuickSettings {
            isHorizontal:     modItem.isH
            barPosition:      root.barPosition
            textColor:        root.cfgQsTextColor
            dimColor:         root.cfgQsDimColor
            accentColor:      root.cfgQsAccent
            fontScale:        root.cfgQsFontScale
            onPanelRequested: root.quickSettingsPanelRequested()
          }
        }
      }

      Loader {
        id: nfLoader
        active:           modId === "notifications"
        anchors.centerIn: parent
        sourceComponent: Component {
          NotifModule.Notifications {
            isHorizontal: modItem.isH
            barPosition:  root.barPosition
            textColor:    root.cfgNotifTextColor
            dimColor:     root.cfgNotifDimColor
            accentColor:  root.cfgNotifAccent
            mutedColor:   root.cfgNotifMuted
            service:      root.notifService
            fontScale:    root.cfgNotifFontScale
            onPanelRequested: root.notificationsPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: wsLoader
        active:           modId === "workspaces"
        anchors.centerIn: parent
        sourceComponent: Component {
          Modules.Workspaces {
            monitorName:         modItem.monName
            orientation:         modItem.isH ? "horizontal" : "vertical"
            barPosition:         root.barPosition
            style:               root.cfgWsStyle
            iconsSort:           root.cfgWsIconsSort
            iconMonochrome:      root.cfgWsIconMonochrome
            iconSpacing:         root.cfgWsIconSpacing
            iconSize:            root.cfgWsIconSize
            showNumber:          root.cfgWsShowNumber
            dotSize:             root.cfgWsDotSize
            fontSize:            root.cfgWsFontSize
            bgOpacity:           root.cfgWsBgOpacity
            bgOpacityActive:     root.cfgWsBgOpacityActive
            bgPaddingH:          root.cfgWsBgPaddingH
            bgPaddingV:          root.cfgWsBgPaddingV
            showAddButton:       root.cfgWsShowAddButton
            showTooltip:         root.cfgWsShowTooltip
            wsSpacing:           root.cfgWsSpacing
            revealMode:           root.cfgWsRevealMode
            hoverRevealDelayMs:   root.cfgWsHoverRevealDelayMs
            clickCollapseMode:    root.cfgWsClickCollapseMode
            clickRevealTimeoutMs: root.cfgWsClickRevealTimeoutMs
            scrollEnabled:        root.cfgWsScrollEnabled
            scrollAction:         root.cfgWsScrollAction
            scrollInvert:         root.cfgWsScrollInvert
            bgGroupEnabled:      root.cfgWsBgGroupEnabled
            bgActiveEnabled:     root.cfgWsBgActiveEnabled
            bgInactiveEnabled:     root.cfgWsBgInactiveEnabled
            bgColorInactive:       root.cfgWsBgColorInactive
            bgOpacityInactive:     root.cfgWsBgOpacityInactive
            bgBorderColorInactive: root.cfgWsBgBorderColorInactive
            bgBorderWidthInactive: root.cfgWsBgBorderWidthInactive
            bgPaddingHInactive:    root.cfgWsBgPaddingHInactive
            bgPaddingVInactive:    root.cfgWsBgPaddingVInactive
            bgRadiusInactive:      root.cfgWsBgRadiusInactive
            indicatorAnimStyle:    root.cfgWsIndicatorAnimStyle
            indicatorAnimDuration: root.cfgWsIndicatorAnimDuration
            addButtonBorderEnabled: root.cfgWsAddButtonBorderEnabled
            addButtonBgEnabled:     root.cfgWsAddButtonBgEnabled
            addButtonBgOpacity:     root.cfgWsAddButtonBgOpacity
            addButtonColor:         root.cfgWsAddButtonColor
            addButtonBgColor:       root.cfgWsAddButtonBgColor
            addButtonSize:          root.cfgWsAddButtonSize
            addButtonPaddingH:      root.cfgWsAddButtonPaddingH
            addButtonPaddingV:      root.cfgWsAddButtonPaddingV
            bgColor:             root.colWsBg
            bgColorActive:       root.colWsBgActive
            bgBorderColor:       Qt.rgba(root.colWsBorder.r, root.colWsBorder.g, root.colWsBorder.b, 0.12)
            bgBorderWidth:       root.cfgWsBgBorderWidth
            bgBorderColorActive: root.cfgWsBgBorderColorActive
            bgBorderWidthActive: root.cfgWsBgBorderWidthActive
            bgPaddingHActive:    root.cfgWsBgPaddingHActive
            bgPaddingVActive:    root.cfgWsBgPaddingVActive
            bgRadiusActive:      root.cfgWsBgRadiusActive
            iconMonoColor:       root.colIconMono
            iconMonoColorActive: root.colIconMonoActive
            numberColor:         root.colWsNumber
            numberColorActive:   root.colWsNumberActive
            numberBgEnabled:     root.cfgWsNumberBgEnabled
            numberBgColor:       root.colWsNumberBg
            numberBgColorActive: root.colWsNumberBgActive
            numberBgRadius:      root.cfgWsNumberBgRadius
            numberBgPaddingH:    root.cfgWsNumberBgPaddingH
            numberBgPaddingV:    root.cfgWsNumberBgPaddingV
            numberSpacing:       root.cfgWsNumberSpacing
            dotColor:            root.colWsDot
            dotActiveColor:      root.colWsDotActive
            dotOccupiedColor:    root.colWsDotOccupied
            dotUrgentColor:      root.colWsDotUrgent
          }
        }
        onItemChanged: {
          if (item) root._updateRefs()
        }
      }

      // ── Propagação reactiva de mudanças dinâmicas do módulo Workspaces ──
      // Quando o utilizador cria/remove um workspace, Workspaces.implicitWidth
      // muda. Em vez de depender só do encadeamento "_activeLoader.item.*"
      // (que pode não estabelecer uma dependência reativa confiável — ver
      // comentário no implicitWidth acima), incrementamos _wsKick aqui, o
      // que força modItem.implicitWidth/Height a reavaliar de imediato.
      Connections {
        target: wsLoader.item
        ignoreUnknownSignals: true
        function onImplicitWidthChanged()  { modItem._wsKick++ }
        function onImplicitHeightChanged() { modItem._wsKick++ }
      }
    }
  }

  // ── Helper: varre um Repeater buscando a primeira ref não-nula ─────────
  function _findRef(repeater, prop) {
    for (var i = 0; i < repeater.count; i++) {
      var loaderItem = repeater.itemAt(i)          // este é o Loader do delegate
      var mod = loaderItem ? loaderItem.item : null  // este é o moduleItemComp
      if (mod && mod[prop]) return mod[prop]
    }
    return null
  }

  // ── Helper: acha o PRÓPRIO delegate (modItem) que corresponde a um modId
  // ─────────────────────────────────────────────────────────────────────
  // Diferente de _findRef (que retorna um WIDGET INTERNO, que muitas vezes
  // só tem implicitWidth, não width real), isto retorna o próprio wrapper
  // (moduleItemComp) que o Row/Column efetivamente posiciona e dimensiona —
  // geometria 100% confiável pra alinhamento de popup.
  function _findModuleItem(repeater, modId) {
    for (var i = 0; i < repeater.count; i++) {
      var loaderItem = repeater.itemAt(i)
      var mod = loaderItem ? loaderItem.item : null
      if (mod && mod.modId === modId) return mod
    }
    return null
  }

  // ── Coleta refs do layout actual (left/center/right OU top/middle/bottom)
  function _updateRefs() {
    var lay = layoutLoader.item
    if (!lay) return
    root.mediaPlayer  = lay.mediaPlayer  || null
    root.volumeWidget = lay.volumeWidget || null
    root.sinkWidget   = lay.sinkWidget   || null
    root.sourceWidget = lay.sourceWidget || null
    root.clock        = lay.clock        || null
    root.dmenu        = lay.dmenu        || null
    root.tasks         = lay.tasks         || null
    root.notifWidget  = lay.notifWidget  || null
    root.qsWidget      = lay.qsWidget      || null
    root.leftGroupItem   = lay.leftGroupItem   || null
    root.rightGroupItem  = lay.rightGroupItem  || null
    root.topGroupItem    = lay.topGroupItem    || null
    root.bottomGroupItem = lay.bottomGroupItem || null
    root.refsUpdated()
  }

  // Delega pro layout carregado (h ou v) — usado por Bar.qml pra achar a
  // geometria confiável de um módulo específico (âncora de popup).
  function moduleItemAt(modId) {
    var lay = layoutLoader.item
    return lay && lay.moduleItemAt ? lay.moduleItemAt(modId) : null
  }

  // ── Loader do layout ───────────────────────────────────────────────────
  Loader {
    id: layoutLoader
    anchors.fill: parent
    sourceComponent: root.isHorizontal ? horizontalComp : verticalComp

    onLoaded: {
      item.monitorName = root.monitorName
      root._updateRefs()
    }
  }

  onIsHorizontalChanged: {
    Qt.callLater(function() {
      if (layoutLoader.item) layoutLoader.item.monitorName = root.monitorName
    })
  }
  onMonitorNameChanged: {
    if (layoutLoader.item) layoutLoader.item.monitorName = monitorName
  }

  // Quando módulos mudam, atualiza refs de clock/mediaPlayer/volume.
  // (Sem _updateContentWidth — o tamanho da janela é fixo neste tema.)
  onCfgModulesLeftChanged:   Qt.callLater(_updateRefs)
  onCfgModulesCenterChanged: Qt.callLater(_updateRefs)
  onCfgModulesRightChanged:  Qt.callLater(_updateRefs)
  onCfgModulesTopChanged:    Qt.callLater(_updateRefs)
  onCfgModulesMiddleChanged: Qt.callLater(_updateRefs)
  onCfgModulesBottomChanged: Qt.callLater(_updateRefs)

  // ── Wrapper de chip individual — usado pelos Repeaters horizontais ──────
  // Cada módulo (exceto separator/spacer) ganha a própria pílula. Espelha as
  // refs (mediaPlayer/volumeWidget/etc) do Loader interno pra cima, pra
  // _findRef continuar funcionando sem precisar de nenhuma lógica especial.
  Component {
    id: chipCompH
    Item {
      id: chipWrap
      property string modelData:   ""
      property string monitorName: ""
      readonly property bool isDivider: modelData === "separator" || modelData === "spacer"
      // FIX-ROUNDING: mesmo princípio do container clip:true da ilha
      // central do Dock.qml ("evita transbordo visual se o conteúdo for
      // maior que o espaço") — aqui height:root.barSize é fixo mas o
      // conteúdo do módulo (ícones, texto) não é clampado a esse valor.
      // Com barSize pequeno (<32px) o conteúdo interno estoura por cima
      // da pílula arredondada, dando a impressão de canto quadrado/não
      // arredondado. clip:true garante que nada renderize fora do
      // retângulo (já arredondado pelo radius) deste Item.
      clip: true
      // _findRef (função compartilhada, ver Dock.qml) espera que
      // "loaderItem.item" exponha mediaPlayer/volumeWidget/etc diretamente —
      // como aqui o Loader do Repeater carrega chipWrap (não o moduleItemComp
      // direto), espelhamos cada ref do Loader interno pra cima:
      readonly property var mediaPlayer:  inner.item ? inner.item.mediaPlayer  : null
      readonly property var volumeWidget: inner.item ? inner.item.volumeWidget : null
      readonly property var sinkWidget:   inner.item ? inner.item.sinkWidget   : null
      readonly property var sourceWidget: inner.item ? inner.item.sourceWidget : null
      readonly property var clock:        inner.item ? inner.item.clock        : null
      readonly property var tasks:        inner.item ? inner.item.tasks        : null
      readonly property var notifWidget:  inner.item ? inner.item.notifWidget  : null

      // FIX: "parent" aqui é o Loader que carrega este chip, e o Loader
      // espelha o TAMANHO do chip — usar parent.height criaria uma
      // referência circular (chip depende do Loader que depende do chip),
      // resultando em altura 0. root.barSize é o valor estável e correto.
      height: root.barSize
      width: {
        var iw = inner.item ? inner.item.implicitWidth : 0
        return isDivider ? iw : iw + root.chipPad * 2
      }
      // FIX3: o módulo "workspaces" busca a lista de workspaces do Hyprland
      // de forma assíncrona (a resposta da IPC leva alguns milissegundos) —
      // então o chip nasce com um tamanho "errado"/vazio e só ajusta pro
      // tamanho real um instante depois. Sem Behavior, isso aparece como um
      // salto brusco logo na inicialização (mais visível em conexões frias,
      // quando o Hyprland ainda não tinha o cache populado) — exatamente o
      // "bug" do primeiro carregamento. A transição suave disfarça o ajuste.
      Behavior on width  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      // FIX-PILL: o Rectangle do QtQuick, na prática, NÃO clampa sozinho
      // um radius muito maior que a altura/largura pra um arco perfeito —
      // com chipRadius >> height ele fica um meio-termo estranho (canto
      // arredondado pequeno + sobra de borda reta), em vez de virar cápsula.
      // Por isso clampamos manualmente aqui: nunca passa de height/2, que é
      // o valor exato que fecha a pílula sem artefato. Isso também permite
      // deixar o slider (root.chipRadius) sempre "no talo" pro usuário sem
      // se preocupar em calcular a metade do barSize na mão.
      readonly property real _pillRadius: Math.min(root.chipRadius, height / 2)

      Rectangle { // sombra sutil
        visible: !chipWrap.isDivider
        width:  parent.width
        height: parent.height
        y:      root.chipShadowOffset
        radius: chipWrap._pillRadius
        color:  "#000000"
        opacity: root.chipShadowOpacity
      }
      Rectangle { // pílula
        visible: !chipWrap.isDivider
        anchors.fill: parent
        radius: chipWrap._pillRadius
        color:  root.colBarBgPill
      }


      Loader {
        id: inner
        anchors.centerIn: parent
        sourceComponent: moduleItemComp
        onLoaded: {
          item.modId   = chipWrap.modelData
          item.isH     = true
          item.monName = chipWrap.monitorName
        }
        // FIX: o Loader de fora (delegate do Repeater) só escreve o valor
        // real em chipWrap.modelData no SEU onLoaded, que dispara DEPOIS
        // deste Loader interno já ter disparado o onLoaded acima — ou seja,
        // sem este Binding, modId ficava travado em "" pra sempre, e o
        // ícone nunca renderizava. Era por isso que não aparecia nada.
        // FIX2: "target: item" sem qualificador NÃO resolve pro item deste
        // Loader (inner) — dentro de um elemento filho como Binding{}, isso
        // só funciona em handlers de sinal anexados diretamente ao próprio
        // Loader (onLoaded/onItemChanged). Em qualquer outro lugar precisa
        // ser explícito: inner.item. Sem isso, o Binding mirava sem querer
        // no item do Loader de FORA (chipWrap), que não tem modId/monName —
        // daí os warnings "Property 'modId' does not exist on QQuickItem*".
        Binding { target: inner.item; property: "modId";   value: chipWrap.modelData;   when: inner.item !== null }
        Binding { target: inner.item; property: "monName"; value: chipWrap.monitorName; when: inner.item !== null }
        onItemChanged: root._updateRefs()
      }
    }
  }

  // ── Wrapper de chip individual — usado pelos Repeaters verticais ───────
  Component {
    id: chipCompV
    Item {
      id: chipWrap
      property string modelData:   ""
      property string monitorName: ""
      readonly property bool isDivider: modelData === "separator" || modelData === "spacer"
      // FIX-ROUNDING: ver comentário equivalente em chipCompH acima —
      // mesmo problema espelhado pro eixo vertical (aqui é width:root.barSize
      // que fica pequeno e o conteúdo não é clampado a ele).
      clip: true
      // _findRef (função compartilhada, ver Dock.qml) espera que
      // "loaderItem.item" exponha mediaPlayer/volumeWidget/etc diretamente —
      // como aqui o Loader do Repeater carrega chipWrap (não o moduleItemComp
      // direto), espelhamos cada ref do Loader interno pra cima:
      readonly property var mediaPlayer:  inner.item ? inner.item.mediaPlayer  : null
      readonly property var volumeWidget: inner.item ? inner.item.volumeWidget : null
      readonly property var sinkWidget:   inner.item ? inner.item.sinkWidget   : null
      readonly property var sourceWidget: inner.item ? inner.item.sourceWidget : null
      readonly property var clock:        inner.item ? inner.item.clock        : null
      readonly property var tasks:        inner.item ? inner.item.tasks        : null
      readonly property var notifWidget:  inner.item ? inner.item.notifWidget  : null

      // FIX: mesmo problema do chipCompH, espelhado pro eixo horizontal
      // (aqui "parent" = Loader, que espelha a largura deste chip).
      width: root.barSize
      height: {
        var ih = inner.item ? inner.item.implicitHeight : 0
        return isDivider ? ih : ih + root.chipPad * 2
      }
      // FIX3: mesmo motivo do chipCompH — ver comentário lá. Sem isso, o
      // chip do workspace "salta" de tamanho assim que os dados do Hyprland
      // chegam (alguns ms depois da criação), mais visível em inicializações
      // frias.
      Behavior on width  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      // FIX-PILL: mesmo motivo do chipCompH — ver comentário lá. Aqui o eixo
      // fixo é a LARGURA (width: root.barSize), então clampamos em width/2.
      readonly property real _pillRadius: Math.min(root.chipRadius, width / 2)

      Rectangle {
        visible: !chipWrap.isDivider
        width:  parent.width
        height: parent.height
        y:      root.chipShadowOffset
        radius: chipWrap._pillRadius
        color:  "#000000"
        opacity: root.chipShadowOpacity
      }
      Rectangle {
        visible: !chipWrap.isDivider
        anchors.fill: parent
        radius: chipWrap._pillRadius
        color:  root.colBarBgPill
      }

      Loader {
        id: inner
        anchors.centerIn: parent
        sourceComponent: moduleItemComp
        onLoaded: {
          item.modId   = chipWrap.modelData
          item.isH     = false
          item.monName = chipWrap.monitorName
        }
        // FIX: mesmo motivo do chipCompH — sem este Binding, modId travava
        // em "" pra sempre.
        // FIX2: "target: item" sem qualificador NÃO resolve pro item deste
        // Loader (inner) — dentro de um elemento filho como Binding{}, isso
        // só funciona em handlers de sinal anexados diretamente ao próprio
        // Loader (onLoaded/onItemChanged). Em qualquer outro lugar precisa
        // ser explícito: inner.item. Sem isso, o Binding mirava sem querer
        // no item do Loader de FORA (chipWrap), que não tem modId/monName —
        // daí os warnings "Property 'modId' does not exist on QQuickItem*".
        Binding { target: inner.item; property: "modId";   value: chipWrap.modelData;   when: inner.item !== null }
        Binding { target: inner.item; property: "monName"; value: chipWrap.monitorName; when: inner.item !== null }
        onItemChanged: root._updateRefs()
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HORIZONTAL — left | center | right
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: horizontalComp

    Item {
      id: hRoot
      anchors.fill: parent
      property string monitorName: ""

      property var mediaPlayer:  root._findRef(leftRep,   "mediaPlayer")
                               || root._findRef(centerRep, "mediaPlayer")
                               || root._findRef(rightRep,  "mediaPlayer")
      property var volumeWidget: root._findRef(leftRep,   "volumeWidget")
                               || root._findRef(centerRep, "volumeWidget")
                               || root._findRef(rightRep,  "volumeWidget")
      property var sinkWidget:   root._findRef(leftRep,   "sinkWidget")
                               || root._findRef(centerRep, "sinkWidget")
                               || root._findRef(rightRep,  "sinkWidget")
      property var sourceWidget: root._findRef(leftRep,   "sourceWidget")
                               || root._findRef(centerRep, "sourceWidget")
                               || root._findRef(rightRep,  "sourceWidget")
      property var clock:        root._findRef(leftRep,   "clock")
                               || root._findRef(centerRep, "clock")
                               || root._findRef(rightRep,  "clock")
      property var dmenu:        root._findRef(leftRep,   "dmenu")
                               || root._findRef(centerRep, "dmenu")
                               || root._findRef(rightRep,  "dmenu")
      property var tasks:        root._findRef(leftRep,   "tasks")
                               || root._findRef(centerRep, "tasks")
                               || root._findRef(rightRep,  "tasks")
      property var notifWidget:  root._findRef(leftRep,   "notifWidget")
                               || root._findRef(centerRep, "notifWidget")
                               || root._findRef(rightRep,  "notifWidget")
      property var qsWidget:     root._findRef(leftRep,   "qsWidget")
                               || root._findRef(centerRep, "qsWidget")
                               || root._findRef(rightRep,  "qsWidget")

      // Devolve o delegate (modItem) do módulo modId — geometria confiável
      // pra âncora de popup, independente do slot em que ele estiver.
      function moduleItemAt(modId) {
        return root._findModuleItem(leftRep, modId)
            || root._findModuleItem(centerRep, modId)
            || root._findModuleItem(rightRep, modId)
      }

      // Refs dos próprios GRUPOS (Rows) — usados pra alinhar popups à
      // borda do grupo de módulos (popupXAlign: "group") em vez da borda
      // da tela.
      property var leftGroupItem:  leftRow
      property var rightGroupItem: rightRow

      // ── Slot esquerda ──────────────────────────────────────────────────
      Row {
        id: leftRow
        objectName: "barSectionLeft"
        anchors.left:           parent.left
        anchors.leftMargin:     root.edgeInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.chipGap

        Repeater {
          id: leftRep
          model: root.cfgModulesLeft
          delegate: Loader {
            id: leftLoader
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: chipCompH
            onLoaded: {
              item.modelData    = modelData
              item.monitorName  = hRoot.monitorName
            }
            // FIX4: atribuição única em onLoaded não acompanha hRoot.monitorName
            // quando ele chega DEPOIS (caso comum no primeiro boot/troca de tema
            // — ver "FIX3" acima). Sem este Binding, chipWrap.monitorName ficava
            // travado em "" pra sempre, e o Workspaces.qml (único módulo que usa
            // monitorName de verdade) nunca mostrava nada além do "+".
            Binding { target: leftLoader.item; property: "monitorName"; value: hRoot.monitorName; when: leftLoader.item !== null }
          }
        }
      }

      // ── Slot direita ─────────────────────────────────────────────────
      Row {
        id: rightRow
        objectName: "barSectionRight"
        anchors.right:          parent.right
        anchors.rightMargin:    root.edgeInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.chipGap

        Repeater {
          id: rightRep
          model: root.cfgModulesRight
          delegate: Loader {
            id: rightLoader
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: chipCompH
            onLoaded: {
              item.modelData    = modelData
              item.monitorName  = hRoot.monitorName
            }
            Binding { target: rightLoader.item; property: "monitorName"; value: hRoot.monitorName; when: rightLoader.item !== null }
          }
        }
      }

      // ── Slot central ───────────────────────────────────────────────────
      Item {
        anchors.fill: parent
        clip: true

        Row {
          id: centerRow
          objectName: "barSectionCenter"
          anchors.centerIn: parent
          spacing: root.chipGap

          Repeater {
            id: centerRep
            model: root.cfgModulesCenter
            delegate: Loader {
              id: centerLoader
              required property string modelData
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              sourceComponent: chipCompH
              onLoaded: {
                item.modelData   = modelData
                item.monitorName = hRoot.monitorName
              }
              Binding { target: centerLoader.item; property: "monitorName"; value: hRoot.monitorName; when: centerLoader.item !== null }
            }
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VERTICAL — top | middle | bottom
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: verticalComp

    Item {
      id: vRoot
      anchors.fill: parent
      property string monitorName: ""

      property var mediaPlayer:  root._findRef(topRep,    "mediaPlayer")
                               || root._findRef(middleRep, "mediaPlayer")
                               || root._findRef(bottomRep, "mediaPlayer")
      property var volumeWidget: root._findRef(topRep,    "volumeWidget")
                               || root._findRef(middleRep, "volumeWidget")
                               || root._findRef(bottomRep, "volumeWidget")
      property var sinkWidget:   root._findRef(topRep,    "sinkWidget")
                               || root._findRef(middleRep, "sinkWidget")
                               || root._findRef(bottomRep, "sinkWidget")
      property var sourceWidget: root._findRef(topRep,    "sourceWidget")
                               || root._findRef(middleRep, "sourceWidget")
                               || root._findRef(bottomRep, "sourceWidget")
      property var clock:        root._findRef(topRep,    "clock")
                               || root._findRef(middleRep, "clock")
                               || root._findRef(bottomRep, "clock")
      property var dmenu:        root._findRef(topRep,    "dmenu")
                               || root._findRef(middleRep, "dmenu")
                               || root._findRef(bottomRep, "dmenu")
      property var tasks:        root._findRef(topRep,    "tasks")
                               || root._findRef(middleRep, "tasks")
                               || root._findRef(bottomRep, "tasks")
      property var notifWidget:  root._findRef(topRep,    "notifWidget")
                               || root._findRef(middleRep, "notifWidget")
                               || root._findRef(bottomRep, "notifWidget")
      property var qsWidget:     root._findRef(topRep,    "qsWidget")
                               || root._findRef(middleRep, "qsWidget")
                               || root._findRef(bottomRep, "qsWidget")

      // Equivalente vertical de hRoot.moduleItemAt().
      function moduleItemAt(modId) {
        return root._findModuleItem(topRep, modId)
            || root._findModuleItem(middleRep, modId)
            || root._findModuleItem(bottomRep, modId)
      }

      // Refs dos grupos (Columns) — equivalente vertical de leftGroupItem/
      // rightGroupItem, usado por popupXAlign:"group" em barras verticais.
      property var topGroupItem:    topCol
      property var bottomGroupItem: bottomCol

      // ── Slot superior ────────────────────────────────────────────────
      Column {
        id: topCol
        objectName: "barSectionTop"
        anchors.top:              parent.top
        anchors.topMargin:        root.edgeInset
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.chipGap

        Repeater {
          id: topRep
          model: root.cfgModulesTop
          delegate: Loader {
            id: topLoader
            required property string modelData
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            sourceComponent: chipCompV
            onLoaded: {
              item.modelData   = modelData
              item.monitorName = vRoot.monitorName
            }
            Binding { target: topLoader.item; property: "monitorName"; value: vRoot.monitorName; when: topLoader.item !== null }
          }
        }
      }

      // ── Slot inferior ────────────────────────────────────────────────
      Column {
        id: bottomCol
        objectName: "barSectionBottom"
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     root.edgeInset
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.chipGap

        Repeater {
          id: bottomRep
          model: root.cfgModulesBottom
          delegate: Loader {
            id: bottomLoader
            required property string modelData
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            sourceComponent: chipCompV
            onLoaded: {
              item.modelData   = modelData
              item.monitorName = vRoot.monitorName
            }
            Binding { target: bottomLoader.item; property: "monitorName"; value: vRoot.monitorName; when: bottomLoader.item !== null }
          }
        }
      }

      // ── Slot central ───────────────────────────────────────────────────
      Item {
        anchors.fill: parent
        clip: true

        Column {
          id: middleCol
          objectName: "barSectionMiddle"
          anchors.centerIn: parent
          spacing: root.chipGap

          Repeater {
            id: middleRep
            model: root.cfgModulesMiddle
            delegate: Loader {
              id: middleLoader
              required property string modelData
              anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
              sourceComponent: chipCompV
              onLoaded: {
                item.modelData   = modelData
                item.monitorName = vRoot.monitorName
              }
              Binding { target: middleLoader.item; property: "monitorName"; value: vRoot.monitorName; when: middleLoader.item !== null }
            }
          }
        }
      }
    }
  }
}
