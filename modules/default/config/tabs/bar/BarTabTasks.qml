import QtQuick
import QtQuick.Layouts
import '../../components' as C

// ── BarTabTasks ─────────────────────────────────────────────────────────
// Aba de config do módulo de BARRA "tasks" (ícone + badge na barra).
// Mesmo padrão do BarTabClock.qml — só cores, já que o módulo não tem
// comportamento próprio configurável (isso fica no painel, ver PanelTab).

C.CfgScroll {
  id: root

  required property var   config
  required property var   colors
  required property var   overlay
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorProgressBg
  required property color colorSidebar
  required property color colorDivider

  signal changed(var opts)

  function g(key, def) {
    if (!config) return def
    var v = config.get("tasks", key)
    return (v !== undefined && v !== null) ? v : def
  }

  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Calendário (botão direito + ícone no painel)"
    checked: root.g("calendarEnabled", true)
    colorAccent: root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "tasks", key: "calendarEnabled", value: !root.g("calendarEnabled", true) })
  }

  Text {
    text: "Data no contador da barra"
    color: root.colorTextDim
    font.pixelSize: 9
    opacity: 0.7
    topPadding: 6
  }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "off",   label: "Desligada" },
        { id: "short", label: "Curta (01/09)" },
        { id: "full",  label: "Por extenso" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label
        active: root.g("dateDisplay", "off") === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "tasks", key: "dateDisplay", value: modelData.id })
      }
    }
  }

  C.CfgToggle {
    label: "Número de tarefas pendentes"
    checked: root.g("showCount", true)
    colorAccent: root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "tasks", key: "showCount", value: !root.g("showCount", true) })
  }

  Text {
    text: "Posição da data"
    color: root.colorTextDim
    font.pixelSize: 9
    opacity: 0.7
    topPadding: 6
  }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "after",  label: "Depois do número" },
        { id: "before", label: "Antes do número" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label
        active: root.g("datePosition", "after") === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "tasks", key: "datePosition", value: modelData.id })
      }
    }
  }

  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.g("textColor", "on_surface")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "tasks", key: "textColor", value: v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "tasks", key: "dimColor", value: v })
  }
  C.CfgPalette {
    label: "Accent (atrasadas)"; value: root.g("accentColor", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "tasks", key: "accentColor", value: v })
  }
}
