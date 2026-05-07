import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
  id: root

  property var  entry:     ({})
  property bool isFocused: false

  signal clicked()
  signal hovered()

  width:  160
  height: 180

  // ── Scale no hover/foco ───────────────────────────────────────────────────
  scale: isFocused ? 1.06 : 1.0
  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

  // ── Glow externo ─────────────────────────────────────────────────────────
  Rectangle {
    anchors.centerIn: parent
    width:   parent.width  + 18
    height:  parent.height + 18
    radius:  26
    color:   "transparent"
    border.color: Colors.primary
    border.width: 1
    opacity: isFocused ? 0.30 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
  }

  // ── Card ─────────────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius:       20

    color: isFocused
      ? Qt.rgba(Colors.primary_container.r, Colors.primary_container.g, Colors.primary_container.b, 0.22)
      : Qt.rgba(Colors.surface_container.r,  Colors.surface_container.g,  Colors.surface_container.b,  0.90)

    border.color: isFocused ? Colors.primary : Colors.outline_variant
    border.width: 1

    Behavior on color        { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    // Linha de acento no topo do card
    Rectangle {
      anchors.top:              parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width:   isFocused ? 56 : 0
      height:  2
      radius:  1
      color:   Colors.primary
      Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
  }

  // ── Conteúdo ──────────────────────────────────────────────────────────────
  ColumnLayout {
    anchors {
      fill:         parent
      topMargin:    26
      bottomMargin: 18
      leftMargin:   12
      rightMargin:  12
    }
    spacing: 8

    // Ícone
    Text {
      Layout.alignment: Qt.AlignHCenter
      text:  entry.text ?? "?"
      color: isFocused ? Colors.primary : Colors.on_surface_variant
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 42 }
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Divisor
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      width:   isFocused ? 30 : 14
      height:  1
      color:   isFocused ? Colors.primary : Colors.outline_variant
      opacity: 0.6
      Behavior on width { NumberAnimation { duration: 200 } }
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Label
    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      text:  (entry.label ?? "").toUpperCase()
      color: isFocused ? Colors.on_primary_container : Colors.on_surface_variant
      horizontalAlignment: Text.AlignHCenter
      font { family: "Fira Sans"; pixelSize: 11; letterSpacing: 2.5; bold: true }
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Keybind badge
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      visible: (entry.keybind ?? "") !== ""
      width:   kbLabel.implicitWidth + 14
      height:  kbLabel.implicitHeight + 6
      radius:  5
      color:   isFocused
        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
        : Colors.surface_container_highest
      border.color: isFocused ? Colors.primary : Colors.outline_variant
      border.width: 1
      Behavior on color        { ColorAnimation { duration: 160 } }
      Behavior on border.color { ColorAnimation { duration: 160 } }

      Text {
        id: kbLabel
        anchors.centerIn: parent
        text:  (entry.keybind ?? "").toUpperCase()
        color: isFocused ? Colors.primary : Colors.outline
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
        Behavior on color { ColorAnimation { duration: 160 } }
      }
    }
  }

  // ── Mouse ─────────────────────────────────────────────────────────────────
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape:  Qt.PointingHandCursor
    onEntered:    root.hovered()
    onClicked:    root.clicked()
  }
}
