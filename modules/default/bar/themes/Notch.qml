import Quickshell
import QtQuick
import QtQuick.Shapes
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
import "../../dmenu" as DmenuModule
import "../../tasks" as TasksModule
import "../../quicksettings" as QsModule
import "../../notifications" as NotifModule

// ════════════════════════════════════════════════════════════════════════
// NOTCH — Dynamic Island para Quickshell.
//
// Conceito: um único lobo centralizado pendurado na borda da tela.
// Não existe faixa lateral — tudo fica dentro do lobo. Ele expande
// suavemente quando tem conteúdo ativo (mídia tocando, notificação nova)
// e encolhe de volta ao mínimo quando nada está acontecendo.
//
// Layout: os módulos são divididos em três ilhas lógicas:
//   left   — slot esquerdo dentro do lobo (ex: mediaplayer, quicksettings)
//   center — slot central (ex: workspaces, clock)
//   right  — slot direito (ex: volume, notifications)
//
// Forma: base trapezoidal — mais larga rente à borda da tela, estreita
// em direção ao desktop (como a haste de um "d"). Nos dois cantos onde
// o lobo encontra a borda da tela, mantém as mordidas côncavas (estilo
// Dynamic Island); o lado de dentro da tela é arredondado normalmente.
// Tudo desenhado com Shape+PathSvg.
//
// Expansão dinâmica: a largura do lobo segue o conteúdo real dos três
// slots (medido via implicitWidth dos Rows internos) com uma animação
// spring. A altura cresce ligeiramente quando o mediaplayer está ativo.
//
// Orientação: só horizontal (posição 1 = topo, posição 3 = baixo).
// Vertical (2/4) não faz sentido semântico pra um "notch de câmera".
// ════════════════════════════════════════════════════════════════════════

