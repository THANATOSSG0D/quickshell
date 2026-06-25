import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  required property string label
  required property bool   checked
  required property color  colorAccent
  required property color  colorTextDim
  // Opcionais: caem pro tema (colorTextDim) em vez de branco fixo.
  // Pode sobrescrever passando ex: colorTrackOff: root.colorDivider
  property color  colorTrackOff: Qt.rgba(colorTextDim.r, colorTextDim.g, colorTextDim.b, 0.18)
  property color  colorKnob: "white"

  signal toggled()

  width: parent ? parent.width : 0

  Text {
    text:             root.label
    color:            root.colorTextDim
    font.pixelSize:   11
    Layout.fillWidth: true
  }

  Rectangle {
    width: 36; height: 20; radius: 10
    color: root.checked
      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.75)
      : root.colorTrackOff
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
      width:  14; height: 14; radius: 7
      color:  root.colorKnob
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - 3 : 3
      Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.toggled()
    }
  }
}
