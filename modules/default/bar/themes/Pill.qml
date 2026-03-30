import Quickshell
import QtQuick
import "../modules" as Modules
import "../../volume" as Vol
import "../../mediaPlayer/" as Media
import "../../clock" as ClockModule
import "../../quicksettings" as QsModule

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

  property var mediaPlayer:  layoutLoader.item ? layoutLoader.item.mediaPlayer  : null
  property var volumeWidget: layoutLoader.item ? layoutLoader.item.volumeWidget : null
  property var clock:        layoutLoader.item ? layoutLoader.item.clock        : null

  readonly property bool isHorizontal: barPosition === 1 || barPosition === 3

  // ── Configs workspaces ─────────────────────────────────────────────────
  property string cfgWsStyle:              "icons"
  property string cfgWsIconsSort:          "position"
  property bool   cfgWsIconMonochrome:     true
  property int    cfgWsIconSpacing:        4
  property real   cfgWsBgOpacity:          0.0
  property real   cfgWsBgPaddingH:         8
  property real   cfgWsBgPaddingV:         2
  property bool   cfgWsShowAddButton:      true
  property color  cfgWsBgColorActive:       Qt.rgba(1,1,1,0.12)
  property real   cfgWsBgOpacityActive:     0.85
  property color  cfgWsBgBorderColorActive: "transparent"
  property real   cfgWsBgBorderWidthActive: 0
  property real   cfgWsBgPaddingHActive:    6
  property real   cfgWsBgPaddingVActive:    2
  property real   cfgWsBgRadiusActive:      99

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

  Loader {
    id: layoutLoader
    anchors.fill:    parent
    sourceComponent: root.isHorizontal ? horizontalComp : verticalComp
    onLoaded: item.monitorName = root.monitorName
  }

  onIsHorizontalChanged: {
    var name = monitorName
    layoutLoader.sourceComponent = null
    layoutLoader.sourceComponent = isHorizontal ? horizontalComp : verticalComp
    if (layoutLoader.item) layoutLoader.item.monitorName = name
  }
  onMonitorNameChanged: {
    if (layoutLoader.item) layoutLoader.item.monitorName = monitorName
  }

  // ══════════════════════════════════════════════════════════════════════
  // HORIZONTAL
  //
  // Layout: [ MediaPlayer ] -------- [ Workspaces ] [ Clock | Volume ]
  //
  // Workspaces fica centralizado no espaço total da pill.
  // Clock e Volume ficam agrupados à direita (sem conflito de anchors).
  // MediaPlayer fica à esquerda.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: horizontalComp

    Item {
      id: hRoot
      anchors.fill:        parent
      anchors.leftMargin:  10
      anchors.rightMargin: 10
      property string monitorName: ""
      property alias  mediaPlayer:  mp
      property alias  volumeWidget: volH
      property alias  clock:        ckH

      // Esquerda: MediaPlayer
      Media.MediaPlayer {
        id: mp
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        isHorizontal:           true
        textColor:              root.cfgMpTextColor
        dimColor:               root.cfgMpDimColor
        accentColor:            root.colAccent
        textMode:               root.cfgMpTextMode
        scrollSpeed:            root.cfgMpScrollSpeed
        scrollPauseMs:          root.cfgMpScrollPauseMs
        scrollWidth:            root.cfgMpScrollWidth
        bgEnabled:              root.cfgMpBgEnabled
        bgOpacity:              root.cfgMpBgOpacity
        bgOpacityActive:        root.cfgMpBgOpacityActive
        bgPaddingH:             root.cfgMpBgPaddingH
        bgPaddingV:             root.cfgMpBgPaddingV
        bgColor:                root.cfgMpBgColor
        bgColorActive:          root.cfgMpBgColorActive
        textColorActive:        root.cfgMpTextColorActive
        dimColorActive:         root.cfgMpDimColorActive
      }

      // Direita: QuickSettings + Clock + separador + Volume, agrupados num Row
      Row {
        id: rightRow
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // ── Botão QuickSettings ────────────────────────────────────────
        QsModule.QuickSettings {
          anchors.verticalCenter: parent.verticalCenter
          isHorizontal:           true
          barPosition:            root.barPosition
          textColor:              root.cfgVolTextColor
          dimColor:               root.cfgVolDimColor
          accentColor:            root.colAccent
          onPanelRequested:       root.quickSettingsPanelRequested()
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width:   1; height: 14; radius: 1
          color:   root.cfgClkDimColor
          opacity: 0.3
        }

        ClockModule.Clock {
          id: ckH
          anchors.verticalCenter: parent.verticalCenter
          isHorizontal:           true
          barPosition:            root.barPosition
          textColor:              root.cfgClkTextColor
          dimColor:               root.cfgClkDimColor
          accentColor:            root.cfgClkAccent
          dismissDelay:           root.cfgClkDismissDelay
          onPanelRequested:       root.clockPanelRequested()
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width:   1; height: 14; radius: 1
          color:   root.cfgClkDimColor
          opacity: 0.3
        }

        Vol.Volume {
          id: volH
          anchors.verticalCenter: parent.verticalCenter
          isHorizontal:           true
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

      // Centro: Workspaces, ancorado entre mp e rightRow
      Modules.Workspaces {
        id: wsH
        anchors.centerIn:    parent
        anchors.leftMargin:     8
        anchors.rightMargin:    8
        monitorName:         hRoot.monitorName
        orientation:         "horizontal"
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

  // ══════════════════════════════════════════════════════════════════════
  // VERTICAL
  //
  // Layout (de cima pra baixo):
  //   MediaPlayer (topo)
  //   Workspaces  (centro — entre mp e grupo inferior)
  //   Clock       (acima do volume, separado por linha)
  //   Volume      (rodapé)
  //
  // Workspaces NÃO fica dentro de Column com Clock.
  // Clock fica entre Workspaces e Volume, todos via anchors independentes.
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: verticalComp

    Item {
      id: vRoot
      anchors.fill:         parent
      anchors.topMargin:    10
      anchors.bottomMargin: 10
      property string monitorName: ""
      property alias  mediaPlayer:  mp
      property alias  volumeWidget: volV
      property alias  clock:        ckV

      // Topo: MediaPlayer
      Media.MediaPlayer {
        id: mp
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        isHorizontal:             false
        textColor:                root.cfgMpTextColor
        dimColor:                 root.cfgMpDimColor
        accentColor:              root.colAccent
        textMode:                 root.cfgMpTextMode
        scrollSpeed:              root.cfgMpScrollSpeed
        scrollPauseMs:            root.cfgMpScrollPauseMs
        scrollWidth:              root.cfgMpScrollWidth
        bgEnabled:                root.cfgMpBgEnabled
        bgOpacity:                root.cfgMpBgOpacity
        bgOpacityActive:          root.cfgMpBgOpacityActive
        bgPaddingH:               root.cfgMpBgPaddingH
        bgPaddingV:               root.cfgMpBgPaddingV
        bgColor:                  root.cfgMpBgColor
        bgColorActive:            root.cfgMpBgColorActive
        textColorActive:          root.cfgMpTextColorActive
        dimColorActive:           root.cfgMpDimColorActive
      }

      // ── Botão QuickSettings (vertical, abaixo do MediaPlayer) ─────────
      QsModule.QuickSettings {
        id: qsV
        anchors.top:              mp.bottom
        anchors.topMargin:        6
        anchors.horizontalCenter: parent.horizontalCenter
        isHorizontal:             false
        barPosition:              root.barPosition
        textColor:                root.cfgVolTextColor
        dimColor:                 root.cfgVolDimColor
        accentColor:              root.colAccent
        onPanelRequested:         root.quickSettingsPanelRequested()
      }

      // Rodapé: Volume
      Vol.Volume {
        id: volV
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        isHorizontal:             false
        textColor:                root.cfgVolTextColor
        dimColor:                 root.cfgVolDimColor
        accentColor:              root.cfgVolAccent
        mutedColor:               root.cfgVolMuted
        showSink:                 root.cfgVolShowSink
        showSource:               root.cfgVolShowSource
        barPosition:              root.barPosition
        onSinkPanelRequested:     root.sinkPanelRequested()
        onSourcePanelRequested:   root.sourcePanelRequested()
      }

      // Clock — acima do Volume, ancorado a ele
      ClockModule.Clock {
        id: ckV
        anchors.bottom:           volV.top
        anchors.bottomMargin:     8
        anchors.horizontalCenter: parent.horizontalCenter
        isHorizontal:             false
        barPosition:              root.barPosition
        textColor:                root.cfgClkTextColor
        dimColor:                 root.cfgClkDimColor
        accentColor:              root.cfgClkAccent
        dismissDelay:             root.cfgClkDismissDelay
        onPanelRequested:         root.clockPanelRequested()
      }

      // Separador entre Workspaces e Clock
      Rectangle {
        id: vSep
        anchors.bottom:           ckV.bottom
        anchors.topMargin:     8
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16; height: 1; radius: 1
        color:   root.cfgClkDimColor
        opacity: 0.2
      }

      // Workspaces — ocupa o espaço entre MediaPlayer e separador
      Modules.Workspaces {
        id: wsV
        anchors.centerIn: parent
        monitorName:         vRoot.monitorName
        orientation:         "vertical"
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
