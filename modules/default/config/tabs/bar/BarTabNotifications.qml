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
  function g(key, def) {
    if (!config) return def
    var v = config.get("notifications", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Helper: linha de enum como chips, mesmo padrão usado em outras abas ─
  component EnumRow: Column {
    id: enumRoot
    property string label: ""
    property var    options: []
    property var    value
    property color  colorAccent
    property color  colorTextDim
    signal picked(var id)

    width: parent ? parent.width : 0
    spacing: 6

    Text { text: enumRoot.label; color: enumRoot.colorTextDim; font.pixelSize: 11 }

    Flow {
      width: parent.width
      spacing: 6
      Repeater {
        model: enumRoot.options
        delegate: C.CfgChip {
          required property var modelData
          label:        modelData.label
          active:       enumRoot.value === modelData.id
          // IMPORTANTE: precisa ser enumRoot.colorAccent / enumRoot.colorTextDim
          // aqui. "colorAccent: colorAccent" (sem qualificar) cria uma
          // auto-referência, porque o CfgChip também tem uma prop com esse
          // mesmo nome — o QML resolve pro próprio CfgChip, não pro EnumRow
          // de fora, e a cor cai pro default não-inicializado (preto).
          colorAccent:  enumRoot.colorAccent
          colorTextDim: enumRoot.colorTextDim
          onChipClicked: enumRoot.picked(modelData.id)
        }
      }
    }
  }

  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Críticas ignoram Não Perturbe"
    checked: root.g("dndAllowCritical", true)
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId:"notifications", key:"dndAllowCritical", value: !checked })
  }

  EnumRow {
    label: "Filtro padrão do painel"
    options: [ {id:0,label:"Todas"}, {id:1,label:"Normais"}, {id:2,label:"Críticas"} ]
    value: root.g("defaultUrgencyFilter", 0)
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
    value: root.g("toastPosition", "top-right")
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onPicked: (id) => root.changed({ moduleId:"notifications", key:"toastPosition", value:id })
  }

  C.CfgSlider {
    label: "Máx. toasts simultâneos"
    value: root.g("maxToasts", 5)
    from: 1; to: 10; step: 1
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"maxToasts", value:v })
  }
  C.CfgSlider {
    label: "Duração (normal)"
    value: root.g("toastTimeoutMs", 5000)
    from: 1000; to: 15000; step: 500; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutMs", value:v })
  }
  C.CfgSlider {
    label: "Duração (baixa urgência)"
    value: root.g("toastTimeoutLow", 3000)
    from: 1000; to: 15000; step: 500; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutLow", value:v })
  }
  C.CfgSlider {
    label: "Duração (crítica, 0=nunca)"
    value: root.g("toastTimeoutCrit", 0)
    from: 0; to: 30000; step: 1000; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastTimeoutCrit", value:v })
  }
  C.CfgSlider {
    label: "Largura do toast"
    value: root.g("toastWidth", 340)
    from: 220; to: 520; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastWidth", value:v })
  }
  C.CfgSlider {
    label: "Margem da borda da tela"
    value: root.g("toastMargin", 12)
    from: 0; to: 60; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastMargin", value:v })
  }
  C.CfgSlider {
    label: "Espaço entre toasts"
    value: root.g("toastSpacing", 8)
    from: 0; to: 30; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"toastSpacing", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "HISTÓRICO E CARDS"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Máx. no histórico"
    value: root.g("maxHistory", 50)
    from: 10; to: 200; step: 10
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"maxHistory", value:v })
  }
  C.CfgSlider {
    label: "Raio dos cards"
    value: root.g("cardRadius", 10)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId:"notifications", key:"cardRadius", value:v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "REGRAS POR APP"; colorTextDim: root.colorTextDim }

  Text {
    text: "Liste apps separados por vírgula. Cada termo é REGEX (case-insensitive) contra o nome do app que mandou a notificação — mesma convenção do campo de prioridade de players da Mídia."
    color: root.colorTextDim
    font.pixelSize: 11
    wrapMode: Text.WordWrap
    width: parent.width
  }

  Text {
    text: "Sempre mostra toast (ignora Não Perturbe)"
    color: root.colorTextDim
    font.pixelSize: 11
    topPadding: 4
  }
  Rectangle {
    width:  parent.width
    height: 34
    radius: 6
    color:  root.colorSidebar
    border.width: 1
    border.color: root.colorDivider

    TextInput {
      id: dndBypassInput
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      verticalAlignment: TextInput.AlignVCenter
      color: root.colorText
      font.pixelSize: 12
      selectByMouse: true
      text: root.g("dndBypassApps", "")

      onEditingFinished: root.changed({ moduleId: "notifications", key: "dndBypassApps", value: text })
    }
  }

  Text {
    text: "Nunca mostra toast (continua indo pro histórico)"
    color: root.colorTextDim
    font.pixelSize: 11
    topPadding: 8
  }
  Rectangle {
    width:  parent.width
    height: 34
    radius: 6
    color:  root.colorSidebar
    border.width: 1
    border.color: root.colorDivider

    TextInput {
      id: blockedToastInput
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      verticalAlignment: TextInput.AlignVCenter
      color: root.colorText
      font.pixelSize: 12
      selectByMouse: true
      text: root.g("blockedToastApps", "")

      onEditingFinished: root.changed({ moduleId: "notifications", key: "blockedToastApps", value: text })
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.g("textColor", "on_surface")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"textColor", value:v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"dimColor", value:v })
  }
  C.CfgPalette {
    label: "Acento"; value: root.g("accentColor", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"accentColor", value:v })
  }
  C.CfgPalette {
    // Key real é "mutedColor" — confirmado em Notifications.qml, NotifTooltip,
    // NotificationsContent/Popup/Toast, que todos leem colorMuted a partir
    // dela. O nome "Urgente" no label é só legado, mas a key não muda.
    label: "Urgente"; value: root.g("mutedColor", "error")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"mutedColor", value:v })
  }
  C.CfgPalette {
    label: "Divisor"; value: root.g("divider", "outline_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId:"notifications", key:"divider", value:v })
  }
}
