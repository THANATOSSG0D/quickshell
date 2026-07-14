import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabBluetooth.qml → modules/widgets/bluetooth/
import '../../../../widgets/bluetooth' as Shared

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

  Shared.BluetoothConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE BLUETOOTH"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Mostra quantos dispositivos estão conectados agora via bluetoothctl, com nome " +
            "e bateria (quando o dispositivo expõe o perfil Battery). É só monitor — ligar/" +
            "desligar o adaptador continua pelo Config Rápida. Some da tela quando " +
            "'Bluetooth' estiver marcado num grupo combinado."
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
      text: "Mostra no máximo 3 dispositivos — o resto vira um resumo tipo '+2 mais', pra " +
            "não crescer sem limite."
    }

    C.CfgSlider {
      label: "Largura"; from: 140; to: 320; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura"; from: 70; to: 260; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DETALHES"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Nome dos dispositivos conectados"
      checked: config.showDeviceNames
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showDeviceNames = !config.showDeviceNames
    }
    C.CfgToggle {
      label: "Bateria dos dispositivos"
      checked: config.showBattery
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showBattery = !config.showBattery
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
        config.fixedHeight = 130
        config.showDeviceNames = true
        config.showBattery = true
      }
    }
  }
}
