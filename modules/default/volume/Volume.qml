import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
  id: volumeRoot

  property bool isHorizontal: true
  property int  barPosition:  2

  property color textColor:    "white"
  property color dimColor:     Qt.rgba(1, 1, 1, 0.5)
  property color accentColor:  "white"
  property color mutedColor:   "red"
  property color progressColor: "#474747"
  property real  maxVol:        1.5

  property bool showSink:   true
  property bool showSource: true
  // Multiplicador global de escala (barState.config.moduleScale) — antes
  // só existia o valor fixo 13/12px no ícone e o 24x24 do AudioIcon.
  property real fontScale:  1.0

  signal sinkPanelRequested()
  signal sourcePanelRequested()

  property var osdService: null

  PwObjectTracker {
    id: tracker
    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
  }

  readonly property var  sink:         Pipewire.defaultAudioSink
  readonly property var  source:       Pipewire.defaultAudioSource
  readonly property bool sinkMuted:    sink   && sink.audio   ? sink.audio.muted    : false
  readonly property bool sourceMuted:  source && source.audio ? source.audio.muted  : false
  readonly property real sinkVolume:   sink   && sink.audio   ? sink.audio.volume   : 0
  readonly property real sourceVolume: source && source.audio ? source.audio.volume : 0

  function toggleSinkMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    if (osdService) osdService.sinkShow()
  }
  function toggleSourceMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
    if (osdService) osdService.sourceShow()
  }

  function adjustSinkVolume(delta) {
    // Removido o guard de channelVolumes: ele era undefined mesmo com o
    // nó de áudio completamente funcional no Quickshell/Pipewire, causando
    // return prematuro. sink.audio.volume já está disponível e é suficiente
    // para ler e escrever o volume do sink.
    if (!sink || !sink.audio) return
    sink.audio.volume = Math.max(0, Math.min(volumeRoot.maxVol, sink.audio.volume + delta))
    if (sink.audio.volume > 0) sink.audio.muted = false
    if (osdService) osdService.sinkShow()
  }

  function adjustSourceVolume(delta) {
    if (!source || !source.audio) return
    source.audio.volume = Math.max(0, Math.min(1.0, source.audio.volume + delta))
    if (source.audio.volume > 0) source.audio.muted = false
    if (osdService) osdService.sourceShow()
  }

  implicitWidth:  isHorizontal ? hRow.implicitWidth  + Math.round(8 * volumeRoot.fontScale) : Math.round(24 * volumeRoot.fontScale)
  implicitHeight: isHorizontal ? hRow.implicitHeight + Math.round(4 * volumeRoot.fontScale) : vCol.implicitHeight + Math.round(8 * volumeRoot.fontScale)

  component AudioIcon: Item {
    id: iconRoot
    property string iconText:    "\uf028"
    property real   iconOpacity: 1.0
    property color  iconColor:   "white"
    property bool   isSink:      true

    signal leftClicked()
    signal rightClicked()
    signal scrolled(real delta)

    width: Math.round(24 * volumeRoot.fontScale); height: Math.round(24 * volumeRoot.fontScale)

    Text {
      anchors.centerIn: parent
      text:             parent.iconText
      color:            parent.iconColor
      opacity:          parent.iconOpacity
      font.pixelSize:   Math.round((parent.isSink ? 13 : 12) * volumeRoot.fontScale)
      font.family:      "JetBrainsMono Nerd Font"
      Behavior on opacity { NumberAnimation { duration: 150 } }
      Behavior on color   { ColorAnimation  { duration: 150 } }
    }

    MouseArea {
      anchors.fill:    parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled:    true

      onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton)  iconRoot.leftClicked()
        if (mouse.button === Qt.RightButton) iconRoot.rightClicked()
      }

      onWheel: (event) => {
        var dy    = event.angleDelta.y
        var dx    = event.angleDelta.x
        var delta = Math.abs(dy) >= Math.abs(dx) ? dy : -dx
        iconRoot.scrolled(delta > 0 ? 0.05 : -0.05)
        // Tooltip rico (mesmo padrão de MediaTooltip/ClockTooltip/QsTooltip)
        VolumeTooltip.update(iconRoot, volumeRoot, iconRoot.isSink, volumeRoot.barPosition)
      }

      onContainsMouseChanged: {
        if (containsMouse)
          VolumeTooltip.show(iconRoot, volumeRoot, iconRoot.isSink, volumeRoot.barPosition)
        else
          VolumeTooltip.hide()
      }
    }
  }

  function sinkIconText()    { return (sinkMuted || sinkVolume <= 0) ? "\uf026" : "\uf028" }
  function sinkIconOpacity() {
    if (sinkMuted || sinkVolume <= 0) return 1.0
    if (sinkVolume <= 0.33)           return 0.45
    if (sinkVolume <= 0.66)           return 0.72
    return 1.0
  }
  function sinkIconColor()   { return sinkMuted ? mutedColor : textColor }
  function sourceIconText()  { return (sourceMuted || sourceVolume <= 0) ? "\uf131" : "\uf130" }
  function sourceIconColor() { return sourceMuted ? mutedColor : dimColor }

  Row {
    id: hRow
    visible:          volumeRoot.isHorizontal
    anchors.centerIn: parent
    spacing: 6

    AudioIcon {
      visible:     volumeRoot.showSink
      isSink:      true
      iconText:    volumeRoot.sinkIconText()
      iconOpacity: volumeRoot.sinkIconOpacity()
      iconColor:   volumeRoot.sinkIconColor()
      onLeftClicked:  volumeRoot.toggleSinkMute()
      onRightClicked: volumeRoot.sinkPanelRequested()
      onScrolled: (d) => volumeRoot.adjustSinkVolume(d)
    }

    AudioIcon {
      visible:     volumeRoot.showSource
      isSink:      false
      iconText:    volumeRoot.sourceIconText()
      iconColor:   volumeRoot.sourceIconColor()
      onLeftClicked:  volumeRoot.toggleSourceMute()
      onRightClicked: volumeRoot.sourcePanelRequested()
      onScrolled: (d) => volumeRoot.adjustSourceVolume(d)
    }
  }

  Column {
    id: vCol
    visible:          !volumeRoot.isHorizontal
    anchors.centerIn: parent
    spacing: 6

    AudioIcon {
      visible:                  volumeRoot.showSink
      isSink:                   true
      iconText:                 volumeRoot.sinkIconText()
      iconOpacity:              volumeRoot.sinkIconOpacity()
      iconColor:                volumeRoot.sinkIconColor()
      anchors.horizontalCenter: parent.horizontalCenter
      onLeftClicked:  volumeRoot.toggleSinkMute()
      onRightClicked: volumeRoot.sinkPanelRequested()
      onScrolled: (d) => volumeRoot.adjustSinkVolume(d)
    }

    AudioIcon {
      visible:                  volumeRoot.showSource
      isSink:                   false
      iconText:                 volumeRoot.sourceIconText()
      iconColor:                volumeRoot.sourceIconColor()
      anchors.horizontalCenter: parent.horizontalCenter
      onLeftClicked:  volumeRoot.toggleSourceMute()
      onRightClicked: volumeRoot.sourcePanelRequested()
      onScrolled: (d) => volumeRoot.adjustSourceVolume(d)
    }
  }
}
