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
  readonly property bool isFocus:  currentStyle === "focus"
  readonly property bool isCurrentOnly: currentStyle === "current"
  // Number/Hybrid/Focus usam o mesmo "fontSize" pro número
  readonly property bool isNumber: currentStyle === "number" || currentStyle === "hybrid" || currentStyle === "focus"
  // Ícones, Focus e "Só atual" compartilham as props de tamanho/espaçamento/
  // ordenação/monocromia de ícone (todos reaproveitam o Icons.qml por dentro)
  readonly property bool showsIconRow: currentStyle === "icons" || currentStyle === "focus" || currentStyle === "current"
  // Dots/Number/Hybrid usam as 4 cores de "ponto" — Focus e Ícones não
  readonly property bool usesDotColors: currentStyle === "dots" || currentStyle === "number" || currentStyle === "hybrid"

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
        { id: "icons",   label: "Ícones"   },
        { id: "dots",    label: "Dots"     },
        { id: "hybrid",  label: "Hybrid"   },
        { id: "number",  label: "Número"   },
        { id: "focus",   label: "Focus"    },
        { id: "current", label: "Só atual" },
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
  C.CfgSection { title: "ORDENAÇÃO"; colorTextDim: root.colorTextDim; visible: root.showsIconRow }
  Row {
    visible: root.showsIconRow
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
    visible: root.showsIconRow
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
    visible: (root.isIcons && root.g("showNumber", false) === true) || root.isFocus
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
  C.CfgToggle {
    label:   "Borda no botão +"
    checked: root.g("addButtonBorderEnabled", true) === true
    visible: root.g("showAddButton", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "addButtonBorderEnabled", value: !(root.g("addButtonBorderEnabled", true) === true) })
  }
  C.CfgToggle {
    label:   "Fundo persistente no botão + (não só no hover)"
    checked: root.g("addButtonBgEnabled", false) === true
    visible: root.g("showAddButton", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "addButtonBgEnabled", value: !(root.g("addButtonBgEnabled", false) === true) })
  }
  C.CfgSlider {
    label: "Opacidade do fundo do botão +"; value: root.g("addButtonBgOpacity", 1.0)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    visible: root.g("showAddButton", false) === true && root.g("addButtonBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "addButtonBgOpacity", value: v })
  }
  C.CfgSlider {
    // Termina em "Size" -> acompanha a "Escala dos módulos" global (moduleScale)
    // igual ao tamanho dos ícones/dots, então o + nunca fica desproporcional
    // ao resto da barra quando o usuário mexe no slider de escala.
    // Agora controla só a FONTE do glifo — o diâmetro do botão nasce dela
    // + o padding abaixo (mesmo padrão do "fundo do número" em Ícones).
    label: "Tamanho da fonte do +"; value: root.g("addButtonSize", 13)
    from: 9; to: 20; step: 1; unit: "px"
    visible: root.g("showAddButton", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "addButtonSize", value: v })
  }
  C.CfgSlider {
    label: "Padding horizontal do botão +"; value: root.g("addButtonPaddingH", 5)
    from: 0; to: 16; step: 1; unit: "px"
    visible: root.g("showAddButton", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "addButtonPaddingH", value: v })
  }
  C.CfgSlider {
    label: "Padding vertical do botão +"; value: root.g("addButtonPaddingV", 5)
    from: 0; to: 16; step: 1; unit: "px"
    visible: root.g("showAddButton", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "addButtonPaddingV", value: v })
  }
  C.CfgPalette {
    label: "Cor do botão + (borda/ícone)"; value: root.g("addButtonColor", "on_surface_variant")
    visible: root.g("showAddButton", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "addButtonColor", value: v })
  }
  C.CfgPalette {
    label: "Cor do fundo do botão +"; value: root.g("addButtonBgColor", "surface_variant")
    visible: root.g("showAddButton", false) === true && root.g("addButtonBgEnabled", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "workspaces", key: "addButtonBgColor", value: v })
  }

  // ── Scroll no módulo (todos os estilos) ──────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "SCROLL NO MÓDULO"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:   "Scroll no módulo troca workspace/janela"
    checked: root.g("scrollEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "scrollEnabled", value: !(root.g("scrollEnabled", false) === true) })
  }
  Row {
    visible: root.g("scrollEnabled", false) === true
    spacing: 6
    Repeater {
      model: [
        { id: "workspace", label: "Workspace" },
        { id: "window",    label: "Janela"    },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.g("scrollAction", "workspace") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ moduleId: "workspaces", key: "scrollAction", value: modelData.id })
      }
    }
  }
  C.CfgToggle {
    label:   "Inverter direção do scroll"
    checked: root.g("scrollInvert", false) === true
    visible: root.g("scrollEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "scrollInvert", value: !(root.g("scrollInvert", false) === true) })
  }

  // ── Animação do indicador — Dots/Número/Hybrid ───────────────────────
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.usesDotColors }
  C.CfgSection { title: "ANIMAÇÃO DO INDICADOR"; colorTextDim: root.colorTextDim; visible: root.usesDotColors }
  Row {
    visible: root.usesDotColors
    spacing: 6
    Repeater {
      model: [
        { id: "none",   label: "Nenhuma" },
        { id: "smooth", label: "Suave"   },
        { id: "pop",    label: "Pop"     },
        { id: "pulse",  label: "Pulso"   },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.gs("indicatorAnimStyle", "smooth") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changedStyled("indicatorAnimStyle", modelData.id)
      }
    }
  }
  C.CfgSlider {
    label: "Duração da animação"; value: root.gs("indicatorAnimDuration", 140)
    from: 0; to: 600; step: 10; unit: "ms"
    visible: root.usesDotColors
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("indicatorAnimDuration", v)
  }

  // ── Revelação — só existe no estilo Focus ────────────────────────────
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.isFocus }
  C.CfgSection { title: "REVELAÇÃO (FOCO)"; colorTextDim: root.colorTextDim; visible: root.isFocus }
  Row {
    visible: root.isFocus
    spacing: 6
    Repeater {
      model: [
        { id: "hover", label: "Hover"  },
        { id: "click", label: "Clique" },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.gs("revealMode", "hover") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changedStyled("revealMode", modelData.id)
      }
    }
  }
  // Delay pra ABRIR no modo hover — 0 = expande na hora (original).
  // Fechar ao sair do hover continua sempre instantâneo, sem delay.
  C.CfgSlider {
    label: "Delay pra abrir (hover)"; value: root.gs("hoverRevealDelayMs", 0)
    from: 0; to: 2000; step: 50; unit: "ms"
    visible: root.isFocus && root.gs("revealMode", "hover") === "hover"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("hoverRevealDelayMs", v)
  }
  // Como os ícones fecham no modo clique: na hora que o mouse sai, ou
  // com um delay configurável (fica aberto um tempo antes de fechar).
  Row {
    visible: root.isFocus && root.gs("revealMode", "hover") === "click"
    spacing: 6
    Repeater {
      model: [
        { id: "exit",  label: "Ao sair do hover" },
        { id: "delay", label: "Com delay"        },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label:  modelData.label
        active: root.gs("clickCollapseMode", "exit") === modelData.id
        colorAccent:  root.colorAccent
        colorTextDim: root.colorTextDim
        onChipClicked: root.changedStyled("clickCollapseMode", modelData.id)
      }
    }
  }
  C.CfgSlider {
    label: "Fecha sozinho depois de (0 = nunca)"; value: root.gs("clickRevealTimeoutMs", 2500)
    from: 0; to: 10000; step: 100; unit: "ms"
    visible: root.isFocus && root.gs("revealMode", "hover") === "click" && root.gs("clickCollapseMode", "exit") === "delay"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("clickRevealTimeoutMs", v)
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
    visible: root.showsIconRow
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "iconSpacing", value: v })
  }
  C.CfgSlider {
    label: "Tamanho dos ícones de app"; value: root.g("iconSize", 18)
    from: 12; to: 36; step: 1; unit: "px"
    visible: root.showsIconRow
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "iconSize", value: v })
  }
  C.CfgSlider {
    label: "Raio do fundo do número"; value: root.g("numberBgRadius", 4)
    from: 0; to: 20; step: 1; unit: "px"
    visible: (root.isIcons || root.isFocus) && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgRadius", value: v })
  }
  C.CfgSlider {
    label: "Padding H do fundo do número"; value: root.g("numberBgPaddingH", 4)
    from: 0; to: 16; step: 1; unit: "px"
    visible: (root.isIcons || root.isFocus) && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgPaddingH", value: v })
  }
  C.CfgSlider {
    label: "Padding V do fundo do número"; value: root.g("numberBgPaddingV", 2)
    from: 0; to: 16; step: 1; unit: "px"
    visible: (root.isIcons || root.isFocus) && root.g("numberBgEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberBgPaddingV", value: v })
  }
  C.CfgSlider {
    label: "Espaço entre número e 1º ícone"; value: root.g("numberSpacing", 4)
    from: 0; to: 20; step: 1; unit: "px"
    visible: root.isIcons && root.g("showNumber", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "workspaces", key: "numberSpacing", value: v })
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

  // Fundo do GRUPO inteiro (contêiner ao redor de TODOS os workspaces + o
  // botão +) — é o mesmo Rectangle pra qualquer estilo selecionado, não é
  // isolado por estilo (por isso usa g()/changed(), não gs()/changedStyled()).
  C.CfgToggle {
    label:   "Fundo do grupo (contêiner ao redor de tudo)"
    checked: root.g("bgGroupEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "workspaces", key: "bgGroupEnabled", value: !(root.g("bgGroupEnabled", false) === true) })
  }

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

  C.CfgToggle {
    label:   "Fundo individual — workspace ativa"
    checked: root.gs("bgActiveEnabled", true) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changedStyled("bgActiveEnabled", !(root.gs("bgActiveEnabled", true) === true))
  }
  C.CfgSlider {
    label: "Opacidade (ativo)"; value: root.gs("bgOpacityActive", 0.18)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    visible: root.gs("bgActiveEnabled", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgOpacityActive", v)
  }
  C.CfgSlider {
    label: "Padding H (ativo)"; value: root.gs("bgPaddingHActive", 8)
    from: 0; to: 20; step: 1; unit: "px"
    visible: root.gs("bgActiveEnabled", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingHActive", v)
  }
  C.CfgSlider {
    label: "Padding V (ativo)"; value: root.gs("bgPaddingVActive", 4)
    from: 0; to: 14; step: 1; unit: "px"
    visible: root.gs("bgActiveEnabled", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingVActive", v)
  }
  C.CfgSlider {
    label: "Raio (ativo) — 0=quadrado, alto=pílula"; value: root.gs("bgRadiusActive", 6)
    from: 0; to: 20; step: 1; unit: "px"
    visible: root.gs("bgActiveEnabled", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgRadiusActive", v)
  }
  C.CfgSlider {
    label: "Borda (ativo)"; value: root.gs("bgBorderWidthActive", 0)
    from: 0; to: 4; step: 1; unit: "px"
    visible: root.gs("bgActiveEnabled", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgBorderWidthActive", v)
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── Fundo individual — workspace INATIVA (vazia ou ocupada, sem foco) ──
  C.CfgSection { title: "FUNDO INDIVIDUAL — WORKSPACE INATIVA"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label:   "Fundo individual — workspaces inativas"
    checked: root.gs("bgInactiveEnabled", false) === true
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changedStyled("bgInactiveEnabled", !(root.gs("bgInactiveEnabled", false) === true))
  }
  C.CfgSlider {
    label: "Opacidade"; value: root.gs("bgOpacityInactive", 0.4)
    from: 0.0; to: 1.0; step: 0.05; unit: ""
    visible: root.gs("bgInactiveEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgOpacityInactive", v)
  }
  C.CfgSlider {
    label: "Padding H"; value: root.gs("bgPaddingHInactive", 6)
    from: 0; to: 20; step: 1; unit: "px"
    visible: root.gs("bgInactiveEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingHInactive", v)
  }
  C.CfgSlider {
    label: "Padding V"; value: root.gs("bgPaddingVInactive", 2)
    from: 0; to: 14; step: 1; unit: "px"
    visible: root.gs("bgInactiveEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgPaddingVInactive", v)
  }
  C.CfgSlider {
    label: "Raio — 0=quadrado, alto=pílula"; value: root.gs("bgRadiusInactive", 99)
    from: 0; to: 99; step: 1; unit: "px"
    visible: root.gs("bgInactiveEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgRadiusInactive", v)
  }
  C.CfgSlider {
    label: "Borda"; value: root.gs("bgBorderWidthInactive", 0)
    from: 0; to: 4; step: 1; unit: "px"
    visible: root.gs("bgInactiveEnabled", false) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changedStyled("bgBorderWidthInactive", v)
  }
  C.CfgPalette {
    label: "Fundo — workspace inativa"; value: root.gs("bgColorInactive", "surface_variant")
    visible: root.gs("bgInactiveEnabled", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgColorInactive", v)
  }
  C.CfgPalette {
    label: "Borda — workspace inativa"; value: root.gs("bgBorderColorInactive", "on_surface")
    visible: root.gs("bgInactiveEnabled", false) === true
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("bgBorderColorInactive", v)
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
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.isDots }
  C.CfgSection { title: "CORES — DOTS"; colorTextDim: root.colorTextDim; visible: root.isDots }
  C.CfgPalette {
    label: "Ponto — workspace vazia (sem janelas)"; value: root.gs("dotColor", "on_surface_variant")
    visible: root.isDots
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace ativa (selecionada)"; value: root.gs("dotActiveColor", "primary")
    visible: root.isDots
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotActiveColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace ocupada (com janelas, não selecionada)"; value: root.gs("dotOccupiedColor", "secondary")
    visible: root.isDots
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotOccupiedColor", v)
  }
  C.CfgPalette {
    label: "Ponto — workspace urgente (notificação pedindo atenção)"; value: root.gs("dotUrgentColor", "error")
    visible: root.isDots
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotUrgentColor", v)
  }

  // ── Cores — estilo Número (badge circular só com o número, sem dot) ────
  // Mesmas 4 chaves de armazenamento do bloco "Dots" acima (dotColor etc),
  // mas isoladas por estilo (gs()/changedStyled() já gravam em
  // workspaces.number.* — não colide com workspaces.dots.*). Só o RÓTULO
  // muda aqui pra descrever o que a cor realmente faz nesse delegate.
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.currentStyle === "number" }
  C.CfgSection { title: "CORES — NÚMERO (BADGE)"; colorTextDim: root.colorTextDim; visible: root.currentStyle === "number" }
  C.CfgPalette {
    label: "Número — cor do texto/borda (sem foco)"; value: root.gs("dotColor", "on_surface_variant")
    visible: root.currentStyle === "number"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotColor", v)
  }
  C.CfgPalette {
    label: "Número — fundo do badge (workspace ativa)"; value: root.gs("dotActiveColor", "primary")
    visible: root.currentStyle === "number"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotActiveColor", v)
  }
  C.CfgPalette {
    label: "Número — cor do texto/borda (ocupada, não selecionada)"; value: root.gs("dotOccupiedColor", "secondary")
    visible: root.currentStyle === "number"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotOccupiedColor", v)
  }
  C.CfgPalette {
    label: "Número — cor do texto/borda (urgente)"; value: root.gs("dotUrgentColor", "error")
    visible: root.currentStyle === "number"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotUrgentColor", v)
  }

  // ── Cores — estilo Hybrid (dot pequeno + nome, expande ao ativar) ──────
  // Mesmo esquema de armazenamento (workspaces.hybrid.*), rótulos próprios
  // porque a cor "ativa" aqui pinta o FUNDO da pílula inteira, não um ponto.
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.currentStyle === "hybrid" }
  C.CfgSection { title: "CORES — HYBRID"; colorTextDim: root.colorTextDim; visible: root.currentStyle === "hybrid" }
  C.CfgPalette {
    label: "Hybrid — cor do dot/texto (sem foco)"; value: root.gs("dotColor", "on_surface_variant")
    visible: root.currentStyle === "hybrid"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotColor", v)
  }
  C.CfgPalette {
    label: "Hybrid — fundo da pílula (workspace ativa)"; value: root.gs("dotActiveColor", "primary")
    visible: root.currentStyle === "hybrid"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotActiveColor", v)
  }
  C.CfgPalette {
    label: "Hybrid — cor do dot/texto (ocupada, não selecionada)"; value: root.gs("dotOccupiedColor", "secondary")
    visible: root.currentStyle === "hybrid"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotOccupiedColor", v)
  }
  C.CfgPalette {
    label: "Hybrid — cor do dot/texto (urgente)"; value: root.gs("dotUrgentColor", "error")
    visible: root.currentStyle === "hybrid"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("dotUrgentColor", v)
  }

  // ── Cores — ícones monocromáticos ────────────────────────────────────
  // Só tem efeito com o estilo Ícones + o toggle "Ícones monocromáticos"
  // ligado (em COMPORTAMENTO); recolore o ícone do app inteiro com uma
  // cor sólida em vez de usar as cores originais do ícone.
  C.CfgDiv { colorDivider: root.colorDivider; visible: root.showsIconRow }
  C.CfgSection { title: "CORES — ÍCONES MONOCROMÁTICOS"; colorTextDim: root.colorTextDim; visible: root.showsIconRow }
  C.CfgPalette {
    label: "Ícone monocromático — workspace sem foco"; value: root.gs("iconMonoColor", "on_surface_variant")
    visible: root.showsIconRow
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("iconMonoColor", v)
  }
  C.CfgPalette {
    label: "Ícone monocromático — workspace ativa"; value: root.gs("iconMonoColorActive", "on_primary")
    visible: root.showsIconRow
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changedStyled("iconMonoColorActive", v)
  }

  // ── Cores — número da workspace ──────────────────────────────────────
  // Texto do número mostrado antes do 1º ícone (toggle em COMPORTAMENTO).
  // As duas últimas só importam com o fundo do número ligado.
  C.CfgDiv { colorDivider: root.colorDivider; visible: (root.isIcons || root.isFocus) }
  C.CfgSection { title: "CORES — NÚMERO DA WORKSPACE"; colorTextDim: root.colorTextDim; visible: (root.isIcons || root.isFocus) }
  C.CfgPalette {
    label: "Número — workspace sem foco"; value: root.g("numberColor", "on_surface_variant")
    visible: (root.isIcons || root.isFocus)
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
    visible: (root.isIcons || root.isFocus) && root.g("numberBgEnabled", false) === true
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
