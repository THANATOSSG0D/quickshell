import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

Item {
  id: root

  property bool grouped: false

  BluetoothConfig { id: config }

  property bool powered: false
  property var  devices: []       // [{ mac, name, battery }]

  property var _batteryMap:   ({})  // mac → % (null se indisponível)
  property var _batteryQueue: []
  property string _currentBatteryMac: ""

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── estado do controlador (ligado/desligado) ────────────────────────
  Process {
    id: showProc
    running: false
    command: ["bluetoothctl", "show"]
    stdout: StdioCollector {
      onStreamFinished: root.powered = /Powered:\s*yes/.test(text)
    }
  }

  // ── dispositivos conectados ──────────────────────────────────────────
  Process {
    id: devicesProc
    running: false
    command: ["bluetoothctl", "devices", "Connected"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l.length > 0)
        const list = []
        for (const line of lines) {
          const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.*)$/)
          if (!m) continue
          const mac = m[1], name = m[2]
          list.push({ mac, name, battery: root._batteryMap[mac] !== undefined ? root._batteryMap[mac] : null })
        }
        root.devices = list

        if (config.showBattery) {
          root._batteryQueue = list.map(d => d.mac).slice(0, 4) // limita a 4 pra não empilhar processos
          root._processNextBattery()
        }
      }
    }
  }

  // ── bateria (via profile Battery, quando o dispositivo suporta) ─────
  Process {
    id: batteryProc
    running: false
    command: root._currentBatteryMac !== "" ? ["bluetoothctl", "info", root._currentBatteryMac] : ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/Battery Percentage:.*\((\d+)\)/)
        const pct = m ? parseInt(m[1]) : null
        const mac = root._currentBatteryMac
        const bm = Object.assign({}, root._batteryMap)
        bm[mac] = pct
        root._batteryMap = bm
        root.devices = root.devices.map(d => d.mac === mac ? Object.assign({}, d, { battery: pct }) : d)
        root._processNextBattery()
      }
    }
  }

  function _processNextBattery() {
    if (root._batteryQueue.length === 0) { root._currentBatteryMac = ""; return }
    root._currentBatteryMac = root._batteryQueue.shift()
    batteryProc.running = false
    batteryProc.running = true
  }

  Timer {
    interval: 3000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!showProc.running) showProc.running = true
      if (!devicesProc.running) devicesProc.running = true
    }
  }

  // mostra no máximo 3 dispositivos (senão a lista cresce e o card deixa
  // de ter altura fixa de verdade) — os "extras" viram um resuminho
  readonly property var visibleDevices: devices.slice(0, 3)
  readonly property int extraCount: Math.max(0, devices.length - 3)

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        text: root.powered ? String(root.devices.length) : "--"
        color: Colors[config.colorValue]
        opacity: root.powered ? 1 : 0.4
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
          text: "BLUETOOTH"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          text: root.powered
                ? (root.devices.length === 0 ? "nenhum dispositivo" : "conectado(s)")
                : "desligado"
          color: Colors[config.colorLabel]
          opacity: 0.6
          font.pixelSize: 11
        }
      }
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 2
      visible: config.showDeviceNames && root.powered && root.devices.length > 0

      Repeater {
        model: root.visibleDevices
        delegate: RowLayout {
          required property var modelData
          Layout.alignment: Qt.AlignHCenter
          spacing: 6

          Text {
            text: modelData.name
            color: Colors[config.colorLabel]
            opacity: 0.85
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.maximumWidth: config.fixedWidth - 60
          }
          Text {
            visible: config.showBattery && modelData.battery !== null
            text: modelData.battery + "%"
            color: Colors[config.colorValue]
            opacity: 0.85
            font.pixelSize: 11
          }
        }
      }

      Text {
        visible: root.extraCount > 0
        Layout.alignment: Qt.AlignHCenter
        text: "+" + root.extraCount + " mais"
        color: Colors[config.colorLabel]
        opacity: 0.5
        font.pixelSize: 10
      }
    }
  }
}
