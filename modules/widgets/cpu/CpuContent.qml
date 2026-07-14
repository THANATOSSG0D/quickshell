import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

Item {
  id: root

  // true quando renderizado dentro da WidgetHost (modo combinado)
  property bool grouped: false

  CpuConfig { id: config }

  // ── Estado ────────────────────────────────────────────────────────────
  property real cpuPercent: 0
  property var  cpuHistory: []     // últimas ~60 amostras, 0..100
  property var  coreLoads:  []     // % por núcleo lógico
  property real cpuFreqGHz: 0
  property var  cpuTemp:    null   // null até a primeira leitura de sensors
  property string cpuModel: ""     // ex: "i7-8750H"

  property var _prevStat: null     // { "cpu": {idle,total}, "cpu0": {...}, ... }

  // tamanho FIXO — não muda conforme os números mudam de largura, senão
  // o card fica "pulando" a cada atualização (e desalinha em modo
  // individual, já que a posição na tela é calculada a partir da largura)
  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── /proc/stat — uso geral + por núcleo ─────────────────────────────
  FileView {
    id: statFile
    path: "/proc/stat"
    watchChanges: false
    onLoaded: root._parseStat(text())
  }

  function _parseStat(text) {
    const lines = text.split("\n")
    const raw = {}
    for (const line of lines) {
      if (!line.startsWith("cpu")) continue
      const parts = line.trim().split(/\s+/)
      const label = parts[0]
      if (label !== "cpu" && !/^cpu\d+$/.test(label)) continue
      const nums = parts.slice(1).map(Number)
      const idle = (nums[3] || 0) + (nums[4] || 0)
      const total = nums.reduce((a, b) => a + b, 0)
      raw[label] = { idle, total }
    }

    if (root._prevStat) {
      const p = root._prevStat["cpu"], n = raw["cpu"]
      if (p && n) {
        const dT = n.total - p.total, dI = n.idle - p.idle
        if (dT > 0) root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - dI / dT)))
      }

      const cores = []
      let i = 0
      while (raw["cpu" + i] !== undefined) {
        const pc = root._prevStat["cpu" + i], nc = raw["cpu" + i]
        if (pc) {
          const dT = nc.total - pc.total, dI = nc.idle - pc.idle
          cores.push(dT > 0 ? Math.max(0, Math.min(100, 100 * (1 - dI / dT))) : 0)
        } else {
          cores.push(0)
        }
        i++
      }
      root.coreLoads = cores

      const h = root.cpuHistory.slice()
      h.push(root.cpuPercent)
      if (h.length > 60) h.shift()
      root.cpuHistory = h
    }

    root._prevStat = raw
  }

  // ── /proc/cpuinfo — frequência média + modelo ───────────────────────
  FileView {
    id: cpuinfoFile
    path: "/proc/cpuinfo"
    watchChanges: false
    onLoaded: {
      const t = text()

      if (config.showModel && root.cpuModel === "") {
        const mm = t.match(/model name\s*:\s*(.+)/)
        if (mm) root.cpuModel = root._shortModel(mm[1].trim())
      }

      if (!config.showFreq) return
      // QJSEngine não suporta String.matchAll — usa exec() num loop
      const re = /cpu MHz\s*:\s*([0-9.]+)/g
      let m, sum = 0, count = 0
      while ((m = re.exec(t)) !== null) {
        sum += parseFloat(m[1])
        count++
      }
      if (count > 0) root.cpuFreqGHz = (sum / count) / 1000
    }
  }

  function _shortModel(full) {
    const m = full.match(/Core\(TM\)\s*([^\s]+)/) || full.match(/Ryzen\s*\d+\s*([^\s]+)/)
    return m ? m[1] : full.replace(/\s*CPU.*$/, "")
  }

  // ── sensors — temperatura do pacote ─────────────────────────────────
  Process {
    id: sensorsProc
    running: false
    command: ["sensors"]
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text
        let m = t.match(/Package id 0:\s*\+?(-?[0-9.]+)°C/)
              || t.match(/Tctl:\s*\+?(-?[0-9.]+)°C/)
              || t.match(/Core 0:\s*\+?(-?[0-9.]+)°C/)
        if (m) root.cpuTemp = parseFloat(m[1])
      }
    }
  }

  Timer {
    interval: 1500; running: true; repeat: true
    property int _tick: 0
    onTriggered: {
      statFile.reload()
      _tick++
      if (config.showFreq || (config.showModel && root.cpuModel === "")) cpuinfoFile.reload()
      // sensors é mais pesado — só a cada ~3s (2 ticks de 1.5s), e só se
      // a chamada anterior já tiver terminado (nunca empilha processo)
      if (config.showTemp && _tick % 2 === 0 && !sensorsProc.running) {
        sensorsProc.running = true
      }
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────
  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root.cpuPercent.toFixed(0) + "%"
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
          text: "CPU"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          visible: config.showFreq
          text: root.cpuFreqGHz.toFixed(2) + " GHz"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
        Text {
          visible: config.showTemp && root.cpuTemp !== null
          text: (root.cpuTemp !== null ? root.cpuTemp.toFixed(0) : "--") + "°C"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
      }
    }

    Text {
      visible: config.showModel && root.cpuModel !== ""
      Layout.alignment: Qt.AlignHCenter
      text: root.cpuModel
      color: Colors[config.colorLabel]
      opacity: 0.55
      font.pixelSize: 10
      elide: Text.ElideRight
      Layout.maximumWidth: config.fixedWidth - 16
    }

    Shared.Sparkline {
      visible: config.showHistory
      Layout.preferredWidth: 140
      Layout.preferredHeight: 32
      history: root.cpuHistory
      lineColor: Colors[config.colorValue]
      fillColor: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.15)
    }

    RowLayout {
      visible: config.showPerCore && root.coreLoads.length > 0
      Layout.alignment: Qt.AlignHCenter
      spacing: 3

      Repeater {
        model: root.coreLoads
        delegate: Rectangle {
          required property real modelData
          width: 6
          height: 6 + (modelData / 100) * 22
          radius: 2
          color: Colors[config.colorValue]
          opacity: 0.35 + (modelData / 100) * 0.65
          Layout.alignment: Qt.AlignBottom
        }
      }
    }
  }
}
