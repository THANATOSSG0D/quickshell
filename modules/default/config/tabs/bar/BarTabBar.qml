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
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  signal changed(var opts)

  // Dimensões da barra vivem soltas na raiz de "bar" (objeto flat).
  function g(key) { return config ? config[key] : undefined }

  // Como g(key), mas com fallback seguro: usa "def" apenas quando o valor
  // é undefined/null — nunca quando é 0. O padrão antigo "g(key) || def"
  // tratava 0 como "não setado" e forçava o default de volta na tela,
  // impedindo o usuário de zerar margem/raio/etc.
  function gd(key, def) {
    var v = g(key)
    return (v !== undefined && v !== null) ? v : def
  }

  // Visibilidade por contrato — recebida do ConfigWindow, que lê o JSON
  // do tema ativo. Fail-open: se não chegou contrato, mostra tudo.
  required property var contract   // win._contract passado pelo Loader

  // Paleta vive aninhada em "palette" (igual aos outros módulos).
  function gp(key, def) {
    if (!config) return def
    var v = config.get("palette", key)
    return (v !== undefined && v !== null) ? v : def
  }

  // ════════════════════════════════════════════════════════════════════
  // DIMENSÕES DA BARRA
  // ════════════════════════════════════════════════════════════════════
  C.CfgSection { title: "DIMENSÕES DA BARRA"; colorTextDim: root.colorTextDim }
  C.CfgSlider {
    label: "Tamanho"; value: root.gd("barSize", 30)
    from: 20; to: 60; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barSize: v })
  }
  C.CfgSlider {
    label: "Margem"; value: root.gd("barMargin", 3)
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barMargin: v })
  }
  C.CfgSlider {
    // Multiplicador global aplicado a ícones/fontes/dots/artwork/paddings
    // dos módulos (ver Bar.qml::_set/_isScalable). NÃO afeta barSize,
    // barMargin, pillWidth/pillMinSpacing nem a geometria do Notch —
    // esses são setados via Binding{} direto, fora do _set().
    label: "Escala dos módulos"; value: root.gd("moduleScale", 1.0)
    from: 0.5; to: 2.0; step: 0.05; unit: "x"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleScale: v })
  }
  C.CfgSlider {
    label: "Largura pílula"; value: root.gd("pillWidth", 400)
    from: 100; to: 1400; step: 10; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["pillWidth"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillWidth: v })
  }
  C.CfgSlider {
    label: "Espaçamento mín."; value: root.gd("pillMinSpacing", 20)
    from: 0; to: 100; step: 5; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["pillMinSpacing"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillMinSpacing: v })
  }
  C.CfgSlider {
    // Margem extra somada à largura do popup aberto quando a pill estica pra
    // "abraçá-lo" (ver Pill.qml::_targetWidth).
    label: "Padding do popup"; value: root.gd("popupPillPadding", 32)
    from: 0; to: 100; step: 4; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["popupPillPadding"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ popupPillPadding: v })
  }

  // ── Notch — campos exclusivos, visíveis só quando o contrato do tema os declara
  C.CfgDiv { colorDivider: root.colorDivider; visible: !root.contract.bar || !!root.contract.bar["notchRadius"] }
  C.CfgSection { title: "NOTCH"; colorTextDim: root.colorTextDim; visible: !root.contract.bar || !!root.contract.bar["notchRadius"] }
  C.CfgSlider {
    label: "Raio interno"; value: root.gd("notchRadius", 18)
    from: 0; to: 40; step: 1; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["notchRadius"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ notchRadius: v })
  }
  C.CfgSlider {
    label: "Côncavo lateral"; value: root.gd("concaveRadius", 10)
    from: 0; to: 30; step: 1; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["concaveRadius"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ concaveRadius: v })
  }
  C.CfgSlider {
    label: "Padding horizontal"; value: root.gd("lobePadH", 14)
    from: 4; to: 40; step: 2; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["lobePadH"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ lobePadH: v })
  }
  C.CfgSlider {
    label: "Inclinação trapézio"; value: root.gd("notchTaper", 20)
    from: 0; to: 60; step: 2; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["notchTaper"]
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ notchTaper: v })
  }
  C.CfgSlider {
    // Margem extra somada à largura do popup aberto quando o lobo estica pra
    // "abraçá-lo" (ver Notch.qml::_lobeW) — mesmo conceito da Pill.
    label: "Padding do popup"; value: root.gd("notchPopupPadding", 32)
    from: 0; to: 100; step: 4; unit: "px"
    visible: !root.contract.bar || !!root.contract.bar["notchPopupPadding"]
    enabled: root.gd("notchExpandForPopups", true) === true
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ notchPopupPadding: v })
  }
  C.CfgToggle {
    label:        "Esticar pro popup"
    checked:      root.gd("notchExpandForPopups", true) === true
    visible:      !root.contract.bar || !!root.contract.bar["notchExpandForPopups"]
    colorAccent:  root.colorAccent
    colorTextDim: root.colorTextDim
    onToggled: root.changed({ notchExpandForPopups: !(root.gd("notchExpandForPopups", true) === true) })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ════════════════════════════════════════════════════════════════════
  // PALETA
  // ════════════════════════════════════════════════════════════════════
  // PALETA
  // Cada campo tem visible pelo contrato do tema ativo — se o tema não
  // declara aquela chave de paleta, o campo some automaticamente.
  // Os campos panelBg/progressBg/progressFg/divider foram removidos pois
  // a auditoria mostrou zero uso em todos os 8 temas.
  // ════════════════════════════════════════════════════════════════════
  C.CfgSection { title: "PALETA — BARRA"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Fundo barra"; value: root.gp("barBg", "surface_container")
    visible: !root.contract.palette || !!root.contract.palette["barBg"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "barBg", value: v })
  }
  C.CfgPalette {
    label: "Fundo pill"; value: root.gp("barBgPill", "surface_container_high")
    visible: !root.contract.palette || !!root.contract.palette["barBgPill"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "barBgPill", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PALETA — TEXTO"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Texto"; value: root.gp("text", "on_surface")
    visible: !root.contract.palette || !!root.contract.palette["text"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "text", value: v })
  }
  C.CfgPalette {
    label: "Texto dim"; value: root.gp("textDim", "on_surface_variant")
    visible: !root.contract.palette || !!root.contract.palette["textDim"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "textDim", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "PALETA — ACCENT"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Accent"; value: root.gp("accent", "primary")
    visible: !root.contract.palette || !!root.contract.palette["accent"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accent", value: v })
  }
  C.CfgPalette {
    label: "Accent bg"; value: root.gp("accentBg", "primary_container")
    visible: !root.contract.palette || !!root.contract.palette["accentBg"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accentBg", value: v })
  }
  C.CfgPalette {
    label: "Accent text"; value: root.gp("accentText", "on_primary")
    visible: !root.contract.palette || !!root.contract.palette["accentText"]
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "palette", key: "accentText", value: v })
  }
}

