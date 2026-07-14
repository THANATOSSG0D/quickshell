import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../" as Shared

Scope {
  id: networkWidget

  NetworkConfig { id: config }
  Shared.WidgetLayoutConfig { id: layoutCfg }

  property int position: config.position
  onPositionChanged: config.position = position

  Variants {
    model: layoutCfg.isGrouped("network") ? [] : Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "network-widget"

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
          width: networkContent.implicitWidth
          height: networkContent.implicitHeight

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.RightButton)
                networkWidget.position = (networkWidget.position + 8) % 9
              else
                networkWidget.position = (networkWidget.position + 1) % 9
            }
          }

          NetworkContent { id: networkContent; grouped: false }
        }
      }
    }
  }
}
