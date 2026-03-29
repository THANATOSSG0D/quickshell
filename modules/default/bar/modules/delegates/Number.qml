import QtQuick

Rectangle {
  id: root

  // 'required' removido — compatível com Loader (wsWrapper) e Repeater direto.
  property var modelData: null

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  readonly property bool   _active: modelData ? modelData.active : false
  readonly property bool   _urgent: modelData ? modelData.urgent : false
  readonly property string _name:   modelData ? modelData.name   : ""

  implicitWidth:  24
  implicitHeight: 24
  width:  implicitWidth
  height: implicitHeight
  radius: width / 2

  color: _active
    ? Qt.rgba(dotActiveColor.r, dotActiveColor.g, dotActiveColor.b, 0.9)
    : "transparent"

  border.color: _urgent
    ? dotUrgentColor
    : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.5)
  border.width: 1

  Behavior on color { ColorAnimation { duration: 120 } }

  Text {
    anchors.centerIn: parent
    text:           root._name
    color:          root._active ? root._contrastColor()
                  : root._urgent ? root.dotUrgentColor
                  : Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.9)
    font.pixelSize: 10
    Behavior on color { ColorAnimation { duration: 120 } }
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
