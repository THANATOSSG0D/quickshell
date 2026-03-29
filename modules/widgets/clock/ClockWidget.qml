import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
  id: clockWidget
  // --- recursos compartilhados entre todos os monitores ---
  property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")
  property string currentDate: Qt.formatDateTime(new Date(), "dddd · MMM dd")

  ClockConfig { id: config }

  // lê position do config
  property int position: config.position

  // salva quando muda
  onPositionChanged: config.position = position

  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      currentTime = Qt.formatDateTime(new Date(), "HH:mm")
      currentDate = Qt.formatDateTime(new Date(), "dddd · MMM dd")
    }
  }

  // --- um por monitor ---
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel 
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        Component.onCompleted: {
          if (this.WlrLayershell != null)
            this.WlrLayershell.layer = WlrLayer.Bottom;
        }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter  },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter  },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter  },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom   },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom   },
          { h: Qt.AlignRight,   v: Qt.AlignBottom   },
        ]

        Item {
          x: {
            if (positions[position].h === Qt.AlignLeft)  return 48
            if (positions[position].h === Qt.AlignRight) return parent.width - width - 48
            return (parent.width - width) / 2
          }
          y: {
            if (positions[position].v === Qt.AlignTop)    return 48
            if (positions[position].v === Qt.AlignBottom) return parent.height - height - 48
            return (parent.height - height) / 2
          }
          width:  layout.implicitWidth
          height: layout.implicitHeight

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.RightButton)
                clockWidget.position = (clockWidget.position + 8) % 9
              else
                clockWidget.position = (clockWidget.position + 1) % 9
            }
          }

          ColumnLayout {
            id: layout
            spacing: 0

            Text {
              id: clock
              Layout.alignment: Qt.AlignHCenter
              color: Colors["primary"]
              font { pixelSize: 72; family: "Inter"; weight: Font.Light }
              text: currentTime
              layer.enabled: true
              layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.8)
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowScale: 1.02      // expande levemente pra criar o efeito de outline
              }
            }

            Item { Layout.preferredHeight: 4 }

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              width: clock.implicitWidth * 0.4
              height: 1
              color: Colors["outline"]
              opacity: 0.6
            }

            Item { Layout.preferredHeight: 8 }

            Text {
              id: date
              Layout.alignment: Qt.AlignHCenter
              color: Colors["on_surface"]
              font {
                pixelSize: 16; family: "Inter"; weight: Font.DemiBold
                letterSpacing: 3; capitalization: Font.AllUppercase
              }
              text: currentDate
              layer.enabled: true
              layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.8)
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowScale: 1.02      // expande levemente pra criar o efeito de outline
              }
            }
          }
        }
      }
    }
  }
}
