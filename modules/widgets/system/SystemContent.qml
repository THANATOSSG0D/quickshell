import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

Item {
  id: root

  property bool grouped: false

  SystemConfig { id: config }

  property real   uptimeSeconds: 0
  property string kernel:   ""
  property string hostname: ""
  property string distro:   ""

  // tamanho FIXO — ver comentário equivalente no CpuContent.qml
  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── uptime — único valor que muda com o tempo, lido periodicamente ──
  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    watchChanges: false
    onLoaded: {
      const secs = parseFloat(text().split(" ")[0])
      if (!isNaN(secs)) root.uptimeSeconds = secs
    }
  }

  Timer {
    interval: 10000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: uptimeFile.reload()
  }

  function _formatUptime(secs) {
    const d = Math.floor(secs / 86400)
    const h = Math.floor((secs % 86400) / 3600)
    const m = Math.floor((secs % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  // ── kernel, hostname, distro — não mudam sem reboot, lidos 1 vez só ──
  FileView {
    id: versionFile
    path: "/proc/version"
    watchChanges: false
    onLoaded: {
      const m = text().match(/Linux version (\S+)/)
      if (m) root.kernel = m[1]
    }
  }

  FileView {
    id: hostnameFile
    path: "/proc/sys/kernel/hostname"
    watchChanges: false
    onLoaded: root.hostname = text().trim()
  }

  FileView {
    id: osReleaseFile
    path: "/etc/os-release"
    watchChanges: false
    onLoaded: {
      const m = text().match(/PRETTY_NAME="?([^"\n]+)"?/)
      if (m) root.distro = m[1]
    }
  }

  Component.onCompleted: {
    if (config.showKernel)   versionFile.reload()
    if (config.showHostname) hostnameFile.reload()
    if (config.showDistro)   osReleaseFile.reload()
  }

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root._formatUptime(root.uptimeSeconds)
        color: Colors[config.colorValue]
        font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.Light }
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.8)
          shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; shadowScale: 1.02
        }
      }

      ColumnLayout {
        spacing: 0
        Text {
          text: "UPTIME"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          visible: config.showHostname && root.hostname !== ""
          text: root.hostname
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
          elide: Text.ElideRight
          Layout.maximumWidth: config.fixedWidth - 90
        }
      }
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 1

      Text {
        visible: config.showDistro && root.distro !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.distro
        color: Colors[config.colorLabel]
        opacity: 0.6
        font.pixelSize: 10
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
      Text {
        visible: config.showKernel && root.kernel !== ""
        Layout.alignment: Qt.AlignHCenter
        text: "Linux " + root.kernel
        color: Colors[config.colorLabel]
        opacity: 0.5
        font.pixelSize: 10
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
    }
  }
}
