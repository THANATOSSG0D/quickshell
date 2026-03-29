import Quickshell
import QtQuick

Rectangle {
  id: root

  // 'required' removido — compatível com Loader (wsWrapper) e Repeater direto.
  // O Repeater injeta modelData via contexto QML automaticamente;
  // o Loader (wsWrapper) injeta via item.modelData = wrapper.modelData no onLoaded.
  property var modelData: null

  width:  12
  height: 12
  color:  "transparent"

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  Rectangle {
    anchors.centerIn: parent
    width:  root.modelData && root.modelData.active ? 10
          : (root.modelData && root.modelData.toplevels && root.modelData.toplevels.values.length > 0) ? 6 : 4
    height: width
    radius: width / 2
    color:  !root.modelData ? root.dotColor
          : root.modelData.active  ? root.dotActiveColor
          : root.modelData.urgent  ? root.dotUrgentColor
          : (root.modelData.toplevels && root.modelData.toplevels.values.length > 0)
            ? root.dotOccupiedColor
            : Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.25)

    Behavior on width {
      NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    MouseArea {
      anchors.fill: parent
      onClicked:    root.modelData && root.modelData.activate()
    }
  }
}
