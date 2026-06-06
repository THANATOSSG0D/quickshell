import QtQuick
import QtQuick.Layouts

// CfgVolumeSlider — slider de volume 0–150% com marca visual nos 100%.
//
// Uso:
//   CfgVolumeSlider {
//     volume:  node.audio.volume    // 0.0 – 1.5
//     muted:   node.audio.muted
//     colorAccent: ...
//     onVolumeAdjusted: (v) => node.audio.volume = v
//     onMuteToggled:    ()  => node.audio.muted  = !node.audio.muted
//   }

RowLayout {
  id: root

  required property real  volume   // 0.0 – 1.5
  required property bool  muted
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorError  // cor quando > 100%

  signal volumeAdjusted(real v)
  signal muteToggled()

  spacing: 8
  width:   parent ? parent.width : 0

  // Ícone / mute
  Rectangle {
    width: 24; height: 24; radius: 5
    color: muteHov.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: 80 } }

    Text {
      anchors.centerIn: parent
      text: root.muted
        ? "\uf026"
        : (root.volume > 0.66 ? "\uf028" : (root.volume > 0.33 ? "\uf027" : "\uf026"))
      color:          root.muted ? root.colorError : root.colorTextDim
      font.pixelSize: 12
      font.family:    "JetBrainsMono Nerd Font"
    }

    MouseArea {
      id: muteHov
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.muteToggled()
    }
  }

  // Track
  Item {
    Layout.fillWidth: true
    height: 20

    // Proporção visual: 0–1.5 mapeado em 0–width
    readonly property real ratio: Math.min(1.5, Math.max(0, root.volume)) / 1.5

    // Track fundo
    Rectangle {
      id: track
      anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
      height: 5; radius: 3
      color:  Qt.rgba(1,1,1,0.1)

      // Preenchimento — muda de cor acima dos 100%
      Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        radius: 3
        width:  parent.parent.ratio * parent.width
        color:  root.volume > 1.0
          ? Qt.rgba(root.colorError.r, root.colorError.g, root.colorError.b, 0.85)
          : (root.muted ? Qt.rgba(1,1,1,0.2) : root.colorAccent)
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }

    // Marca nos 100% (2/3 do track já que max=150%)
    Rectangle {
      anchors.verticalCenter: track.verticalCenter
      x: (2/3) * parent.width - width/2
      width:  2; height: 10; radius: 1
      color:  Qt.rgba(1,1,1,0.35)
    }
    // Label "100%"
    Text {
      anchors { top: track.bottom; topMargin: 2 }
      x: (2/3) * parent.width - width/2
      text:           "100%"
      color:          Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.5)
      font.pixelSize: 7
      font.family:    "JetBrainsMono Nerd Font"
    }

    // Thumb
    Rectangle {
      id: thumb
      anchors.verticalCenter: parent.verticalCenter
      x: parent.ratio * (parent.width - width)
      width: 14; height: 14; radius: 7
      color: root.muted ? Qt.rgba(1,1,1,0.4) : "white"
      Behavior on x { enabled: !sma.pressed; NumberAnimation { duration: 60 } }
    }

    MouseArea {
      id: sma
      anchors.fill: parent
      function apply(mx) {
        var ratio = Math.max(0, Math.min(1, mx / parent.width))
        root.volumeAdjusted(ratio * 1.5)
      }
      onPositionChanged: (m) => { if (pressed) apply(m.x) }
      onClicked:         (m) => apply(m.x)
    }
  }

  // Valor
  Text {
    text:                  Math.round(root.volume * 100) + "%"
    color:                 root.volume > 1.0 ? root.colorError : root.colorText
    font.pixelSize:        9
    font.family:           "JetBrainsMono Nerd Font"
    Layout.preferredWidth: 36
    horizontalAlignment:   Text.AlignRight
    Behavior on color { ColorAnimation { duration: 120 } }
  }
}
