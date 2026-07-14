import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabSystem.qml → modules/widgets/system/
import '../../../../widgets/system' as Shared

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

  Shared.SystemConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE SISTEMA"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Uptime, kernel, hostname e distro. Tudo lido direto de /proc e /etc/os-release " +
            "— não roda nenhum processo externo, é o widget mais leve de todos. Some da " +
            "tela quando 'Sistema' estiver marcado num grupo combinado."
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

    C.CfgSlider {
      label: "Largura"; from: 140; to: 340; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 80; to: 220; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DETALHES"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Hostname"
      checked: config.showHostname
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showHostname = !config.showHostname
    }
    C.CfgToggle {
      label: "Distro"
      checked: config.showDistro
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showDistro = !config.showDistro
    }
    C.CfgToggle {
      label: "Versão do kernel"
      checked: config.showKernel
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showKernel = !config.showKernel
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 220
        config.fixedHeight = 140
        config.showHostname = true
        config.showDistro = true
        config.showKernel = true
      }
    }
  }
}
