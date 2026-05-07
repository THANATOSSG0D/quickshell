import QtQuick
import QtQuick.Layouts
import "root:/"
import "."

Item {
  id: root

  property var entries: []
  property int focused: -1

  signal actionRequested(string cmd)
  signal closeRequested()
  signal focusIndexChanged(int idx)

  // ── Fundo ─────────────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color:        Qt.rgba(0, 0, 0, 0.72)
    MouseArea {
      anchors.fill: parent
      onClicked:    root.closeRequested()
    }
  }

  // ── Linha decorativa topo ─────────────────────────────────────────────────
  Rectangle {
    anchors.top:              parent.top
    anchors.topMargin:        48
    anchors.horizontalCenter: parent.horizontalCenter
    width:   120
    height:  2
    radius:  1
    color:   Colors.primary
    opacity: 0.5
  }

  // ── Container central ─────────────────────────────────────────────────────
  Column {
    anchors.centerIn: parent
    spacing:          32

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text:    "SESSÃO"
      color:   Colors.on_surface_variant
      opacity: 0.4
      font {
        family:        "Fira Sans"
        pixelSize:     11
        letterSpacing: 5
      }
    }

    // Mesma estrutura da versão que funcionava: Row + Repeater direto
    Row {
      spacing: 20
      anchors.horizontalCenter: parent.horizontalCenter

      Repeater {
        model: root.entries

        PowerMenuButton {
          required property var modelData
          required property int index

          entry:     modelData
          isFocused: root.focused === index

          onClicked: root.actionRequested(modelData.action)
          onHovered: {
            root.focused = index
            root.focusIndexChanged(index)
          }
        }
      }
    }
  }

  // ── Hints de teclado ──────────────────────────────────────────────────────
  Row {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom:           parent.bottom
      bottomMargin:     36
    }
    spacing: 24

    Repeater {
      model: [
        { key: "ESC",   desc: "fechar"    },
        { key: "Tab",   desc: "navegar"   },
        { key: "Enter", desc: "confirmar" }
      ]

      delegate: Row {
        required property var modelData
        spacing: 7

        Rectangle {
          width:   keyTxt.implicitWidth + 12
          height:  18
          radius:  4
          color:   Colors.surface_container_high
          border.color: Colors.outline_variant
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: keyTxt
            anchors.centerIn: parent
            text:  modelData.key
            color: Colors.on_surface_variant
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:    modelData.desc
          color:   Colors.on_surface_variant
          opacity: 0.45
          font { family: "Fira Sans"; pixelSize: 12 }
        }
      }
    }
  }
}
