import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabMediaPlayer.qml → modules/widgets/mediaplayer/
import '../../../../widgets/mediaplayer' as Shared

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

  Shared.MediaPlayerConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE MEDIA PLAYER"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Mostra o player MPRIS ativo agora (capa, título, artista, progresso e " +
            "controles). Se nenhum player estiver aberto, mostra um botão que executa o " +
            "comando de abertura configurado abaixo."
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "PLAYER"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      color: root.colorTextDim
      opacity: 0.7
      font.pixelSize: 10
      text: "Player preferido (opcional)"
    }
    Rectangle {
      width: parent.width
      height: 32
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"
      TextInput {
        anchors.fill: parent
        anchors.margins: 8
        color: root.colorText
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        text: config.preferredPlayerId
        onEditingFinished: config.preferredPlayerId = text

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: parent.text.length === 0
          text: "identity ou desktopEntry MPRIS — vazio = automático"
          color: root.colorTextDim
          opacity: 0.5
          font.pixelSize: 11
        }
      }
    }

    Text {
      width: parent.width
      Layout.topMargin: 4
      color: root.colorTextDim
      opacity: 0.7
      font.pixelSize: 10
      text: "Rótulo mostrado sem player aberto"
    }
    Rectangle {
      width: parent.width
      height: 32
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"
      TextInput {
        anchors.fill: parent
        anchors.margins: 8
        color: root.colorText
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        text: config.appLabel
        onEditingFinished: config.appLabel = text
      }
    }

    Text {
      width: parent.width
      color: root.colorTextDim
      opacity: 0.7
      font.pixelSize: 10
      text: "Comando pra abrir o app (quando fechado)"
    }
    Rectangle {
      width: parent.width
      height: 32
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"
      TextInput {
        anchors.fill: parent
        anchors.margins: 8
        color: root.colorText
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        text: config.launchCommand
        onEditingFinished: config.launchCommand = text

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: parent.text.length === 0
          text: "ex: spotify"
          color: root.colorTextDim
          opacity: 0.5
          font.pixelSize: 11
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
      label: "Largura"; from: 180; to: 400; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 100; to: 260; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DETALHES"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Mostrar capa do álbum"
      checked: config.showCoverArt
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showCoverArt = !config.showCoverArt
    }
    C.CfgToggle {
      label: "Mostrar barra de progresso (com seek)"
      checked: config.showProgress
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showProgress = !config.showProgress
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 260
        config.fixedHeight = 150
        config.showCoverArt = true
        config.showProgress = true
      }
    }
  }
}
