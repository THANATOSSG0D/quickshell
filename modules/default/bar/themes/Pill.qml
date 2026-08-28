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

Item {
  id: root

  // ── Layout (lido pelo Bar.qml) ─────────────────────────────────────────
  property int    barSize:       30
  property int    barMargin:     3
  property bool   pill:          true
  property int    panelWidth:    400
  property string monitorName:   ""
  property bool   hasMediaPanel: true
  property int    barPosition:   2

  // ── Largura mínima configurável (injetada pelo Bar.qml via editor) ─────
  property int minPillWidth:   400
  // Espaço mínimo garantido entre o slot central e cada lateral.
  // Ex: 20px → o centro nunca chega a menos de 20px do left ou do right.
  property int pillMinSpacing: 20

  // ── Expansão da pill quando popup está aberto ───────────────────────────
  // activePopupW: largura do popup atualmente visível (0 quando nenhum está aberto).
  // anyPanelOpen: true quando qualquer popup da barra está aberto.
  // Injetadas reativamente pelo Bar.qml via Binding.
  property int  activePopupW: 0
  property bool anyPanelOpen: false

  // popupPillPadding: margem extra além da largura do popup para que a pill
  // fique visivelmente maior e "abrace" o popup dos dois lados. Configurável
  // via BarTabBar (seção DIMENSÕES DA BARRA) — o default aqui só vale antes
  // do Bar.qml injetar o valor de barState.config.popupPillPadding.
  property int popupPillPadding: 32

  // Liga/desliga o esticamento da pill pra acompanhar popups mais largos.
  // Desligado: a pill fica sempre no tamanho natural do conteúdo (_naturalW),
  // e os popups abrem "por cima", sem a barra reagir — mesmo conceito e
  // mesmo nome (sem prefixo de tema) do notchExpandForPopups do Notch.qml.
  // Configurável via BarTabBar (seção DIMENSÕES DA BARRA).
  property bool pillExpandForPopups: true

  // _naturalW: largura mínima da pill quando nenhum popup está aberto.
  // _targetWidth: cresce para activePopupW + padding quando popup aberto,
  //               volta para _naturalW quando fecha.
  readonly property int _naturalW: Math.max(minPillWidth, _measuredContentWidth)
  readonly property int _targetWidth: {
    if (pillExpandForPopups && anyPanelOpen && activePopupW > 0) {
      var expanded = activePopupW + popupPillPadding
      if (expanded > _naturalW) return expanded
    }
    return _naturalW
  }

  implicitWidth:  _targetWidth
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation {
      duration: 400
      easing.type:      Easing.OutBack
      easing.overshoot: 0.35
    }
  }

  // _measuredContentWidth: largura mínima necessária para que os três slots
  // caibam sem colisão — calculada pelos Repeaters do layout.
  //
  // Raciocínio geométrico (pill horizontal simétrica):
  //   • O centro fica ancorado ao meio da pill.
  //   • Para que não colida com os laterais, o lado mais largo (left ou right)
  //     precisa de espaço em ambos os lados do centro.
  //   • Largura mínima = max(leftW, rightW)*2 + centerW + margens + espaçamentos.
  property int _measuredContentWidth: 0

  signal sinkPanelRequested()
  signal sourcePanelRequested()
  signal clockPanelRequested()
  signal dmenuRequested()
  signal tasksPanelRequested()
  signal quickSettingsPanelRequested()
  signal notificationsPanelRequested()
  signal mediaPlayerClicked()
  signal refsUpdated()

  // Refs coletadas do layout carregado — Bar.qml lê estas props
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
  // Só um par é não-nulo por vez, conforme root.isHorizontal.
  property var leftGroupItem:   null
  property var rightGroupItem:  null
  property var topGroupItem:    null
  property var bottomGroupItem: null

  // Injetado pelo Bar.qml após o onLoaded
  property var notifService: null

  readonly property bool isHorizontal: barPosition === 1 || barPosition === 3

  // ── Listas de módulos por slot ─────────────────────────────────────────
  // Iniciam VAZIAS — o Bar.qml injeta os valores do JSON via _set() logo após
  // ── Módulos por slot ──────────────────────────────────────────────────
  // Mantidos em sincronia pelos Binding declarativos em Bar.qml via
  // barState.modules* (propriedades diretas, rastreáveis pelo QML).
  // O layoutLoader é sempre ativo — os Repeaters reagem às mudanças
  // nestas props diretamente, sem _reloadLayout() ou timers.
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

  // ── Fundo da pill ──────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color:        root.colBarBgPill
    radius:       root.barSize / 2
  }

  // ── Loader do layout ───────────────────────────────────────────────────
  // anchors.fill: parent → o layout ocupa todo o espaço da pill.
  // A largura real é medida pela função _updateContentWidth() chamada pelos
  // Repeaters quando os módulos mudam — não dependemos de implicitWidth
  // de items com anchors (que o QML não calcula automaticamente).
  Loader {
    id: layoutLoader
    anchors.fill: parent
    sourceComponent: root.isHorizontal ? horizontalComp : verticalComp

    onLoaded: {
      item.monitorName = root.monitorName
      root._updateRefs()
      // Mede o conteúdo inicial logo após o layout carregar
      Qt.callLater(root._updateContentWidth)
    }
  }

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

  // ── Medição da largura/altura real do conteúdo ───────────────────────
  // Para layout HORIZONTAL (hRoot): lê lay.contentWidth.
  // Para layout VERTICAL   (vRoot): lê lay.contentHeight.
  //
  // Em ambos os casos, o valor resultante é gravado em _measuredContentWidth,
  // que representa a DIMENSÃO LONGA da pill (largura para barras horizontais,
  // altura para barras verticais). Bar.qml usa isso via Pill.implicitWidth
  // → effectivePillWidth → tamanho real do PanelWindow.
  //
  // A directAssignment via onContentWidthChanged / onContentHeightChanged
  // (dentro de hRoot / vRoot) trata as mudanças reactivas normais.
  // Esta função é o caminho imperativo chamado por Qt.callLater quando os
  // Rows/Columns mudam de tamanho (ex: módulos carregados, workspaces adicionados).
  //
  // HYSTERESIS: só actualiza _measuredContentWidth se a diferença for ≥ 4px.
  // Razão: as Behavior animations (150ms) em wsWrapper.implicitWidth/Height
  // causam que layout.implicitHeight oscile ±1-2px durante a animação de
  // troca de workspace activo. Sem histérése, cada frame propaga para
  // effectivePillWidth → pillSideMargin, que oscila entre 164-166 a cada
  // 100ms (visível no log de cursor). Ícones de workspace têm ≥ 20px, logo
  // 4px de histerése filtra o ruído sem perder mudanças reais.
  function _updateContentWidth() {
    var lay = layoutLoader.item
    if (!lay) return
    // contentHeight tem prioridade sobre contentWidth para layouts verticais
    var w = lay.contentHeight || lay.contentWidth || 0
    if (w > 0 && Math.abs(w - root._measuredContentWidth) >= 4) {
      root._measuredContentWidth = w
    }
  }

  // isHorizontal muda quando a posição da barra muda (h↔v).
  // O binding sourceComponent já troca o componente; só propaga monitorName.
  onIsHorizontalChanged: {
    Qt.callLater(function() {
      if (layoutLoader.item) layoutLoader.item.monitorName = root.monitorName
    })
  }
  onMonitorNameChanged: {
    if (layoutLoader.item) layoutLoader.item.monitorName = monitorName
  }

  // Quando módulos mudam, atualiza refs de clock/mediaPlayer/volume e a largura.
  onCfgModulesLeftChanged:   { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }
  onCfgModulesCenterChanged: { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }
  onCfgModulesRightChanged:  { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }
  onCfgModulesTopChanged:    { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }
  onCfgModulesMiddleChanged: { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }
  onCfgModulesBottomChanged: { Qt.callLater(_updateRefs); Qt.callLater(_updateContentWidth) }

  // ══════════════════════════════════════════════════════════════════════
  // Componente de módulo individual
  //
  // Instanciado por cada Repeater de cada slot. Dado um modId (string),
  // ativa o Loader correto. Expõe mediaPlayer/volumeWidget/clock para
  // o layout pai coletar.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: moduleItemComp

    Item {
      id: modItem
      property string modId:   ""
      property bool   isH:     true
      property string monName: ""

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
        if (modId === "separator") return isH ? 1  : 16
        if (modId === "spacer")    return isH ? 12 : 1
        var l = _activeLoader
        return (l && l.item) ? l.item.implicitWidth : 0
      }
      implicitHeight: {
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
      //
      // Cada módulo usa Component {} interno para que os bindings QML
      // sejam declarativos (ligados directamente a root.cfg*).
      // Isso garante que mudanças em runtime propagam automaticamente
      // sem precisar de Connections ou onLoaded.

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
        // Notifica o layout pai quando o item aparece (para coletar a ref)
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
        // Quando o Loader (re)carrega o item Workspaces, actualiza refs e
        // dispara uma nova medição. Necessário porque o item pode ter sido
        // criado após _updateContentWidth ter corrido na primeira vez.
        onItemChanged: {
          if (item) root._updateRefs()
          Qt.callLater(root._updateContentWidth)
        }
      }

      // ── Propagação reactiva de mudanças dinâmicas do módulo Workspaces ──
      //
      // Problema: quando o utilizador cria ou remove um workspace (botão "+",
      // fechar workspace), Hyprland.workspaces.values muda → o GridLayout do
      // Workspaces.qml recalcula → bg.width muda → Workspaces.implicitWidth
      // muda. Esta cadeia DEVERIA chegar até Row.onWidthChanged e disparar
      // _updateContentWidth. Porém, modItem.implicitWidth lê
      //   var l = _activeLoader; l.item.implicitWidth
      // e o QML engine pode não criar a dependência reactiva correcta através
      // de uma indireção de property var.
      //
      // Solução: Connections explícito em wsLoader.item. Quando implicitWidth
      // ou implicitHeight muda (workspaces adicionados/removidos), forçamos
      // _updateContentWidth para que a pill se expanda/contraia em tempo real.
      Connections {
        target: wsLoader.item
        ignoreUnknownSignals: true
        function onImplicitWidthChanged()  { Qt.callLater(root._updateContentWidth) }
        function onImplicitHeightChanged() { Qt.callLater(root._updateContentWidth) }
      }
    }
  }

  // ── Helper: varre um Repeater buscando a primeira ref não-nula ─────────
  function _findRef(repeater, prop) {
    for (var i = 0; i < repeater.count; i++) {
      var loaderItem = repeater.itemAt(i)        // este é o Loader do delegate
      var mod = loaderItem ? loaderItem.item : null  // este é o moduleItemComp
      if (mod && mod[prop]) return mod[prop]
    }
    return null
  }

  // ── Helper: acha o PRÓPRIO delegate (modItem) que corresponde a um modId
  // ─────────────────────────────────────────────────────────────────────
  // Diferente de _findRef (que retorna um WIDGET INTERNO, ex: o conteúdo
  // do Tasks, carregado via Loader+anchors.centerIn — que muitas vezes só
  // tem implicitWidth, não width real), isto retorna o próprio wrapper
  // (moduleItemComp) que o Row/Column efetivamente posiciona e dimensiona
  // — geometria 100% confiável pra alinhamento de popup.
  function _findModuleItem(repeater, modId) {
    for (var i = 0; i < repeater.count; i++) {
      var loaderItem = repeater.itemAt(i)
      var mod = loaderItem ? loaderItem.item : null
      if (mod && mod.modId === modId) return mod
    }
    return null
  }

  // ══════════════════════════════════════════════════════════════════════
  // HORIZONTAL — left | center | right
  //
  // • left  ancora-se à esquerda
  // • right ancora-se à direita
  // • center fica num Item que ocupa o espaço entre os dois lados com
  //   clip:true, e o Row interno fica anchors.centerIn: parent →
  //   SEMPRE centrado na pill inteira, independente do tamanho dos lados
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: horizontalComp

    Item {
      id: hRoot
      anchors.fill:        parent
      anchors.leftMargin:  10
      anchors.rightMargin: 10
      property string monitorName: ""

      // contentWidth: largura mínima necessária sem colisão entre os slots.
      //
      // O centro é ancorado no meio → para não colidir com left nem right,
      // o maior dos dois laterais determina o espaço necessário em cada lado.
      // Fórmula: max(leftW, rightW)*2 + centerW + espaçamento mínimo*2 + margens
      //
      // pillMinSpacing vem do root (injetado pelo Bar.qml) e garante uma folga
      // mínima entre o centro e cada lateral.
      readonly property int contentWidth: {
        var lw  = leftRow.width
        var rw  = rightRow.width
        var cw  = centerInnerRow.width
        var gap = root.pillMinSpacing
        // Lado dominante × 2 garante simetria; +gap*2 adiciona folga em cada lado
        return Math.max(lw, rw) * 2 + cw + gap * 2 + 40
      }

      // Propaga para root sempre que contentWidth muda.
      // Propaga para root sempre que contentWidth muda.
      // Histérése de 4px: filtra oscilações de 1-2px das animações dos
      // módulos sem perder mudanças reais (ícone ≥ 20px por workspace).
      onContentWidthChanged: {
        if (Math.abs(contentWidth - root._measuredContentWidth) >= 4)
          root._measuredContentWidth = contentWidth
      }

      // Refs coletadas pelos Repeaters — usadas por root._updateRefs()
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

      // Refs dos próprios GRUPOS (Rows) — usados pra alinhar popups à
      // borda do grupo de módulos (popupXAlign: "group") em vez da borda
      // da tela. leftRow/rightRow são ids diretos deste Component, então
      // a referência é trivial (sem precisar de _findRef).
      // Devolve o delegate (modItem) do módulo modId, seja qual for o slot
      // onde ele estiver — usado por Bar.qml pra âncoras de popup confiáveis.
      function moduleItemAt(modId) {
        return root._findModuleItem(leftRep, modId)
            || root._findModuleItem(centerRep, modId)
            || root._findModuleItem(rightRep, modId)
      }

      property var leftGroupItem:  leftRow
      property var rightGroupItem: rightRow

      // ── Slot Esquerda ──────────────────────────────────────────────────
      Row {
        id: leftRow
        objectName: "barSectionLeft"
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        z: 1   // fica acima do slot central (que tem z:0)
        // Quando workspaces ou módulos mudam a largura deste slot,
        // actualiza a medição global da pill.
        onWidthChanged: Qt.callLater(root._updateContentWidth)

        Repeater {
          id: leftRep
          model: root.cfgModulesLeft
          delegate: Loader {
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: {
              item.modId   = modelData
              item.isH     = true
              item.monName = hRoot.monitorName
            }
            Binding { target: item; property: "monName"; value: hRoot.monitorName; when: item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // ── Slot Direita ───────────────────────────────────────────────────
      Row {
        id: rightRow
        objectName: "barSectionRight"
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        z: 1   // fica acima do slot central
        onWidthChanged: Qt.callLater(root._updateContentWidth)

        Repeater {
          id: rightRep
          model: root.cfgModulesRight
          delegate: Loader {
            required property string modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: {
              item.modId   = modelData
              item.isH     = true
              item.monName = hRoot.monitorName
            }
            Binding { target: item; property: "monName"; value: hRoot.monitorName; when: item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // ── Slot Centro ────────────────────────────────────────────────────
      // anchors.fill: parent → o container ocupa o hRoot INTEIRO.
      //
      // Por quê: com anchors.left/right limitados pelos laterais, o centro
      // do container só coincide com o centro da pill quando
      // leftRow.width == rightRow.width. Na prática, os slots são assimétricos
      // (ex: mediaplayer à esq, clock+volume à dir) e o centerInnerRow ficava
      // deslocado para o lado mais curto.
      //
      // Com anchors.fill: parent, centerInnerRow.anchors.centerIn: parent
      // posiciona no centro geométrico exato do hRoot (= centro da pill).
      // leftRow e rightRow têm z:1 — cobrem visualmente qualquer sobreposição.
      // clip:true impede transbordamento para fora das bordas da pill se o
      // conteúdo central for maior que o espaço disponível.
      //
      // A fórmula contentWidth já garante que a pill se expande o suficiente
      // para que não haja sobreposição real:
      //   Math.max(lw, rw)*2 + cw + gap*2 + 40
      // onde os +40 = 20px de margens do hRoot (10+10) + 20px de folga extra.
      Item {
        id: centerRowContainer
        anchors.fill: parent   // ← era: anchors.left/right limitados por laterais
        z: 0                   // abaixo dos laterais (z:1)
        clip: true             // safety net: evita que um centro muito largo
                               // vaze para fora dos limites visuais da pill

        Row {
          id: centerInnerRow
          objectName: "barSectionCenter"
          anchors.centerIn: parent
          spacing: 6
          // Quando a largura do centro muda (ex: workspaces mudou),
          // propaga a actualização da medição global.
          onWidthChanged: Qt.callLater(root._updateContentWidth)

          Repeater {
            id: centerRep
            model: root.cfgModulesCenter
            delegate: Loader {
              required property string modelData
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              sourceComponent: moduleItemComp
              onLoaded: {
                item.modId   = modelData
                item.isH     = true
                item.monName = hRoot.monitorName
              }
              Binding { target: item; property: "monName"; value: hRoot.monitorName; when: item !== null }
              onItemChanged: root._updateRefs()
            }
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VERTICAL — top | middle | bottom
  //
  // • top ancora-se ao topo
  // • bottom ancora-se ao rodapé
  // • middle é um Item que ocupa o espaço entre os dois com clip:true,
  //   e o Column interno fica anchors.centerIn:parent
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: verticalComp

    Item {
      id: vRoot
      anchors.fill:         parent
      anchors.topMargin:    10
      anchors.bottomMargin: 10
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

      // Refs dos grupos (Columns) — equivalente vertical de leftGroupItem/
      // rightGroupItem, usado por popupXAlign:"group" em barras verticais.
      // Equivalente vertical de hRoot.moduleItemAt().
      function moduleItemAt(modId) {
        return root._findModuleItem(topRep, modId)
            || root._findModuleItem(middleRep, modId)
            || root._findModuleItem(bottomRep, modId)
      }

      property var topGroupItem:    topCol
      property var bottomGroupItem: bottomCol

      // ── Altura mínima para os três slots não se sobreporem ──────────────
      // Análogo ao contentWidth do hRoot (layout horizontal).
      //
      // Raciocínio (pill vertical simétrica):
      //   • O middle fica centrado no vRoot inteiro.
      //   • Para não colidir com top nem bottom, o slot mais alto dos dois
      //     determina quanto espaço é necessário em cada lado do middle.
      //   • Altura mínima = max(topH, bottomH)*2 + middleH + margens + espaçamentos.
      //
      // Este valor é lido por _updateContentWidth → _measuredContentWidth
      // → Pill.implicitWidth → Bar.qml.effectivePillWidth → altura real da pill.
      readonly property int contentHeight: {
        var th  = topCol.height
        var bh  = bottomCol.height
        var mh  = middleCol.implicitHeight
        var gap = root.pillMinSpacing
        // Mesmo raciocínio do contentWidth horizontal:
        // topMargin(10) + bottomMargin(10) + gap*2 + 20 de folga extra = +40
        return Math.max(th, bh) * 2 + mh + gap * 2 + 40
      }

      // Propaga para root sempre que contentHeight muda.
      // Histérése de 4px: mesma razão do hRoot.onContentWidthChanged.
      onContentHeightChanged: {
        if (Math.abs(contentHeight - root._measuredContentWidth) >= 4)
          root._measuredContentWidth = contentHeight
      }

      // ── Slot Topo ──────────────────────────────────────────────────────
      Column {
        id: topCol
        objectName: "barSectionTop"
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        z: 1
        // Propaga mudanças de altura (novos módulos carregados) para
        // a medição global da pill — igual ao onWidthChanged dos Rows horizontais.
        onHeightChanged: Qt.callLater(root._updateContentWidth)

        Repeater {
          id: topRep
          model: root.cfgModulesTop
          delegate: Loader {
            required property string modelData
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: {
              item.modId   = modelData
              item.isH     = false
              item.monName = vRoot.monitorName
            }
            Binding { target: item; property: "monName"; value: vRoot.monitorName; when: item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // ── Slot Rodape ────────────────────────────────────────────────────
      Column {
        id: bottomCol
        objectName: "barSectionBottom"
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        z: 1
        onHeightChanged: Qt.callLater(root._updateContentWidth)

        Repeater {
          id: bottomRep
          model: root.cfgModulesBottom
          delegate: Loader {
            required property string modelData
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            sourceComponent: moduleItemComp
            onLoaded: {
              item.modId   = modelData
              item.isH     = false
              item.monName = vRoot.monitorName
            }
            Binding { target: item; property: "monName"; value: vRoot.monitorName; when: item !== null }
            onItemChanged: root._updateRefs()
          }
        }
      }

      // ── Slot Centro (vertical) ─────────────────────────────────────────
      // Mesma lógica do layout horizontal: anchors.fill: parent garante que
      // o Column interno (anchors.centerIn: parent) fica no centro geométrico
      // exato do vRoot — não no espaço residual entre topCol e bottomCol.
      // topCol/bottomCol têm z:1 e cobrem visualmente qualquer sobreposição.
      // clip:true impede transbordamento para fora da pill.
      Item {
        anchors.fill:             parent
        anchors.horizontalCenter: parent.horizontalCenter
        width:                    parent.width
        z: 0
        clip: true

        Column {
          id: middleCol                   // ← id necessário para contentHeight
          objectName: "barSectionMiddle"
          anchors.centerIn: parent
          spacing: 6
          // Propaga crescimento dinâmico do middle (workspaces adicionados)
          onHeightChanged: Qt.callLater(root._updateContentWidth)

          Repeater {
            id: middleRep
            model: root.cfgModulesMiddle
            delegate: Loader {
              required property string modelData
              anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
              sourceComponent: moduleItemComp
              onLoaded: {
                item.modId   = modelData
                item.isH     = false
                item.monName = vRoot.monitorName
              }
              Binding { target: item; property: "monName"; value: vRoot.monitorName; when: item !== null }
              onItemChanged: root._updateRefs()
            }
          }
        }
      }
    }
  }
}
