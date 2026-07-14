import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabDisk.qml → modules/widgets/disk/
import '../../../../widgets/disk' as Shared

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

  Shared.DiskConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE DISCO"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Espaço usado (via df) e throughput de leitura/escrita (via /proc/diskstats) " +
            "do ponto de montagem '" + config.mountPoint + "'. Pra monitorar outro " +
            "filesystem, edite 'mountPoint' direto em state/DiskWidget.json — não tem " +
            "campo de texto aqui ainda. Some da tela quando 'Disco' estiver marcado num " +
            "grupo combinado."
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
      label: "Largura"; from: 140; to: 320; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 70; to: 220; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DETALHES"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Gráfico de histórico (I/O)"
      checked: config.showHistory
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showHistory = !config.showHistory
    }
    C.CfgToggle {
      label: "Leitura/escrita em tempo real"
      checked: config.showIO
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showIO = !config.showIO
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
        config.fixedHeight = 110
        config.showHistory = true
        config.showIO = true
      }
    }
  }
}
