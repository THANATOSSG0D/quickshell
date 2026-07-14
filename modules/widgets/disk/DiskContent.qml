import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

Item {
  id: root

  property bool grouped: false

  DiskConfig { id: config }

  property real diskPercent: 0
  property real usedGB:      0
  property real totalGB:     0

  property string _diskDev: ""    // ex: "nvme0n1p2" (sem "/dev/")
  property real readBps:  0
  property real writeBps: 0
  property var  readHistory:  []
  property var  writeHistory: []
  property var  _prevIo: null     // { r, w, t }

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── espaço usado (df) ────────────────────────────────────────────────
  Process {
    id: dfProc
    running: false
    command: ["df", "-B1", "--output=size,used,avail", config.mountPoint]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        if (lines.length < 2) return
        const nums = lines[1].trim().split(/\s+/).map(Number)
        if (nums.length < 2 || nums.some(isNaN)) return
        const [size, used] = nums
        if (size <= 0) return
        root.totalGB    = size / 1024 / 1024 / 1024
        root.usedGB     = used / 1024 / 1024 / 1024
        root.diskPercent = Math.max(0, Math.min(100, (used / size) * 100))
      }
    }
  }

  // ── device por trás do mountPoint (findmnt) ─────────────────────────
  Process {
    id: findmntProc
    running: false
    command: ["findmnt", "-no", "SOURCE", config.mountPoint]
    stdout: StdioCollector {
      onStreamFinished: {
        let dev = text.trim().replace("/dev/", "")
        // btrfs às vezes reporta "nvme0n1p2[/@]" (subvolume) — corta o resto
        const br = dev.indexOf("[")
        if (br !== -1) dev = dev.substring(0, br)
        if (dev !== root._diskDev) root._prevIo = null // troca de device: não gera pico falso
        root._diskDev = dev
      }
    }
  }

  // ── I/O (leitura/escrita, via /proc/diskstats) ──────────────────────
  FileView {
    id: diskstatsFile
    path: "/proc/diskstats"
    watchChanges: false
    onLoaded: root._parseDiskstats(text())
  }

  function _parseDiskstats(text) {
    if (root._diskDev === "" || !config.showIO) return
    const lines = text.split("\n")
    for (const line of lines) {
      const f = line.trim().split(/\s+/)
      if (f.length < 10 || f[2] !== root._diskDev) continue

      const sectorsRead    = parseInt(f[5])
      const sectorsWritten = parseInt(f[9])
      const now = Date.now()

      if (root._prevIo) {
        const dt = (now - root._prevIo.t) / 1000
        if (dt > 0) {
          root.readBps  = Math.max(0, (sectorsRead    - root._prevIo.r) * 512 / dt)
          root.writeBps = Math.max(0, (sectorsWritten - root._prevIo.w) * 512 / dt)

          const hr = root.readHistory.slice();  hr.push(root.readBps);  if (hr.length > 60) hr.shift()
          const hw = root.writeHistory.slice(); hw.push(root.writeBps); if (hw.length > 60) hw.shift()
          root.readHistory = hr
          root.writeHistory = hw
        }
      }
      root._prevIo = { r: sectorsRead, w: sectorsWritten, t: now }
      break
    }
  }

  function _normalize(arr) {
    if (arr.length === 0) return []
    const max = Math.max(1024 * 1024, ...arr) // piso de 1MB/s
    return arr.map(v => (v / max) * 100)
  }

  function formatSpeed(bps) {
    if (bps >= 1024 * 1024) return (bps / 1024 / 1024).toFixed(1) + " MB/s"
    if (bps >= 1024)        return (bps / 1024).toFixed(0) + " KB/s"
    return bps.toFixed(0) + " B/s"
  }

  Timer {
    interval: 5000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (!dfProc.running) dfProc.running = true }
  }

  Timer {
    interval: 15000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (!findmntProc.running) findmntProc.running = true }
  }

  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: diskstatsFile.reload()
  }

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root.diskPercent.toFixed(0) + "%"
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
          text: "DISCO"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          text: root.usedGB.toFixed(0) + " / " + root.totalGB.toFixed(0) + " GB"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
      }
    }

    RowLayout {
      visible: config.showIO && root._diskDev !== ""
      Layout.alignment: Qt.AlignHCenter
      spacing: 16

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "R"; color: Colors[config.colorValue]; opacity: 0.7; font.pixelSize: 10 }
          Text {
            text: root.formatSpeed(root.readBps)
            color: Colors[config.colorValue]
            font.pixelSize: 12
          }
        }
        Shared.Sparkline {
          visible: config.showHistory
          Layout.preferredWidth: 60
          Layout.preferredHeight: 18
          history: root._normalize(root.readHistory)
          lineColor: Colors[config.colorValue]
          fillColor: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.15)
        }
      }

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "W"; color: Colors[config.colorWrite]; opacity: 0.7; font.pixelSize: 10 }
          Text {
            text: root.formatSpeed(root.writeBps)
            color: Colors[config.colorWrite]
            font.pixelSize: 12
          }
        }
        Shared.Sparkline {
          visible: config.showHistory
          Layout.preferredWidth: 60
          Layout.preferredHeight: 18
          history: root._normalize(root.writeHistory)
          lineColor: Colors[config.colorWrite]
          fillColor: Qt.rgba(Colors[config.colorWrite].r, Colors[config.colorWrite].g, Colors[config.colorWrite].b, 0.15)
        }
      }
    }
  }
}
