import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabWeather.qml → modules/widgets/weather/
import '../../../../widgets/weather' as Widgets

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

  Widgets.WeatherConfig { id: wthrCfg }

  C.CfgScroll {

    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: wthrCfg.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => wthrCfg.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: wthrCfg.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => wthrCfg.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "LOCALIZAÇÃO"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Sem busca por nome de cidade — defina latitude/longitude manualmente " +
            "(ex: openstreetmap.org, botão direito no local → \"O que há aqui?\")."
    }

    Rectangle {
      width: parent.width; height: 30; radius: 6
      color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
      border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
      border.width: 1
      TextInput {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: root.colorText
        font.pixelSize: 12
        text: wthrCfg.cityLabel
        onEditingFinished: wthrCfg.cityLabel = text
      }
    }

    RowLayout {
      width: parent.width
      spacing: 6

      Rectangle {
        Layout.fillWidth: true; height: 30; radius: 6
        color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
        border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
        border.width: 1
        TextInput {
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: root.colorText
          font.pixelSize: 12
          validator: DoubleValidator {}
          text: wthrCfg.latitude.toString()
          onEditingFinished: wthrCfg.latitude = parseFloat(text) || wthrCfg.latitude
        }
      }
      Rectangle {
        Layout.fillWidth: true; height: 30; radius: 6
        color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.06)
        border.color: Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.15)
        border.width: 1
        TextInput {
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: root.colorText
          font.pixelSize: 12
          validator: DoubleValidator {}
          text: wthrCfg.longitude.toString()
          onEditingFinished: wthrCfg.longitude = parseFloat(text) || wthrCfg.longitude
        }
      }
    }

    Row {
      spacing: 6
      C.CfgChip {
        label: "°C"; active: wthrCfg.units === "celsius"
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: wthrCfg.units = "celsius"
      }
      C.CfgChip {
        label: "°F"; active: wthrCfg.units === "fahrenheit"
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: wthrCfg.units = "fahrenheit"
      }
    }

    C.CfgSlider {
      label: "Atualizar a cada"; from: 5; to: 60; step: 5; unit: " min"
      value: wthrCfg.updateIntervalMin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => wthrCfg.updateIntervalMin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "APARÊNCIA"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Mostrar ícone"
      checked: wthrCfg.showIcon
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: wthrCfg.showIcon = !wthrCfg.showIcon
    }

    C.CfgToggle {
      label: "Mostrar sensação térmica"
      checked: wthrCfg.showFeelsLike
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: wthrCfg.showFeelsLike = !wthrCfg.showFeelsLike
    }

    C.CfgSlider {
      label: "Tamanho da fonte da temperatura"; from: 24; to: 96; step: 2; unit: " px"
      value: wthrCfg.fontSizeTemp
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => wthrCfg.fontSizeTemp = v
    }

    C.CfgSlider {
      label: "Tamanho da fonte da descrição"; from: 10; to: 24; step: 1; unit: " px"
      value: wthrCfg.fontSizeDesc
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => wthrCfg.fontSizeDesc = v
    }

    C.CfgPalette {
      label: "Cor da temperatura"
      value: wthrCfg.colorTemp
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => wthrCfg.colorTemp = v
    }

    C.CfgPalette {
      label: "Cor da descrição"
      value: wthrCfg.colorDesc
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => wthrCfg.colorDesc = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões do clima"
      onClicked: {
        wthrCfg.position          = 2
        wthrCfg.edgeMargin        = 48
        wthrCfg.latitude          = -19.9167
        wthrCfg.longitude         = -43.9345
        wthrCfg.cityLabel         = "Belo Horizonte"
        wthrCfg.units             = "celsius"
        wthrCfg.updateIntervalMin = 15
        wthrCfg.fontSizeTemp      = 48
        wthrCfg.fontSizeDesc      = 14
        wthrCfg.showFeelsLike     = true
        wthrCfg.showIcon          = true
        wthrCfg.colorTemp         = "primary"
        wthrCfg.colorDesc         = "on_surface"
      }
    }
  }
}
