import Quickshell
import QtQuick
import QtQuick.Shapes
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
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
// Forma: o lobo tem cantos côncavos (estilo Dynamic Island) nos dois
// lados onde encontra a borda da tela, usando Shape+PathSvg.
// O lado de dentro da tela é arredondado normalmente.
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
  property var notifService:  null

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

  // ── Configs Volume ─────────────────────────────────────────────────────
  property bool  cfgVolShowSink:    true
  property bool  cfgVolShowSource:  false
  property real  cfgVolMaxVol:      1.5
  property color cfgVolTextColor:   Qt.rgba(1,1,1,0.9)
  property color cfgVolDimColor:    Qt.rgba(1,1,1,0.45)
  property color cfgVolAccent:      Qt.rgba(1,1,1,1.0)
  property color cfgVolMuted:       "#cf6679"
  property color cfgVolProgress:    "#474747"

  // ── Configs QuickSettings ──────────────────────────────────────────────
  property color cfgQsTextColor:    Qt.rgba(1,1,1,0.9)
  property color cfgQsDimColor:     Qt.rgba(1,1,1,0.45)
  property color cfgQsAccent:       Qt.rgba(1,1,1,1.0)

  // ── Configs Notifications ──────────────────────────────────────────────
  property color cfgNotifTextColor: Qt.rgba(1,1,1,0.9)
  property color cfgNotifDimColor:  Qt.rgba(1,1,1,0.45)
  property color cfgNotifAccent:    Qt.rgba(1,1,1,1.0)
  property color cfgNotifMuted:     "#cf6679"

  // ── Configs Clock ──────────────────────────────────────────────────────
  property color cfgClkTextColor:    Qt.rgba(1,1,1,0.9)
  property color cfgClkDimColor:     Qt.rgba(1,1,1,0.45)
  property color cfgClkAccent:       Qt.rgba(1,1,1,1.0)
  property int   cfgClkDismissDelay: 6000

  // ── Paleta ─────────────────────────────────────────────────────────────
  property color colBarBg:          "#0d0d0d"
  property color colBarBgPill:      "#161616"
  property color colText:           "#e8e8e8"
  property color colTextDim:        "#9a9a9a"
  property color colAccent:         "#ffb4a9"
  property color colAccentBg:       "#7d2b22"
  property color colAccentText:     "#5f150f"
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
  readonly property int moduleSpacing: pillMinSpacing

  // ── Estado de expansão ─────────────────────────────────────────────────
  property real _contentW: leftRow.implicitWidth + centerRow.implicitWidth + rightRow.implicitWidth
                           + (leftRow.implicitWidth  > 0 ? moduleSpacing : 0)
                           + (rightRow.implicitWidth > 0 ? moduleSpacing : 0)

  property real _lobeW:  Math.max(60, _contentW + lobePadH * 2)
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

  function _updateRefs() {
    root.mediaPlayer  = _findRef(leftRep,   "mediaPlayer")  || _findRef(centerRep, "mediaPlayer")  || _findRef(rightRep,  "mediaPlayer")
    root.volumeWidget = _findRef(leftRep,   "volumeWidget") || _findRef(centerRep, "volumeWidget") || _findRef(rightRep,  "volumeWidget")
    root.sinkWidget   = _findRef(leftRep,   "sinkWidget")   || _findRef(centerRep, "sinkWidget")   || _findRef(rightRep,  "sinkWidget")
    root.sourceWidget = _findRef(leftRep,   "sourceWidget") || _findRef(centerRep, "sourceWidget") || _findRef(rightRep,  "sourceWidget")
    root.clock        = _findRef(leftRep,   "clock")        || _findRef(centerRep, "clock")        || _findRef(rightRep,  "clock")
    root.notifWidget  = _findRef(leftRep,   "notifWidget")  || _findRef(centerRep, "notifWidget")  || _findRef(rightRep,  "notifWidget")
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
      readonly property var notifWidget:  nfLoader.active  && nfLoader.item  ? nfLoader.item  : null

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
            onPanelRequested: root.clockPanelRequested()
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

  // Constrói o path SVG do lobo com cantos côncavos laterais.
  // Clampamos r e cr para que r+cr ≤ h*0.45 — geometria sempre válida.
  function _buildLobePath(w, h, r, cr) {
    // Clampar: r+cr não pode exceder h.
    // Quando r+cr == h, o côncavo e convexo se encontram direto (sem
    // seção reta) — ainda válido e visualmente elegante como DI real.
    var total = r + cr
    if (total > h) {
      var scale = h / total
      r  = Math.floor(r  * scale)
      cr = Math.floor(cr * scale)
    }
    r  = Math.max(2, r)
    cr = Math.max(2, cr)
    var straight = Math.max(0, h - r - cr)

    var d = ""
    if (_facesDown) {
      d  = "M 0,0"
      d += " L " + w + ",0"
      d += " L " + w + "," + straight
      d += " A " + cr + "," + cr + " 0 0 0 " + (w - cr) + "," + (straight + cr)
      d += " A " + r  + "," + r  + " 0 0 1 " + (w - r)  + "," + h
      d += " L " + r  + "," + h
      d += " A " + r  + "," + r  + " 0 0 1 " + cr        + "," + (straight + cr)
      d += " A " + cr + "," + cr + " 0 0 0 0," + straight
      d += " Z"
    } else {
      d  = "M 0," + h
      d += " L " + w + "," + h
      d += " L " + w + "," + (h - straight)
      d += " A " + cr + "," + cr + " 0 0 0 " + (w - cr) + "," + (h - straight - cr)
      d += " A " + r  + "," + r  + " 0 0 0 " + (w - r)  + ",0"
      d += " L " + r  + ",0"
      d += " A " + r  + "," + r  + " 0 0 0 " + cr        + "," + (h - straight - cr)
      d += " A " + cr + "," + cr + " 0 0 0 0," + (h - straight)
      d += " Z"
    }
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
                                    root.notchRadius, root.concaveRadius)
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
