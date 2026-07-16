import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

Item {
  id: root

  property bool grouped: false

  RamConfig { id: config }

  property real ramPercent:  0
  property real usedGB:      0
  property real totalGB:     0
  property real swapPercent: 0
  property real swapUsedGB:  0
  property real swapTotalGB: 0
  property var  ramHistory:  []

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  FileView {
    id: meminfoFile
    path: "/proc/meminfo"
    watchChanges: false
    onLoaded: root._parseMeminfo(text())
  }

  function _field(text, key) {
    const m = text.match(new RegExp(key + "\\s*:\\s*([0-9]+)\\s*kB"))
    return m ? parseInt(m[1]) : 0
  }

  function _parseMeminfo(text) {
    const totalKB = _field(text, "MemTotal")
    const availKB = _field(text, "MemAvailable")
    const swapTotalKB = _field(text, "SwapTotal")
    const swapFreeKB  = _field(text, "SwapFree")

    if (totalKB > 0) {
      const usedKB = totalKB - availKB
      root.ramPercent = Math.max(0, Math.min(100, (usedKB / totalKB) * 100))
      root.usedGB  = usedKB  / 1024 / 1024
      root.totalGB = totalKB / 1024 / 1024

      const h = root.ramHistory.slice()
      h.push(root.ramPercent)
      if (h.length > 60) h.shift()
      root.ramHistory = h
    }

    if (swapTotalKB > 0) {
      const swapUsedKB = swapTotalKB - swapFreeKB
      root.swapPercent  = Math.max(0, Math.min(100, (swapUsedKB / swapTotalKB) * 100))
      root.swapUsedGB   = swapUsedKB  / 1024 / 1024
      root.swapTotalGB  = swapTotalKB / 1024 / 1024
    } else {
      root.swapPercent = 0
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true
    onTriggered: meminfoFile.reload()
  }

  FontMetrics {
    id: bigNumberMetrics
    font.pixelSize: config.fontSizeValue
    font.family: "Inter"
  }
  FontMetrics {
    id: secondaryMetrics
    font.pixelSize: 11
    font.family: "Inter"
  }

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root.ramPercent.toFixed(0) + "%"
        color: Colors[config.colorValue]
        font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.Light }
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: bigNumberMetrics.boundingRect("100%").width
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.8)
          shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; shadowScale: 1.02
        }
      }

      ColumnLayout {
        id: secondaryCol
        spacing: 0
        // maior conteúdo plausível: "999.9 / 999.9 GB" cobre até discos
        // gigantescos de RAM/swap sem nunca precisar recalcular
        readonly property real reservedWidth: secondaryMetrics.boundingRect("999.9 / 999.9 GB").width
        Layout.preferredWidth: reservedWidth

        Text {
          text: "RAM"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          text: root.usedGB.toFixed(1) + " / " + root.totalGB.toFixed(1) + " GB"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
        Text {
          visible: config.showSwap && root.swapTotalGB > 0
          text: "swap " + root.swapUsedGB.toFixed(1) + " / " + root.swapTotalGB.toFixed(1) + " GB"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
          elide: Text.ElideRight
          Layout.maximumWidth: secondaryCol.reservedWidth
        }
      }
    }

    Shared.Sparkline {
      visible: config.showHistory
      Layout.preferredWidth: 140
      Layout.preferredHeight: 32
      history: root.ramHistory
      lineColor: Colors[config.colorValue]
      fillColor: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.15)
    }
  }
}
