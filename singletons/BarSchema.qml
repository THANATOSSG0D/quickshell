pragma Singleton
import QtQuick

// BarSchema — definição central de todos os módulos configuráveis do bar.
//
// Cada módulo tem:
//   id:        string — chave usada no JSON e nas APIs get/set
//   perTheme:  bool   — se true, configs são isoladas por tema
//   perStyle:  bool   — se true, configs são isoladas por subestilo (ex: ws style)
//   styles:    list   — lista de subestilos válidos (só quando perStyle=true)
//   props:     list   — lista de props configuráveis
//
// Cada prop tem:
//   key:      string  — chave no JSON
//   type:     string  — "palette"|"color"|"bool"|"int"|"real"|"enum"
//   default:  any     — valor padrão hardcoded (fallback final)
//   label:    string  — label no painel de config
//   section:  string  — agrupa props em seções no painel
//   min/max/step      — para int/real
//   options:  list    — para enum: [{id, label}]
//   visibleWhen: string — expressão de visibilidade no painel ("_hasIcons", etc.)

QtObject {
  id: root

  // ── Módulos disponíveis para layout do bar ─────────────────────────────
  readonly property var moduleIds: [
    "mediaplayer", "workspaces", "clock", "volume",
    "quicksettings", "notifications", "separator"
  ]

  // ── Schema completo ────────────────────────────────────────────────────
  readonly property var modules: [

    // ══════════════════════════════════════════════
    // BAR — estrutura/dimensões/posição do bar por tema
    // (modules.{left,center,right,top,middle,bottom} são tratados fora
    //  deste schema — são listas de ids, não props tipadas — mas vivem
    //  no mesmo bloco themes[tema].bar dentro de Bar.json)
    // ══════════════════════════════════════════════
    {
      id: "bar", label: "Barra", perTheme: true, perStyle: false,
      props: [
        { key:"autoHide",       type:"bool", default:false, label:"Auto-ocultar",      section:"COMPORTAMENTO" },
        { key:"position",       type:"enum", default:4,     label:"Posição",           section:"POSIÇÃO",
          options:[{id:1,label:"Topo"},{id:3,label:"Baixo"},{id:4,label:"Esquerda"},{id:2,label:"Direita"}] },
        { key:"barSize",        type:"int",  default:30,  min:20,  max:60,   step:2,  unit:"px", label:"Tamanho",          section:"DIMENSÕES" },
        { key:"barMargin",      type:"int",  default:3,   min:0,   max:20,   step:1,  unit:"px", label:"Margem",           section:"DIMENSÕES" },
        { key:"moduleScale",    type:"real", default:1.0, min:0.5, max:2.0,  step:0.05, unit:"x", label:"Escala dos módulos", section:"DIMENSÕES" },
        { key:"pillWidth",      type:"int",  default:400, min:100, max:1400, step:10, unit:"px", label:"Largura pílula",   section:"DIMENSÕES" },
        { key:"pillMinSpacing", type:"int",  default:20,  min:0,   max:100,  step:5,  unit:"px", label:"Espaçamento mín.", section:"DIMENSÕES" },
        { key:"popupPillPadding", type:"int", default:32, min:0,  max:100,  step:4,  unit:"px", label:"Padding do popup", section:"DIMENSÕES" },
        { key:"pillExpandForPopups", type:"bool", default:true, label:"Esticar pro popup", section:"DIMENSÕES" },
        // Notch — antes viviam só como fallback hardcoded (`|| 18` etc.) espalhado
        // pelo código; registrados aqui para que get()/defaultValue() os resolvam
        // corretamente e o valor 0 deixe de ser tratado como "não setado".
        { key:"notchRadius",    type:"int",  default:18,  min:0,   max:40,   step:1,  unit:"px", label:"Raio interno",     section:"NOTCH" },
        { key:"concaveRadius",  type:"int",  default:10,  min:0,   max:30,   step:1,  unit:"px", label:"Côncavo lateral",  section:"NOTCH" },
        { key:"lobePadH",       type:"int",  default:14,  min:0,   max:40,   step:2,  unit:"px", label:"Padding horizontal", section:"NOTCH" },
        { key:"notchTaper",     type:"int",  default:20,  min:0,   max:60,   step:2,  unit:"px", label:"Inclinação trapézio", section:"NOTCH" },
        { key:"notchPopupPadding", type:"int", default:32, min:0,  max:100,  step:4,  unit:"px", label:"Padding do popup", section:"NOTCH" },
        { key:"notchExpandForPopups", type:"bool", default:true, label:"Esticar pro popup", section:"NOTCH" },
        // Arredondamento — cada tema expõe sua própria prop de raio (nomes já
        // usados internamente nos QML dos temas: Aurora.barRadius,
        // Bento.chipRadius, Dock.islandRadius, Slider.handleRadius). O
        // Rectangle do QtQuick já clampa sozinho o radius a metade da menor
        // dimensão do elemento — então qualquer valor aqui, por maior que
        // seja, nunca "estoura" a forma; o slider só limita a faixa útil.
        { key:"barRadius",     type:"int", default:16, min:0, max:40, step:1, unit:"px", label:"Arredondamento", section:"ARREDONDAMENTO" },
        { key:"chipRadius",    type:"int", default:14, min:0, max:60, step:1, unit:"px", label:"Arredondamento", section:"ARREDONDAMENTO" },
        { key:"islandRadius",  type:"int", default:12, min:0, max:40, step:1, unit:"px", label:"Arredondamento", section:"ARREDONDAMENTO" },
        { key:"handleRadius",  type:"int", default:40, min:0, max:60, step:1, unit:"px", label:"Arredondamento", section:"ARREDONDAMENTO" },
      ]
    },

    // ══════════════════════════════════════════════
    // PALETTE — cores globais do bar por tema
    // ══════════════════════════════════════════════
    {
      id: "palette", label: "Paleta", perTheme: true, perStyle: false,
      props: [
        { key:"barBg",      type:"palette", default:"surface_container_lowest", label:"Fundo do bar",    section:"BAR" },
        { key:"barBgPill",  type:"palette", default:"background",               label:"Fundo da pílula", section:"BAR" },
        { key:"text",       type:"palette", default:"on_surface",               label:"Texto",           section:"TEXTO" },
        { key:"textDim",    type:"palette", default:"on_surface_variant",       label:"Texto dim",       section:"TEXTO" },
        { key:"accent",     type:"palette", default:"primary",                  label:"Acento",          section:"ACENTO" },
        { key:"accentBg",   type:"palette", default:"primary_container",        label:"Fundo acento",    section:"ACENTO" },
        { key:"accentText", type:"palette", default:"on_primary",               label:"Texto acento",    section:"ACENTO" },
        { key:"panelBg",    type:"palette", default:"surface_container",        label:"Fundo painel",    section:"PAINEL" },
        { key:"progressBg", type:"palette", default:"outline_variant",          label:"Fundo progresso", section:"PROGRESSO" },
        { key:"progressFg", type:"palette", default:"primary",                  label:"Progresso",       section:"PROGRESSO" },
        { key:"divider",    type:"palette", default:"outline_variant",          label:"Divisor",         section:"DIVISOR" },
      ]
    },

    // ══════════════════════════════════════════════
    // MEDIAPLAYER
    // ══════════════════════════════════════════════
    {
      id: "mediaplayer", label: "Mídia", perTheme: true, perStyle: false,
      props: [
        // genérico (não por tema)
        { key:"showText",    type:"bool", default:true, label:"Mostrar texto", section:"GERAL" },
        { key:"textStatic",  type:"bool", default:false, label:"Texto estático (sem carretel)", section:"GERAL" },
        { key:"textMode",    type:"enum", default:"artistAndTitle", label:"Modo de texto", section:"GERAL",
          options:[{id:"artistAndTitle",label:"Artista + Título"},{id:"title",label:"Só título"},{id:"artist",label:"Só artista"},{id:"album",label:"Só álbum"}] },
        { key:"scrollSpeed", type:"int",  default:40,   min:10,  max:200, step:5,  label:"Velocidade scroll", section:"GERAL", unit:"px/s" },
        { key:"scrollWidth", type:"int",  default:140,  min:60,  max:400, step:10, label:"Largura scroll",    section:"GERAL", unit:"px" },
        { key:"volumeStep",  type:"real", default:0.05, min:0.01, max:0.2, step:0.01, label:"Passo de volume (scroll)", section:"GERAL", unit:"%" },
        { key:"playerPriority", type:"string", default:"spotify,ncspot,vivaldi,brave", label:"Prioridade de players", section:"PRIORIDADE DE PLAYERS" },
        { key:"idleInhibit",    type:"bool",   default:true,                           label:"Impedir tela de dormir enquanto toca", section:"IDLE INHIBITOR" },
        // capa do álbum (por tema, como o resto do módulo)
        { key:"artworkSize",   type:"int", default:22, min:14, max:48, step:1, label:"Tamanho da capa", section:"CAPA" },
        { key:"artworkRadius", type:"int", default:11, min:0,  max:24, step:1, label:"Arredondamento",  section:"CAPA" },
        // visual (por tema)
        { key:"bgEnabled",       type:"bool",    default:false,               label:"Fundo habilitado",  section:"FUNDO" },
        { key:"bgOpacity",       type:"real",    default:0.5,   min:0, max:1, step:0.05, label:"Opacidade",          section:"FUNDO", unit:"%" },
        { key:"bgOpacityActive", type:"real",    default:0.8,   min:0, max:1, step:0.05, label:"Opacidade ativo",    section:"FUNDO", unit:"%" },
        { key:"bgPaddingH",      type:"int",     default:8,     min:0, max:32, step:2,   label:"Padding H",          section:"FUNDO", unit:"px" },
        { key:"bgPaddingV",      type:"int",     default:4,     min:0, max:20, step:1,   label:"Padding V",          section:"FUNDO", unit:"px" },
        { key:"bgColor",         type:"palette", default:"surface_variant",         label:"Fundo",          section:"CORES" },
        { key:"bgColorActive",   type:"palette", default:"primary_container",       label:"Fundo ativo",    section:"CORES" },
        { key:"textColor",       type:"palette", default:"on_surface",              label:"Texto",          section:"CORES" },
        { key:"dimColor",        type:"palette", default:"on_surface_variant",      label:"Dim",            section:"CORES" },
        { key:"textColorActive", type:"palette", default:"on_primary_container",    label:"Texto ativo",    section:"CORES" },
        { key:"dimColorActive",  type:"palette", default:"on_surface_variant",      label:"Dim ativo",      section:"CORES" },
      ]
    },

    // ══════════════════════════════════════════════
    // CLOCK
    // ══════════════════════════════════════════════
    {
      id: "clock", label: "Relógio", perTheme: true, perStyle: false,
      props: [
        { key:"dismissDelayMs", type:"int",     default:8000,               min:2000, max:30000, step:1000, label:"Auto-fechar (ms)", section:"GERAL", unit:"ms" },
        { key:"textColor",      type:"palette", default:"on_surface",        label:"Texto",  section:"CORES" },
        { key:"dimColor",       type:"palette", default:"on_surface_variant",label:"Dim",    section:"CORES" },
        { key:"accentColor",    type:"palette", default:"primary",           label:"Acento", section:"CORES" },
      ]
    },

    // ══════════════════════════════════════════════
    // VOLUME
    // ══════════════════════════════════════════════
    {
      id: "volume", label: "Volume", perTheme: true, perStyle: false,
      props: [
        { key:"showSink",   type:"bool", default:true, label:"Mostrar saída",  section:"GERAL" },
        { key:"showSource", type:"bool", default:true, label:"Mostrar entrada",section:"GERAL" },
        { key:"maxVol",     type:"real", default:1.5,  min:1.0, max:2.0, step:0.1, label:"Volume máximo", section:"GERAL", unit:"×" },
        { key:"textColor",  type:"palette", default:"on_surface",        label:"Texto",        section:"CORES" },
        { key:"dimColor",   type:"palette", default:"on_surface_variant",label:"Dim",          section:"CORES" },
        { key:"accentColor",type:"palette", default:"primary",           label:"Acento",       section:"CORES" },
        { key:"mutedColor", type:"palette", default:"error",             label:"Mutado",       section:"CORES" },
        { key:"progressBg", type:"palette", default:"outline_variant",   label:"Fundo slider", section:"CORES" },
      ]
    },

    // ══════════════════════════════════════════════
    // QUICKSETTINGS
    // ══════════════════════════════════════════════
    {
      id: "quicksettings", label: "Config Rápida", perTheme: true, perStyle: false,
      props: [
        { key:"textColor",  type:"palette", default:"on_surface",        label:"Texto",        section:"CORES" },
        { key:"dimColor",   type:"palette", default:"on_surface_variant",label:"Dim",          section:"CORES" },
        { key:"accentColor",type:"palette", default:"primary",           label:"Acento",       section:"CORES" },
        { key:"mutedColor", type:"palette", default:"error",             label:"Erro/Mutado",  section:"CORES" },
        { key:"progressBg", type:"palette", default:"outline_variant",   label:"Fundo slider", section:"CORES" },
        { key:"divider",    type:"palette", default:"outline_variant",   label:"Divisor",      section:"CORES" },
      ]
    },

    // ══════════════════════════════════════════════
    // NOTIFICATIONS
    // ══════════════════════════════════════════════
    {
      id: "notifications", label: "Notificações", perTheme: true, perStyle: false,
      props: [
        { key:"textColor",  type:"palette", default:"on_surface",        label:"Texto",   section:"CORES" },
        { key:"dimColor",   type:"palette", default:"on_surface_variant",label:"Dim",     section:"CORES" },
        { key:"accentColor",type:"palette", default:"primary",           label:"Acento",  section:"CORES" },
        { key:"mutedColor", type:"palette", default:"error",             label:"Urgente", section:"CORES" },
        { key:"divider",    type:"palette", default:"outline_variant",   label:"Divisor", section:"CORES" },

        // ── Comportamento ────────────────────────────────────────────
        { key:"dndAllowCritical", type:"bool", default:true,
          label:"Críticas ignoram Não Perturbe", section:"COMPORTAMENTO" },
        { key:"defaultUrgencyFilter", type:"enum", default:0, label:"Filtro padrão do painel", section:"COMPORTAMENTO",
          options:[{id:0,label:"Todas"},{id:1,label:"Normais"},{id:2,label:"Críticas"}] },

        // ── Toasts ───────────────────────────────────────────────────
        // Antes a posição do toast só dava pra trocar por um botão dentro
        // do próprio painel (menu flutuante) — agora também vive aqui,
        // então o botão de posição saiu do painel e essa é a única fonte.
        { key:"toastPosition", type:"enum", default:"top-right", label:"Posição dos toasts", section:"TOASTS",
          options:[
            {id:"top-left",     label:"Superior esquerdo"},
            {id:"top-center",   label:"Superior centro"},
            {id:"top-right",    label:"Superior direito"},
            {id:"bottom-left",  label:"Inferior esquerdo"},
            {id:"bottom-center",label:"Inferior centro"},
            {id:"bottom-right", label:"Inferior direito"},
          ] },
        { key:"maxToasts",        type:"int", default:5,    min:1,   max:10,    step:1,    unit:"",   label:"Máx. toasts simultâneos", section:"TOASTS" },
        { key:"toastTimeoutMs",   type:"int", default:5000, min:1000,max:15000, step:500,  unit:"ms", label:"Duração (normal)",         section:"TOASTS" },
        { key:"toastTimeoutLow",  type:"int", default:3000, min:1000,max:15000, step:500,  unit:"ms", label:"Duração (baixa urgência)", section:"TOASTS" },
        { key:"toastTimeoutCrit", type:"int", default:0,    min:0,   max:30000, step:1000, unit:"ms", label:"Duração (crítica, 0=nunca)", section:"TOASTS" },

        // ── Histórico e aparência dos cards ────────────────────────────
        { key:"maxHistory", type:"int", default:50, min:10, max:200, step:10, unit:"",  label:"Máx. no histórico", section:"HISTÓRICO" },
        { key:"cardRadius", type:"int", default:10, min:0,  max:20,  step:1,  unit:"px",label:"Raio dos cards",    section:"HISTÓRICO" },
      ]
    },

    // ══════════════════════════════════════════════
    // WORKSPACES — perStyle: true
    // ══════════════════════════════════════════════
    {
      id: "workspaces", label: "Workspaces", perTheme: true, perStyle: true,
      styles: ["dots", "icons", "hybrid", "number", "focus", "current"],
      // props sem estilo (comuns a todos os estilos dentro do tema)
      commonProps: [
        { key:"style",          type:"enum",  default:"icons", label:"Estilo", section:"ESTILO",
          options:[{id:"dots",label:"Pontos"},{id:"icons",label:"Ícones"},{id:"hybrid",label:"Híbrido"},{id:"number",label:"Número"},{id:"focus",label:"Foco (ativa=ícones, resto=número)"},{id:"current",label:"Só atual (só ícones da ativa)"}] },
        { key:"iconsSort",      type:"enum",  default:"position", label:"Ordenação", section:"ÍCONES",
          options:[{id:"position",label:"Posição"},{id:"alphabetical",label:"Alfabética"}],
          visibleWhen:"_hasIcons" },
        { key:"iconMonochrome", type:"bool",  default:true, label:"Monocromático", section:"ÍCONES", visibleWhen:"_hasIcons" },
        { key:"iconSpacing",    type:"int",   default:4, min:0, max:16, step:1, unit:"px", label:"Espaçamento ícones", section:"ÍCONES", visibleWhen:"_hasIcons" },
        { key:"iconSize",       type:"int",   default:18, min:12, max:36, step:1, unit:"px", label:"Tamanho dos ícones", section:"ÍCONES", visibleWhen:"_hasIcons" },
        { key:"showNumber",     type:"bool",  default:false, label:"Mostrar número da workspace", section:"ÍCONES", visibleWhen:"_hasIcons" },
        { key:"numberBgEnabled",  type:"bool", default:false, label:"Fundo no número", section:"NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberBgRadius",   type:"int",  default:4, min:0, max:20, step:1, unit:"px", label:"Raio do fundo do número",      section:"NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberBgPaddingH", type:"int",  default:4, min:0, max:16, step:1, unit:"px", label:"Padding H do fundo do número", section:"NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberBgPaddingV", type:"int",  default:2, min:0, max:16, step:1, unit:"px", label:"Padding V do fundo do número", section:"NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberSpacing",    type:"int",  default:4, min:0, max:20, step:1, unit:"px", label:"Espaço até o 1º ícone",        section:"NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberColor",         type:"palette", default:"on_surface_variant", label:"Número",                section:"CORES — NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberColorActive",   type:"palette", default:"on_primary",         label:"Número ativo",          section:"CORES — NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberBgColor",       type:"palette", default:"surface_variant",    label:"Fundo do número",       section:"CORES — NÚMERO", visibleWhen:"_hasIcons" },
        { key:"numberBgColorActive", type:"palette", default:"primary",            label:"Fundo do número ativo", section:"CORES — NÚMERO", visibleWhen:"_hasIcons" },
        { key:"showAddButton",  type:"bool",  default:true, label:"Mostrar botão +", section:"GERAL" },
        { key:"showTooltip",    type:"bool",  default:true, label:"Mostrar tooltip ao passar o mouse", section:"GERAL" },
        { key:"spacing",        type:"int",   default:2, min:0, max:24, step:1, unit:"px", label:"Espaçamento entre ws", section:"GERAL" },
        { key:"scrollEnabled", type:"bool", default:false, label:"Scroll troca workspace/janela", section:"SCROLL" },
        { key:"scrollAction",  type:"enum", default:"workspace", label:"O que o scroll muda", section:"SCROLL",
          options:[{id:"workspace",label:"Workspace"},{id:"window",label:"Janela"}] },
        { key:"scrollInvert",  type:"bool", default:false, label:"Inverter direção do scroll", section:"SCROLL" },
      ],
      // props por estilo (isoladas entre dots/icons/hybrid/number)
      props: [
        // tamanho dos itens (dots/número) — não afeta "icons" (ver iconSize, commonProp acima)
        { key:"dotSize",             type:"int",     default:8,    min:4, max:16, step:1,    unit:"px", label:"Tamanho do dot",        section:"TAMANHO", visibleWhen:"_hasDots" },
        { key:"fontSize",            type:"int",     default:10,   min:8, max:20, step:1,    unit:"px", label:"Tamanho do número",     section:"TAMANHO", visibleWhen:"_hasDots" },
        { key:"bgOpacity",           type:"real",    default:0.0,  min:0, max:1, step:0.05, unit:"%", label:"Opacidade fundo",       section:"FUNDO" },
        { key:"bgPaddingH",          type:"int",     default:8,    min:0, max:32, step:2,   unit:"px", label:"Padding H",             section:"FUNDO" },
        { key:"bgPaddingV",          type:"int",     default:2,    min:0, max:20, step:1,   unit:"px", label:"Padding V",             section:"FUNDO" },
        { key:"bgBorderWidth",       type:"real",    default:0,    min:0, max:4,  step:1,   unit:"px", label:"Borda (inativo)",       section:"FUNDO" },
        { key:"bgOpacityActive",     type:"real",    default:0.85, min:0, max:1, step:0.05, unit:"%", label:"Opacidade ativo",        section:"ATIVA" },
        { key:"bgPaddingHActive",    type:"int",     default:6,    min:0, max:32, step:2,   unit:"px", label:"Padding H ativo",       section:"ATIVA" },
        { key:"bgPaddingVActive",    type:"int",     default:2,    min:0, max:20, step:1,   unit:"px", label:"Padding V ativo",       section:"ATIVA" },
        { key:"bgRadiusActive",      type:"real",    default:99,   min:0, max:99, step:1,   unit:"px", label:"Raio ativo",            section:"ATIVA" },
        { key:"bgBorderWidthActive", type:"real",    default:0,    min:0, max:4,  step:1,   unit:"px", label:"Borda ativo",           section:"ATIVA" },
        { key:"bgColor",             type:"palette", default:"surface_variant",      label:"Fundo",        section:"CORES — FUNDO" },
        { key:"bgColorActive",       type:"palette", default:"primary_container",    label:"Fundo ativo",  section:"CORES — FUNDO" },
        { key:"bgBorderColor",       type:"palette", default:"on_surface",           label:"Borda",        section:"CORES — FUNDO" },
        { key:"bgBorderColorActive", type:"palette", default:"primary",              label:"Borda ativa",  section:"CORES — FUNDO" },
        { key:"dotColor",            type:"palette", default:"on_surface_variant",   label:"Ponto vazio",  section:"CORES — PONTOS", visibleWhen:"_hasDots" },
        { key:"dotActiveColor",      type:"palette", default:"on_surface",           label:"Ponto ativo",  section:"CORES — PONTOS", visibleWhen:"_hasDots" },
        { key:"dotOccupiedColor",    type:"palette", default:"on_surface",           label:"Ponto ocupado",section:"CORES — PONTOS", visibleWhen:"_hasDots" },
        { key:"dotUrgentColor",      type:"palette", default:"error",                label:"Ponto urgente",section:"CORES — PONTOS", visibleWhen:"_hasDots" },
        { key:"iconMonoColor",       type:"palette", default:"on_surface",           label:"Ícone",        section:"CORES — ÍCONES",  visibleWhen:"_hasIcons" },
        { key:"iconMonoColorActive", type:"palette", default:"primary",              label:"Ícone ativo",  section:"CORES — ÍCONES",  visibleWhen:"_hasIcons" },
        { key:"revealMode",           type:"enum", default:"hover", label:"Modo de revelação", section:"FOCO — REVELAÇÃO",
          options:[{id:"hover",label:"Hover"},{id:"click",label:"Clique"}], visibleWhen:"_isFocus" },
        { key:"hoverRevealDelayMs",   type:"int",  default:0, min:0, max:2000, step:50, unit:"ms",
          label:"Delay pra abrir (hover)", section:"FOCO — REVELAÇÃO", visibleWhen:"_isFocus" },
        { key:"clickCollapseMode",    type:"enum", default:"exit", label:"Fecha (clique)", section:"FOCO — REVELAÇÃO",
          options:[{id:"exit",label:"Ao sair do hover"},{id:"delay",label:"Com delay"}], visibleWhen:"_isFocus" },
        { key:"clickRevealTimeoutMs", type:"int",  default:2500, min:0, max:10000, step:100, unit:"ms",
          label:"Fecha sozinho depois de", section:"FOCO — REVELAÇÃO", visibleWhen:"_isFocus" },
      ]
    },

  ] // fim modules

  // ── Helpers ────────────────────────────────────────────────────────────

  // Retorna o módulo pelo id
  function module(id) {
    for (var i = 0; i < modules.length; i++)
      if (modules[i].id === id) return modules[i]
    return null
  }

  // Retorna a prop pelo módulo e chave
  function prop(moduleId, key) {
    var m = module(moduleId)
    if (!m) return null
    var props = m.props || []
    for (var i = 0; i < props.length; i++)
      if (props[i].key === key) return props[i]
    if (m.commonProps) {
      var cp = m.commonProps
      for (var j = 0; j < cp.length; j++)
        if (cp[j].key === key) return cp[j]
    }
    return null
  }

  // Retorna o default hardcoded de uma prop
  function defaultValue(moduleId, key) {
    var p = prop(moduleId, key)
    return p ? p.default : undefined
  }

  // Retorna true se a prop é comum (não isolada por estilo)
  function isCommonProp(moduleId, key) {
    var m = module(moduleId)
    if (!m || !m.commonProps) return false
    for (var i = 0; i < m.commonProps.length; i++)
      if (m.commonProps[i].key === key) return true
    return false
  }
}
