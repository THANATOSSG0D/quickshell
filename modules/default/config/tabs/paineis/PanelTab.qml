import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// ── PanelTab ──────────────────────────────────────────────────────────────────
// Aba de configuração dos painéis da barra no ConfigWindow.
// Botão de reset fica na subbar do ConfigWindow (chama resetCurrent()).
//
// Subtabs:
//   0 — Global          defaults para todos os painéis
//   1 — Volume          VolumePopupTabbed
//   2 — Config Rápida   QuickSettingsPopup
//   3 — Mídia           MediaPlayerPopup
//   4 — Relógio         ClockPopup
//   5 — Notificações    NotificationsPopup
//   6 — Dmenu           DmenuPopup  (cores via PopupConfig)
//   7 — Editor          BarEditorPopup
//   8 — Dmenu Config    configurações do módulo dmenu (lançador, painel,
//                        posição, comportamento, cores — em seções retráteis)

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

  // dmenuConfig é passado pelo ConfigWindow (instância de DmenuConfig)
  property var dmenuConfig: null

  anchors.fill: parent

  readonly property var _popupNames: [
    null,
    "VolumePopupTabbed",
    "QuickSettingsPopup",
    "MediaPlayerPopup",
    "ClockPopup",
    "NotificationsPopup",
    "DmenuPopup",
    "BarEditorPopup",
    null,   // subtab 8 = Dmenu Config — não usa PopupConfig
  ]
  readonly property string _name: _popupNames[activeSubtab] || ""

  // ── Helpers PopupConfig ───────────────────────────────────────────────
  function g(key, def) {
    var popup = _popupNames[activeSubtab]
    if (popup) {
      var ov = PopupConfig.get(popup, key, undefined)
      if (ov !== undefined) return ov
    }
    var gl = PopupConfig.get(null, key, undefined)
    if (gl !== undefined) return gl
    return def
  }
  function s(key, value) {
    PopupConfig.set(key, value, _popupNames[activeSubtab] || undefined)
  }
  function resetCurrent() {
    var popup = _popupNames[activeSubtab]
    if (popup) PopupConfig.reset(popup)
    else       PopupConfig.reset()
  }

  // ── Helpers DmenuConfig (subtab 8) ───────────────────────────────────
  function dg(key, def) {
    if (!dmenuConfig) return def
    var v = dmenuConfig[key]
    return (v !== undefined && v !== null) ? v : def
  }
  function ds(opts) {
    if (dmenuConfig) dmenuConfig.saveAll(opts)
  }

  // ── Seção de cores com labels contextuais por painel ─────────────────
  readonly property var _colorDefs: {
    var defs = {
      "": [
        { key: "colorPanelBg",    label: "Fundo do painel",                    def: "surface_container"      },
        { key: "colorText",       label: "Texto principal",                    def: "on_surface"             },
        { key: "colorTextDim",    label: "Texto secundário / labels dim",      def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Destaque / elemento ativo",          def: "primary"                },
        { key: "colorMuted",      label: "Mudo / erro / urgente",              def: "error"                  },
        { key: "colorProgressBg", label: "Trilha de barra de progresso",       def: "surface_container_high" },
        { key: "colorProgressFg", label: "Fill de barra de progresso",         def: "primary"                },
        { key: "colorDivider",    label: "Linha divisória",                    def: "outline_variant"        },
        { key: "colorInputBg",    label: "Fundo da caixa de busca",            def: "surface_container_low"  },
      ],
      "VolumePopupTabbed": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Nome do dispositivo / aplicativo",             def: "on_surface"             },
        { key: "colorTextDim",    label: "Percentagem / labels secundários",             def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Barra de volume / ícone ativo / tab",          def: "primary"                },
        { key: "colorMuted",      label: "Ícone de mudo / indicador silenciado",         def: "error"                  },
        { key: "colorProgressBg", label: "Trilha da barra de volume (fundo)",            def: "surface_container_high" },
        { key: "colorDivider",    label: "Linha entre saída e entrada",                  def: "outline_variant"        },
      ],
      "QuickSettingsPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Label dos tiles / texto dos toggles",          def: "on_surface"             },
        { key: "colorTextDim",    label: "Subtítulo / valor atual / label dim",          def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Tile selecionado / toggle ligado",             def: "primary"                },
        { key: "colorMuted",      label: "Toggle desabilitado / indicador de erro",      def: "error"                  },
        { key: "colorProgressBg", label: "Trilha da barra de brilho (fundo)",            def: "surface_container_high" },
        { key: "colorDivider",    label: "Separadores entre seções",                     def: "outline_variant"        },
      ],
      "MediaPlayerPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Título da música / nome do artista",           def: "on_surface"             },
        { key: "colorTextDim",    label: "Álbum / tempo decorrido / label dim",          def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Botões de controle / barra de progresso",      def: "primary"                },
        { key: "colorProgressBg", label: "Trilha da barra de progresso (fundo)",         def: "surface_container_high" },
        { key: "colorProgressFg", label: "Fill da barra de progresso (frente)",          def: "primary"                },
      ],
      "ClockPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Hora atual / data",                            def: "on_surface"             },
        { key: "colorTextDim",    label: "Labels do timer / fase do pomodoro",           def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Fase ativa do pomodoro / barra do timer",      def: "primary"                },
        { key: "colorProgressBg", label: "Trilha da barra do timer (fundo)",             def: "surface_container_high" },
        { key: "colorDivider",    label: "Separadores entre seções",                     def: "outline_variant"        },
      ],
      "NotificationsPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Título da notificação / nome do app",          def: "on_surface"             },
        { key: "colorTextDim",    label: "Corpo da notificação / horário",               def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Botão de ação / badge de contagem",            def: "primary"                },
        { key: "colorMuted",      label: "Notificação crítica / urgente",                def: "error"                  },
        { key: "colorDivider",    label: "Linha entre notificações",                     def: "outline_variant"        },
      ],
      "DmenuPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Label do resultado / texto do item",           def: "on_surface"             },
        { key: "colorTextDim",    label: "Subtítulo / hint / atalho de teclado",         def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Item selecionado / cursor de navegação",       def: "primary"                },
        { key: "colorDivider",    label: "Separador de grupos de resultados",            def: "outline_variant"        },
        { key: "colorInputBg",    label: "Fundo da barra de busca",                      def: "surface_container_low"  },
      ],
      "BarEditorPopup": [
        { key: "colorPanelBg",    label: "Fundo do painel",                              def: "surface_container"      },
        { key: "colorText",       label: "Labels dos controles do editor",               def: "on_surface"             },
        { key: "colorTextDim",    label: "Valores atuais / placeholders",                def: "on_surface_variant"     },
        { key: "colorAccent",     label: "Chip / opção selecionada",                     def: "primary"                },
        { key: "colorDivider",    label: "Separadores entre seções",                     def: "outline_variant"        },
      ],
    }
    return defs[_name] || defs[""]
  }

  // ── Loader principal ──────────────────────────────────────────────────
  Loader {
    anchors.fill: parent
    property int _sub: root.activeSubtab
    on_SubChanged: { active = false; active = true }
    active: true
    sourceComponent: {
      if (root.activeSubtab === 0) return _compGlobal
      if (root.activeSubtab === 8) return _compDmenuConfig
      return _compPopup
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // GLOBAL (subtab 0)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compGlobal
    C.CfgScroll {

      C.CfgSection { title: "ANIMAÇÃO"; colorTextDim: root.colorTextDim }

      Row {
        spacing: 6
        Repeater {
          model: [
            { id: "slide",       label: "Slide"       },
            { id: "fade",        label: "Fade"        },
            { id: "scale",       label: "Scale"       },
            { id: "scale-slide", label: "Scale+Slide" },
            { id: "none",        label: "Nenhuma"     },
          ]
          delegate: C.CfgChip {
            required property var modelData
            label:  modelData.label
            active: root.g("animationStyle", "slide") === modelData.id
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            onChipClicked: root.s("animationStyle", modelData.id)
          }
        }
      }

      C.CfgSlider {
        label: "Duração da animação"; from: 80; to: 500; step: 10; unit: " ms"
        value: root.g("animDuration", 200)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("animDuration", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "APARÊNCIA"; colorTextDim: root.colorTextDim }

      C.CfgSlider {
        label: "Opacidade do fundo"; from: 0.3; to: 1.0; step: 0.01; unit: ""
        value: root.g("bgOpacity", 0.95)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("bgOpacity", v)
      }

      C.CfgSlider {
        label: "Raio de borda"; from: 0; to: 28; step: 1; unit: " px"
        value: root.g("bgRadius", 12)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("bgRadius", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "BORDA"; colorTextDim: root.colorTextDim }

      C.CfgSlider {
        label: "Espessura da borda"; from: 0; to: 4; step: 1; unit: " px"
        value: root.g("borderWidth", 0)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("borderWidth", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "SOMBRA"; colorTextDim: root.colorTextDim }

      C.CfgToggle {
        label: "Ativar sombra"
        checked: root.g("shadowEnabled", false)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("shadowEnabled", !root.g("shadowEnabled", false))
      }

      C.CfgSlider {
        label: "Blur da sombra"; from: 4; to: 40; step: 2; unit: " px"
        value: root.g("shadowBlur", 16)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowBlur", v)
      }

      C.CfgSlider {
        label: "Deslocamento vertical da sombra"; from: 0; to: 20; step: 1; unit: " px"
        value: root.g("shadowOffsetY", 4)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowOffsetY", v)
      }

      C.CfgSlider {
        label: "Opacidade da sombra"; from: 0.05; to: 0.8; step: 0.05; unit: ""
        value: root.g("shadowOpacity", 0.45)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowOpacity", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
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
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // POR POPUP (subtabs 1–7)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compPopup
    C.CfgScroll {

      // Aviso de override
      Rectangle {
        width: parent.width; height: 34; radius: 8
        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.07)
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
        border.width: 1
        Row {
          anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
          spacing: 8
          Text {
            text: "\uf05a"; color: root.colorAccent; font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Sobrescreve apenas este painel. Vazio = herda o global."
            color: root.colorTextDim; font.pixelSize: 9
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }

      C.CfgSlider {
        label: "Largura do painel"; from: 160; to: 800; step: 4; unit: " px"
        value: root.g("popupW", 320)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("popupW", v)
      }

      C.CfgSlider {
        label: "Altura do painel"; from: 120; to: 900; step: 4; unit: " px"
        value: root.g("popupH", 400)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("popupH", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "ANIMAÇÃO"; colorTextDim: root.colorTextDim }

      Row {
        spacing: 6
        Repeater {
          model: [
            { id: "slide",       label: "Slide"       },
            { id: "fade",        label: "Fade"        },
            { id: "scale",       label: "Scale"       },
            { id: "scale-slide", label: "Scale+Slide" },
            { id: "none",        label: "Nenhuma"     },
          ]
          delegate: C.CfgChip {
            required property var modelData
            label:  modelData.label
            active: root.g("animationStyle", "slide") === modelData.id
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            onChipClicked: root.s("animationStyle", modelData.id)
          }
        }
      }

      C.CfgSlider {
        label: "Duração da animação"; from: 80; to: 500; step: 10; unit: " ms"
        value: root.g("animDuration", 200)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("animDuration", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "APARÊNCIA"; colorTextDim: root.colorTextDim }

      C.CfgSlider {
        label: "Opacidade do fundo"; from: 0.3; to: 1.0; step: 0.01; unit: ""
        value: root.g("bgOpacity", 0.95)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("bgOpacity", v)
      }

      C.CfgSlider {
        label: "Raio de borda"; from: 0; to: 28; step: 1; unit: " px"
        value: root.g("bgRadius", 12)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("bgRadius", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "BORDA"; colorTextDim: root.colorTextDim }

      C.CfgSlider {
        label: "Espessura da borda"; from: 0; to: 4; step: 1; unit: " px"
        value: root.g("borderWidth", 0)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("borderWidth", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "SOMBRA"; colorTextDim: root.colorTextDim }

      C.CfgToggle {
        label: "Ativar sombra"
        checked: root.g("shadowEnabled", false)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("shadowEnabled", !root.g("shadowEnabled", false))
      }

      C.CfgSlider {
        label: "Blur da sombra"; from: 4; to: 40; step: 2; unit: " px"
        value: root.g("shadowBlur", 16)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowBlur", v)
      }

      C.CfgSlider {
        label: "Deslocamento vertical da sombra"; from: 0; to: 20; step: 1; unit: " px"
        value: root.g("shadowOffsetY", 4)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowOffsetY", v)
      }

      C.CfgSlider {
        label: "Opacidade da sombra"; from: 0.05; to: 0.8; step: 0.05; unit: ""
        value: root.g("shadowOpacity", 0.45)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("shadowOpacity", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
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
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DMENU CONFIG (subtab 8) — seções retráteis
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compDmenuConfig

    C.CfgScroll {

      // ── Aviso quando dmenuConfig não está conectado ─────────────────
      Rectangle {
        width: parent.width; height: 36; radius: 8
        visible: !root.dmenuConfig
        color:   Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.07)
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
        border.width: 1
        Row {
          anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
          spacing: 8
          Text { text: "\uf071"; color: root.colorAccent; font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "dmenuConfig não conectado ao PanelTab."
            color: root.colorTextDim; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // ── 1. LANÇADOR ─────────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "LANÇADOR"
        expanded:     true
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        // Modo padrão
        Column {
          width: parent.width; spacing: 6

          Text { text: "Modo padrão"; color: root.colorText
            font.pixelSize: 11; font.weight: Font.Medium }
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
                { id: "drun",   label: "Apps",     icon: "󰀻" },
                { id: "run",    label: "Histórico", icon: "󰆍" },
                { id: "window", label: "Janelas",   icon: "󱂬" },
              ]
              delegate: C.CfgChip {
                required property var modelData
                label:  modelData.label; icon: modelData.icon
                active: root.dg("dmenuDefaultMode", "drun") === modelData.id
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.ds({ dmenuDefaultMode: modelData.id })
              }
            }
          }
        }

        C.CfgToggle {
          label: "Mostrar ícones (modo apps)"
          checked: root.dg("dmenuShowIcons", true) === true
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onToggled: root.ds({ dmenuShowIcons: !root.dg("dmenuShowIcons", true) })
        }

        C.CfgSlider {
          label: "Entradas visíveis (máx)"
          value: root.dg("dmenuMaxVisible", 12)
          from: 5; to: 24; step: 1; unit: ""
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuMaxVisible: v })
        }
      }

      // ── 2. ORDENAÇÃO ─────────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "ORDENAÇÃO"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        Column {
          width: parent.width; spacing: 8

          Row {
            spacing: 6
            Repeater {
              model: [
                { id: "name",  label: "Nome exato",  icon: "󰈞" },
                { id: "desc",  label: "Descrição",    icon: "󰦨" },
                { id: "usage", label: "Uso",          icon: "󰄲" },
              ]
              delegate: C.CfgChip {
                required property var modelData
                label:  modelData.label; icon: modelData.icon
                active: root.dg("dmenuSortMode", "name") === modelData.id
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.ds({ dmenuSortMode: modelData.id })
              }
            }
          }

          Text {
            width: parent.width
            property var _hints: ({
              "name":  "Resultados ordenados por proximidade com o nome do app. Desempate alfabético.",
              "desc":  "Match na descrição do app sobe antes de match por substring no nome. Útil para apps com nomes genéricos.",
              "usage": "Apps mais lançados aparecem primeiro ao empatar no score. A lista completa também é ordenada por frequência de uso."
            })
            text: _hints[root.dg("dmenuSortMode", "name")] || _hints["name"]
            color: root.colorTextDim; font.pixelSize: 9
            wrapMode: Text.WordWrap; opacity: 0.6
          }
        }
      }

      // ── 3. COMANDO DE LANÇAMENTO ──────────────────────────────────────
      C.CfgCollapsible {
        title:        "COMANDO DE LANÇAMENTO"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        Column {
          id: _launchCol
          width: parent.width; spacing: 8
          property string _cmd: root.dg("dmenuLaunchCmd", "uwsm app -- {exec}")

          Row {
            spacing: 6
            Repeater {
              model: [
                { label: "uwsm",   cmd: "uwsm app -- {exec}" },
                { label: "direto", cmd: "{exec}"              },
              ]
              delegate: C.CfgChip {
                required property var modelData
                label:  modelData.label
                active: _launchCol._cmd === modelData.cmd
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: {
                  _launchCol._cmd     = modelData.cmd
                  _launchInput.text   = modelData.cmd
                  root.ds({ dmenuLaunchCmd: modelData.cmd })
                }
              }
            }
          }

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
                id: _launchInput
                Layout.fillWidth: true
                Component.onCompleted: text = _launchCol._cmd
                color: root.colorText
                selectionColor: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
                selectedTextColor: root.colorText
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                verticalAlignment: TextInput.AlignVCenter
                height: parent.height
                onEditingFinished: {
                  var v = text.trim()
                  if (v === "") { text = _launchCol._cmd; return }
                  if (v !== _launchCol._cmd) {
                    _launchCol._cmd = v
                    root.ds({ dmenuLaunchCmd: v })
                  }
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "Use {exec} como placeholder para o executável do app."
            color: root.colorTextDim; font.pixelSize: 9
            wrapMode: Text.WordWrap; opacity: 0.55
          }
        }
      }

      // ── 4. PAINEL ─────────────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "PAINEL"
        expanded:     true
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        C.CfgSlider {
          label: "Largura"; value: root.dg("dmenuPanelWidth", 320)
          from: 240; to: 600; step: 10; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPanelWidth: v })
        }

        C.CfgSlider {
          label: "Altura base"; value: root.dg("dmenuPanelHeight", 460)
          from: 300; to: 800; step: 10; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPanelHeight: v })
        }

        C.CfgSlider {
          label: "Altura c/ preview"; value: root.dg("dmenuPanelHeightImg", 580)
          from: 400; to: 900; step: 10; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPanelHeightImg: v })
        }

        C.CfgSlider {
          label: "Raio de borda"; value: root.dg("dmenuPanelRadius", 14)
          from: 0; to: 24; step: 2; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPanelRadius: v })
        }
      }

      // ── 5. POSIÇÃO ────────────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "POSIÇÃO"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        Column {
          width: parent.width; spacing: 6
          Text { text: "Alinhamento horizontal"; color: root.colorText
            font.pixelSize: 11; font.weight: Font.Medium }
          Row {
            spacing: 6
            Repeater {
              model: [
                { id: "left",   label: "Esquerda", icon: "󰅃" },
                { id: "center", label: "Centro",   icon: "󰉸" },
                { id: "right",  label: "Direita",  icon: "󰅂" },
              ]
              delegate: C.CfgChip {
                required property var modelData
                label:  modelData.label; icon: modelData.icon
                active: root.dg("dmenuPopupXAlign", "center") === modelData.id
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.ds({ dmenuPopupXAlign: modelData.id })
              }
            }
          }
        }

        C.CfgSlider {
          label: "Offset horizontal"; value: root.dg("dmenuPopupXOffset", 0)
          from: 0; to: 400; step: 4; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPopupXOffset: v })
        }

        Column {
          width: parent.width; spacing: 6
          Text { text: "Posição vertical"; color: root.colorText
            font.pixelSize: 11; font.weight: Font.Medium }
          Row {
            spacing: 6
            Repeater {
              model: [
                { id: "bar",    label: "Junto da barra", icon: "󱂬" },
                { id: "top",    label: "Topo",            icon: "󰁝" },
                { id: "bottom", label: "Base",            icon: "󰁅" },
              ]
              delegate: C.CfgChip {
                required property var modelData
                label:  modelData.label; icon: modelData.icon
                active: root.dg("dmenuPopupYAnchor", "bar") === modelData.id
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.ds({ dmenuPopupYAnchor: modelData.id })
              }
            }
          }
          Text {
            width: parent.width
            property var _hints: ({
              "bar":    "Popup encosta na barra, como todos os outros painéis.",
              "top":    "Popup flutua no topo do monitor com o offset abaixo.",
              "bottom": "Popup flutua na base do monitor com o offset acima."
            })
            text: _hints[root.dg("dmenuPopupYAnchor", "bar")] || _hints["bar"]
            color: root.colorTextDim; font.pixelSize: 9
            wrapMode: Text.WordWrap; opacity: 0.6
          }
        }

        C.CfgSlider {
          label: "Offset vertical"; value: root.dg("dmenuPopupYOffset", 0)
          from: 0; to: 200; step: 4; unit: "px"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuPopupYOffset: v })
        }
      }

      // ── 6. COMPORTAMENTO ──────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "COMPORTAMENTO"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        C.CfgToggle {
          label: "Toggle — fechar ao reabrir com mesmo keybind"
          checked: root.dg("dmenuToggle", true) === true
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onToggled: root.ds({ dmenuToggle: !root.dg("dmenuToggle", true) })
        }

        C.CfgToggle {
          label: "Backspace vazio navega para nível anterior"
          checked: root.dg("dmenuBackOnEmpty", true) === true
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onToggled: root.ds({ dmenuBackOnEmpty: !root.dg("dmenuBackOnEmpty", true) })
        }

        C.CfgToggle {
          label: "Mascarar campo em modo senha"
          checked: root.dg("dmenuPasswordMask", true) === true
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          onToggled: root.ds({ dmenuPasswordMask: !root.dg("dmenuPasswordMask", true) })
        }

        C.CfgSlider {
          label: "Cooldown entre requests"; value: root.dg("dmenuCooldownMs", 450)
          from: 200; to: 1000; step: 50; unit: "ms"
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorProgressBg: root.colorProgressBg
          onMoved: (v) => root.ds({ dmenuCooldownMs: v })
        }
      }

      // ── 7. CORES ──────────────────────────────────────────────────────
      C.CfgCollapsible {
        title:        "CORES"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        Repeater {
          model: [
            { key: "dmenuColorBg",       label: "Fundo do painel",
              desc: "Cor de fundo do popup inteiro.", def: "surface_container" },
            { key: "dmenuColorInputBg",  label: "Fundo do campo de busca",
              desc: "Fundo da caixa de texto onde você digita.", def: "surface_container_low" },
            { key: "dmenuColorSelected", label: "Fundo do item selecionado",
              desc: "Destaque de fundo na linha em foco.", def: "surface_container_high" },
            { key: "dmenuColorText",     label: "Texto principal",
              desc: "Nome do app, comandos, entradas de script.", def: "on_surface" },
            { key: "dmenuColorTextDim",  label: "Texto secundário",
              desc: "Descrição do app, prompt, label de seção.", def: "on_surface_variant" },
            { key: "dmenuColorAccent",   label: "Accent / seleção",
              desc: "Cor do texto selecionado e swatches de cor.", def: "primary" },
            { key: "dmenuColorDivider",  label: "Divisor",
              desc: "Linha separadora entre grupos de entradas.", def: "outline_variant" },
          ]
          delegate: Column {
            required property var modelData
            width: parent.width; spacing: 2; bottomPadding: 10

            Text { text: modelData.label; color: root.colorText
              font.pixelSize: 11; font.weight: Font.Medium }
            Text {
              width: parent.width; text: modelData.desc
              color: root.colorTextDim; font.pixelSize: 9; opacity: 0.65
              wrapMode: Text.WordWrap; bottomPadding: 4
            }
            C.CfgPalette {
              width: parent.width; label: ""
              value:   root.dg(modelData.key, modelData.def)
              colors:  root.colors; overlay: root.overlay
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorSidebar: root.colorSidebar
              colorDivider: root.colorDivider
              onEdited: (v) => root.ds(
                (function(k, v2) { var o = {}; o[k] = v2; return o })(modelData.key, v)
              )
            }
          }
        }
      }

      // ── 8. INFO / SOCKET IPC ──────────────────────────────────────────
      C.CfgCollapsible {
        title:        "INFO / SOCKET IPC"
        expanded:     false
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider

        Rectangle {
          width: parent.width; height: _ipcCol.implicitHeight + 16; radius: 8
          color:  Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.06)
          border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
          border.width: 1

          Column {
            id: _ipcCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 12; rightMargin: 12; topMargin: 8 }
            spacing: 5

            Row {
              spacing: 6
              Text { text: "󰛳"; color: root.colorAccent
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Socket IPC"; color: root.colorText
                font.pixelSize: 11; font.weight: Font.SemiBold
                anchors.verticalCenter: parent.verticalCenter }
            }

            Text {
              width: parent.width
              text: "$XDG_RUNTIME_DIR/qs-dmenu.sock"
              color: root.colorTextDim
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
              wrapMode: Text.WrapAtWordBoundaryOrAnywhere; opacity: 0.7
            }
            Text {
              width: parent.width
              text: "Scripts externos enviam JSON via socket para abrir o painel em modo script. Use o wrapper qs-dmenu no PATH."
              color: root.colorTextDim; font.pixelSize: 9
              wrapMode: Text.WordWrap; opacity: 0.55
            }

            Rectangle {
              width: parent.width; height: 1
              color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.3)
            }

            Row {
              spacing: 6
              Text { text: "󰸏"; color: root.colorAccent
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Comandos IPC"; color: root.colorText
                font.pixelSize: 11; font.weight: Font.SemiBold
                anchors.verticalCenter: parent.verticalCenter }
            }

            Repeater {
              model: [
                { cmd: "qs ipc call dmenu drun",   desc: "abre launcher de apps"      },
                { cmd: "qs ipc call dmenu run",    desc: "abre histórico de comandos"  },
                { cmd: "qs ipc call dmenu window", desc: "abre seletor de janelas"     },
              ]
              delegate: Row {
                required property var modelData
                spacing: 8; width: _ipcCol.width
                Rectangle {
                  height: 18; width: _cmdLbl.implicitWidth + 12; radius: 4
                  color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.9)
                  border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.5)
                  border.width: 1
                  anchors.verticalCenter: parent.verticalCenter
                  Text {
                    id: _cmdLbl; anchors.centerIn: parent; text: modelData.cmd
                    color: root.colorAccent
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                  }
                }
                Text { text: modelData.desc; color: root.colorTextDim
                  font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter; opacity: 0.65 }
              }
            }
          }
        }
      }

      // ── Botão restaurar padrões ───────────────────────────────────────
      C.CfgDiv { colorDivider: root.colorDivider }

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
            Text { text: "restaurar padrões dmenu"; color: root.colorAccent
              font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea {
            id: _resetMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.dmenuConfig) root.dmenuConfig.resetToDefaults() }
          }
        }
      }
    }
  }
}
