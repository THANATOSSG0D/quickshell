import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabClock.qml → modules/widgets/clock/
import '../../../../widgets/clock' as Widgets

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

  Widgets.ClockConfig { id: clockCfg }

  readonly property var _dateFormats: [
    { id: "dddd · MMM dd", label: "Dia · Mês" },
    { id: "dd/MM/yyyy",    label: "31/12/2026" },
    { id: "MMM dd, yyyy",  label: "Mês dd, ano" },
    { id: "yyyy-MM-dd",    label: "ISO" },
  ]

  C.CfgScroll {

    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: clockCfg.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => clockCfg.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: clockCfg.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => clockCfg.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "HORA"; colorTextDim: root.colorTextDim }

    Row {
      spacing: 6
      C.CfgChip {
        label: "24h"; active: clockCfg.use24h
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: clockCfg.use24h = true
      }
      C.CfgChip {
        label: "12h (AM/PM)"; active: !clockCfg.use24h
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: clockCfg.use24h = false
      }
    }

    C.CfgSlider {
      label: "Tamanho da fonte da hora"; from: 32; to: 140; step: 2; unit: " px"
      value: clockCfg.fontSizeTime
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => clockCfg.fontSizeTime = v
    }

    C.CfgPalette {
      label: "Cor da hora"
      value: clockCfg.colorTime
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => clockCfg.colorTime = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "DATA"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Mostrar data"
      checked: clockCfg.showDate
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: clockCfg.showDate = !clockCfg.showDate
    }

    Row {
      spacing: 6
      visible: clockCfg.showDate
      Repeater {
        model: root._dateFormats
        delegate: C.CfgChip {
          required property var modelData
          label:  modelData.label
          active: clockCfg.dateFormat === modelData.id
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: clockCfg.dateFormat = modelData.id
        }
      }
    }

    C.CfgSlider {
      visible: clockCfg.showDate
      label: "Tamanho da fonte da data"; from: 10; to: 32; step: 1; unit: " px"
      value: clockCfg.fontSizeDate
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => clockCfg.fontSizeDate = v
    }

    C.CfgPalette {
      visible: clockCfg.showDate
      label: "Cor da data"
      value: clockCfg.colorDate
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => clockCfg.colorDate = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "LINHA DIVISÓRIA"; colorTextDim: root.colorTextDim }

    C.CfgToggle {
      label: "Mostrar linha entre hora e data"
      checked: clockCfg.showLine
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: clockCfg.showLine = !clockCfg.showLine
    }

    C.CfgPalette {
      visible: clockCfg.showLine
      label: "Cor da linha"
      value: clockCfg.colorLine
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => clockCfg.colorLine = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões do relógio"
      onClicked: {
        clockCfg.position     = 4
        clockCfg.edgeMargin   = 48
        clockCfg.fontSizeTime = 72
        clockCfg.use24h       = true
        clockCfg.colorTime    = "primary"
        clockCfg.showDate     = true
        clockCfg.fontSizeDate = 16
        clockCfg.dateFormat   = "dddd · MMM dd"
        clockCfg.colorDate    = "on_surface"
        clockCfg.showLine     = true
        clockCfg.colorLine    = "outline"
      }
    }
  }
}
