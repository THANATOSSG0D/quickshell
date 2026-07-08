import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTab.qml → modules/widgets/clock/
// (sobe 4 níveis: widgets/ → tabs/ → config/ → default/ → modules/,
// depois entra em widgets/clock/)
import '../../../../widgets/clock' as Widgets

// ── WidgetsTab ────────────────────────────────────────────────────────────
// Aba de configuração dos widgets "livres" (overlay na tela, fora da barra).
// Por enquanto só tem o Relógio, mas a estrutura já fica pronta pra receber
// mais widgets no futuro (sub-abas em _allModules → "widgets").
//
// Igual ao ClockConfig.qml: essa aba abre sua PRÓPRIA instância de
// ClockConfig, que lê/escreve o mesmo JSON (state/ClockWidget.json) que a
// instância dentro do ClockWidget.qml. FileView com watchChanges cuida da
// sincronização — não precisa passar nenhuma referência pelo shell.qml.

Item {
  id: root

  property int activeSubtab: 0

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

  readonly property var _positionGrid: [
    { i: 0, label: "\uf062\uf060" }, { i: 1, label: "\uf062" }, { i: 2, label: "\uf062\uf061" },
    { i: 3, label: "\uf060" },       { i: 4, label: "\uf055" }, { i: 5, label: "\uf061" },
    { i: 6, label: "\uf063\uf060" }, { i: 7, label: "\uf063" }, { i: 8, label: "\uf063\uf061" },
  ]
  readonly property var _positionNames: [
    "Superior esquerdo", "Superior centro", "Superior direito",
    "Centro esquerdo",   "Centro",          "Centro direito",
    "Inferior esquerdo", "Inferior centro", "Inferior direito",
  ]

  readonly property var _dateFormats: [
    { id: "dddd · MMM dd", label: "Dia · Mês" },
    { id: "dd/MM/yyyy",    label: "31/12/2026" },
    { id: "MMM dd, yyyy",  label: "Mês dd, ano" },
    { id: "yyyy-MM-dd",    label: "ISO" },
  ]

  C.CfgScroll {

    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    GridLayout {
      columns: 3
      rowSpacing: 6; columnSpacing: 6
      width: parent.width

      Repeater {
        model: root._positionGrid
        delegate: C.CfgChip {
          required property var modelData
          Layout.fillWidth: true
          label:  root._positionNames[modelData.i]
          active: clockCfg.position === modelData.i
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: clockCfg.position = modelData.i
        }
      }
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

    // ── Botão restaurar padrões ─────────────────────────────────────────
    Item {
      width: parent.width; height: 32

      Rectangle {
        id: _resetBtn
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        height: 22; width: _resetRow.implicitWidth + 14; radius: 6
        color: _resetMa.containsMouse
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
          : "transparent"
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b,
                              _resetMa.containsMouse ? 0.5 : 0.25)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 60 } }
        Behavior on border.color { ColorAnimation { duration: 60 } }

        Row {
          id: _resetRow; anchors.centerIn: parent; spacing: 5
          Text { text: "󰑙"; color: root.colorAccent
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
            anchors.verticalCenter: parent.verticalCenter }
          Text { text: "restaurar padrões do relógio"; color: root.colorAccent
            font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
          id: _resetMa; anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
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
  }
}
