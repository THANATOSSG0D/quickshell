import QtQuick

Item {
  id: root

  property var modelData: null
  property bool isHorizontal: true

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.55)
  property color dotUrgentColor:   "#f38ba8"

  readonly property bool _active:   modelData ? modelData.active : false
  readonly property bool _urgent:   modelData ? modelData.urgent : false
  readonly property bool _occupied: modelData
    ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false

  readonly property real _size:
    _active ? 8 : _occupied ? 5 : 3

  readonly property color _color:
    _active   ? dotActiveColor
    : _urgent   ? dotUrgentColor
    : _occupied ? dotOccupiedColor
    : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.22)

  // Container quadrado fixo — deixa o spacing do GridLayout controlar o gap
  implicitWidth:  16
  implicitHeight: 16

  Rectangle {
    anchors.centerIn: parent
    width:  root._size
    height: root._size
    radius: width / 2
    color:  root._color

    Behavior on width  { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
    Behavior on color  { ColorAnimation  { duration: 140 } }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.modelData && root.modelData.activate()
  }
}
