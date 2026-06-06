import QtQuick
import QtQuick.Layouts

Rectangle {
  required property color colorDivider

  Layout.fillWidth: true
  width: parent ? parent.width : 0
  height: 1
  color: Qt.rgba(colorDivider.r, colorDivider.g, colorDivider.b, 0.4)
}
