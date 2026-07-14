import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
            "do ponto de montagem principal '" + config.mountPoint + "'. Pra trocar ESSE, " +
            "ainda só editando state/DiskWidget.json direto — mas dá pra adicionar outros " +
            "discos (HD externo, outra partição etc.) ali embaixo, em 'Discos extras'. " +
            "Some da tela quando 'Disco' estiver marcado num grupo combinado."
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
    C.CfgSection { title: "DISCOS EXTRAS"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Adicione o ponto de montagem de outro disco (ex: /mnt/hd, /run/media/" +
            "antonio/Backup). Aparece como uma linha compacta abaixo do disco principal."
    }

    RowLayout {
      width: parent.width
      spacing: 8

      TextField {
        id: mountInput
        Layout.fillWidth: true
        placeholderText: "/mnt/hd"
        color: root.colorText
        font.pixelSize: 12
        background: Rectangle {
          radius: 6
          color: Qt.rgba(1, 1, 1, 0.05)
          border.width: 1
          border.color: mountInput.activeFocus
            ? root.colorAccent
            : Qt.rgba(1, 1, 1, 0.12)
        }
        onAccepted: {
          config.addMount(text)
          text = ""
        }
      }

      Rectangle {
        width: 30; height: 30; radius: 8
        color: addMa.containsMouse
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
          : "transparent"
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b,
                              addMa.containsMouse ? 0.6 : 0.3)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "󰐕"; color: root.colorAccent
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }

        MouseArea {
          id: addMa; anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { config.addMount(mountInput.text); mountInput.text = "" }
        }
      }
    }

    ColumnLayout {
      width: parent.width
      spacing: 4
      visible: config.extraMounts.length > 0

      Repeater {
        model: config.extraMounts
        delegate: RowLayout {
          required property string modelData
          Layout.fillWidth: true
          spacing: 8

          Text {
            Layout.fillWidth: true
            text: modelData
            color: root.colorText
            font.pixelSize: 12
            elide: Text.ElideMiddle
          }
          Text {
            text: "󰩹"
            color: root.colorTextDim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              cursorShape: Qt.PointingHandCursor
              onClicked: config.removeMount(modelData)
            }
          }
        }
      }
    }

    Text {
      visible: config.extraMounts.length === 0
      text: "Nenhum disco extra adicionado."
      color: root.colorTextDim
      font.pixelSize: 11
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
