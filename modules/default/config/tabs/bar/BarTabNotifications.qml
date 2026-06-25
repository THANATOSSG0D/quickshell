import QtQuick
import '../../components' as C

C.CfgScroll {
  id: root
  required property var   config
  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  signal changed(var opts)
  function g(key) { return config ? config.get("notifications", key) : undefined }

  // ── Helper: linha de enum como chips, mesmo padrão usado em outras abas ─
  component EnumRow: Column {
    property string label: ""
    property var    options: []
    property var    value
    property color  colorAccent
    property color  colorTextDim
    signal picked(var id)

    width: parent ? parent.width : 0
    spacing: 6

    Text { text: label; color: colorTextDim; font.pixelSize: 11 }

    Flow {
      width: parent.width
      spacing: 6
      Repeater {
        model: options
        delegate: C.CfgChip {
          required property var modelData
          label:        modelData.label
          active:       value === modelData.id
          colorAccent:  colorAccent
          colorTextDim: colorTextDim
          onChipClicked: picked(modelData.id)
        }
      }
    }
  }

  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.g("textColor") || "on_surface"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"textColor", value:v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"dimColor", value:v })
  }
  C.CfgPalette {
    label: "Acento"; value: root.g("accentColor") || "primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"accentColor", value:v })
  }
  C.CfgPalette {
    label: "Urgente"; value: root.g("mutedColor") || "error"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"mutedColor", value:v })
  }
  C.CfgPalette {
    label: "Divisor"; value: root.g("divider") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"divider", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Críticas ignoram Não Perturbe"
    checked: root.g("dndAllowCritical") ?? true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId:"notifications", key:"dndAllowCritical", value: !checked })
  }

  EnumRow {
    label: "Filtro padrão do painel"
    options: [ {id:0,label:"Todas"}, {id:1,label:"Normais"}, {id:2,label:"Críticas"} ]
    value: root.g("defaultUrgencyFilter") ?? 0
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onPicked: (id) => root.changed({ moduleId:"notifications", key:"defaultUrgencyFilter", value:id })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "TOASTS"; colorTextDim: root.colorTextDim }

  // A posição dos toasts antes só dava pra trocar por um menu flutuante
  // dentro do próprio painel — agora mora aqui, então o painel ficou mais
  // limpo (sem aquele botão extra no cabeçalho).
  EnumRow {
    label: "Posição na tela"
    options: [
      {id:"top-left",     label:"Sup. esquerdo"},
      {id:"top-center",   label:"Sup. centro"},
      {id:"top-right",    label:"Sup. direito"},
      {id:"bottom-left",  label:"Inf. esquerdo"},
      {id:"bottom-center",label:"Inf. centro"},
      {id:"bottom-right", label:"Inf. direito"},
    ]
    value: root.g("toastPosition") || "top-right"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onPicked: (id) => root.changed({ moduleId:"notifications", key:"toastPosition", value:id })
  }

  C.CfgSlider {
    label: "Máx. toasts simultâneos"
    value: root.g("maxToasts") ?? 5
    from: 1; to: 10; step: 1
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"maxToasts", value:v })
  }
  C.CfgSlider {
    label: "Duração (normal)"
    value: root.g("toastTimeoutMs") ?? 5000
    from: 1000; to: 15000; step: 500; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutMs", value:v })
  }
  C.CfgSlider {
    label: "Duração (baixa urgência)"
    value: root.g("toastTimeoutLow") ?? 3000
    from: 1000; to: 15000; step: 500; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutLow", value:v })
  }
  C.CfgSlider {
    label: "Duração (crítica, 0=nunca)"
    value: root.g("toastTimeoutCrit") ?? 0
    from: 0; to: 30000; step: 1000; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutCrit", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "HISTÓRICO E CARDS"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Máx. no histórico"
    value: root.g("maxHistory") ?? 50
    from: 10; to: 200; step: 10
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"maxHistory", value:v })
  }
  C.CfgSlider {
    label: "Raio dos cards"
    value: root.g("cardRadius") ?? 10
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"cardRadius", value:v })
  }
}
