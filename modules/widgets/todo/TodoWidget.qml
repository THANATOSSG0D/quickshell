import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
  id: todoWidget

  TodoConfig { id: config }

  readonly property var priorityColor: ({
    alta:  "#e5484d",
    media: "#f5a524",
    baixa: "#45a249",
  })
  readonly property var priorityOrder: ({ alta: 0, media: 1, baixa: 2 })

  function sortedTasks() {
    let list = config.tasks.slice()
    if (!config.showCompleted) list = list.filter(function(t) { return !t.done })
    list.sort(function(a, b) {
      if (a.done !== b.done) return a.done ? 1 : -1
      if (config.sortBy === "priority") {
        const ao = priorityOrder[a.priority] !== undefined ? priorityOrder[a.priority] : 1
        const bo = priorityOrder[b.priority] !== undefined ? priorityOrder[b.priority] : 1
        return ao - bo
      }
      if (config.sortBy === "due")
        return (a.due || "9999-99-99") < (b.due || "9999-99-99") ? -1 : 1
      return (a.created || "") < (b.created || "") ? -1 : 1
    })
    return list
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        // Bottom: widgets ficam abaixo dos apps de propósito. Sem input de
        // teclado aqui — digitar a tarefa agora é no popup (BarPopup).
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "todo-widget"

        mask: Region { item: content }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
          { h: Qt.AlignRight,   v: Qt.AlignBottom  },
        ]

        Item {
          id: content
          x: {
            if (positions[config.position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[config.position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[config.position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[config.position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: 260
          height: layout.implicitHeight

          ColumnLayout {
            id: layout
            width: parent.width
            spacing: 8

            Text {
              Layout.fillWidth: true
              text: "Tarefas · " + todoWidget.sortedTasks().filter(function(t) { return !t.done }).length + " pendentes"
              color: Colors[config.colorText]
              font { pixelSize: config.fontSize; family: "Inter"; weight: Font.DemiBold }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 28; radius: 6
              color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
              border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
              Behavior on color { ColorAnimation { duration: 80 } }

              Text {
                anchors.centerIn: parent
                text: "+ nova tarefa"
                color: Colors[config.colorText]
                font { pixelSize: config.fontSize - 3; family: "Inter" }
              }

              MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // TODO: abrir popup de nova tarefa (texto + prioridade + data)
                // assim que eu adaptar o BarPopup pra esse caso de uso.
                onClicked: console.log("abrir popup de nova tarefa")
              }
            }

            Repeater {
              model: todoWidget.sortedTasks()
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                  width: 14; height: 14; radius: 7
                  border.width: 1.5
                  border.color: modelData.done ? "#45a249" : Qt.rgba(1, 1, 1, 0.4)
                  color: modelData.done ? "#45a249" : "transparent"
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: config.toggleTask(modelData.id)
                  }
                }

                Rectangle {
                  width: 6; height: 6; radius: 3
                  color: todoWidget.priorityColor[modelData.priority] || "#999999"
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.text
                  color: Colors[config.colorText]
                  opacity: modelData.done ? 0.45 : 1.0
                  font { pixelSize: config.fontSize - 3; family: "Inter"; strikeout: modelData.done }
                  elide: Text.ElideRight
                }

                Text {
                  visible: !!modelData.due
                  text: modelData.due
                  color: (!modelData.done && modelData.due && modelData.due < Qt.formatDate(new Date(), "yyyy-MM-dd"))
                    ? "#e5484d" : Qt.rgba(1, 1, 1, 0.5)
                  font.pixelSize: config.fontSize - 5
                }

                Text {
                  text: "×"
                  color: Qt.rgba(1, 1, 1, 0.4)
                  font.pixelSize: config.fontSize
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: config.removeTask(modelData.id)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
