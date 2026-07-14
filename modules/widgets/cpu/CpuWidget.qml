import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// WidgetLayoutConfig.qml mora em modules/widgets/ — um nível acima daqui
import "../" as Shared

Scope {
  id: cpuWidget

  CpuConfig { id: config }
  Shared.WidgetLayoutConfig { id: layoutCfg }

  property int position: config.position
  onPositionChanged: config.position = position

  Variants {
    // se "cpu" está no grupo combinado, a WidgetHost.qml quem renderiza
    model: layoutCfg.isGrouped("cpu") ? [] : Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "cpu-widget"

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
            if (positions[position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: cpuContent.implicitWidth
          height: cpuContent.implicitHeight

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.RightButton)
                cpuWidget.position = (cpuWidget.position + 8) % 9
              else
                cpuWidget.position = (cpuWidget.position + 1) % 9
            }
          }

          CpuContent { id: cpuContent; grouped: false }
        }
      }
    }
  }
}
