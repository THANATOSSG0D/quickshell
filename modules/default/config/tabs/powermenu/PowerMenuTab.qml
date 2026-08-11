import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// ── PowerMenuTab ─────────────────────────────────────────────────────────────
// Aba de configuração do Power Menu no ConfigWindow.
// Segue o MESMO padrão estrutural do PanelTab: um único Loader trocando entre
// Components nomeados por subtab (em vez de vários Loaders com `active:
// activeSubtab === N`), e reaproveita os componentes compartilhados (C.CfgChip
// em vez de um chip próprio) sempre que existe equivalente na lib.
//
// Subtabs:
//   0 — Entradas       lista editável: label, ícone, keybind, ação, confirmação
//   1 — Aparência      cores via C.CfgPalette
//   2 — Layout         tamanhos via C.CfgSlider
//   3 — Comportamento  confirmação, timeout, animação

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

  // PowerMenuConfig — passada pelo ConfigWindow (win.configPowerMenu)
  property var config: null

  function g(key, def) { return root.config ? root.config.get(key, def) : def }
  function s(key, value) { if (root.config) root.config.set(key, value) }

  readonly property var _entries: root.config ? root.config.getEntries() : []

  readonly property var _colorDefs: [
    { key: "colorAccent",        label: "Destaque / linha de foco",  def: "primary"                   },
    { key: "colorCardBg",        label: "Fundo do card (parado)",    def: "surface_container"         },
    { key: "colorCardBgFocused", label: "Fundo do card (focado)",    def: "primary_container"         },
    { key: "colorBorder",        label: "Borda do card (parado)",    def: "outline_variant"           },
    { key: "colorIcon",          label: "Ícone (parado)",            def: "on_surface_variant"        },
    { key: "colorLabel",         label: "Texto do label (parado)",   def: "on_surface_variant"        },
    { key: "colorLabelFocused",  label: "Texto do label (focado)",   def: "on_primary_container"      },
    { key: "colorKeybindBg",     label: "Fundo do badge de atalho",  def: "surface_container_highest" },
    { key: "colorDanger",        label: "Cor de ações destrutivas",  def: "error"                     },
    { key: "colorWindowBg",      label: "Fundo do card (modo janela)", def: "surface_container_high"  },
  ]

  // ── Loader principal — mesmo padrão do PanelTab: um Loader só, trocando
  // entre Components nomeados; força recriação ao mudar de subtab pra evitar
  // estado velho de scroll/foco vazando entre abas. ─────────────────────────
  Loader {
    anchors.fill: parent
    property int _sub: root.activeSubtab
    on_SubChanged: { active = false; active = true }
    active: true
    sourceComponent: {
      if (root.activeSubtab === 0) return _compEntradas
      if (root.activeSubtab === 1) return _compAparencia
      if (root.activeSubtab === 2) return _compLayout
      return _compComportamento
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ENTRADAS (subtab 0)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compEntradas
    C.CfgScroll {

      C.CfgSection { title: "ENTRADAS DO MENU"; colorTextDim: root.colorTextDim }
      Text {
        width: parent.width
        text: "Arraste não é suportado ainda — use as setas ▲▼ pra reordenar. O ícone aceita qualquer glifo Nerd Font (ex: \uf011)."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root._entries
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          width: parent ? parent.width : 0
          height: rowCol.implicitHeight + 20
          radius: 10
          color: Qt.darker(root.colorSidebar, 0.96)
          border.color: root.colorDivider
          border.width: 1

          ColumnLayout {
            id: rowCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PmField {
                Layout.preferredWidth: 44
                text: row.modelData.text ?? ""
                placeholder: "icon"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateEntry(row.modelData.id, { text: v })
              }
              PmField {
                Layout.fillWidth: true
                text: row.modelData.label ?? ""
                placeholder: "Label"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateEntry(row.modelData.id, { label: v })
              }
              PmField {
                Layout.preferredWidth: 44
                text: row.modelData.keybind ?? ""
                placeholder: "tecla"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateEntry(row.modelData.id, { keybind: v.slice(0,1) })
              }

              // Reordenar / remover
              Row {
                spacing: 4
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: root.colorDivider; border.width: 1
                  Text { anchors.centerIn: parent; text: "▲"; color: root.colorTextDim; font.pixelSize: 10 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.moveEntry(row.index, row.index - 1)
                  }
                }
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: root.colorDivider; border.width: 1
                  Text { anchors.centerIn: parent; text: "▼"; color: root.colorTextDim; font.pixelSize: 10 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.moveEntry(row.index, row.index + 1)
                  }
                }
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: Colors.error; border.width: 1
                  Text { anchors.centerIn: parent; text: "✕"; color: Colors.error; font.pixelSize: 11 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.removeEntry(row.modelData.id)
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PmField {
                Layout.fillWidth: true
                text: row.modelData.action ?? ""
                placeholder: "comando (bash -c \"...\")"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateEntry(row.modelData.id, { action: v })
              }
              // Mesmo componente compartilhado que o PanelTab usa (C.CfgChip),
              // em vez de um chip próprio — onChipClicked é a API dele.
              C.CfgChip {
                label:  "Confirmar"
                active: row.modelData.confirm === true
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.config && root.config.updateEntry(row.modelData.id, { confirm: !row.modelData.confirm })
              }
              C.CfgChip {
                label:  "Destrutiva"
                active: row.modelData.danger === true
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.config && root.config.updateEntry(row.modelData.id, { danger: !row.modelData.danger })
              }
            }
          }
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }

      Row {
        spacing: 10
        Rectangle {
          width: addTxt.implicitWidth + 24; height: 32; radius: 8
          color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.16)
          border.color: root.colorAccent; border.width: 1
          Text { id: addTxt; anchors.centerIn: parent; text: "+ Nova entrada"; color: root.colorAccent
            font { family: "Fira Sans"; pixelSize: 12; bold: true } }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.config && root.config.addEntry({
              text: "\uf011", label: "Nova ação", keybind: "",
              action: "echo troque-me", confirm: true, danger: false
            })
          }
        }
        Rectangle {
          width: resetTxt.implicitWidth + 24; height: 32; radius: 8
          color: "transparent"; border.color: root.colorDivider; border.width: 1
          Text { id: resetTxt; anchors.centerIn: parent; text: "Restaurar padrões"; color: root.colorTextDim
            font { family: "Fira Sans"; pixelSize: 12 } }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.config && root.config.resetEntries()
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // APARÊNCIA (subtab 1)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compAparencia
    C.CfgScroll {
      C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }
      Repeater {
        model: root._colorDefs
        delegate: C.CfgPalette {
          required property var modelData
          label:    modelData.label
          value:    root.g(modelData.key, modelData.def)
          colors:   root.colors; overlay: root.overlay
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorSidebar: root.colorSidebar
          colorDivider: root.colorDivider
          onEdited: (v) => root.s(modelData.key, v)
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "OVERLAY"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Opacidade do fundo escurecido"; from: 0.2; to: 1.0; step: 0.02; unit: ""
        value: root.g("overlayOpacity", 0.72)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("overlayOpacity", v)
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // LAYOUT (subtab 2)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compLayout
    C.CfgScroll {
      // ── Estilo geral ────────────────────────────────────────────────────
      C.CfgSection { title: "ESTILO DO MENU"; colorTextDim: root.colorTextDim }
      Text {
        width: parent.width
        text: "\"Cards\" é o visual clássico em grade. \"Lista\" empilha linhas compactas — bom pra janela ancorada num canto. \"Compacto\" vira círculos só com o ícone."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }
      Row {
        spacing: 8
        C.CfgChip {
          label: "Cards"
          active: root.g("menuStyle", "cards") === "cards"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("menuStyle", "cards")
        }
        C.CfgChip {
          label: "Lista"
          active: root.g("menuStyle", "cards") === "list"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("menuStyle", "list")
        }
        C.CfgChip {
          label: "Compacto"
          active: root.g("menuStyle", "cards") === "compact"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("menuStyle", "compact")
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "EXIBIÇÃO"; colorTextDim: root.colorTextDim }
      C.CfgToggle {
        label: "Mostrar labels (texto abaixo do ícone)"
        checked: root.g("showLabels", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("showLabels", !root.g("showLabels", true))
      }
      C.CfgToggle {
        label: "Mostrar badge de atalho de teclado"
        checked: root.g("showKeybindBadge", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("showKeybindBadge", !root.g("showKeybindBadge", true))
      }

      // ── Grupo "cards"/"compact" — grade ───────────────────────────────
      C.CfgDiv { colorDivider: root.colorDivider; visible: root.g("menuStyle", "cards") !== "list" }
      C.CfgSection {
        title: "LAYOUT DA GRADE"; colorTextDim: root.colorTextDim
        visible: root.g("menuStyle", "cards") !== "list"
      }
      Text {
        visible: root.g("menuStyle", "cards") !== "list"
        width: parent.width
        text: "\"Linha única\" ignora o número de colunas — sempre coloca todas as entradas lado a lado."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }
      Row {
        visible: root.g("menuStyle", "cards") !== "list"
        spacing: 8
        C.CfgChip {
          label: "Linha única"
          active: root.g("buttonLayoutMode", "row") === "row"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("buttonLayoutMode", "row")
        }
        C.CfgChip {
          label: "Grade"
          active: root.g("buttonLayoutMode", "row") === "grid"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("buttonLayoutMode", "grid")
        }
        C.CfgChip {
          label: "Empilhado"
          active: root.g("buttonLayoutMode", "row") === "column"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onChipClicked: root.s("buttonLayoutMode", "column")
        }
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") !== "list"
        label: "Colunas na grade"; from: 1; to: 6; step: 1; unit: ""
        value: root.g("gridColumns", 3)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("gridColumns", v)
      }

      // ── Tamanho — estilo "cards" ───────────────────────────────────────
      C.CfgDiv { colorDivider: root.colorDivider; visible: root.g("menuStyle", "cards") === "cards" }
      C.CfgSection {
        title: "TAMANHO DOS CARDS"; colorTextDim: root.colorTextDim
        visible: root.g("menuStyle", "cards") === "cards"
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "cards"
        label: "Largura"; from: 100; to: 260; step: 2; unit: " px"
        value: root.g("cardWidth", 160)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("cardWidth", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "cards"
        label: "Altura"; from: 120; to: 280; step: 2; unit: " px"
        value: root.g("cardHeight", 180)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("cardHeight", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "cards"
        label: "Espaçamento entre cards"; from: 4; to: 60; step: 2; unit: " px"
        value: root.g("cardSpacing", 20)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("cardSpacing", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "cards"
        label: "Raio de borda"; from: 0; to: 40; step: 1; unit: " px"
        value: root.g("cardRadius", 20)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("cardRadius", v)
      }

      // ── Tamanho — estilo "compact" ──────────────────────────────────────
      C.CfgDiv { colorDivider: root.colorDivider; visible: root.g("menuStyle", "cards") === "compact" }
      C.CfgSection {
        title: "TAMANHO DOS CÍRCULOS"; colorTextDim: root.colorTextDim
        visible: root.g("menuStyle", "cards") === "compact"
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "compact"
        label: "Diâmetro"; from: 40; to: 120; step: 2; unit: " px"
        value: root.g("compactDiameter", 64)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("compactDiameter", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "compact"
        label: "Espaçamento"; from: 4; to: 48; step: 2; unit: " px"
        value: root.g("compactSpacing", 18)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("compactSpacing", v)
      }

      // ── Tamanho — estilo "list" ──────────────────────────────────────────
      C.CfgDiv { colorDivider: root.colorDivider; visible: root.g("menuStyle", "cards") === "list" }
      C.CfgSection {
        title: "LAYOUT DA LISTA"; colorTextDim: root.colorTextDim
        visible: root.g("menuStyle", "cards") === "list"
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "list"
        label: "Largura"; from: 220; to: 520; step: 10; unit: " px"
        value: root.g("listWidth", 340)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("listWidth", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "list"
        label: "Altura de cada linha"; from: 36; to: 84; step: 2; unit: " px"
        value: root.g("listItemHeight", 52)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("listItemHeight", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "list"
        label: "Espaçamento entre linhas"; from: 0; to: 24; step: 1; unit: " px"
        value: root.g("listSpacing", 8)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("listSpacing", v)
      }
      C.CfgSlider {
        visible: root.g("menuStyle", "cards") === "list"
        label: "Raio de borda"; from: 0; to: 32; step: 1; unit: " px"
        value: root.g("listRadius", 14)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("listRadius", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "ÍCONE"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Tamanho do ícone"; from: 20; to: 64; step: 2; unit: " px"
        value: root.g("iconSize", 42)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("iconSize", v)
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // COMPORTAMENTO (subtab 3)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compComportamento
    C.CfgScroll {
      C.CfgSection { title: "CONFIRMAÇÃO"; colorTextDim: root.colorTextDim }
      C.CfgToggle {
        label: "Exigir confirmação em ações marcadas como \"Destrutiva/Confirmar\""
        checked: root.g("confirmDestructive", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("confirmDestructive", !root.g("confirmDestructive", true))
      }
      C.CfgSlider {
        label: "Tempo até cancelar confirmação pendente"; from: 1000; to: 10000; step: 500; unit: " ms"
        value: root.g("confirmTimeoutMs", 4000)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("confirmTimeoutMs", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "GERAL"; colorTextDim: root.colorTextDim }
      C.CfgToggle {
        label: "Tela cheia (desliga = popup flutuante real, do tamanho do conteúdo)"
        checked: root.g("fullscreen", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("fullscreen", !root.g("fullscreen", true))
      }
      C.CfgToggle {
        label: "Fechar ao clicar fora / perder o foco"
        checked: root.g("closeOnClickOutside", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("closeOnClickOutside", !root.g("closeOnClickOutside", true))
      }

      // ── Modo janela: posição, margens, aparência do popup — só relevantes
      // com fullscreen desligado. A janela agora é uma superfície real do
      // tamanho do conteúdo, ancorada num ponto da tela (não mais um card
      // desenhado sobre um dim cobrindo a tela toda). ─────────────────────
      C.CfgDiv { colorDivider: root.colorDivider; visible: !root.g("fullscreen", true) }
      C.CfgSection {
        title: "POSIÇÃO DO POPUP (MODO JANELA)"; colorTextDim: root.colorTextDim
        visible: !root.g("fullscreen", true)
      }
      GridLayout {
        visible: !root.g("fullscreen", true)
        columns: 3
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
          model: [
            { key: "top-left",     label: "↖" }, { key: "top",     label: "↑" }, { key: "top-right",    label: "↗" },
            { key: "left",         label: "←" }, { key: "center",  label: "•" }, { key: "right",        label: "→" },
            { key: "bottom-left",  label: "↙" }, { key: "bottom",  label: "↓" }, { key: "bottom-right", label: "↘" },
          ]
          delegate: Rectangle {
            required property var modelData
            Layout.preferredWidth: 44; Layout.preferredHeight: 40
            radius: 8
            readonly property bool _active: root.g("windowPosition", "center") === modelData.key
            color: _active
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
              : "transparent"
            border.color: _active ? root.colorAccent : root.colorDivider
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: _active ? root.colorAccent : root.colorTextDim
              font.pixelSize: 16
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.s("windowPosition", modelData.key)
            }
          }
        }
      }
      C.CfgSlider {
        visible: !root.g("fullscreen", true) && root.g("windowPosition", "center") !== "center"
        label: "Margem da borda (horizontal)"; from: 0; to: 200; step: 4; unit: " px"
        value: root.g("windowMarginX", 56)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("windowMarginX", v)
      }
      C.CfgSlider {
        visible: !root.g("fullscreen", true) && root.g("windowPosition", "center") !== "center"
        label: "Margem da borda (vertical)"; from: 0; to: 200; step: 4; unit: " px"
        value: root.g("windowMarginY", 56)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("windowMarginY", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider; visible: !root.g("fullscreen", true) }
      C.CfgSection {
        title: "APARÊNCIA DO POPUP (MODO JANELA)"; colorTextDim: root.colorTextDim
        visible: !root.g("fullscreen", true)
      }
      C.CfgSlider {
        visible: !root.g("fullscreen", true)
        label: "Espaço interno do card"; from: 16; to: 80; step: 2; unit: " px"
        value: root.g("windowedPadding", 40)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("windowedPadding", v)
      }
      C.CfgSlider {
        visible: !root.g("fullscreen", true)
        label: "Raio de borda do card"; from: 0; to: 48; step: 2; unit: " px"
        value: root.g("windowedRadius", 24)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("windowedRadius", v)
      }
      C.CfgToggle {
        visible: !root.g("fullscreen", true)
        label: "Sombra atrás do card"
        checked: root.g("windowShadow", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("windowShadow", !root.g("windowShadow", true))
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "ANIMAÇÃO"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Duração da animação de abrir/fechar"; from: 80; to: 500; step: 10; unit: " ms"
        value: root.g("panelAnimMs", 200)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("panelAnimMs", v)
      }
      C.CfgSlider {
        label: "Duração da animação de hover"; from: 60; to: 400; step: 10; unit: " ms"
        value: root.g("hoverAnimMs", 160)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("hoverAnimMs", v)
      }
      C.CfgSlider {
        label: "Escala do card focado"; from: 1.0; to: 1.2; step: 0.01; unit: "x"
        value: root.g("focusScale", 1.06)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("focusScale", v)
      }
    }
  }
}
