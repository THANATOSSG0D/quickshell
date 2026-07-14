import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabNetwork.qml → modules/widgets/network/
import '../../../../widgets/network' as Shared

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

  Shared.NetworkConfig { id: config }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE REDE"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Detecta automaticamente a interface ativa via NetworkManager (prioriza cabo " +
            "sobre Wi-Fi) e mostra down/upload em tempo real, IP local, DNS (via " +
            "/etc/resolv.conf — se aparecer só 127.0.0.53 é o stub do systemd-resolved) " +
            "e se tem VPN ativa. Some da tela quando 'Rede' estiver marcado num grupo " +
            "combinado."
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
      label: "Gráfico de histórico"
      checked: config.showHistory
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showHistory = !config.showHistory
    }
    C.CfgToggle {
      label: "Nome da interface/SSID"
      checked: config.showIface
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showIface = !config.showIface
    }
    C.CfgToggle {
      label: "IP do dispositivo"
      checked: config.showIP
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showIP = !config.showIP
    }
    C.CfgToggle {
      label: "DNS"
      checked: config.showDNS
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showDNS = !config.showDNS
    }
    C.CfgToggle {
      label: "VPN ativa"
      checked: config.showVPN
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: config.showVPN = !config.showVPN
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
        config.fixedHeight = 150
        config.showHistory = true
        config.showIface = true
        config.showIP = true
        config.showDNS = true
        config.showVPN = true
      }
    }
  }
}
