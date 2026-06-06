import QtQuick

Rectangle {
  id: root

  required property string label
  required property bool   active
  required property color  colorAccent
  required property color  colorTextDim

  property string icon: ""

  signal chipClicked()

  height: 30
  width:  row.implicitWidth + 18
  radius: 6

  color: active
    ? Qt.rgba(colorAccent.r, colorAccent.g, colorAccent.b, 0.18)
    : (ma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
  border.color: active ? colorAccent : Qt.rgba(1,1,1,0.1)
  border.width: 1

  Behavior on color        { ColorAnimation { duration: 80 } }
  Behavior on border.color { ColorAnimation { duration: 80 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      visible:        root.icon !== ""
      text:           root.icon
      color:          root.active ? root.colorAccent : root.colorTextDim
      font.pixelSize: 10
      font.family:    "JetBrainsMono Nerd Font"
      anchors.verticalCenter: parent.verticalCenter
      Behavior on color { ColorAnimation { duration: 80 } }
    }
    Text {
      text:           root.label
      color:          root.active ? root.colorAccent : root.colorTextDim
      font.pixelSize: 10
      anchors.verticalCenter: parent.verticalCenter
      Behavior on color { ColorAnimation { duration: 80 } }
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.chipClicked()
  }
}
