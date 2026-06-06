import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  required property string label
  required property real   value
  required property real   from
  required property real   to
  required property real   step
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg

  property string unit: ""

  signal moved(real v)

  width:   parent ? parent.width : 0
  spacing: 10

  Text {
    text:                  root.label
    color:                 root.colorTextDim
    font.pixelSize:        11
    Layout.preferredWidth: 130
  }

  Item { Layout.fillWidth: true }

  Text {
    text:                  Math.round(root.value) + root.unit
    color:                 root.colorText
    font.pixelSize:        10
    font.family:           "JetBrainsMono Nerd Font"
    Layout.preferredWidth: 54
    horizontalAlignment:   Text.AlignRight
  }

  Item {
    Layout.preferredWidth: 130
    height: 20

    readonly property real ratio: (root.value - root.from) / Math.max(1, root.to - root.from)

    Rectangle {
      anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
      height: 4; radius: 2
      color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.8)

      Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        radius: 2
        width:  parent.parent.ratio * parent.width
        color:  root.colorAccent
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x:      parent.ratio * (parent.width - width)
      width:  14; height: 14; radius: 7; color: "white"
      Behavior on x { enabled: !sma.pressed; NumberAnimation { duration: 80 } }
    }

    MouseArea {
      id: sma
      anchors.fill: parent
      function apply(mx) {
        var r   = Math.max(0, Math.min(1, mx / parent.width))
        var raw = root.from + r * (root.to - root.from)
        root.moved(Math.round(raw / root.step) * root.step)
      }
      onPositionChanged: (m) => apply(m.x)
      onClicked:         (m) => apply(m.x)
    }
  }
}
