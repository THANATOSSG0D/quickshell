import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
  id: root

  // true quando renderizado dentro da WidgetHost (modo combinado) — hoje
  // só existe pra eventuais ajustes visuais futuros por contexto.
  property bool grouped: false

  ClockConfig { id: config }

  property string currentTime: Qt.formatDateTime(new Date(), config.use24h ? "HH:mm" : "h:mm AP")
  property string currentDate: Qt.formatDateTime(new Date(), config.dateFormat)

  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      root.currentTime = Qt.formatDateTime(new Date(), config.use24h ? "HH:mm" : "h:mm AP")
      root.currentDate = Qt.formatDateTime(new Date(), config.dateFormat)
    }
  }

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  ColumnLayout {
    id: layout
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 0

    Text {
      id: clock
      Layout.alignment: Qt.AlignHCenter
      color: Colors[config.colorTime]
      font { pixelSize: config.fontSizeTime; family: "Inter"; weight: Font.Light }
      text: root.currentTime
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.8)
        shadowBlur: 0.8
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowScale: 1.02
      }
    }

    Item { Layout.preferredHeight: 4; visible: config.showDate }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      width: clock.implicitWidth * 0.4
      height: 1
      color: Colors[config.colorLine]
      opacity: 0.6
      visible: config.showLine && config.showDate
    }

    Item { Layout.preferredHeight: 8; visible: config.showDate }

    Text {
      id: date
      Layout.alignment: Qt.AlignHCenter
      color: Colors[config.colorDate]
      font {
        pixelSize: config.fontSizeDate; family: "Inter"; weight: Font.DemiBold
        letterSpacing: 3; capitalization: Font.AllUppercase
      }
      text: root.currentDate
      visible: config.showDate
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.8)
        shadowBlur: 0.8
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowScale: 1.02
      }
    }
  }
}
