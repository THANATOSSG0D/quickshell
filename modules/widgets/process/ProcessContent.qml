import qs

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root

  property bool grouped: false

  ProcessConfig { id: config }

  property var procList: []   // [{ name, cpu, mem }], já ordenado pelo ps

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  Process {
    id: psProc
    running: false
    command: ["ps", "-eo", "comm,%cpu,%mem",
      "--sort=-" + (config.sortBy === "ram" ? "%mem" : "%cpu"),
      "--no-headers"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").slice(0, config.count)
        const list = []
        for (const line of lines) {
          const m = line.trim().match(/^(.+?)\s+([\d.]+)\s+([\d.]+)$/)
          if (!m) continue
          list.push({ name: m[1], cpu: parseFloat(m[2]), mem: parseFloat(m[3]) })
        }
        root.procList = list
      }
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (!psProc.running) psProc.running = true }
  }

  // trocar config.sortBy já refaz o comando do Process (é uma binding),
  // e o próximo tick do Timer acima reordena — não precisa de mais nada aqui

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 6

      Text {
        text: "PROCESSOS"
        color: Colors[config.colorLabel]
        font { pixelSize: 12; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
      }

      Item { Layout.preferredWidth: 6 }

      // toggle CPU / RAM — clique alterna o critério de ordenação
      Row {
        spacing: 4
        Repeater {
          model: ["cpu", "ram"]
          delegate: Rectangle {
            required property string modelData
            readonly property bool active: config.sortBy === modelData
            width: chipLabel.implicitWidth + 12
            height: 16
            radius: 8
            color: active ? Colors[config.colorValue] : "transparent"
            border.width: active ? 0 : 1
            border.color: Colors[config.colorLine]

            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: parent.modelData.toUpperCase()
              font.pixelSize: 9
              font.weight: Font.DemiBold
              color: parent.active ? Colors.background : Colors[config.colorLabel]
              opacity: parent.active ? 1 : 0.6
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                config.sortBy = parent.modelData
                if (!psProc.running) psProc.running = true
              }
            }
          }
        }
      }
    }

    // altura RESERVADA fixa (count linhas de 16px) — não pula quando a
    // lista demora um tick pra chegar ou muda de ordenação
    Item {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: config.fixedWidth - 24
      implicitHeight: config.count * 17

      ColumnLayout {
        anchors.fill: parent
        spacing: 1

        Repeater {
          model: root.procList
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true

            Text {
              Layout.fillWidth: true
              text: modelData.name
              color: Colors[config.colorLabel]
              opacity: 0.85
              font.pixelSize: config.fontSizeValue
              elide: Text.ElideRight
            }
            Text {
              text: (config.sortBy === "ram" ? modelData.mem : modelData.cpu).toFixed(1) + "%"
              color: Colors[config.colorValue]
              font.pixelSize: config.fontSizeValue
            }
          }
        }
      }
    }
  }
}
