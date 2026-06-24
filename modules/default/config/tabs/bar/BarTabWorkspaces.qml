import QtQuick
import QtQuick.Layouts
import '../../components' as C

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
    var v = config.get("workspaces", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ── Estilo ativo (necessário para isolar props perStyle) ────────────────
  // Todas as props da seção "FUNDO DOS ITENS" e "CORES" abaixo são
  // isoladas por estilo (BarSchema: workspaces.props, perStyle:true).
  // gs()/changedStyled() garantem que leitura e escrita usem o mesmo
  // caminho aninhado (workspaces.<style>.<key>) que o Bar.qml já lê via
  // wsGet(). Sem isso, o painel escreve solto na raiz do módulo e a
  // barra nunca vê a mudança (lia de workspaces.icons.*, por exemplo).
  readonly property string currentStyle: root.g("style", "icons")

  // A aba só mostra os controles relevantes pro estilo selecionado acima —
  // cada estilo (Ícones/Dots/Hybrid/Número) tem propriedades bem diferentes
  // (ícone tem cor mono + número opcional, dots tem 4 cores de ponto, etc),
  // então misturar tudo numa lista só confunde mais do que ajuda.
  readonly property bool isIcons:  currentStyle === "icons"
  readonly property bool isDots:   currentStyle === "dots"
  readonly property bool isNumber: currentStyle === "number" || currentStyle === "hybrid"

  function gs(key, def) {
    if (!config) return def
    var v = config.get("workspaces", key, root.currentStyle)
    return (v !== undefined && v !== null) ? v : def
  }

  function changedStyled(key, value) {
    root.changed({ moduleId: "workspaces", key: key, value: value, style: root.currentStyle })
  }

  // ── Estilo ────────────────────────────────────────────────────────────
  C.CfgSection { title: "ESTILO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "icons",  label: "Ícones" },
        { id: "dots",   label: "Dots"   },
        { id: "hybrid", label: "Hybrid" },
        { id: "number", label: "Número" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("style", "icons") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "workspaces", key: "style", value: modelData.id })
      }
    }
  }

  // ── Ordenação dos ícones dentro de cada workspace (só "Ícones") ─────────
  C.CfgSection { title: "ORDENAÇÃO"; colorTextDim: root.colorTextDim; visible: root.isIcons }
  Row {
    visible: root.isIcons
    spacing: 6
    Repeater {
      model: [
        { id: "position",     label: "Posição"    },
        { id: "alphabetical", label: "Alfabética" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("iconsSort", "position") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "workspaces", key: "iconsSort", value: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "COMPORTAMENTO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label:   "Ícones monocromáticos"
    checked: root.g("iconMonochrome", false) === true
    visible: root.isIcons
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "iconMonochrome", value: !(root.g("iconMonochrome", false) === true) })
  }
  C.CfgToggle {
    label:   "Mostrar número da workspace antes do 1º ícone"
    checked: root.g("showNumber", false) === true
    visible: root.isIcons
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "showNumber", value: !(root.g("showNumber", false) === true) })
  }
  C.CfgToggle {
    label:   "Fundo (quadrado/pílula) atrás do número"
    checked: root.g("numberBgEnabled", false) === true
    visible: root.isIcons && root.g("showNumber", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "numberBgEnabled", value: !(root.g("numberBgEnabled", false) === true) })
  }
  C.CfgToggle {
    label:   "Botão + para criar workspace"
    checked: root.g("showAddButton", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "showAddButton", value: !(root.g("showAddButton", false) === true) })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Espaçamento entre workspaces"; value: root.g("spacing", 2)
    from: 0; to: 24; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "spacing", value: v })
  }
  C.CfgSlider {
    label: "Espaçamento entre ícones"; value: root.g("iconSpacing", 4)
    from: 0; to: 16; step: 1; unit: "px"
    visible: root.isIcons
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "iconSpacing", value: v })
  }
  C.CfgSlider {
    label: "Tamanho dos ícones de app"; value: root.g("iconSize", 18)
    from: 12; to: 36; step: 1; unit: "px"
    visible: root.isIcons
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "iconSize", value: v })
  }
  C.CfgSlider {
    label: "Raio do fundo do número"; value: root.g("numberBgRadius", 4)
    from: 0; to: 20; step: 1; unit: "px"
    visible: root.isIcons && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgRadius", value: v })
  }
  C.CfgSlider {
    label: "Padding H do fundo do número"; value: root.g("numberBgPaddingH", 4)
    from: 0; to: 16; step: 1; unit: "px"
    visible: root.isIcons && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgPaddingH", value: v })
  }
  C.CfgSlider {
    label: "Padding V do fundo do número"; value: root.g("numberBgPaddingV", 2)
    from: 0; to: 16; step: 1; unit: "px"
    visible: root.isIcons && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgPaddingV", value: v })
  }
  C.CfgSlider {
    label: "Tamanho do dot"; value: root.gs("dotSize", 8)
    from: 4; to: 16; step: 1; unit: "px"
    visible: root.isDots
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("dotSize", v)
  }
  C.CfgSlider {
    label: "Tamanho do número"; value: root.gs("fontSize", 10)
    from: 8; to: 20; step: 1; unit: "px"
    visible: root.isNumber
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("fontSize", v)
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "FUNDO DA PÍLULA (TODOS OS ESTILOS)"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Opacidade (inativo)"; value: root.gs("bgOpacity", 0.0)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgOpacity", v)
  }
  C.CfgSlider {
    label: "Padding H (inativo)"; value: root.gs("bgPaddingH", 6)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingH", v)
  }
  C.CfgSlider {
    label: "Padding V (inativo)"; value: root.gs("bgPaddingV", 3)
    from: 0; to: 14; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingV", v)
  }
  C.CfgSlider {
    label: "Borda (inativo)"; value: root.gs("bgBorderWidth", 0)
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgBorderWidth", v)
  }

  C.CfgSlider {
    label: "Opacidade (ativo)"; value: root.gs("bgOpacityActive", 0.18)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgOpacityActive", v)
  }
  C.CfgSlider {
    label: "Padding H (ativo)"; value: root.gs("bgPaddingHActive", 8)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingHActive", v)
  }
  C.CfgSlider {
    label: "Padding V (ativo)"; value: root.gs("bgPaddingVActive", 4)
    from: 0; to: 14; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingVActive", v)
  }
  C.CfgSlider {
    label: "Raio (ativo) — 0=quadrado, alto=pílula"; value: root.gs("bgRadiusActive", 6)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgRadiusActive", v)
  }
  C.CfgSlider {
    label: "Borda (ativo)"; value: root.gs("bgBorderWidthActive", 0)
    from: 0; to: 4; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgBorderWidthActive", v)
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── Cores — pílula do item ───────────────────────────────────────────
  // O "fundo da pílula" é o contêiner por trás de cada workspace (existe
  // em qualquer estilo); é ele que destaca visualmente qual workspace
  // está selecionada, por trás do ícone/dot/número.
  C.CfgSection { title: "CORES — FUNDO DA PÍLULA"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo da pílula — workspace sem foco"; value: root.gs("bgColor", "surface_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgColor", v)
  }
  C.CfgPalette {
    label: "Fundo da pílula — workspace ativa"; value: root.gs("bgColorActive", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgColorActive", v)
  }
  C.CfgPalette {
    label: "Borda da pílula — workspace sem foco"; value: root.gs("bgBorderColor", "outline_variant")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgBorderColor", v)
  }
  C.CfgPalette {
    label: "Borda da pílula — workspace ativa"; value: root.gs("bgBorderColorActive", "primary")
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgBorderColorActive", v)
  }

  // ── Cores — pontos (Dots/Hybrid/Número) ──────────────────────────────
  // O círculo indicador de cada workspace tem 4 estados possíveis, cada
  // um com sua cor. Não existe no estilo Ícones (que mostra ícones de
  // app no lugar do ponto).
  C.CfgDiv { colorDivider: root.colorDivider; visible: !root.isIcons }
  C.CfgSection { title: "CORES — PONTOS"; colorTextDim: root.colorTextDim; visible: !root.isIcons }
  C.CfgPalette {
    label: "Ponto — workspace vazia (sem janelas)"; value: root.gs("dotColor", "on_surface_variant")
    visible: !root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace ativa (selecionada)"; value: root.gs("dotActiveColor", "primary")
    visible: !root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotActiveColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace ocupada (com janelas, não selecionada)"; value: root.gs("dotOccupiedColor", "secondary")
    visible: !root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotOccupiedColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace urgente (notificação pedindo atenção)"; value: root.gs("dotUrgentColor", "error")
    visible: !root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotUrgentColor", v)
  }

  // ── Cores — ícones monocromáticos ────────────────────────────────────
  // Só tem efeito com o estilo Ícones + o toggle "Ícones monocromáticos"
  // ligado (em COMPORTAMENTO); recolore o ícone do app inteiro com uma
  // cor sólida em vez de usar as cores originais do ícone.
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.isIcons }
  C.CfgSection { title: "CORES — ÍCONES MONOCROMÁTICOS"; colorTextDim: root.colorTextDim; visible: root.isIcons }
  C.CfgPalette {
    label: "Ícone monocromático — workspace sem foco"; value: root.gs("iconMonoColor", "on_surface_variant")
    visible: root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("iconMonoColor", v)
  }
  C.CfgPalette {
    label: "Ícone monocromático — workspace ativa"; value: root.gs("iconMonoColorActive", "on_primary")
    visible: root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("iconMonoColorActive", v)
  }

  // ── Cores — número da workspace ──────────────────────────────────────
  // Texto do número mostrado antes do 1º ícone (toggle em COMPORTAMENTO).
  // As duas últimas só importam com o fundo do número ligado.
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.isIcons }
  C.CfgSection { title: "CORES — NÚMERO DA WORKSPACE"; colorTextDim: root.colorTextDim; visible: root.isIcons }
  C.CfgPalette {
    label: "Número — workspace sem foco"; value: root.g("numberColor", "on_surface_variant")
    visible: root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "numberColor", value: v })
  }
  C.CfgPalette {
    label: "Número — workspace ativa"; value: root.g("numberColorActive", "on_primary")
    visible: root.isIcons
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "numberColorActive", value: v })
  }
  C.CfgPalette {
    label: "Fundo do número — workspace sem foco"; value: root.g("numberBgColor", "surface_variant")
    visible: root.isIcons && root.g("numberBgEnabled", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "numberBgColor", value: v })
  }
  C.CfgPalette {
    label: "Fundo do número — workspace ativa"; value: root.g("numberBgColorActive", "primary")
    visible: root.isIcons && root.g("numberBgEnabled", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "numberBgColorActive", value: v })
  }
}
