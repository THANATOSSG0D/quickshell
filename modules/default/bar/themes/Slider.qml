import QtQuick

// Slider.qml — slider simples para uso interno no BarEditor.
Item {
  id: root
  height: 20

  property real  from:     0
  property real  to:       100
  property real  stepSize: 1
  property real  value:    50
  property color accent:   "#ffb4a9"
  property color track:    "#333333"

  signal moved()

  readonly property real _ratio: (value - from) / Math.max(1, to - from)

  Rectangle {
    id: trackRect
    anchors.verticalCenter: parent.verticalCenter
    anchors.left:  parent.left
    anchors.right: parent.right
    height: 4; radius: 2
    color: root.track

    Rectangle {
      anchors.left:   parent.left
      anchors.top:    parent.top
      anchors.bottom: parent.bottom
      radius: 2
      width: root._ratio * parent.width
      color: root.accent
    }
  }

  Rectangle {
    id: handle
    anchors.verticalCenter: parent.verticalCenter
    x: root._ratio * (root.width - width)
    width: 14; height: 14; radius: 7
    color: "white"
    Behavior on x { enabled: !sliderArea.pressed; NumberAnimation { duration: 80 } }
  }

  MouseArea {
    id: sliderArea
    anchors.fill: parent
    onPositionChanged: (mouse) => {
      var ratio = Math.max(0, Math.min(1, mouse.x / root.width))
      var raw   = root.from + ratio * (root.to - root.from)
      root.value = Math.round(raw / root.stepSize) * root.stepSize
      root.moved()
    }
    onClicked: (mouse) => {
      var ratio = Math.max(0, Math.min(1, mouse.x / root.width))
      var raw   = root.from + ratio * (root.to - root.from)
      root.value = Math.round(raw / root.stepSize) * root.stepSize
      root.moved()
    }
  }
}