Item {
  id: root
  anchors.fill: parent

  // ── Contrato com Bar.qml ───────────────────────────────────────────────
  property int    barSize:       44
  property int    barMargin:     0
  property bool   pill:          false
  property int    panelWidth:    400
  property string monitorName:   ""
  property bool   hasMediaPanel: true
  property int    barPosition:   1      // 1=topo (padrão natural pra notch)

  property int  minPillWidth:   400
  property int  pillMinSpacing: 8
  property int  activePopupW:   0
  property bool anyPanelOpen:   false

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
  property var notifService:  null

  // Refs dos grupos (Rows) — usados por popupXAlign:"group"/"module".
  property var leftGroupItem:  null
  property var rightGroupItem: null

  readonly property bool isHorizontal: true   // Notch só horizontal

  property var cfgModulesLeft:   []
  property var cfgModulesCenter: []
  property var cfgModulesRight:  []
  property var cfgModulesTop:    []
  property var cfgModulesMiddle: []
  property var cfgModulesBottom: []

  // ── Configs Workspaces ─────────────────────────────────────────────────
  property string cfgWsStyle:               "dots"
  property string cfgWsIconsSort:           "position"
  property bool   cfgWsIconMonochrome:      true
  property int    cfgWsIconSpacing:         3
  property int    cfgWsIconSize:            14
  property bool   cfgWsShowNumber:          false
  property real   cfgWsBgOpacity:           0.0
  property real   cfgWsBgPaddingH:          4
  property real   cfgWsBgPaddingV:          2
  property real   cfgWsBgBorderWidth:       0
  property int    cfgWsDotSize:             5
  property int    cfgWsFontSize:            9
  property bool   cfgWsNumberBgEnabled:     false
  property int    cfgWsNumberBgRadius:      3
  property int    cfgWsNumberBgPaddingH:    3
  property int    cfgWsNumberBgPaddingV:    1
  property int    cfgWsNumberSpacing:       3
  property bool   cfgWsShowAddButton:       false
  property bool   cfgWsShowTooltip:         true
  property int    cfgWsSpacing:             4
  property color  cfgWsBgColorActive:        Qt.rgba(1,1,1,0.0)
  property real   cfgWsBgOpacityActive:      0.0
  property color  cfgWsBgBorderColorActive:  "transparent"
  property real   cfgWsBgBorderWidthActive:  0
  property real   cfgWsBgPaddingHActive:     4
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
  property int    cfgMpScrollSpeed:     35
  property real   cfgMpVolumeStep:      0.05
  property int    cfgMpScrollPauseMs:   1800
  property int    cfgMpScrollWidth:     120
  property int    cfgMpArtworkSize:     20
  property int    cfgMpArtworkRadius:   10
  property bool   cfgMpBgEnabled:       false
  property real   cfgMpBgOpacity:       0.5
  property real   cfgMpBgOpacityActive: 0.8
  property real   cfgMpBgPaddingH:      6
  property real   cfgMpBgPaddingV:      3
  property color  cfgMpBgColor:         Qt.rgba(1,1,1,0.08)
  property color  cfgMpBgColorActive:   Qt.rgba(1,1,1,0.12)
  property color  cfgMpTextColor:       Qt.rgba(1,1,1,0.9)
  property color  cfgMpDimColor:        Qt.rgba(1,1,1,0.45)
  property color  cfgMpTextColorActive: Qt.rgba(1,1,1,1.0)
  property color  cfgMpDimColorActive:  Qt.rgba(1,1,1,0.5)
  property string cfgMpPlayerPriority:  "spotify,ncspot,vivaldi,brave"
  property bool   cfgMpIdleInhibit:     true
  property real   cfgMpFontScale:       1.0

  // ── Configs Volume ─────────────────────────────────────────────────────
  property bool  cfgVolShowSink:    true
  property bool  cfgVolShowSource:  false
  property real  cfgVolMaxVol:      1.5
  property color cfgVolTextColor:   Qt.rgba(1,1,1,0.9)
  property color cfgVolDimColor:    Qt.rgba(1,1,1,0.45)
  property color cfgVolAccent:      Qt.rgba(1,1,1,1.0)
  property color cfgVolMuted:       "#cf6679"
  property color cfgVolProgress:    "#474747"
  property real  cfgVolFontScale:   1.0

  // ── Configs QuickSettings ──────────────────────────────────────────────
  property color cfgQsTextColor:    Qt.rgba(1,1,1,0.9)
  property color cfgQsDimColor:     Qt.rgba(1,1,1,0.45)
  property color cfgQsAccent:       Qt.rgba(1,1,1,1.0)
  property real  cfgQsFontScale:    1.0

  // ── Configs Notifications ──────────────────────────────────────────────
  property color cfgNotifTextColor: Qt.rgba(1,1,1,0.9)
  property color cfgNotifDimColor:  Qt.rgba(1,1,1,0.45)
  property color cfgNotifAccent:    Qt.rgba(1,1,1,1.0)
  property color cfgNotifMuted:     "#cf6679"
  property real  cfgNotifFontScale: 1.0

  // ── Configs Clock ──────────────────────────────────────────────────────
  property color cfgClkTextColor:    Qt.rgba(1,1,1,0.9)
  property color cfgClkDimColor:     Qt.rgba(1,1,1,0.45)
  property color cfgClkAccent:       Qt.rgba(1,1,1,1.0)
  property int   cfgClkDismissDelay: 6000
  property real  cfgClkFontScale:    1.0

  // ── Configs Dmenu ────────────────────────────────────────────────────
  property color  cfgDmenuTextColor:    Qt.rgba(1,1,1,1.0)
  property color  cfgDmenuDimColor:     Qt.rgba(1,1,1,0.5)
  property color  cfgDmenuAccent:       Qt.rgba(1,1,1,1.0)
  property bool   cfgDmenuShowIcon:      true
  property string cfgDmenuIconType:      "glyph"
  property bool   cfgDmenuShowTitle:     true
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
  property string cfgDmenuWorkspaceIgnorePattern: ""

  // ── Configs Tasks ────────────────────────────────────────────────────
  property color cfgTasksTextColor: Qt.rgba(1,1,1,0.9)
  property color cfgTasksDimColor:  Qt.rgba(1,1,1,0.45)
  property color cfgTasksAccent:    Qt.rgba(1,1,1,1.0)
  property real  cfgTasksFontScale: 1.0

  // ── Paleta ─────────────────────────────────────────────────────────────
  // Só barBg/textDim/accent são de fato pintadas neste tema — barBgPill/
  // text/accentBg/accentText eram recebidas do Bar.qml (via _set()) mas
  // nunca consumidas em lugar nenhum, então o contract.json não expõe mais
  // seletor de cor pra elas (evita cor "fantasma" que o usuário edita e
  // não vê efeito nenhum na barra).
  property color colBarBg:          "#0d0d0d"
  property color colTextDim:        "#9a9a9a"
  property color colAccent:         "#ffb4a9"
  property color colWsDot:          "#666666"
  property color colWsDotActive:    "#e8e8e8"
  property color colWsDotOccupied:  "#aaaaaa"
  property color colWsDotUrgent:    "#ffb4ab"
  property color colWsBg:           "#2a2a2a"
  property color colWsBgActive:     "#3a3a3a"
  property color colWsBorder:       "#e8e8e8"
  property color colIconMono:       "#cccccc"
  property color colIconMonoActive: "#ffb4a9"
  property color colWsNumber:         "#888888"
  property color colWsNumberActive:   "#0d0d0d"
  property color colWsNumberBg:       "#2a2a2a"
  property color colWsNumberBgActive: "#ffb4a9"

  // ── Aparência do Notch ─────────────────────────────────────────────────
  property int  notchRadius:   10
  property int  concaveRadius:  8
  property int  lobePadH:       14
  property int  lobePadV:        6
  property int  notchTaper:    20   // inclinação do trapézio (px de estreitamento por lado, rente ao desktop)
  readonly property int moduleSpacing: pillMinSpacing

  // popupPillPadding: margem extra além da largura do popup para que o lobo
  // fique visivelmente maior que o popup "colado" nele — mesmo conceito e
  // mesmo nome que Pill.qml usa. Configurável via BarTabBar (seção NOTCH).
  property int notchPopupPadding: 32

  // Liga/desliga o esticamento do lobo pra acompanhar popups mais largos.
  // Desligado: o lobo fica sempre no tamanho natural do conteúdo
  // (_naturalLobeW), e os popups abrem "por cima", sem a barra reagir —
  // comportamento antigo, pra quem prefere o notch sempre do mesmo tamanho.
  property bool notchExpandForPopups: true

  // ── Estado de expansão ─────────────────────────────────────────────────
  property real _contentW: leftRow.implicitWidth + centerRow.implicitWidth + rightRow.implicitWidth
                           + (leftRow.implicitWidth  > 0 ? moduleSpacing : 0)
                           + (rightRow.implicitWidth > 0 ? moduleSpacing : 0)

  readonly property real _naturalLobeW: Math.max(60, _contentW + lobePadH * 2)

  // Mesmo comportamento da Pill: quando um popup está aberto e é mais largo
  // que o lobo natural, o lobo estica pra "abraçar" o popup (activePopupW +
  // notchPopupPadding). Quando o popup é mais estreito que o conteúdo atual,
  // o lobo não encolhe abaixo do necessário pro próprio conteúdo.
  property real _lobeW: {
    if (notchExpandForPopups && anyPanelOpen && activePopupW > 0) {
      var expanded = activePopupW + notchPopupPadding
      if (expanded > _naturalLobeW) return expanded
    }
    return _naturalLobeW
  }
  property real _lobeH:  barSize

  property real _lobeX: (parent.width - _lobeW) / 2

  // true quando há conteúdo activo que "justifica" o lobo maior
  property bool _expanded: cfgModulesLeft.length > 0 || cfgModulesRight.length > 0

  // ── Helpers ────────────────────────────────────────────────────────────
  function _findRef(rep, prop) {
    for (var i = 0; i < rep.count; i++) {
      var it = rep.itemAt(i)
      var mod = it ? it.item : null
      if (mod && mod[prop]) return mod[prop]
    }
    return null
  }

  // Acha o próprio delegate (modItem) por modId — geometria confiável
  // (width/x reais) pra âncora de popup, diferente dos refs de widget
  // interno acima (que podem só ter implicitWidth).
  function _findModuleItem(rep, modId) {
    for (var i = 0; i < rep.count; i++) {
      var it = rep.itemAt(i)
      var mod = it ? it.item : null
      if (mod && mod.modId === modId) return mod
    }
    return null
  }

  function moduleItemAt(modId) {
    return _findModuleItem(leftRep, modId)
        || _findModuleItem(centerRep, modId)
        || _findModuleItem(rightRep, modId)
  }

  function _updateRefs() {
    root.mediaPlayer  = _findRef(leftRep,   "mediaPlayer")  || _findRef(centerRep, "mediaPlayer")  || _findRef(rightRep,  "mediaPlayer")
    root.volumeWidget = _findRef(leftRep,   "volumeWidget") || _findRef(centerRep, "volumeWidget") || _findRef(rightRep,  "volumeWidget")
    root.sinkWidget   = _findRef(leftRep,   "sinkWidget")   || _findRef(centerRep, "sinkWidget")   || _findRef(rightRep,  "sinkWidget")
    root.sourceWidget = _findRef(leftRep,   "sourceWidget") || _findRef(centerRep, "sourceWidget") || _findRef(rightRep,  "sourceWidget")
    root.clock        = _findRef(leftRep,   "clock")        || _findRef(centerRep, "clock")        || _findRef(rightRep,  "clock")
    root.dmenu        = _findRef(leftRep,   "dmenu")        || _findRef(centerRep, "dmenu")        || _findRef(rightRep,  "dmenu")
    root.tasks        = _findRef(leftRep,   "tasks")        || _findRef(centerRep, "tasks")        || _findRef(rightRep,  "tasks")
    root.notifWidget  = _findRef(leftRep,   "notifWidget")  || _findRef(centerRep, "notifWidget")  || _findRef(rightRep,  "notifWidget")
    root.qsWidget      = _findRef(leftRep,   "qsWidget")      || _findRef(centerRep, "qsWidget")      || _findRef(rightRep,  "qsWidget")
    root.leftGroupItem  = leftRow
    root.rightGroupItem = rightRow
    root.refsUpdated()
  }

  onCfgModulesLeftChanged:   Qt.callLater(_updateRefs)
  onCfgModulesCenterChanged: Qt.callLater(_updateRefs)
  onCfgModulesRightChanged:  Qt.callLater(_updateRefs)

  // ── Componente de módulo individual ────────────────────────────────────
  Component {
    id: moduleItemComp

    Item {
      id: modItem
      property string modId:   ""
      property bool   isH:     true
      property string monName: ""
      property int    _wsKick: 0

      readonly property var mediaPlayer:  mpLoader.active  && mpLoader.item  ? mpLoader.item  : null
      readonly property var volumeWidget: volLoader.active && volLoader.item ? volLoader.item : null
      readonly property var sinkWidget:   skLoader.active  && skLoader.item  ? skLoader.item  : null
      readonly property var sourceWidget: srLoader.active  && srLoader.item  ? srLoader.item  : null
      readonly property var clock:        ckLoader.active  && ckLoader.item  ? ckLoader.item  : null
      readonly property var dmenu:        dmLoader.active  && dmLoader.item  ? dmLoader.item  : null
      readonly property var tasks:        tkLoader.active  && tkLoader.item  ? tkLoader.item  : null
      readonly property var notifWidget:  nfLoader.active  && nfLoader.item  ? nfLoader.item  : null
      readonly property var qsWidget:     qsLoader.active  && qsLoader.item  ? qsLoader.item  : null

      implicitWidth: {
        var _k = _wsKick
        if (modId === "separator") return 1
        if (modId === "spacer")    return 8
        var l = _activeLoader
        return (l && l.item) ? l.item.implicitWidth : 0
      }
      implicitHeight: {
        var _k = _wsKick
        if (modId === "separator") return 12
        if (modId === "spacer")    return 1
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

      Rectangle {
        visible:          modId === "separator"
        anchors.centerIn: parent
        width: 1; height: 12; radius: 1
        color: root.colTextDim; opacity: 0.25
      }

      Loader {
        id: mpLoader
        active: modId === "mediaplayer"
        anchors.centerIn: parent
        sourceComponent: Component {
          Media.MediaPlayer {
            isHorizontal: true; barPosition: root.barPosition
            showText: root.cfgMpShowText; textStatic: root.cfgMpTextStatic
            textColor: root.cfgMpTextColor; dimColor: root.cfgMpDimColor
            accentColor: root.colAccent; textMode: root.cfgMpTextMode
            scrollSpeed: root.cfgMpScrollSpeed; volumeStep: root.cfgMpVolumeStep
            scrollPauseMs: root.cfgMpScrollPauseMs; scrollWidth: root.cfgMpScrollWidth
            artworkSize: root.cfgMpArtworkSize; artworkRadius: root.cfgMpArtworkRadius
            bgEnabled: root.cfgMpBgEnabled; bgOpacity: root.cfgMpBgOpacity
            bgOpacityActive: root.cfgMpBgOpacityActive
            bgPaddingH: root.cfgMpBgPaddingH; bgPaddingV: root.cfgMpBgPaddingV
            bgColor: root.cfgMpBgColor; bgColorActive: root.cfgMpBgColorActive
            textColorActive: root.cfgMpTextColorActive; dimColorActive: root.cfgMpDimColorActive
            playerPriority: root.cfgMpPlayerPriority; idleInhibit: root.cfgMpIdleInhibit
            fontScale: root.cfgMpFontScale
            onClicked: root.mediaPlayerClicked()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: volLoader
        active: modId === "volume"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgVolTextColor; dimColor: root.cfgVolDimColor
            accentColor: root.cfgVolAccent; mutedColor: root.cfgVolMuted
            progressColor: root.cfgVolProgress; maxVol: root.cfgVolMaxVol
            showSink: root.cfgVolShowSink; showSource: root.cfgVolShowSource
            fontScale: root.cfgVolFontScale
            onSinkPanelRequested: root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: skLoader
        active: modId === "sink"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgVolTextColor; dimColor: root.cfgVolDimColor
            accentColor: root.cfgVolAccent; mutedColor: root.cfgVolMuted
            progressColor: root.cfgVolProgress; maxVol: root.cfgVolMaxVol
            showSink: true; showSource: false
            fontScale: root.cfgVolFontScale
            onSinkPanelRequested: root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: srLoader
        active: modId === "source"
        anchors.centerIn: parent
        sourceComponent: Component {
          Vol.Volume {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgVolTextColor; dimColor: root.cfgVolDimColor
            accentColor: root.cfgVolAccent; mutedColor: root.cfgVolMuted
            progressColor: root.cfgVolProgress; maxVol: root.cfgVolMaxVol
            showSink: false; showSource: true
            fontScale: root.cfgVolFontScale
            onSinkPanelRequested: root.sinkPanelRequested()
            onSourcePanelRequested: root.sourcePanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: ckLoader
        active: modId === "clock"
        anchors.centerIn: parent
        sourceComponent: Component {
          ClockModule.Clock {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgClkTextColor; dimColor: root.cfgClkDimColor
            accentColor: root.cfgClkAccent; dismissDelay: root.cfgClkDismissDelay
            fontScale: root.cfgClkFontScale
            onPanelRequested: root.clockPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: dmLoader
        active: modId === "dmenu"
        anchors.centerIn: parent
        sourceComponent: Component {
          DmenuModule.Dmenu {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgDmenuTextColor; dimColor: root.cfgDmenuDimColor
            accentColor: root.cfgDmenuAccent
            showIcon: root.cfgDmenuShowIcon; iconType: root.cfgDmenuIconType; showTitle: root.cfgDmenuShowTitle
            iconGlyph: root.cfgDmenuIconGlyph; emptyText: root.cfgDmenuEmptyText
            titleMaxWidth: root.cfgDmenuTitleMaxWidth; fontScale: root.cfgDmenuFontScale
            windowIconSize: root.cfgDmenuWindowIconSize; textStatic: root.cfgDmenuTextStatic
            scrollSpeed: root.cfgDmenuScrollSpeed; scrollPauseMs: root.cfgDmenuScrollPauseMs
            showWorkspace: root.cfgDmenuShowWorkspace; workspacePosition: root.cfgDmenuWorkspacePosition
            workspaceFormat: root.cfgDmenuWorkspaceFormat; workspaceChipWidth: root.cfgDmenuWorkspaceChipWidth
            workspaceIconMap: root.cfgDmenuWorkspaceIconMap
            workspaceIgnorePattern: root.cfgDmenuWorkspaceIgnorePattern
            onPanelRequested: root.dmenuRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: tkLoader
        active: modId === "tasks"
        anchors.centerIn: parent
        sourceComponent: Component {
          TasksModule.Tasks {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgTasksTextColor; dimColor: root.cfgTasksDimColor
            accentColor: root.cfgTasksAccent
            fontScale: root.cfgTasksFontScale
            onPanelRequested: root.tasksPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: qsLoader
        active: modId === "quicksettings"
        anchors.centerIn: parent
        sourceComponent: Component {
          QsModule.QuickSettings {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgQsTextColor; dimColor: root.cfgQsDimColor
            accentColor: root.cfgQsAccent
            fontScale: root.cfgQsFontScale
            onPanelRequested: root.quickSettingsPanelRequested()
          }
        }
      }

      Loader {
        id: nfLoader
        active: modId === "notifications"
        anchors.centerIn: parent
        sourceComponent: Component {
          NotifModule.Notifications {
            isHorizontal: true; barPosition: root.barPosition
            textColor: root.cfgNotifTextColor; dimColor: root.cfgNotifDimColor
            accentColor: root.cfgNotifAccent; mutedColor: root.cfgNotifMuted
            service: root.notifService
            fontScale: root.cfgNotifFontScale
            onPanelRequested: root.notificationsPanelRequested()
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Loader {
        id: wsLoader
        active: modId === "workspaces"
        anchors.centerIn: parent
        sourceComponent: Component {
          Modules.Workspaces {
            monitorName: modItem.monName
            orientation: "horizontal"
            barPosition: root.barPosition
            style: root.cfgWsStyle; iconsSort: root.cfgWsIconsSort
            iconMonochrome: root.cfgWsIconMonochrome; iconSpacing: root.cfgWsIconSpacing
            iconSize: root.cfgWsIconSize; showNumber: root.cfgWsShowNumber
            dotSize: root.cfgWsDotSize; fontSize: root.cfgWsFontSize
            bgOpacity: root.cfgWsBgOpacity; bgOpacityActive: root.cfgWsBgOpacityActive
            bgPaddingH: root.cfgWsBgPaddingH; bgPaddingV: root.cfgWsBgPaddingV
            showAddButton: root.cfgWsShowAddButton; showTooltip: root.cfgWsShowTooltip
            wsSpacing: root.cfgWsSpacing
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
            bgColor: root.colWsBg; bgColorActive: root.colWsBgActive
            bgBorderColor: Qt.rgba(root.colWsBorder.r, root.colWsBorder.g, root.colWsBorder.b, 0.12)
            bgBorderWidth: root.cfgWsBgBorderWidth
            bgBorderColorActive: root.cfgWsBgBorderColorActive
            bgBorderWidthActive: root.cfgWsBgBorderWidthActive
            bgPaddingHActive: root.cfgWsBgPaddingHActive; bgPaddingVActive: root.cfgWsBgPaddingVActive
            bgRadiusActive: root.cfgWsBgRadiusActive
            iconMonoColor: root.colIconMono; iconMonoColorActive: root.colIconMonoActive
            numberColor: root.colWsNumber; numberColorActive: root.colWsNumberActive
            numberBgEnabled: root.cfgWsNumberBgEnabled
            numberBgColor: root.colWsNumberBg; numberBgColorActive: root.colWsNumberBgActive
            numberBgRadius: root.cfgWsNumberBgRadius
            numberBgPaddingH: root.cfgWsNumberBgPaddingH; numberBgPaddingV: root.cfgWsNumberBgPaddingV
            numberSpacing: root.cfgWsNumberSpacing
            dotColor: root.colWsDot; dotActiveColor: root.colWsDotActive
            dotOccupiedColor: root.colWsDotOccupied; dotUrgentColor: root.colWsDotUrgent
          }
        }
        onItemChanged: if (item) root._updateRefs()
      }

      Connections {
        target: wsLoader.item
        ignoreUnknownSignals: true
        function onImplicitWidthChanged()  { modItem._wsKick++ }
        function onImplicitHeightChanged() { modItem._wsKick++ }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // LOBO — a peça central do notch.
  //
  // Geometria:
  //   - Lado que encosta na borda da tela (topo se pos=1, baixo se pos=3):
  //     plano, sem raio — termina reto na borda do monitor.
  //   - Lado de dentro (que aponta pra tela): arredondado com notchRadius.
  //   - Cantos laterais do lobo: côncavos (curva pra dentro) com
  //     concaveRadius — o efeito "Dynamic Island" de ilha flutuante.
  //
  // A côncavidade lateral é feita com Shape+PathSvg: desenhamos um arco
  // de raio concaveRadius que curva pra dentro do lobo, criando aquela
  // "mordida" nos cantos que é a assinatura visual do Dynamic Island.
  // ══════════════════════════════════════════════════════════════════════

  readonly property bool _facesDown: barPosition === 1

  // Constrói o path SVG do lobo: trapézio (mais largo rente à borda da
  // tela, estreito rumo ao desktop).
  //
  // A ponta que encosta no monitor fica SEMPRE reta e fixa em (w, y0) —
  // nunca é arredondada nem deslocada por nenhum raio. Só a ponta do
  // desktop é arredondada (notchRadius), e a parede lateral entre as duas
  // pontas é que se curva (concaveRadius), partindo fixa da ponta de cima
  // até encostar suavemente na quina de baixo.
  //
  // Isso também evita o bug do "bojo": o giro do fillet do desktop nunca
  // passa de 90° (ele vai de "direção da parede" pra "borda horizontal",
  // um giro de 90°-δ, sempre ≤90°), diferente de tentar arredondar a ponta
  // de cima, cujo giro seria 90°+δ — e um giro >90° tem seu ponto mais
  // largo NO MEIO do arco, não na ponta, o que gera o bojo.
  function _buildLobePath(w, h, r, cr, taper) {
    r = Math.max(0, r)
    // r nunca pode comer mais que a altura disponível nem mais que a
    // largura (só precisa caber na quina de baixo agora).
    r = Math.min(r, h - 1, w / 2 - 2)
    r = Math.max(0, r)

    taper = Math.max(0, taper || 0)
    // trava de segurança: taper não pode fechar a base nem passar do centro.
    taper = Math.min(taper, Math.max(0, w / 2 - r - 2))
    cr = Math.max(0, cr || 0)

    var sgnY = _facesDown ? 1 : -1
    var y0   = _facesDown ? 0 : h
    var sweep = _facesDown ? 1 : 0

    // Ângulo da parede a partir da vertical: o mesmo ângulo de uma reta
    // ligando a ponta de cima (w,y0) até o canto teórico de baixo
    // (w-taper, y0+h) — ou seja, com concaveRadius=0 a parede É essa reta.
    var delta = Math.atan2(taper, h)
    var u2x = -Math.sin(delta), u2y = sgnY * Math.cos(delta)
    var u3x = -1, u3y = 0

    var ax = w, ay = y0   // ponta fixa no monitor (nunca arredondada)

    // Fillet só na base (giro = 90°-δ, sempre seguro/≤90°): canto teórico
    // onde a parede encontraria a borda de baixo, arredondado com raio r.
    var pc2x = w - taper, pc2y = y0 + sgnY * h
    var aIn  = Math.atan2(u2y, u2x)
    var aOut = Math.atan2(u3y, u3x)
    var turn2 = ((aOut - aIn + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI
    var L2 = r * Math.tan(Math.abs(turn2) / 2)
    var t2InX  = pc2x - u2x * L2, t2InY  = pc2y - u2y * L2
    var t2OutX = pc2x + u3x * L2, t2OutY = pc2y + u3y * L2

    // Bezier cúbica da ponta fixa (ax,ay) até t2In. P2 fica sobre a MESMA
    // reta que liga ax a t2In (garante tangente = u2 em t2In, encaixando
    // suave na quina de baixo). P1 é o ponto livre: parte dessa mesma reta
    // (handleLen à frente de ax) mais um deslocamento PERPENDICULAR real —
    // é esse deslocamento perpendicular (não colinear!) que de fato
    // encurva a parede; concaveRadius controla o quanto ele empurra.
    // Sem isso, um ponto de controle colinear com ax/t2In sempre produz
    // reta, nunca um arco, não importa o valor de concaveRadius.
    var dx = t2InX - ax, dy = t2InY - ay
    var baseLen = Math.sqrt(dx * dx + dy * dy)
    var ubx = baseLen > 0.001 ? dx / baseLen : 0
    var uby = baseLen > 0.001 ? dy / baseLen : 1
    // normal perpendicular, sempre apontando pra DENTRO (rumo ao centro) —
    // apontar pra fora estouraria a borda, já que ax está bem na quina w.
    var nbx = -uby, nby = ubx
    if (nbx > 0) { nbx = -nbx; nby = -nby }

    var handleLen = baseLen / 3
    var baseP1x = ax + ubx * handleLen, baseP1y = ay + uby * handleLen
    var maxBowWidth = Math.max(0, baseP1x - (w / 2 + 2))
    var maxBowScale = handleLen * 0.9   // o "bojo" nunca pode dominar sobre o próprio raio da curva
    var bow = Math.min(cr, maxBowWidth, maxBowScale)
    var useCurve = bow > 0.5

    var p1x = baseP1x + nbx * bow, p1y = baseP1y + nby * bow
    var p2x = t2InX - u2x * handleLen, p2y = t2InY - u2y * handleLen

    var startX = w - ax, startY = ay

    var d = "M " + startX + "," + startY
    d += " L " + ax + "," + ay
    d += useCurve
      ? (" C " + p1x + "," + p1y + " " + p2x + "," + p2y + " " + t2InX + "," + t2InY)
      : (" L " + t2InX + "," + t2InY)
    if (r > 0.001) d += " A " + r + "," + r + " 0 0 " + sweep + " " + t2OutX + "," + t2OutY
    d += " L " + (w - t2OutX) + "," + t2OutY
    if (r > 0.001) d += " A " + r + "," + r + " 0 0 " + sweep + " " + (w - t2InX) + "," + t2InY
    d += useCurve
      ? (" C " + (w - p2x) + "," + p2y + " " + (w - p1x) + "," + p1y + " " + startX + "," + startY)
      : (" L " + startX + "," + startY)
    d += " Z"
    return d
  }

  // ── Lobo: Shape com cantos côncavos ────────────────────────────────────
  Item {
    id: lobeItem
    x: root._lobeX
    y: 0
    height: parent.height

    // Animação spring na largura — suave, não mecânica
    Behavior on x     { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    width: root._lobeW
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Shape {
      id: lobeShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor:   root.colBarBg
        strokeColor: "transparent"
        strokeWidth: 0
        PathSvg {
          path: root._buildLobePath(lobeItem.width, lobeItem.height,
                                    root.notchRadius, root.concaveRadius, root.notchTaper)
        }
      }
    }

    // ── Conteúdo do lobo ─────────────────────────────────────────────────
    Item {
      id: lobeContent
      anchors.centerIn: parent
      width:  leftRow.implicitWidth + centerRow.implicitWidth + rightRow.implicitWidth
              + (leftRow.implicitWidth  > 0 ? root.moduleSpacing : 0)
              + (rightRow.implicitWidth > 0 ? root.moduleSpacing : 0)
      height: parent.height

      // Slot Esquerda
      Row {
        id: leftRow
        objectName: "barSectionLeft"
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing

        Repeater {
          id: leftRep
          model: root.cfgModulesLeft
          delegate: Loader {
            id: leftLoader
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: { item.modId = modelData; item.isH = true; item.monName = root.monitorName }
            Binding { target: leftLoader.item; property: "monName"; value: root.monitorName; when: leftLoader.item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // Slot Centro
      Row {
        id: centerRow
        objectName: "barSectionCenter"
        anchors.centerIn: parent
        spacing: root.moduleSpacing

        Repeater {
          id: centerRep
          model: root.cfgModulesCenter
          delegate: Loader {
            id: centerLoader
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: { item.modId = modelData; item.isH = true; item.monName = root.monitorName }
            Binding { target: centerLoader.item; property: "monName"; value: root.monitorName; when: centerLoader.item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // Slot Direita
      Row {
        id: rightRow
        objectName: "barSectionRight"
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing

        Repeater {
          id: rightRep
          model: root.cfgModulesRight
          delegate: Loader {
            id: rightLoader
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: { item.modId = modelData; item.isH = true; item.monName = root.monitorName }
            Binding { target: rightLoader.item; property: "monName"; value: root.monitorName; when: rightLoader.item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }
    }
  }
}
