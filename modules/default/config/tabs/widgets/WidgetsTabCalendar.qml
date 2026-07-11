import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabCalendar.qml → modules/widgets/calendar/
import '../../../../widgets/calendar' as Widgets

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

  Widgets.CalendarConfig { id: calCfg }

  C.CfgScroll {

    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: calCfg.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => calCfg.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: calCfg.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => calCfg.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "APARÊNCIA"; colorTextDim: root.colorTextDim }

    C.CfgSlider {
      label: "Tamanho da fonte dos dias"; from: 10; to: 22; step: 1; unit: " px"
      value: calCfg.fontSize
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => calCfg.fontSize = v
    }

    C.CfgSlider {
      label: "Tamanho da fonte do cabeçalho"; from: 10; to: 28; step: 1; unit: " px"
      value: calCfg.fontSizeHeader
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => calCfg.fontSizeHeader = v
    }

    C.CfgToggle {
      label: "Semana começa na segunda"
      checked: calCfg.weekStartsMonday
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: calCfg.weekStartsMonday = !calCfg.weekStartsMonday
    }

    C.CfgToggle {
      label: "Marcar dias com tarefas"
      checked: calCfg.showTaskDots
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onToggled: calCfg.showTaskDots = !calCfg.showTaskDots
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

    C.CfgPalette {
      label: "Cor do dia atual"
      value: calCfg.colorToday
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => calCfg.colorToday = v
    }

    C.CfgPalette {
      label: "Cor do texto"
      value: calCfg.colorText
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => calCfg.colorText = v
    }

    C.CfgPalette {
      label: "Cor de fim de semana"
      value: calCfg.colorWeekend
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar
      colorDivider: root.colorDivider
      onEdited: (v) => calCfg.colorWeekend = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões do calendário"
      onClicked: {
        calCfg.position         = 5
        calCfg.edgeMargin       = 48
        calCfg.fontSize         = 13
        calCfg.fontSizeHeader   = 16
        calCfg.weekStartsMonday = true
        calCfg.showWeekNumbers  = false
        calCfg.showTaskDots     = true
        calCfg.colorToday       = "primary"
        calCfg.colorWeekend     = "on_surface"
        calCfg.colorText        = "on_surface"
      }
    }
  }
}
