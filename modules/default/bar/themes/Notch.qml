import Quickshell
import QtQuick
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
import "../../quicksettings" as QsModule
import "../../notifications" as NotifModule

// ════════════════════════════════════════════════════════════════════════
// NOTCH — uma aba pendurada na borda da tela.
//
// Mesma base estrutural do Embrace.qml (janela já do tamanho do lobo,
// faixa fina inserida dentro dela) — mas o "lobo" central aqui NÃO é
// simétrico/arredondado dos dois lados: ele fica achatado (raio 0) no
// lado encostado na borda real da tela, e arredondado só no lado de
// dentro — como se fosse uma aba/gaveta pendurada ali, no estilo do
// notch de câmera de um notebook. As pontas da barra também ganham
// pequenas peças nos cantos, da mesma cor, sugerindo que a barra nasce
// da própria curva do canto do monitor.
//
// pill = false — como os outros temas não-Pill, a janela ocupa a tela
// inteira. Mesmo bloco de cor sólida (colBarBg), sem gradiente.
//
// Como nos outros temas da família, toda a parte de configuração
// (cfgWs*/cfgMp*/cfgVol*/cfgQs*/cfgNotif*/cfgClk*, moduleItemComp) é
// mantida idêntica.
// ════════════════════════════════════════════════════════════════════════

