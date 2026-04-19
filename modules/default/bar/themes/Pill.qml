import Quickshell
import QtQuick
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
import "../../quicksettings" as QsModule
import "../../notifications" as NotifModule

Item {
  id: root

  // ── Layout (lido pelo Bar.qml) ─────────────────────────────────────────
  property int    barSize:       30
  property int    barMargin:     3
  property bool   pill:          true
  property int    pillWidth:     800
  property int    panelWidth:    400
  property string monitorName:   ""
  property bool   hasMediaPanel: true
  property int    barPosition:   2

  signal sinkPanelRequested()
  signal sourcePanelRequested()
  signal clockPanelRequested()
  signal quickSettingsPanelRequested()
  signal notificationsPanelRequested()

  // Refs coletadas do layout carregado — Bar.qml lê estas props
  property var mediaPlayer:   null
  property var volumeWidget:  null
  property var clock:         null
  property var notifWidget:   null

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
  property real   cfgWsBgOpacity:           0.0
  property real   cfgWsBgPaddingH:          8
  property real   cfgWsBgPaddingV:          2
  property bool   cfgWsShowAddButton:       true
  property color  cfgWsBgColorActive:        Qt.rgba(1,1,1,0.12)
  property real   cfgWsBgOpacityActive:      0.85
  property color  cfgWsBgBorderColorActive:  "transparent"
  property real   cfgWsBgBorderWidthActive:  0
  property real   cfgWsBgPaddingHActive:     6
  property real   cfgWsBgPaddingVActive:     2
  property real   cfgWsBgRadiusActive:       99

  // ── Configs MediaPlayer ────────────────────────────────────────────────
  property string cfgMpTextMode:        "artistAndTitle"
  property int    cfgMpScrollSpeed:     40
  property int    cfgMpScrollPauseMs:   1800
  property int    cfgMpScrollWidth:     140
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

  // ── Configs Volume ─────────────────────────────────────────────────────
  property bool  cfgVolShowSink:   true
  property bool  cfgVolShowSource: true
  property color cfgVolTextColor:  Qt.rgba(1,1,1,1.0)
  property color cfgVolDimColor:   Qt.rgba(1,1,1,0.5)
  property color cfgVolAccent:     Qt.rgba(1,1,1,1.0)
  property color cfgVolMuted:      "#cf6679"

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

  // ── Fundo da pill ──────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color:        root.colBarBgPill
    radius:       root.barSize / 2
  }

  // ── Loader do layout ───────────────────────────────────────────────────
  // Sempre ativo. Os Repeaters dentro usam cfgModules* como model diretamente
  // — quando os Bindings em Bar.qml atualizam as props, os Repeaters reagem.
  Loader {
    id: layoutLoader
    anchors.fill:    parent
    sourceComponent: root.isHorizontal ? horizontalComp : verticalComp

    onLoaded: {
      item.monitorName = root.monitorName
      root._updateRefs()
    }
  }

  function _updateRefs() {
    var lay = layoutLoader.item
    if (!lay) return
    root.mediaPlayer  = lay.mediaPlayer  || null
    root.volumeWidget = lay.volumeWidget || null
    root.clock        = lay.clock        || null
    root.notifWidget  = lay.notifWidget  || null
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

  // Quando módulos mudam, atualiza refs de clock/mediaPlayer/volume.
  onCfgModulesLeftChanged:   Qt.callLater(_updateRefs)
  onCfgModulesCenterChanged: Qt.callLater(_updateRefs)
  onCfgModulesRightChanged:  Qt.callLater(_updateRefs)
  onCfgModulesTopChanged:    Qt.callLater(_updateRefs)
  onCfgModulesMiddleChanged: Qt.callLater(_updateRefs)
  onCfgModulesBottomChanged: Qt.callLater(_updateRefs)

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
      readonly property var clock:        ckLoader.active  && ckLoader.item  ? ckLoader.item  : null
      readonly property var notifWidget:  nfLoader.active  && nfLoader.item  ? nfLoader.item  : null

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
            textColor:       root.cfgMpTextColor
            dimColor:        root.cfgMpDimColor
            accentColor:     root.colAccent
            textMode:        root.cfgMpTextMode
            scrollSpeed:     root.cfgMpScrollSpeed
            scrollPauseMs:   root.cfgMpScrollPauseMs
            scrollWidth:     root.cfgMpScrollWidth
            bgEnabled:       root.cfgMpBgEnabled
            bgOpacity:       root.cfgMpBgOpacity
            bgOpacityActive: root.cfgMpBgOpacityActive
            bgPaddingH:      root.cfgMpBgPaddingH
            bgPaddingV:      root.cfgMpBgPaddingV
            bgColor:         root.cfgMpBgColor
            bgColorActive:   root.cfgMpBgColorActive
            textColorActive: root.cfgMpTextColorActive
            dimColorActive:  root.cfgMpDimColorActive
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
            showSink:               root.cfgVolShowSink
            showSource:             root.cfgVolShowSource
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
            textColor:        root.cfgVolTextColor
            dimColor:         root.cfgVolDimColor
            accentColor:      root.colAccent
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
            textColor:    root.colText
            dimColor:     root.colTextDim
            accentColor:  root.colAccent
            mutedColor:   root.colWsDotUrgent
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
            style:               root.cfgWsStyle
            iconsSort:           root.cfgWsIconsSort
            iconMonochrome:      root.cfgWsIconMonochrome
            iconSpacing:         root.cfgWsIconSpacing
            bgOpacity:           root.cfgWsBgOpacity
            bgOpacityActive:     root.cfgWsBgOpacityActive
            bgPaddingH:          root.cfgWsBgPaddingH
            bgPaddingV:          root.cfgWsBgPaddingV
            showAddButton:       root.cfgWsShowAddButton
            bgColor:             root.colWsBg
            bgColorActive:       root.colWsBgActive
            bgBorderColor:       Qt.rgba(root.colWsBorder.r, root.colWsBorder.g, root.colWsBorder.b, 0.12)
            bgBorderWidth:       1
            bgBorderColorActive: root.cfgWsBgBorderColorActive
            bgBorderWidthActive: root.cfgWsBgBorderWidthActive
            bgPaddingHActive:    root.cfgWsBgPaddingHActive
            bgPaddingVActive:    root.cfgWsBgPaddingVActive
            bgRadiusActive:      root.cfgWsBgRadiusActive
            iconMonoColor:       root.colIconMono
            iconMonoColorActive: root.colIconMonoActive
            dotColor:            root.colWsDot
            dotActiveColor:      root.colWsDotActive
            dotOccupiedColor:    root.colWsDotOccupied
            dotUrgentColor:      root.colWsDotUrgent
          }
        }
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

      // Refs coletadas pelos Repeaters — usadas por root._updateRefs()
      property var mediaPlayer:  root._findRef(leftRep,   "mediaPlayer")
                               || root._findRef(centerRep, "mediaPlayer")
                               || root._findRef(rightRep,  "mediaPlayer")
      property var volumeWidget: root._findRef(leftRep,   "volumeWidget")
                               || root._findRef(centerRep, "volumeWidget")
                               || root._findRef(rightRep,  "volumeWidget")
      property var clock:        root._findRef(leftRep,   "clock")
                               || root._findRef(centerRep, "clock")
                               || root._findRef(rightRep,  "clock")
      property var notifWidget:  root._findRef(leftRep,   "notifWidget")
                               || root._findRef(centerRep, "notifWidget")
                               || root._findRef(rightRep,  "notifWidget")

      // ── Slot Esquerda ──────────────────────────────────────────────────
      Row {
        id: leftRow
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        z: 1   // fica acima do slot central (que tem z:0)

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
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        z: 1   // fica acima do slot central

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
      // Usa anchors.left/right delimitados pelos laterais para NUNCA sobrepor.
      // O Row interno usa anchors.centerIn do container — com 1 modulo fica
      // no centro absoluto da area disponivel; com N modulos ficam agrupados
      // no centro (identico ao Waybar).
      // Nota: o container nao e anchors.fill para nao cobrir os laterais.
      Item {
        anchors.left:           leftRow.right
        anchors.right:          rightRow.left
        anchors.leftMargin:     4
        anchors.rightMargin:    4
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        z: 0   // abaixo dos laterais

        Row {
          // anchors.centerIn centraliza no espaco disponivel entre left e right.
          // Com 1 modulo: centro absoluto da area.
          // Com N modulos: agrupados e centralizados juntos.
          anchors.centerIn: parent
          spacing: 6

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
      property var clock:        root._findRef(topRep,    "clock")
                               || root._findRef(middleRep, "clock")
                               || root._findRef(bottomRep, "clock")
      property var notifWidget:  root._findRef(topRep,    "notifWidget")
                               || root._findRef(middleRep, "notifWidget")
                               || root._findRef(bottomRep, "notifWidget")

      // ── Slot Topo ──────────────────────────────────────────────────────
      Column {
        id: topCol
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        z: 1

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
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        z: 1

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

      // ── Slot Centro ────────────────────────────────────────────────────
      // Delimitado entre topCol.bottom e bottomCol.top para nao sobrepor.
      // Column interno centralizado: 1 modulo = centro absoluto da area,
      // N modulos = agrupados e centralizados juntos (estilo Waybar).
      Item {
        anchors.top:              topCol.bottom
        anchors.bottom:           bottomCol.top
        anchors.topMargin:        4
        anchors.bottomMargin:     4
        anchors.horizontalCenter: parent.horizontalCenter
        width:                    parent.width
        z: 0

        Column {
          anchors.centerIn: parent
          spacing: 6

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
