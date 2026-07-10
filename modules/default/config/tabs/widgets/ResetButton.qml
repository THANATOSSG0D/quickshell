import QtQuick

Item {
  id: root
  property color colorAccent
  property string label: "restaurar padrões"
  signal clicked()

  height: 32

  Rectangle {
    id: btn
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    height: 22; width: row.implicitWidth + 14; radius: 6
    color: ma.containsMouse
      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
      : "transparent"
    border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b,
                          ma.containsMouse ? 0.5 : 0.25)
    border.width: 1
    Behavior on color        { ColorAnimation { duration: 60 } }
    Behavior on border.color { ColorAnimation { duration: 60 } }

    Row {
      id: row; anchors.centerIn: parent; spacing: 5
      Text {
        text: "󰑙"; color: root.colorAccent
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: root.label; color: root.colorAccent
        font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea {
      id: ma; anchors.fill: parent; hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.clicked()
    }
  }
}
