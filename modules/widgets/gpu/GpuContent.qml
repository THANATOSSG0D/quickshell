import qs

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../" as Shared

Item {
  id: root

  property bool grouped: false

  GpuConfig { id: config }

  property bool gpuAvailable: true // false se nvidia-smi falhar (ex: GPU
                                    // em PRIME offload / suspensa)
  property real gpuUtil:     0
  property real vramUsedMB:  0
  property real vramTotalMB: 0
  property real gpuTemp:     0
  property real gpuPowerW:   0
  property var  gpuHistory:  []

  // Intel UHD 630 — via intel_gpu_top. Precisa de acesso a perf_event;
  // se `sensors`/permissões não liberarem, fica indisponível (sem travar
  // nada). Pra habilitar sem rodar como root:
  //   sudo sysctl -w dev.i915.perf_stream_paranoid=0
  // (ou uma regra udev/setcap equivalente, a gosto)
  property bool intelAvailable: false
  property real intelUtil: 0

  // nomes dos modelos (via lspci, uma vez só — hardware não muda sem reboot)
  property string nvidiaModel: ""
  property string intelModel:  ""

  // tamanho FIXO — ver comentário equivalente no CpuContent.qml
  implicitWidth: config.fixedWidth
  implicitHeight: config.fixedHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  // ── nomes dos modelos (lspci, uma vez só no início) ─────────────────
  Process {
    id: lspciProc
    running: false
    command: ["lspci", "-mm"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        for (const line of lines) {
          const m = line.match(/^\S+\s+"(VGA compatible controller|3D controller)"\s+"([^"]+)"\s+"([^"]+)"/)
          if (!m) continue
          const vendor = m[2], device = m[3]
          const bracket = device.match(/\[([^\]]+)\]/)
          const short = bracket ? bracket[1] : device
          if (/nvidia/i.test(vendor)) root.nvidiaModel = short
          else if (/intel/i.test(vendor)) root.intelModel = short
        }
      }
    }
  }
  Component.onCompleted: lspciProc.running = true

  Process {
    id: nvProc
    running: false
    command: ["nvidia-smi",
      "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
      "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      onStreamFinished: {
        const line = text.trim().split("\n")[0]
        if (!line) { root.gpuAvailable = false; return }
        const parts = line.split(",").map(s => parseFloat(s.trim()))
        if (parts.length < 5 || parts.some(isNaN)) { root.gpuAvailable = false; return }

        root.gpuAvailable = true
        root.gpuUtil     = parts[0]
        root.vramUsedMB  = parts[1]
        root.vramTotalMB = parts[2]
        root.gpuTemp     = parts[3]
        root.gpuPowerW    = parts[4]

        const h = root.gpuHistory.slice()
        h.push(root.gpuUtil)
        if (h.length > 60) h.shift()
        root.gpuHistory = h
      }
    }
    onExited: (code) => { if (code !== 0) root.gpuAvailable = false }
  }

  // amostra de ~1s do intel_gpu_top em JSON; pega o primeiro "busy" que
  // aparecer (motor Render/3D, que é o mais representativo de carga geral)
  Process {
    id: intelProc
    running: false
    command: ["timeout", "1", "intel_gpu_top", "-J", "-s", "1000"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/"busy"\s*:\s*([0-9.]+)/)
        if (m) {
          root.intelAvailable = true
          root.intelUtil = parseFloat(m[1])
        } else {
          root.intelAvailable = false
        }
      }
    }
    onExited: (code) => { if (code !== 0 && code !== 124) root.intelAvailable = false }
  }

  Timer {
    interval: 2000; running: true; repeat: true
    property int _tick: 0
    onTriggered: {
      // nunca reinicia um processo que ainda não terminou — evita
      // empilhar chamadas de nvidia-smi/intel_gpu_top (causa real do
      // travamento com o tempo: processos zumbis se acumulando)
      if (!nvProc.running) nvProc.running = true
      _tick++
      // intel_gpu_top demora ~1s pra amostrar — dispara com menos frequência
      if (config.showIntel && _tick % 2 === 0 && !intelProc.running) {
        intelProc.running = true
      }
    }
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
      spacing: 12
      visible: root.gpuAvailable

      // espaçador "fantasma" — reserva a diferença entre "100%" e a
      // largura ATUAL do número, ficando ANTES do texto, que por sua vez
      // nunca tem largura limitada (então nunca pode ser cortado, mesmo
      // se a métrica errar por causa de QT_FONT_DPI/scale do ambiente)
      Item {
        Layout.preferredWidth: Math.max(0,
          bigNumberMetrics.advanceWidth("100%") + 2 - gpuPercentText.implicitWidth)
        Layout.preferredHeight: 1
      }

      Text {
        id: gpuPercentText
        text: root.gpuUtil.toFixed(0) + "%"
        color: Colors[config.colorValue]
        font { pixelSize: config.fontSizeValue; family: "Inter"; weight: Font.Light }
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.8)
          shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; shadowScale: 1.02
        }
      }

      ColumnLayout {
        id: secondaryCol
        spacing: 0
        // maior conteúdo plausível entre as 3 linhas: VRAM "99.9 / 99.9 GB",
        // "999°C  ·  999W", ou "iGPU 100%" — pega o mais largo dos três
        readonly property real reservedWidth: Math.max(
          secondaryMetrics.advanceWidth("99.9 / 99.9 GB"),
          secondaryMetrics.advanceWidth("999°C  ·  999W"),
          secondaryMetrics.advanceWidth("iGPU 100%")) + 2
        Layout.preferredWidth: reservedWidth

        Text {
          text: "GPU"
          color: Colors[config.colorLabel]
          font { pixelSize: 13; family: "Inter"; weight: Font.DemiBold; letterSpacing: 2; capitalization: Font.AllUppercase }
        }
        Text {
          visible: config.showVram
          text: (root.vramUsedMB / 1024).toFixed(1) + " / " + (root.vramTotalMB / 1024).toFixed(1) + " GB"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
        Text {
          visible: config.showTemp || config.showPower
          text: [
            config.showTemp  ? root.gpuTemp.toFixed(0) + "°C" : "",
            config.showPower ? root.gpuPowerW.toFixed(0) + "W" : "",
          ].filter(s => s.length > 0).join("  ·  ")
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
        Text {
          visible: config.showIntel && root.intelAvailable
          text: "iGPU " + root.intelUtil.toFixed(0) + "%"
          color: Colors[config.colorLabel]
          opacity: 0.7
          font.pixelSize: 11
        }
      }
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 0
      visible: config.showModel && (root.nvidiaModel !== "" || root.intelModel !== "")

      Text {
        visible: root.gpuAvailable && root.nvidiaModel !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.nvidiaModel
        color: Colors[config.colorLabel]
        opacity: 0.55
        font.pixelSize: 10
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
      Text {
        visible: config.showIntel && root.intelModel !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.intelModel
        color: Colors[config.colorLabel]
        opacity: 0.55
        font.pixelSize: 10
        elide: Text.ElideRight
        Layout.maximumWidth: config.fixedWidth - 16
      }
    }

    Shared.Sparkline {
      visible: config.showHistory && root.gpuAvailable
      Layout.preferredWidth: 140
      Layout.preferredHeight: 32
      history: root.gpuHistory
      lineColor: Colors[config.colorValue]
      fillColor: Qt.rgba(Colors[config.colorValue].r, Colors[config.colorValue].g, Colors[config.colorValue].b, 0.15)
    }

    Text {
      visible: !root.gpuAvailable
      Layout.alignment: Qt.AlignHCenter
      text: "GPU indisponível"
      color: Colors[config.colorLabel]
      opacity: 0.5
      font.pixelSize: 12
    }
  }
}
