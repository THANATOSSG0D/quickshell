import QtQuick

Rectangle {
  id: root

  property var modelData: null

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  readonly property bool   _active:   modelData ? modelData.active : false
  readonly property bool   _urgent:   modelData ? modelData.urgent : false
  readonly property bool   _occupied: modelData ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false
  readonly property string _name:     modelData ? modelData.name   : ""

  // Círculo adapta ao número de dígitos — ws "10" cabe sem truncar
  readonly property real _minSize: 22
  readonly property real _textPad: 10
  implicitWidth:  Math.max(_minSize, labelText.implicitWidth + _textPad)
  implicitHeight: _minSize

  width:  implicitWidth
  height: implicitHeight
  radius: height / 2

  color: _active
    ? Qt.rgba(dotActiveColor.r, dotActiveColor.g, dotActiveColor.b, 0.90)
    : _occupied
      ? Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.08)
      : "transparent"

  border.color: _urgent
    ? dotUrgentColor
    : _active
      ? "transparent"
      : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.30)
  border.width: _urgent ? 1.5 : 1

  Behavior on color        { ColorAnimation { duration: 150 } }
  Behavior on border.color { ColorAnimation { duration: 150 } }
  Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

  Text {
    id: labelText
    anchors.centerIn: parent
    text:           root._name
    font.pixelSize: 10
    font.weight:    root._active ? Font.Medium : Font.Normal

    color: root._active ? root._contrastColor()
         : root._urgent ? root.dotUrgentColor
         : root._occupied
           ? Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.90)
           : Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.45)

    Behavior on color { ColorAnimation { duration: 150 } }
  }

  function _contrastColor() {
    var lum = 0.299 * dotActiveColor.r + 0.587 * dotActiveColor.g + 0.114 * dotActiveColor.b
    return lum > 0.5 ? "#1a1a1a" : "#f0f0f0"
  }

  MouseArea {
    anchors.fill: parent
    onClicked:    root.modelData && root.modelData.activate()
  }
}
