import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabHabits.qml → modules/widgets/habits/
import '../../../../widgets/habits' as Shared

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

  Shared.HabitsConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE HÁBITOS"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Dois tipos de hábito: \"marcar feito\" (ex: meditar) ou \"meta com contador\" pra " +
            "coisas que você registra várias vezes ao dia (ex: 8 copos de água, 30min de " +
            "exercício). Adicionar, editar e ver o histórico agora é feito direto no widget: " +
            "clique em \"+ novo hábito\" ou no ícone de painel (\uf0e4) no canto dele — essa " +
            "aba aqui é só pra ajustes visuais/comportamento."
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
      label: "Largura"; from: 160; to: 360; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura máxima"; from: 100; to: 400; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }
    C.CfgSlider {
      label: "Máximo de hábitos visíveis"; from: 1; to: 10; step: 1; unit: ""
      value: config.maxVisible
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.maxVisible = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "HEATMAP"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Mostrar heatmap agregado"
      checked: config.showHeatmap
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showHeatmap = !config.showHeatmap
    }
    C.CfgSlider {
      label: "Semanas no heatmap"; from: 4; to: 26; step: 1; unit: ""
      value: config.heatmapWeeks
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.heatmapWeeks = v
    }
    C.CfgSlider {
      label: "Tamanho do quadrado"; from: 6; to: 18; step: 1; unit: " px"
      value: config.squareSize
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.squareSize = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 240
        config.fixedHeight = 240
        config.maxVisible = 4
        config.showHeatmap = true
        config.heatmapWeeks = 10
        config.squareSize = 10
      }
    }
  }
}
