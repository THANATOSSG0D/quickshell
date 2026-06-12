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
//   6 — Dmenu           DmenuPopup
//   7 — Editor          BarEditorPopup

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

  readonly property var _popupNames: [
    null,
    "VolumePopupTabbed",
    "QuickSettingsPopup",
    "MediaPlayerPopup",
    "ClockPopup",
    "NotificationsPopup",
    "DmenuPopup",
    "BarEditorPopup",
  ]
  readonly property string _name: _popupNames[activeSubtab] || ""

  // ── Helpers ───────────────────────────────────────────────────────────────
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

  // ── Seção de cores com labels contextuais por painel ─────────────────────
  // Retorna array de { key, label, default } para o painel ativo.
  // Apenas as cores que o popup realmente usa.
  readonly property var _colorDefs: {
    var sub = activeSubtab
    var defs = {
      // Global (0) — todas as cores
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

  // ── Loader ────────────────────────────────────────────────────────────────
  Loader {
    anchors.fill: parent
    property int _sub: root.activeSubtab
    on_SubChanged: { active = false; active = true }
    active: true
    sourceComponent: root.activeSubtab === 0 ? _compGlobal : _compPopup
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GLOBAL
  // ══════════════════════════════════════════════════════════════════════════
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

      // Cores globais — todas as cores com labels genéricos
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

  // ══════════════════════════════════════════════════════════════════════════
  // POR POPUP (subtabs 1–7)
  // ══════════════════════════════════════════════════════════════════════════
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

      // Cores específicas do popup com labels contextuais
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
}
