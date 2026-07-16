import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

Item {
  id: root

  property bool grouped: false

  NetworkConfig { id: config }

  property string ifaceName: ""     // ex: "wlan0", "enp3s0"
  property string ifaceType: ""     // "wifi" | "ethernet" | ""
  property string connName:  ""     // SSID ou nome da conexão cabeada
  property string ipAddress: ""     // IP local da interface ativa
  property string dnsServers: ""    // DNS da conexão ativa (via nmcli, não mais /etc/resolv.conf)
  property bool   vpnActive: false
  property string vpnName:   ""

  property real downBps: 0
  property real upBps:   0
  property var  downHistory: []     // bytes/s crus, últimas ~60 amostras
  property var  upHistory:   []

  property var _prevSample: null    // { rx, tx, t }
  property var _byteBuf: []

  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── descoberta da interface ativa (nmcli) ───────────────────────────
  Process {
    id: ifaceProc
    running: false
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        let ethernet = null, wifi = null

        for (const line of lines) {
          const parts = line.split(":")
          if (parts.length < 4) continue
          const dev = parts[0], type = parts[1], state = parts[2]
          const conn = parts.slice(3).join(":")
          if (!state.startsWith("connected")) continue
          if (type === "ethernet" && !ethernet) ethernet = { dev, type, conn }
          if (type === "wifi" && !wifi)         wifi = { dev, type, conn }
        }

        const picked = ethernet || wifi
        if (picked) {
          if (picked.dev !== root.ifaceName) {
            // trocou de interface — reseta o histórico/base pra não gerar
            // um pico falso na primeira amostra
            root._prevSample = null
            root.downHistory = []
            root.upHistory = []
          }
          root.ifaceName = picked.dev
          root.ifaceType = picked.type
          root.connName  = picked.conn
        } else {
          root.ifaceName = ""
          root.ifaceType = ""
          root.connName  = ""
          root.ipAddress = ""
          root.dnsServers = ""
        }
      }
    }
  }

  Timer {
    interval: 5000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!ifaceProc.running) ifaceProc.running = true
      if (config.showIP && root.ifaceName !== "" && !ipProc.running) ipProc.running = true
      if (config.showDNS && root.connName !== "" && !dnsProc.running) dnsProc.running = true
      if (config.showVPN && !vpnProc.running) vpnProc.running = true
    }
  }

  // ── IP local da interface ativa ──────────────────────────────────────
  Process {
    id: ipProc
    running: false
    command: root.ifaceName === "" ? ["true"] : ["ip", "-4", "-o", "addr", "show", "dev", root.ifaceName]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/inet ([\d.]+)\//)
        root.ipAddress = m ? m[1] : ""
      }
    }
  }

  // ── DNS — via nmcli connection show <nome> (não usa mais
  // /etc/resolv.conf, que só mostra o stub 127.0.0.53 do
  // systemd-resolved quando ele está ativo) ───────────────────────────
  Process {
    id: dnsProc
    running: false
    command: root.connName === "" ? ["true"] : ["nmcli", "-g", "IP4.DNS", "connection", "show", root.connName]
    stdout: StdioCollector {
      onStreamFinished: {
        // nmcli -g junta múltiplos valores com " | " (ou quebra de linha,
        // dependendo da versão) — trata os dois casos
        const servers = text.trim().split(/\s*\|\s*|\n/).map(s => s.trim()).filter(s => s.length > 0)
        root.dnsServers = servers.join(", ")
      }
    }
  }

  // ── VPN ativa (WireGuard/OpenVPN/etc via NetworkManager) ────────────
  Process {
    id: vpnProc
    running: false
    command: ["nmcli", "-t", "-f", "TYPE,STATE,NAME", "connection", "show", "--active"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        let found = null
        for (const line of lines) {
          const parts = line.split(":")
          if (parts.length < 3) continue
          const type = parts[0]
          if (type === "vpn" || type === "wireguard") { found = parts.slice(2).join(":"); break }
        }
        root.vpnActive = found !== null
        root.vpnName   = found || ""
      }
    }
  }

  // ── throughput (rx/tx bytes da interface ativa) ─────────────────────
  Process {
    id: bytesProc
    running: false
    command: root.ifaceName === "" ? ["true"] : ["sh", "-c",
      "cat /sys/class/net/" + root.ifaceName + "/statistics/rx_bytes " +
      "/sys/class/net/" + root.ifaceName + "/statistics/tx_bytes 2>/dev/null"]
    stdout: SplitParser {
      onRead: (line) => {
        const n = parseInt(line)
        if (isNaN(n)) return
        root._byteBuf.push(n)
        if (root._byteBuf.length === 2) {
          root._onBytesSample(root._byteBuf[0], root._byteBuf[1])
          root._byteBuf = []
        }
      }
    }
  }

  function _onBytesSample(rx, tx) {
    const now = Date.now()
    if (root._prevSample) {
      const dt = (now - root._prevSample.t) / 1000
      if (dt > 0) {
        root.downBps = Math.max(0, (rx - root._prevSample.rx) / dt)
        root.upBps   = Math.max(0, (tx - root._prevSample.tx) / dt)

        const hd = root.downHistory.slice(); hd.push(root.downBps); if (hd.length > 60) hd.shift()
        const hu = root.upHistory.slice();   hu.push(root.upBps);   if (hu.length > 60) hu.shift()
        root.downHistory = hd
        root.upHistory = hu
      }
    }
    root._prevSample = { rx, tx, t: now }
  }

  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      if (root.ifaceName === "") return
      // guard crítico: esse Timer dispara a cada 1s — sem checar
      // `!bytesProc.running`, um "cat" que demore mais que 1s (disco
      // lento, interface travando) empilha processos indefinidamente
      if (bytesProc.running) return
      root._byteBuf = []
      bytesProc.running = true
    }
  }

  // ── normalização pra sparkline (escala pelo próprio pico recente) ──
  function _normalize(arr) {
    if (arr.length === 0) return []
    const max = Math.max(1024, ...arr) // piso de 1KB/s pra não ficar ruidoso parado
    return arr.map(v => (v / max) * 100)
  }

  function formatSpeed(bps) {
    if (bps >= 1024 * 1024) return (bps / 1024 / 1024).toFixed(1) + " MB/s"
    if (bps >= 1024)        return (bps / 1024).toFixed(0) + " KB/s"
    return bps.toFixed(0) + " B/s"
  }

  FontMetrics {
    id: speedMetrics
    font.pixelSize: config.fontSizeValue
    font.family: "Inter"
  }

  ColumnLayout {
    id: layout
    anchors.centerIn: parent
    spacing: 6

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 0
      visible: config.showIface

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.ifaceName === "" ? "Sem conexão" : (root.connName || root.ifaceName)
        color: Colors[config.colorLabel]
        font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold }
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
      Text {
        visible: root.ifaceName !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.ifaceType === "wifi" ? "Wi-Fi" : "Cabo"
        color: Colors[config.colorLabel]
        opacity: 0.6
        font.pixelSize: 10
      }
      Text {
        visible: config.showIP && root.ipAddress !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.ipAddress
        color: Colors[config.colorLabel]
        opacity: 0.55
        font.pixelSize: 10
      }
      Text {
        visible: config.showDNS && root.dnsServers !== ""
        Layout.alignment: Qt.AlignHCenter
        text: "DNS " + root.dnsServers
        color: Colors[config.colorLabel]
        opacity: 0.55
        font.pixelSize: 9
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
      Text {
        visible: config.showVPN && root.vpnActive
        Layout.alignment: Qt.AlignHCenter
        text: "󰖂 VPN: " + root.vpnName
        color: Colors[config.colorValue]
        opacity: 0.85
        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 16
      visible: root.ifaceName !== ""

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "↓"; color: Colors[config.colorValue]; font.pixelSize: 12 }
          Text {
            text: root.formatSpeed(root.downBps)
            color: Colors[config.colorValue]
            font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.Light }
            horizontalAlignment: Text.AlignLeft
            // largura reservada pro maior valor plausível — sem isso, o
            // texto pula de tamanho toda vez que passa de B/s pra KB/s
            // pra MB/s, e o lado "↑" inteiro desliza junto
            Layout.preferredWidth: speedMetrics.boundingRect("999.9 MB/s").width
          }
        }
        Shared.Sparkline {
          visible: config.showHistory
          Layout.preferredWidth: 70
          Layout.preferredHeight: 24
          history: root._normalize(root.downHistory)
          lineColor: Colors[config.colorValue]
          fillColor: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.15)
        }
      }

      ColumnLayout {
        spacing: 2
        RowLayout {
          spacing: 4
          Text { text: "↑"; color: Colors[config.colorUp]; font.pixelSize: 12 }
          Text {
            text: root.formatSpeed(root.upBps)
            color: Colors[config.colorUp]
            font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.Light }
            horizontalAlignment: Text.AlignLeft
            Layout.preferredWidth: speedMetrics.boundingRect("999.9 MB/s").width
          }
        }
        Shared.Sparkline {
          visible: config.showHistory
          Layout.preferredWidth: 70
          Layout.preferredHeight: 24
          history: root._normalize(root.upHistory)
          lineColor: Colors[config.colorUp]
          fillColor: Qt.rgba(Colors[config.colorUp].r, Colors[config.colorUp].g, Colors[config.colorUp].b, 0.15)
        }
      }
    }
  }
}