Item {
  id: root
  anchors.fill: parent   // tema estático (não-pill) — ocupa toda a PanelWindow

  // ── Layout (lido pelo Bar.qml) ─────────────────────────────────────────
  property int    barSize:       44
  property int    barMargin:     6
  property bool   pill:          false
  property int    panelWidth:    400
  property string monitorName:   ""
  property bool   hasMediaPanel: true
  property int    barPosition:   4

  // ── Props de compatibilidade com o contrato do Pill (não usadas aqui —
  // ver explicação completa no Dock.qml) ─────────────────────────────────
  property int  minPillWidth:   400
  property int  pillMinSpacing: 10
  property int  activePopupW:   0
  property bool anyPanelOpen:   false

  signal sinkPanelRequested()
  signal sourcePanelRequested()
  signal clockPanelRequested()
  signal quickSettingsPanelRequested()
  signal notificationsPanelRequested()
  signal mediaPlayerClicked()
  signal refsUpdated()

  property var mediaPlayer:   null
  property var volumeWidget:  null
  property var sinkWidget:    null
  property var sourceWidget:  null
  property var clock:         null
  property var notifWidget:   null

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

  // ── Configs Volume ─────────────────────────────────────────────────────
  property bool  cfgVolShowSink:    true
  property bool  cfgVolShowSource:  true
  property real  cfgVolMaxVol:      1.5
  property color cfgVolTextColor:   Qt.rgba(1,1,1,1.0)
  property color cfgVolDimColor:    Qt.rgba(1,1,1,0.5)
  property color cfgVolAccent:      Qt.rgba(1,1,1,1.0)
  property color cfgVolMuted:       "#cf6679"
  property color cfgVolProgress:    "#474747"

  // ── Configs QuickSettings ──────────────────────────────────────────────
  property color cfgQsTextColor:    Qt.rgba(1,1,1,1.0)
  property color cfgQsDimColor:     Qt.rgba(1,1,1,0.5)
  property color cfgQsAccent:       Qt.rgba(1,1,1,1.0)

  // ── Configs Notifications ──────────────────────────────────────────────
  property color cfgNotifTextColor: Qt.rgba(1,1,1,1.0)
  property color cfgNotifDimColor:  Qt.rgba(1,1,1,0.5)
  property color cfgNotifAccent:    Qt.rgba(1,1,1,1.0)
  property color cfgNotifMuted:     "#cf6679"

  // ── Configs Clock ──────────────────────────────────────────────────────
  property color cfgClkTextColor:    Qt.rgba(1,1,1,1.0)
  property color cfgClkDimColor:     Qt.rgba(1,1,1,0.5)
  property color cfgClkAccent:       Qt.rgba(1,1,1,1.0)
  property int   cfgClkDismissDelay: 8000

  // ── Paleta ─────────────────────────────────────────────────────────────
  property color colBarBg:          "#0e0e0e"
  property color colBarBgPill:      "#131313"
  property color colText:           "#e2e2e2"
  property color colTextDim:        "#c6c6c6"
  property color colAccent:         "#ffb4a9"
  property color colAccentBg:       "#7d2b22"
  property color colAccentText:     "#5f150f"
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

  // ── Aparência específica do Embrace (constantes de implementação, não
  // expostas no schema/editor) ────────────────────────────────────────────
  property int  stripThickness: 20            // espessura visível da faixa fina (bem menor que barSize)
  property int  capRadius:    14             // cantos arredondados nas pontas da faixa principal
  property int  lobeRadius:   28             // arredondado SÓ no lado de dentro da tela (ver corpo)
  property int  lobePad:      10             // padding do conteúdo dentro do lobo, no eixo principal
  property int  slotSpacing:  pillMinSpacing // espaço entre módulos — ligado ao slider "Espaçamento mín."
  property int  edgeInset:    16             // um pouco maior — dá espaço pra peça de canto não encavalar o 1º módulo
  property int  cornerSize:   22             // extensão das peças de canto, no eixo principal da barra

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
      readonly property var notifWidget:  nfLoader.active  && nfLoader.item  ? nfLoader.item  : null

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
            onPanelRequested: root.clockPanelRequested()
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

  // ── Coleta refs do layout actual (left/center/right OU top/middle/bottom)
  function _updateRefs() {
    var lay = layoutLoader.item
    if (!lay) return
    root.mediaPlayer  = lay.mediaPlayer  || null
    root.volumeWidget = lay.volumeWidget || null
    root.sinkWidget   = lay.sinkWidget   || null
    root.sourceWidget = lay.sourceWidget || null
    root.clock        = lay.clock        || null
    root.notifWidget  = lay.notifWidget  || null
    root.refsUpdated()
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

  // ══════════════════════════════════════════════════════════════════════
  // HORIZONTAL — left | center | right
  //
  // A janela já nasce do tamanho da gaveta (barSize = altura total). A
  // faixa principal é fina e fica inserida (centrada) dentro dessa altura;
  // a gaveta do slot central preenche a altura inteira da janela, achatada
  // no lado que encosta na borda real da tela e arredondada só no lado de
  // dentro — a silhueta de um notch pendurado, não um lobo simétrico.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: horizontalComp

    Item {
      id: hRoot
      anchors.fill: parent
      property string monitorName: ""

      readonly property bool topFacesDown: root.barPosition === 1   // barra no topo → conteúdo fica abaixo

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
      property var notifWidget:  root._findRef(leftRep,   "notifWidget")
                               || root._findRef(centerRep, "notifWidget")
                               || root._findRef(rightRep,  "notifWidget")

      // ── Faixa principal — fina, inserida dentro da janela (que já nasce
      // do tamanho do lobo) ─────────────────────────────────────────────
      Rectangle {
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.stripThickness
        color:  root.colBarBg
        radius: root.capRadius
      }

      // ── Gaveta — achatada no lado que encosta na borda da tela,
      // arredondada no lado de dentro. Preenche a altura real da janela.
      Rectangle {
        id: lobe
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter:   parent.verticalCenter
        width:  centerRow.width + root.lobePad * 2
        height: parent.height
        color:  root.colBarBg
        visible: root.cfgModulesCenter.length > 0
        topLeftRadius:     hRoot.topFacesDown ? 0 : root.lobeRadius
        topRightRadius:    hRoot.topFacesDown ? 0 : root.lobeRadius
        bottomLeftRadius:  hRoot.topFacesDown ? root.lobeRadius : 0
        bottomRightRadius: hRoot.topFacesDown ? root.lobeRadius : 0
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      }

      // ── Cantos — pequenas peças que "nascem" da curva da tela,
      // preenchendo a altura real da janela igual a gaveta ─────────────
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width:  root.cornerSize
        height: parent.height
        color:  root.colBarBg
        topLeftRadius:    hRoot.topFacesDown ? 0 : root.capRadius
        bottomLeftRadius: hRoot.topFacesDown ? root.capRadius : 0
      }
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width:  root.cornerSize
        height: parent.height
        color:  root.colBarBg
        topRightRadius:    hRoot.topFacesDown ? 0 : root.capRadius
        bottomRightRadius: hRoot.topFacesDown ? root.capRadius : 0
      }

      // ── Slot esquerda ──────────────────────────────────────────────────
      Row {
        id: leftRow
        anchors.left:           parent.left
        anchors.leftMargin:     root.edgeInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.slotSpacing

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

      // ── Slot direita ─────────────────────────────────────────────────
      Row {
        id: rightRow
        anchors.right:          parent.right
        anchors.rightMargin:    root.edgeInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.slotSpacing

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

      // ── Slot central — fica por cima do lobo, sem fundo próprio ───────
      Item {
        anchors.fill: parent
        clip: false

        Row {
          id: centerRow
          anchors.centerIn: parent
          spacing: root.slotSpacing

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
  // Mesma ideia, eixo trocado: a gaveta do slot do meio fica achatada no
  // lado que encosta na borda real da tela, arredondada no lado de dentro.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: verticalComp

    Item {
      id: vRoot
      anchors.fill: parent
      property string monitorName: ""

      readonly property bool outwardIsRight: root.barPosition === 4   // barra à esquerda → fora é a direita

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
      property var notifWidget:  root._findRef(topRep,    "notifWidget")
                               || root._findRef(middleRep, "notifWidget")
                               || root._findRef(bottomRep, "notifWidget")

      // ── Faixa principal — fina, inserida dentro da janela (que já nasce
      // do tamanho do lobo) ─────────────────────────────────────────────
      Rectangle {
        anchors.top:              parent.top
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width:  root.stripThickness
        color:  root.colBarBg
        radius: root.capRadius
      }

      // ── Gaveta — achatada no lado que encosta na borda da tela,
      // arredondada no lado de dentro. Preenche a largura real da janela.
      Rectangle {
        id: lobe
        anchors.verticalCenter:   parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width:  parent.width
        height: middleCol.height + root.lobePad * 2
        color:  root.colBarBg
        visible: root.cfgModulesMiddle.length > 0
        topLeftRadius:     vRoot.outwardIsRight ? 0 : root.lobeRadius
        bottomLeftRadius:  vRoot.outwardIsRight ? 0 : root.lobeRadius
        topRightRadius:    vRoot.outwardIsRight ? root.lobeRadius : 0
        bottomRightRadius: vRoot.outwardIsRight ? root.lobeRadius : 0
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      }

      // ── Cantos — pequenas peças que "nascem" da curva da tela,
      // preenchendo a largura real da janela igual a gaveta ────────────
      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.cornerSize
        width:  parent.width
        color:  root.colBarBg
        topLeftRadius:  vRoot.outwardIsRight ? 0 : root.capRadius
        topRightRadius: vRoot.outwardIsRight ? root.capRadius : 0
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.cornerSize
        width:  parent.width
        color:  root.colBarBg
        bottomLeftRadius:  vRoot.outwardIsRight ? 0 : root.capRadius
        bottomRightRadius: vRoot.outwardIsRight ? root.capRadius : 0
      }

      // ── Slot superior ────────────────────────────────────────────────
      Column {
        id: topCol
        anchors.top:              parent.top
        anchors.topMargin:        root.edgeInset
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.slotSpacing

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

      // ── Slot inferior ────────────────────────────────────────────────
      Column {
        id: bottomCol
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     root.edgeInset
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.slotSpacing

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

      // ── Slot do meio — fica por cima do lobo, sem fundo próprio ───────
      Item {
        anchors.fill: parent
        clip: false

        Column {
          id: middleCol
          anchors.centerIn: parent
          spacing: root.slotSpacing

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
