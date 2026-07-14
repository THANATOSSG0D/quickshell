import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabGPU.qml → modules/widgets/gpu/
import '../../../../widgets/gpu' as Shared

Item {
  id: root

  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  anchors.fill: parent

  Shared.GpuConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE GPU"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Uso, VRAM, temperatura e consumo da GTX 1060 via nvidia-smi. Se a GPU estiver " +
            "em modo de economia (PRIME offload) e nvidia-smi não responder, mostra " +
            "'GPU indisponível' em vez de travar. A Intel UHD 630 aparece como uma linha " +
            "extra (via intel_gpu_top) — se não aparecer nada, pode precisar liberar " +
            "acesso a perf_event (ex: sudo sysctl -w dev.i915.perf_stream_paranoid=0). " +
            "Some da tela quando 'GPU' estiver marcado num grupo combinado."
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: config.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => config.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: config.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "TAMANHO"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Fixo — evita que o card mude de tamanho/posição quando o texto muda de largura."
    }

    C.CfgSlider {
      label: "Largura"; from: 140; to: 320; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 90; to: 300; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DETALHES"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Gráfico de histórico"
      checked: config.showHistory
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showHistory = !config.showHistory
    }
    C.CfgToggle {
      label: "Mostrar VRAM"
      checked: config.showVram
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showVram = !config.showVram
    }
    C.CfgToggle {
      label: "Temperatura"
      checked: config.showTemp
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showTemp = !config.showTemp
    }
    C.CfgToggle {
      label: "Consumo (W)"
      checked: config.showPower
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showPower = !config.showPower
    }
    C.CfgToggle {
      label: "Intel UHD 630 (intel_gpu_top)"
      checked: config.showIntel
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showIntel = !config.showIntel
    }
    C.CfgToggle {
      label: "Nomes dos modelos (lspci)"
      checked: config.showModel
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showModel = !config.showModel
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 210
        config.fixedHeight = 190
        config.showHistory = true
        config.showVram = true
        config.showTemp = true
        config.showPower = true
        config.showIntel = true
        config.showModel = true
      }
    }
  }
}
