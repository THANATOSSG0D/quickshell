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
      text: "Lista de hábitos com contador de streak e um heatmap agregado estilo GitHub " +
            "(intensidade = % de hábitos concluídos naquele dia). Clique no quadradinho ao " +
            "lado do nome pra marcar o hábito como feito hoje."
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "HÁBITOS"; colorTextDim: root.colorTextDim }

    // ── lista de hábitos existentes ──────────────────────────────────
    Column {
      width: parent.width
      spacing: 6

      Repeater {
        model: config.habits
        delegate: Rectangle {
          required property var modelData
          width: parent.width
          height: 40
          radius: 8
          color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.5)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
              width: 16; height: 16; radius: 4
              color: colorFor(modelData.color)
              function colorFor(key) { return Colors[key] || root.colorAccent }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: config.cycleHabitColor(modelData.id)
              }
            }

            TextInput {
              Layout.fillWidth: true
              text: modelData.name
              color: root.colorText
              font.pixelSize: 12
              clip: true
              selectByMouse: true
              onEditingFinished: config.renameHabit(modelData.id, text)
            }

            Text {
              text: config.streakFor(modelData) + "d"
              color: root.colorAccent
              font.pixelSize: 11
            }

            Text {
              text: "\uf1f8" // lixeira (Nerd Font)
              color: root.colorTextDim
              font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
              MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: config.removeHabit(modelData.id)
              }
            }
          }
        }
      }
    }

    // ── adicionar novo hábito ────────────────────────────────────────
    Rectangle {
      width: parent.width
      height: 36
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        TextInput {
          id: newHabitInput
          Layout.fillWidth: true
          color: root.colorText
          font.pixelSize: 12
          clip: true
          selectByMouse: true

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: newHabitInput.text.length === 0
            text: "novo hábito…"
            color: root.colorTextDim
            opacity: 0.5
            font.pixelSize: 12
          }

          onAccepted: {
            if (text.trim().length === 0) return
            config.addHabit(text)
            text = ""
          }
        }

        Text {
          text: "adicionar"
          color: root.colorAccent
          font.pixelSize: 11
          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (newHabitInput.text.trim().length === 0) return
              config.addHabit(newHabitInput.text)
              newHabitInput.text = ""
            }
          }
        }
      }
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
