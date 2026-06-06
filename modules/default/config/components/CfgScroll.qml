import QtQuick
import QtQuick.Layouts

Flickable {
  id: root

  default property alias children: col.data

  anchors { fill: parent; margins: 18 }
  contentHeight: col.implicitHeight + 24
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: col
    width: parent.width
    spacing: 11
  }
}
