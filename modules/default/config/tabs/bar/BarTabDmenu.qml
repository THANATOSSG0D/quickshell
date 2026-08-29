import QtQuick
import QtQuick.Layouts
import '../../components' as C

// BarTabDmenu — configurações do módulo "dmenu" da barra (Dmenu.qml).
// Mesmo padrão do BarTabMidia.qml/BarTabClock.qml: cada controle lê o valor
// atual via config.get() e emite changed({moduleId,key,value}) na edição —
// o ConfigWindow escuta "changed" e chama win.applyChange(opts).
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
    var v = config.get("dmenu", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Campo de texto genérico (glifo / texto sem janela ativa) — mesmo
  //    idioma caseiro que o BarTabMidia.qml usa pra "Prioridade de players"
  component TextField: Item {
    id: fld
    required property string key
    property string label: ""
    property string hint:  ""
    property string defaultValue: ""
    property int    fieldWidth: 90
    property string fontFamily: ""
    width:  parent ? parent.width : 0
    height: 46

    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text { text: fld.label; color: root.colorText;    font.pixelSize: 11 }
      Text { text: fld.hint;  color: root.colorTextDim; font.pixelSize: 9; visible: fld.hint !== "" }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: fld.fieldWidth; height: 28; radius: 6
      color: Qt.rgba(1,1,1,0.05)
      border.color: input.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.12)
      border.width: 1
      Behavior on border.color { ColorAnimation { duration: 80 } }

      TextInput {
        id: input
        anchors.centerIn: parent
        width: parent.width - 16
        color: root.colorText
        font.pixelSize: 11
        font.family: fld.fontFamily !== "" ? fld.fontFamily : undefined
        horizontalAlignment: fld.fontFamily !== "" ? TextInput.AlignHCenter : TextInput.AlignLeft
        clip: true
        selectByMouse: true
        // NÃO deixa "text:" como binding permanente pro config — se o
        // round-trip changed()→applyChange()→config disparasse de novo
        // enquanto o usuário ainda está digitando, o binding reavaliaria
        // e sobrescreveria o texto no meio da digitação (parecia "não
        // fazer nada"). Em vez disso, carrega o valor UMA VEZ e depois só
        // escreve pro config — nunca mais lê de volta pro campo.
        Component.onCompleted: text = root.g(fld.key, fld.defaultValue)
        onTextChanged: {
          if (activeFocus) root.changed({ moduleId: "dmenu", key: fld.key, value: text })
        }
      }
    }
  }

  // ══════════════════════════════════════════════
  C.CfgSection { title: "GERAL"; colorTextDim: root.colorTextDim }

  Text {
    text: "O que o botão mostra na barra"
    color: root.colorTextDim
    font.pixelSize: 10
    width: parent.width
  }
  C.CfgToggle {
    label:   "Mostrar ícone"
    checked: root.g("showIcon", true) !== false
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "dmenu", key: "showIcon", value: !(root.g("showIcon", true) !== false) })
  }

  readonly property bool _showIcon: root.g("showIcon", true) !== false

  Row {
    spacing: 6
    visible: root._showIcon
    Repeater {
      model: [
        { id: "glyph", label: "Glifo fixo"   },
        { id: "app",   label: "Ícone do app" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("iconType", "glyph") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "dmenu", key: "iconType", value: modelData.id })
      }
    }
  }

  TextField {
    key: "iconGlyph"; label: "Glifo do ícone"
    hint: "Caractere Nerd Font — usado quando o tipo de ícone é \"Glifo fixo\""
    defaultValue: "\uf00a"; fieldWidth: 70; fontFamily: "JetBrainsMono Nerd Font"
    visible: root._showIcon && root.g("iconType", "glyph") === "glyph"
  }

  C.CfgSlider {
    label: "Tamanho do ícone do app"; value: root.g("windowIconSize", 18)
    from: 12; to: 32; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    visible: root._showIcon && root.g("iconType", "glyph") === "app"
    onMoved: (v) => root.changed({ moduleId: "dmenu", key: "windowIconSize", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  C.CfgToggle {
    label:   "Mostrar título"
    checked: root.g("showTitle", true) !== false
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "dmenu", key: "showTitle", value: !(root.g("showTitle", true) !== false) })
  }

  readonly property bool _showTitle: root.g("showTitle", true) !== false

  TextField {
    key: "emptyText"; label: "Sem janela ativa"
    hint: "Texto/estado mostrado com a área de trabalho vazia"
    defaultValue: "Desktop"; fieldWidth: 130
  }

  C.CfgDiv { colorDivider: root.colorDivider; visible: root._showTitle }
  C.CfgSection { title: "CARRETEL"; colorTextDim: root.colorTextDim; visible: root._showTitle }

  C.CfgSlider {
    label: "Largura do título"; value: root.g("titleMaxWidth", 180)
    from: 60; to: 400; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    visible: root._showTitle
    onMoved: (v) => root.changed({ moduleId: "dmenu", key: "titleMaxWidth", value: v })
  }

  C.CfgToggle {
    label:   "Texto estático (sem carretel)"
    checked: root.g("textStatic", false) === true
    visible: root._showTitle
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "dmenu", key: "textStatic", value: !(root.g("textStatic", false) === true) })
  }

  C.CfgSlider {
    label: "Velocidade do carretel"; value: root.g("scrollSpeed", 40)
    from: 10; to: 120; step: 5; unit: "px/s"
    visible: root._showTitle && root.g("textStatic", false) !== true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "dmenu", key: "scrollSpeed", value: v })
  }

  C.CfgSlider {
    label: "Pausa antes de rolar"; value: root.g("scrollPauseMs", 1800)
    from: 0; to: 5000; step: 100; unit: "ms"
    visible: root._showTitle && root.g("textStatic", false) !== true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "dmenu", key: "scrollPauseMs", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  Text {
    text: "Clique esquerdo abre/fecha o dmenu (toggle) no modo abaixo. Clique direito abre um menu pra fechar a janela focada ou movê-la de workspace."
    color: root.colorTextDim
    font.pixelSize: 10
    wrapMode: Text.WordWrap
    width: parent.width
  }

  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "drun",   label: "Aplicativos" },
        { id: "run",    label: "Executar"    },
        { id: "window", label: "Janelas"     },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("openMode", "drun") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "dmenu", key: "openMode", value: modelData.id })
      }
    }
  }

  TextField {
    key: "workspaceIgnorePattern"; label: "Ignorar workspaces"
    hint: "Some da lista \"mover para\" do menu de contexto. Padrão com * como coringa, várias por vírgula — ex: \"special-T*,special:*\""
    defaultValue: ""; fieldWidth: 160
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "WORKSPACE"; colorTextDim: root.colorTextDim }

  Text {
    text: "Selo com a workspace da janela focada, antes ou depois do conteúdo — igual ao módulo de janela do waybar combinado com indicador de workspace."
    color: root.colorTextDim
    font.pixelSize: 10
    wrapMode: Text.WordWrap
    width: parent.width
  }

  C.CfgToggle {
    label:   "Mostrar workspace"
    checked: root.g("showWorkspace", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "dmenu", key: "showWorkspace", value: !(root.g("showWorkspace", false) === true) })
  }

  readonly property bool _showWs: root.g("showWorkspace", false) === true

  Row {
    spacing: 6
    visible: root._showWs
    Repeater {
      model: [
        { id: "before", label: "Antes" },
        { id: "after",  label: "Depois" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("workspacePosition", "before") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "dmenu", key: "workspacePosition", value: modelData.id })
      }
    }
  }

  Row {
    spacing: 6
    visible: root._showWs
    Repeater {
      model: [
        { id: "number", label: "Número"        },
        { id: "icon",   label: "Ícone"          },
        { id: "both",   label: "Ícone + número" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("workspaceFormat", "number") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "dmenu", key: "workspaceFormat", value: modelData.id })
      }
    }
  }

  TextField {
    key: "workspaceIconMap"; label: "Ícones por workspace"
    hint: "\"1:,2:,www:,default:\" — id ou nome : glifo, separados por vírgula"
    defaultValue: ""; fieldWidth: 160
    visible: root._showWs && root.g("workspaceFormat", "number") !== "number"
  }

  C.CfgSlider {
    label: "Largura do selo"; value: root.g("workspaceChipWidth", 20)
    from: 14; to: 40; step: 1; unit: "px"
    visible: root._showWs
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "dmenu", key: "workspaceChipWidth", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Texto"; value: root.g("textColor", "on_surface")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "dmenu", key: "textColor", value: v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor", "on_surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "dmenu", key: "dimColor", value: v })
  }
  C.CfgPalette {
    label: "Accent"; value: root.g("accentColor", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "dmenu", key: "accentColor", value: v })
  }
}
