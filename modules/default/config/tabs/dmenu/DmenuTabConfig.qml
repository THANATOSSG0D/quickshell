import QtQuick
import QtQuick.Layouts
import '../../components' as C

// ── DmenuTabConfig ────────────────────────────────────────────────────────────
// Aba de configuração do módulo Dmenu no ConfigWindow.
//
// Config keys lidas/escritas (todas via config.get / config.set com moduleId "dmenu"):
//
//   LANÇADOR
//     dmenuLaunchCmd        string   "uwsm app -- {exec}"   — template de lançamento drun
//     dmenuShowIcons        bool     true                   — ícones no drun
//     dmenuDefaultMode      string   "drun"                 — modo padrão ao abrir
//     dmenuMaxVisible       int      12                     — máx. de entradas visíveis
//
//   PAINEL
//     dmenuPanelWidth       int      320     — largura do popup
//     dmenuPanelHeight      int      460     — altura base (sem preview)
//     dmenuPanelHeightImg   int      580     — altura com preview de imagem
//     dmenuPanelRadius      int      14      — raio de borda do popup
//
//   COMPORTAMENTO
//     dmenuToggle           bool     true    — mesmo keybind fecha se aberto
//     dmenuPasswordMask     bool     true    — mascarar campo em modo password
//     dmenuBackOnEmpty      bool     true    — Backspace vazio volta ao nível anterior
//     dmenuCooldownMs       int      450     — cooldown entre requests (ms)
//
// Esses campos são consumidos por:
//   Bar.qml          → _dmenuLaunchCmd, _dmenuShowIcons (já existentes)
//   DmenuIpc.qml     → openNative, _showTop (popupW / popupH)
//   DmenuContent.qml → maxVisible, showIcons
//
// O tab emite `changed(opts)` com os pares chave→valor alterados.
// O ConfigWindow chama applyChange() que persiste via config.set.

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

  function g(key) { return config ? config[key] : undefined }
  function gd(key, def) {
    var v = g(key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── LANÇADOR ──────────────────────────────────────────────────────────────
  C.CfgSection { title: "LANÇADOR"; colorTextDim: root.colorTextDim }

  // Modo padrão
  Column {
    width: parent.width; spacing: 6

    Text {
      text: "Modo padrão"
      color: root.colorText; font.pixelSize: 11; font.weight: Font.Medium
    }
    Text {
      width: parent.width
      text: "Usado por  qs ipc call dmenu open  e como fallback genérico."
      color: root.colorTextDim; font.pixelSize: 9; opacity: 0.65
      wrapMode: Text.WordWrap
    }

    Row {
      spacing: 6
      Repeater {
        model: [
          { id: "drun",   label: "Apps",      icon: "󰀻" },
          { id: "run",    label: "Histórico",  icon: "󰆍" },
          { id: "window", label: "Janelas",    icon: "󱂬" },
        ]
        delegate: C.CfgChip {
          required property var modelData
          label:   modelData.label
          icon:    modelData.icon
          active:  root.gd("dmenuDefaultMode", "drun") === modelData.id
          colorAccent:  root.colorAccent
          colorTextDim: root.colorTextDim
          onChipClicked: root.changed({ dmenuDefaultMode: modelData.id })
        }
      }
    }
  }

  // Mostrar ícones
  C.CfgToggle {
    label:   "Mostrar ícones (modo apps)"
    checked: root.gd("dmenuShowIcons", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ dmenuShowIcons: !root.gd("dmenuShowIcons", true) })
  }

  // Máximo de entradas visíveis
  C.CfgSlider {
    label: "Entradas visíveis (máx)"
    value: root.gd("dmenuMaxVisible", 12)
    from: 5; to: 24; step: 1; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuMaxVisible: v })
  }

  // Ordenação
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "ORDENAÇÃO"; colorTextDim: root.colorTextDim }

  Column {
    width: parent.width; spacing: 6

    Row {
      spacing: 6
      Repeater {
        model: [
          { id: "name",  label: "Nome exato",   icon: "󰈞",
            hint: "Resultados ordenados por proximidade com o nome do app. Desempate alfabético." },
          { id: "desc",  label: "Descrição",     icon: "󰦨",
            hint: "Match na descrição do app sobe antes de match por substring no nome." },
          { id: "usage", label: "Uso",           icon: "󰄲",
            hint: "Apps mais lançados aparecem primeiro ao empatar no score de busca. Também ordena a lista completa por frequência." },
        ]
        delegate: C.CfgChip {
          required property var modelData
          label:   modelData.label
          icon:    modelData.icon
          active:  root.gd("dmenuSortMode", "name") === modelData.id
          colorAccent:  root.colorAccent
          colorTextDim: root.colorTextDim
          onChipClicked: root.changed({ dmenuSortMode: modelData.id })
        }
      }
    }

    // Hint dinâmico baseado no modo selecionado
    Text {
      id: sortHintText
      width: parent.width
      property var _hints: ({
        "name":  "Resultados ordenados por proximidade com o nome do app. Desempate alfabético.",
        "desc":  "Match na descrição do app sobe antes de match por substring no nome. Útil para apps com nomes genéricos.",
        "usage": "Apps mais lançados aparecem primeiro ao empatar no score. A lista completa (sem busca) também é ordenada por frequência de uso."
      })
      text: _hints[root.gd("dmenuSortMode", "name")] || _hints["name"]
      color: root.colorTextDim; font.pixelSize: 9
      wrapMode: Text.WordWrap; opacity: 0.6
    }
  }

  // Launch command
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMANDO DE LANÇAMENTO"; colorTextDim: root.colorTextDim }

  // Chips de template + campo livre
  Column {
    id: launchCmdCol
    width: parent.width; spacing: 8

    // Valor local — inicializado do config, atualizado pelos chips e salvo no blur
    property string _cmd: root.gd("dmenuLaunchCmd", "uwsm app -- {exec}")

    // Chips com os templates mais comuns
    Row {
      spacing: 6
      Repeater {
        model: [
          { label: "uwsm",  cmd: "uwsm app -- {exec}" },
          { label: "direto", cmd: "{exec}"             },
        ]
        delegate: C.CfgChip {
          required property var modelData
          label:  modelData.label
          active: launchCmdCol._cmd === modelData.cmd
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: {
            launchCmdCol._cmd = modelData.cmd
            launchInput.text  = modelData.cmd
            root.changed({ dmenuLaunchCmd: modelData.cmd })
          }
        }
      }
    }

    // Campo texto livre para comando personalizado
    Rectangle {
      width: parent.width; height: 34; radius: 7
      color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.7)
      border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.5)
      border.width: 1

      RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        Text {
          text: "󰆍"; color: root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
          Layout.alignment: Qt.AlignVCenter
        }

        TextInput {
          id: launchInput
          Layout.fillWidth: true
          // Sem binding direto — inicializado no onCompleted para não brigar com o usuário
          Component.onCompleted: text = launchCmdCol._cmd
          color: root.colorText
          selectionColor: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
          selectedTextColor: root.colorText
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
          verticalAlignment: TextInput.AlignVCenter
          height: parent.height

          onEditingFinished: {
            var v = text.trim()
            if (v === "") { text = launchCmdCol._cmd; return }
            if (v !== launchCmdCol._cmd) {
              launchCmdCol._cmd = v
              root.changed({ dmenuLaunchCmd: v })
            }
          }
        }
      }
    }

    // Hint sobre {exec}
    Text {
      width: parent.width
      text: "Use {exec} como placeholder para o executável do app."
      color: root.colorTextDim; font.pixelSize: 9
      wrapMode: Text.WordWrap; opacity: 0.55
    }
  }

  // ── PAINEL ────────────────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PAINEL"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Largura"
    value: root.gd("dmenuPanelWidth", 320)
    from: 240; to: 600; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuPanelWidth: v })
  }

  C.CfgSlider {
    label: "Altura base"
    value: root.gd("dmenuPanelHeight", 460)
    from: 300; to: 800; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuPanelHeight: v })
  }

  C.CfgSlider {
    label: "Altura c/ preview"
    value: root.gd("dmenuPanelHeightImg", 580)
    from: 400; to: 900; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuPanelHeightImg: v })
  }

  C.CfgSlider {
    label: "Raio de borda"
    value: root.gd("dmenuPanelRadius", 14)
    from: 0; to: 24; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuPanelRadius: v })
  }

  // ── COMPORTAMENTO ─────────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:   "Toggle — fechar ao reabrir com mesmo keybind"
    checked: root.gd("dmenuToggle", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ dmenuToggle: !root.gd("dmenuToggle", true) })
  }

  C.CfgToggle {
    label:   "Backspace vazio navega para nível anterior"
    checked: root.gd("dmenuBackOnEmpty", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ dmenuBackOnEmpty: !root.gd("dmenuBackOnEmpty", true) })
  }

  C.CfgToggle {
    label:   "Mascarar campo em modo senha"
    checked: root.gd("dmenuPasswordMask", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ dmenuPasswordMask: !root.gd("dmenuPasswordMask", true) })
  }

  C.CfgSlider {
    label: "Cooldown entre requests"
    value: root.gd("dmenuCooldownMs", 450)
    from: 200; to: 1000; step: 50; unit: "ms"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ dmenuCooldownMs: v })
  }

  // ── INFO / STATUS ─────────────────────────────────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "INFO"; colorTextDim: root.colorTextDim }

  // Box informativa sobre o socket IPC
  Rectangle {
    width: parent.width; height: infoCol.implicitHeight + 16; radius: 8
    color:  Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.06)
    border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
    border.width: 1

    Column {
      id: infoCol
      anchors { left: parent.left; right: parent.right; top: parent.top }
      anchors { leftMargin: 12; rightMargin: 12; topMargin: 8 }
      spacing: 5

      Row {
        spacing: 6
        Text {
          text: "󰛳"
          color: root.colorAccent
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Socket IPC"
          color: root.colorText; font.pixelSize: 11; font.weight: Font.SemiBold
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Text {
        width: parent.width
        text: "$XDG_RUNTIME_DIR/qs-dmenu.sock"
        color: root.colorTextDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere; opacity: 0.7
      }

      Text {
        width: parent.width
        text: "Scripts externos enviam JSON via socket para abrir o painel em modo script. Use o wrapper qs-dmenu no PATH."
        color: root.colorTextDim; font.pixelSize: 9
        wrapMode: Text.WordWrap; opacity: 0.55
      }

      // Linha de separação interna
      Rectangle {
        width: parent.width; height: 1
        color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.3)
      }

      Row {
        spacing: 6
        Text {
          text: "󰸏"
          color: root.colorAccent
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Comandos IPC"
          color: root.colorText; font.pixelSize: 11; font.weight: Font.SemiBold
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Repeater {
        model: [
          { cmd: "qs ipc call dmenu drun",   desc: "abre launcher de apps"      },
          { cmd: "qs ipc call dmenu run",    desc: "abre histórico de comandos"  },
          { cmd: "qs ipc call dmenu window", desc: "abre seletor de janelas"     },
        ]
        delegate: Row {
          required property var modelData
          spacing: 8; width: infoCol.width

          Rectangle {
            height: 18; width: cmdTxt.implicitWidth + 12; radius: 4
            color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.9)
            border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.5)
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Text {
              id: cmdTxt
              anchors.centerIn: parent
              text: modelData.cmd
              color: root.colorAccent
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
            }
          }

          Text {
            text: modelData.desc
            color: root.colorTextDim; font.pixelSize: 9
            anchors.verticalCenter: parent.verticalCenter; opacity: 0.65
          }
        }
      }
    }
  }
}
