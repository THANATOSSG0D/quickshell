import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabFavorites.qml → modules/widgets/favorites/
import '../../../../widgets/favorites' as Shared

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

  Shared.FavoritesConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE APPS FAVORITOS"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Grade de atalhos configurados manualmente. Cada item usa um glyph de Nerd " +
            "Font como ícone (ex: \\uf001) e um comando executado via shell ao clicar."
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "APPS"; colorTextDim: root.colorTextDim }

    Column {
      width: parent.width
      spacing: 6

      Repeater {
        model: config.apps
        delegate: Rectangle {
          required property var modelData
          width: parent.width
          height: 44
          radius: 8
          color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.5)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
              width: 28; height: 28; radius: 6
              color: "transparent"
              border.width: 1
              border.color: root.colorDivider

              TextInput {
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: root.colorAccent
                font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                text: modelData.icon
                selectByMouse: true
                maximumLength: 4
                onEditingFinished: config.updateApp(modelData.id, { icon: text })
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              TextInput {
                Layout.fillWidth: true
                text: modelData.name
                color: root.colorText
                font.pixelSize: 12
                clip: true
                selectByMouse: true
                onEditingFinished: config.updateApp(modelData.id, { name: text })
              }
              TextInput {
                Layout.fillWidth: true
                text: modelData.command
                color: root.colorTextDim
                font.pixelSize: 10
                clip: true
                selectByMouse: true
                onEditingFinished: config.updateApp(modelData.id, { command: text })
              }
            }

            Text {
              text: "\uf1f8"
              color: root.colorTextDim
              font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
              MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: config.removeApp(modelData.id)
              }
            }
          }
        }
      }
    }

    // ── adicionar novo app ────────────────────────────────────────────
    Rectangle {
      width: parent.width
      height: 76
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            width: 28; height: 28; radius: 6
            border.width: 1
            border.color: root.colorDivider
            color: "transparent"
            TextInput {
              id: newIconInput
              anchors.fill: parent
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              color: root.colorAccent
              font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
              maximumLength: 4
              selectByMouse: true
            }
          }

          TextInput {
            id: newNameInput
            Layout.fillWidth: true
            color: root.colorText
            font.pixelSize: 12
            selectByMouse: true
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: newNameInput.text.length === 0
              text: "nome"
              color: root.colorTextDim
              opacity: 0.5
              font.pixelSize: 12
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          TextInput {
            id: newCommandInput
            Layout.fillWidth: true
            color: root.colorText
            font.pixelSize: 11
            selectByMouse: true
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: newCommandInput.text.length === 0
              text: "comando (ex: firefox)"
              color: root.colorTextDim
              opacity: 0.5
              font.pixelSize: 11
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
                if (newNameInput.text.trim().length === 0) return
                config.addApp(newNameInput.text, newCommandInput.text, newIconInput.text)
                newNameInput.text = ""
                newCommandInput.text = ""
                newIconInput.text = ""
              }
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
    C.CfgSection { title: "GRADE"; colorTextDim: root.colorTextDim }

    C.CfgSlider {
      label: "Colunas"; from: 2; to: 8; step: 1; unit: ""
      value: config.columns
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.columns = v
    }
    C.CfgSlider {
      label: "Tamanho do ícone"; from: 14; to: 36; step: 1; unit: " px"
      value: config.iconSize
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.iconSize = v
    }
    C.CfgSlider {
      label: "Largura"; from: 140; to: 360; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura máxima"; from: 80; to: 320; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
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
        config.columns = 4
        config.iconSize = 22
      }
    }
  }
}
