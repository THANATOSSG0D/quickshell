import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabCPU.qml → modules/widgets/cpu/
import '../../../../widgets/cpu' as Shared

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

  Shared.CpuConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE CPU"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Uso geral (via /proc/stat), frequência média e temperatura (via lm-sensors). " +
            "Some da tela quando 'CPU' estiver marcado num grupo combinado."
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
      text: "Fixo — se o conteúdo passar do espaço reservado, ele só é cortado em vez de " +
            "empurrar o card e mudar a posição na tela."
    }

    C.CfgSlider {
      label: "Largura"; from: 140; to: 320; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 90; to: 280; step: 4; unit: " px"
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
      label: "Barras por núcleo"
      checked: config.showPerCore
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showPerCore = !config.showPerCore
    }
    C.CfgToggle {
      label: "Frequência (GHz)"
      checked: config.showFreq
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showFreq = !config.showFreq
    }
    C.CfgToggle {
      label: "Temperatura"
      checked: config.showTemp
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showTemp = !config.showTemp
    }
    C.CfgToggle {
      label: "Nome do modelo (ex: i7-8750H)"
      checked: config.showModel
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showModel = !config.showModel
    }
    C.CfgToggle {
      label: "Governor (ex: performance, powersave)"
      checked: config.showGovernor
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showGovernor = !config.showGovernor
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 200
        config.fixedHeight = 176
        config.showHistory = true
        config.showPerCore = true
        config.showFreq = true
        config.showTemp = true
        config.showModel = true
        config.showGovernor = true
      }
    }
  }
}
