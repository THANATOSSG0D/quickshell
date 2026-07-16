import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

// ── DiskMountRow ─────────────────────────────────────────────────────────
// Uma "linha" de disco autocontida: faz sua PRÓPRIA leitura de espaço (df),
// descoberta de device (findmnt) e I/O (/proc/diskstats) pro mountPoint
// dado. Usado tanto pro disco principal (primary: true, visual grande,
// igual sempre foi) quanto pros discos extras (primary: false, visual
// compacto — só uma linha de texto, sem sparkline, pra não inflar a
// altura do card a cada disco adicionado).

Item {
  id: root

  required property string mountPoint
  property bool primary: false
  property bool showIO: true
  property bool showHistory: true

  property color colorValue: "white"
  property color colorWrite: "white"
  property color colorLabel: "white"
  property int   fontSizeValue: 32
  property int   maxLabelWidth: 160

  readonly property string label: mountPoint === "/" ? "/" : mountPoint.split("/").filter(s => s.length > 0).pop()

  property real diskPercent: 0
  property real usedGB:      0
  property real totalGB:     0

  property string _diskDev: ""
  property real readBps:  0
  property real writeBps: 0
  property var  readHistory:  []
  property var  writeHistory: []
  property var  _prevIo: null

  implicitWidth: primary ? bigLayout.implicitWidth : compactRow.implicitWidth
  implicitHeight: primary ? bigLayout.implicitHeight : compactRow.implicitHeight

  Process {
    id: dfProc
    running: false
    command: ["df", "-B1", "--output=size,used,avail", root.mountPoint]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        if (lines.length < 2) return
        const nums = lines[1].trim().split(/\s+/).map(Number)
        if (nums.length < 2 || nums.some(isNaN)) return
        const [size, used] = nums
        if (size <= 0) return
        root.totalGB     = size / 1024 / 1024 / 1024
        root.usedGB      = used / 1024 / 1024 / 1024
        root.diskPercent = Math.max(0, Math.min(100, (used / size) * 100))
      }
    }
  }

  Process {
    id: findmntProc
    running: false
    command: ["findmnt", "-no", "SOURCE", root.mountPoint]
    stdout: StdioCollector {
      onStreamFinished: {
        let dev = text.trim().replace("/dev/", "")
        const br = dev.indexOf("[")
        if (br !== -1) dev = dev.substring(0, br)
        if (dev !== root._diskDev) root._prevIo = null
        root._diskDev = dev
      }
    }
  }

  FileView {
    id: diskstatsFile
    path: "/proc/diskstats"
    watchChanges: false
    onLoaded: root._parseDiskstats(text())
  }

  function _parseDiskstats(text) {
    if (root._diskDev === "" || !root.showIO) return
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
    const max = Math.max(1024 * 1024, ...arr)
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

  FontMetrics {
    id: bigNumberMetrics
    font.pixelSize: root.fontSizeValue
    font.family: "Inter"
  }
  FontMetrics {
    id: secondaryMetrics
    font.pixelSize: 11
    font.family: "Inter"
  }
  FontMetrics {
    id: ioMetrics
    font.pixelSize: 12
    font.family: "Inter"
  }

  // ── visual GRANDE (disco principal) ─────────────────────────────────
  ColumnLayout {
    id: bigLayout
    visible: root.primary
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root.diskPercent.toFixed(0) + "%"
        color: root.colorValue
        font { pixelSize: root.fontSizeValue; family: "Inter"; weight: Font.Light }
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
        // "9999 / 9999 GB" cobre até discos de vários TB sem recalcular
        readonly property real reservedWidth: secondaryMetrics.boundingRect("9999 / 9999 GB").width
        Layout.preferredWidth: reservedWidth

        Text {
          text: "DISCO"
          color: root.colorLabel
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          text: root.usedGB.toFixed(0) + " / " + root.totalGB.toFixed(0) + " GB"
          color: root.colorLabel
          opacity: 0.7
          font.pixelSize: 11
        }
      }
    }

    RowLayout {
      visible: root.showIO && root._diskDev !== ""
      Layout.alignment: Qt.AlignHCenter
      spacing: 16

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "R"; color: root.colorValue; opacity: 0.7; font.pixelSize: 10 }
          Text {
            text: root.formatSpeed(root.readBps)
            color: root.colorValue
            font.pixelSize: 12
            horizontalAlignment: Text.AlignLeft
            Layout.preferredWidth: ioMetrics.boundingRect("999.9 MB/s").width
          }
        }
        Shared.Sparkline {
          visible: root.showHistory
          Layout.preferredWidth: 60
          Layout.preferredHeight: 18
          history: root._normalize(root.readHistory)
          lineColor: root.colorValue
          fillColor: Qt.rgba(root.colorValue.r, root.colorValue.g, root.colorValue.b, 0.15)
        }
      }

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "W"; color: root.colorWrite; opacity: 0.7; font.pixelSize: 10 }
          Text {
            text: root.formatSpeed(root.writeBps)
            color: root.colorWrite
            font.pixelSize: 12
            horizontalAlignment: Text.AlignLeft
            Layout.preferredWidth: ioMetrics.boundingRect("999.9 MB/s").width
          }
        }
        Shared.Sparkline {
          visible: root.showHistory
          Layout.preferredWidth: 60
          Layout.preferredHeight: 18
          history: root._normalize(root.writeHistory)
          lineColor: root.colorWrite
          fillColor: Qt.rgba(root.colorWrite.r, root.colorWrite.g, root.colorWrite.b, 0.15)
        }
      }
    }
  }

  // ── visual COMPACTO (discos extras) — uma linha só, sem sparkline ───
  RowLayout {
    id: compactRow
    visible: !root.primary
    anchors.centerIn: parent
    spacing: 6

    Text {
      text: root.label
      color: root.colorLabel
      font.pixelSize: 11
      font.weight: Font.DemiBold
      elide: Text.ElideRight
      Layout.maximumWidth: root.maxLabelWidth * 0.35
    }
    Text {
      text: root.diskPercent.toFixed(0) + "%"
      color: root.colorValue
      font.pixelSize: 11
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: secondaryMetrics.boundingRect("100%").width
    }
    Text {
      text: root.usedGB.toFixed(0) + "/" + root.totalGB.toFixed(0) + "GB"
      color: root.colorLabel
      opacity: 0.6
      font.pixelSize: 10
      horizontalAlignment: Text.AlignLeft
      Layout.preferredWidth: secondaryMetrics.boundingRect("9999/9999GB").width
    }
    Text {
      visible: root.showIO && root._diskDev !== ""
      text: "↓" + root.formatSpeed(root.readBps) + " ↑" + root.formatSpeed(root.writeBps)
      color: root.colorLabel
      opacity: 0.6
      font.pixelSize: 9
      elide: Text.ElideRight
      Layout.maximumWidth: root.maxLabelWidth * 0.5
    }
  }
}
