import qs

import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property bool grouped: false

  DiskConfig { id: config }

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    DiskMountRow {
      Layout.alignment: Qt.AlignHCenter
      mountPoint: config.mountPoint
      primary: true
      showIO: config.showIO
      showHistory: config.showHistory
      colorValue: Colors[config.colorValue]
      colorWrite: Colors[config.colorWrite]
      colorLabel: Colors[config.colorLabel]
      fontSizeValue: config.fontSizeValue
    }

    Repeater {
      model: config.extraMounts
      delegate: DiskMountRow {
        required property string modelData
        Layout.alignment: Qt.AlignHCenter
        mountPoint: modelData
        primary: false
        showIO: config.showIO
        colorValue: Colors[config.colorValue]
        colorWrite: Colors[config.colorWrite]
        colorLabel: Colors[config.colorLabel]
        maxLabelWidth: config.fixedWidth - 24
      }
    }
  }
}
