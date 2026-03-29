import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  // 'required' removido — compatível com Loader (wsWrapper) e Repeater direto.
  property var modelData: null

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  readonly property bool   _active:    modelData ? modelData.active : false
  readonly property bool   _urgent:    modelData ? modelData.urgent : false
  readonly property bool   _occupied:  modelData ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false
  readonly property string _name:      modelData ? modelData.name   : ""

  // Cor de contraste para texto sobre fundo ativo
  readonly property color _textOnActive: {
    var lum = 0.299 * dotActiveColor.r + 0.587 * dotActiveColor.g + 0.114 * dotActiveColor.b
    return lum > 0.5 ? Qt.rgba(0.1, 0.1, 0.1, 1) : Qt.rgba(0.94, 0.94, 0.94, 1)
  }

  implicitWidth:  row.implicitWidth + 12
  implicitHeight: 24
  width:  implicitWidth
  height: implicitHeight
  radius: height / 2

  color: _active
    ? Qt.rgba(dotActiveColor.r, dotActiveColor.g, dotActiveColor.b, 0.9)
    : "transparent"

  border.color: _urgent
    ? dotUrgentColor
    : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.5)
  border.width: 1

  Behavior on color { ColorAnimation { duration: 120 } }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Rectangle {
      width:  6
      height: 6
      radius: 3
      color: root._active   ? root._textOnActive
           : root._urgent   ? root.dotUrgentColor
           : root._occupied ? Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.9)
           :                  Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.4)
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
      text:           root._name
      color:          root._active ? root._textOnActive
                    : root._urgent ? root.dotUrgentColor
                    :                Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.9)
      font.pixelSize: 10
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked:    root.modelData && root.modelData.activate()
  }
}
