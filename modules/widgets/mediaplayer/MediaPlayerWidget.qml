import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../" as Shared

Scope {
  id: mediaPlayerWidget

  MediaPlayerConfig { id: config }
  Shared.WidgetLayoutConfig { id: layoutCfg }

  property int position: config.position
  onPositionChanged: config.position = position

  Variants {
    model: (layoutCfg.isGrouped("mediaplayer") || !layoutCfg.isEnabled("mediaplayer")) ? [] : Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "mediaplayer-widget"

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
          width: mediaPlayerContent.implicitWidth
          height: mediaPlayerContent.implicitHeight

          // botão direito muda posição — esquerdo fica livre pros
          // controles internos (play/pause, seek, prev/next, launch)
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (mouse) => {
              mediaPlayerWidget.position = (mediaPlayerWidget.position + 8) % 9
            }
          }

          MediaPlayerContent { id: mediaPlayerContent; grouped: false }
        }
      }
    }
  }
}
