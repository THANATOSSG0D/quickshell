import qs

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root

  property bool grouped: false

  FavoritesConfig { id: config }

  implicitWidth: config.fixedWidth
  implicitHeight: gridHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  readonly property int rows: Math.max(1, Math.ceil(Math.max(1, config.apps.length) / Math.max(1, config.columns)))
  readonly property int cellSize: config.iconSize + 26
  readonly property int gridHeight: Math.min(config.fixedHeight, rows * cellSize + 24)

  Process {
    id: launchProc
    running: false
    property string cmd: ""
    command: cmd !== "" ? ["sh", "-c", cmd] : ["true"]
  }

  function launch(command) {
    if (!command) return
    launchProc.running = false
    launchProc.cmd = command
    launchProc.running = true
  }

  ColumnLayout {
    anchors.centerIn: parent
    spacing: 6

    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: config.apps.length === 0
      text: "nenhum app favorito"
      color: Colors[config.colorLabel]
      opacity: 0.5
      font.pixelSize: 11
    }

    GridLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: config.apps.length > 0
      columns: config.columns
      rowSpacing: 4
      columnSpacing: 4

      Repeater {
        model: config.apps
        delegate: ColumnLayout {
          required property var modelData
          Layout.alignment: Qt.AlignHCenter
          spacing: 2

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: root.cellSize - 6
            height: root.cellSize - 6
            radius: 10
            color: iconArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              color: Colors[config.colorValue]
              font { pixelSize: config.iconSize; family: "JetBrainsMono Nerd Font" }
            }

            MouseArea {
              id: iconArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launch(modelData.command)
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.cellSize + 10
            text: modelData.name
            color: Colors[config.colorLabel]
            opacity: 0.75
            font.pixelSize: 9
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
