import QtQuick
import Quickshell
import Quickshell.Io
import qs

// BarConfig — API central de leitura e escrita de configurações do bar.
//
// LEITURA:
//   config.get("mediaplayer", "bgColor")          → string (por tema atual)
//   config.get("workspaces",  "bgColor", "icons") → string (por tema + estilo)
//   config.get("workspaces",  "style")            → string (prop comum)
//
// ESCRITA:
//   config.set("mediaplayer", "bgColor", "primary")
//   config.set("workspaces",  "bgColor", "primary", "icons")
//   config.set("workspaces",  "style",   "dots")
//
// CASCATA de leitura:
//   1. BarState.json [tema][moduleId][style?][key]  — override do usuário
//   2. Bar.json themes[tema][moduleId][style?][key] — default do tema
//   3. BarSchema.defaultValue(moduleId, key)        — default hardcoded
//
// ISOLAMENTO:
//   • Cada tema tem seus próprios overrides em BarState.json
//   • Módulos com perStyle:true isolam configs por estilo dentro do tema
//   • set() grava APENAS o par (tema, moduleId, style?) tocado
//   • Trocar de tema → get() automaticamente lê o novo tema

Item {
  id: root
  visible: false

  // ── Props globais (não por tema) ────────────────────────────────────────
  property string theme:       "Pill"
  property bool   silenceMode: false

  // ── Props "bar" — por tema ───────────────────────────────────────────────
  // NOTA: estas são properties ARMAZENADAS (não bindings calculados via
  // get()/getModules() direto). Usar "readonly property X: get(...)" aqui
  // causava "Binding loop detected" no boot — 12 properties calculadas pela
  // mesma função, lidas em cascata durante a inicialização do componente,
  // levavam o motor de bindings do QtQuick a detectar reentrância. A solução
  // estável é recalcular explicitamente via _recalcBar(), chamada sempre que
  // theme/_dep mudam — mesmo padrão que o resto do arquivo já usa para
  // garantir previsibilidade (ver _syncBar nas versões anteriores deste
  // arquivo, que existia exatamente por este motivo).
  property bool autoHide:       false
  property int  position:       4
  property int  barSize:        30
  property int  barMargin:      3
  property int  pillWidth:      400
  property int  pillMinSpacing: 20

  property var modulesLeft:   []
  property var modulesCenter: []
  property var modulesRight:  []
  property var modulesTop:    []
  property var modulesMiddle: []
  property var modulesBottom: []

  // Recalcula as 12 properties acima a partir do tema atual.
  // Chamada após theme mudar, após _bump(), e uma vez no boot.
  function _recalcBar() {
    root.autoHide       = get("bar", "autoHide")
    root.position       = get("bar", "position")
    root.barSize        = get("bar", "barSize")
    root.barMargin      = get("bar", "barMargin")
    root.pillWidth      = get("bar", "pillWidth")
    root.pillMinSpacing = get("bar", "pillMinSpacing")

    root.modulesLeft   = getModules("left")
    root.modulesCenter = getModules("center")
    root.modulesRight  = getModules("right")
    root.modulesTop    = getModules("top")
    root.modulesMiddle = getModules("middle")
    root.modulesBottom = getModules("bottom")
  }
  onThemeChanged: _recalcBar()

  signal modulesUpdated()

  // ── Guards ─────────────────────────────────────────────────────────────
  property bool _ready:       false
  property bool _parsing:     false
  property bool configLoaded: false

  // ── Dep token — força reavaliação de get() quando tema/overrides mudam ─
  property int _dep: 0
  function _bump() { _dep++; _recalcBar() }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — get / set / saveAll
  // ══════════════════════════════════════════════════════════════════════

  // get(moduleId, key, style?) → any
  // Lê em cascata: BarState.json → Bar.json themes → BarSchema default
  function get(moduleId, key, style) {
    var _ = root._dep   // dependência reativa — reavalia quando _bump()
    var th = root.theme
    var m  = BarSchema.module(moduleId)
    if (!m) return undefined

    // Se perStyle e style fornecido (ou prop não é common), usa path com style
    var useStyle = m.perStyle && style && !BarSchema.isCommonProp(moduleId, key)

    // 1. override do usuário (BarState.json)
    try {
      var ov = stateAdapter.overrides
      var th_ov = ov && ov[th] ? ov[th] : null
      if (th_ov) {
        var mod_ov = th_ov[moduleId]
        if (mod_ov !== undefined) {
          if (useStyle) {
            if (mod_ov[style] && mod_ov[style][key] !== undefined)
              return mod_ov[style][key]
          } else {
            if (mod_ov[key] !== undefined) return mod_ov[key]
          }
        }
      }
    } catch(e) {}

    // 2. default do tema (Bar.json)
    // Tenta moduleId direto, com fallback camelCase para compatibilidade
    try {
      var themes = barAdapter.themes
      var th_def = themes && themes[th] ? themes[th] : null
      if (th_def) {
        // Fallback camelCase: "mediaplayer"→"mediaPlayer", "quicksettings"→"quickSettings"
        var camelKey = moduleId.replace(/(player|settings|spaces)/, function(m){
          return m.charAt(0).toUpperCase() + m.slice(1)
        })
        var keys = (camelKey !== moduleId) ? [moduleId, camelKey] : [moduleId]
        for (var ki = 0; ki < keys.length; ki++) {
          var mod_def = th_def[keys[ki]]
          if (mod_def !== undefined) {
            if (useStyle) {
              if (mod_def[style] && mod_def[style][key] !== undefined)
                return mod_def[style][key]
            } else {
              if (mod_def[key] !== undefined) return mod_def[key]
            }
            break
          }
        }
      }
    } catch(e) {}

    // 3. default hardcoded do schema
    return BarSchema.defaultValue(moduleId, key)
  }

  // getModules(slot) → array de ids de módulo para um slot do layout
  // (left/center/right/top/middle/bottom). Mesma cascata de get():
  // BarState.json[tema].bar.modules[slot] → Bar.json themes[tema].bar.modules[slot] → []
  function getModules(slot) {
    var _ = root._dep
    var th = root.theme

    try {
      var ov = stateAdapter.overrides
      var bar_ov = ov && ov[th] ? ov[th].bar : null
      if (bar_ov && bar_ov.modules && bar_ov.modules[slot] !== undefined)
        return bar_ov.modules[slot].slice()
    } catch(e) {}

    try {
      var themes = barAdapter.themes
      var bar_def = themes && themes[th] ? themes[th].bar : null
      if (bar_def && bar_def.modules && bar_def.modules[slot] !== undefined)
        return bar_def.modules[slot].slice()
    } catch(e) {}

    return []
  }

  // setModules(slot, list) → grava override do usuário para um slot do layout
  function setModules(slot, list) {
    var th = root.theme
    var o = {}
    try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
    if (!o[th])              o[th]              = {}
    if (!o[th].bar)          o[th].bar           = {}
    if (!o[th].bar.modules)  o[th].bar.modules   = {}
    o[th].bar.modules[slot] = list.slice()

    stateAdapter.overrides = o
    stateFile.writeAdapter()
    _bump()
    console.log("[BarConfig] setModules " + slot + " (tema:" + th + ")")
  }

  // set(moduleId, key, value, style?) → grava override do usuário e emite sinal
  function set(moduleId, key, value, style) {
    var th = root.theme
    var m  = BarSchema.module(moduleId)
    if (!m) return

    var useStyle = m.perStyle && style && !BarSchema.isCommonProp(moduleId, key)

    // Lê overrides existentes
    var o = {}
    try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
    if (!o[th])             o[th]             = {}
    if (!o[th][moduleId])   o[th][moduleId]   = {}

    if (useStyle) {
      if (!o[th][moduleId][style]) o[th][moduleId][style] = {}
      o[th][moduleId][style][key] = value
    } else {
      o[th][moduleId][key] = value
    }

    stateAdapter.overrides = o
    stateFile.writeAdapter()
    _bump()
    console.log("[BarConfig] set " + moduleId + "." + (useStyle ? style+"." : "") + key + " = " + value + " (tema:" + th + ")")
  }

  // clearModule(moduleId) — remove todos os overrides de um módulo no tema atual.
  // Após o clear, get() retorna os defaults do schema → paleta global volta a valer.
  function clearModule(moduleId) {
    var th = root.theme
    var o  = {}
    try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
    if (o[th] && o[th][moduleId]) {
      delete o[th][moduleId]
      stateAdapter.overrides = o
      stateFile.writeAdapter()
      _bump()
      console.log("[BarConfig] clearModule " + moduleId + " (tema:" + th + ")")
    }
  }

  // saveAll(opts) — chamado pelo ConfigWindow com pacote de mudanças
  // opts = { moduleId: { key: value, ... }, ... }  OU o formato legado flat
  function saveAll(opts) {
    console.log("[BarConfig] saveAll()")
    root._parsing = true

    // ── Globais (não por tema) ──────────────────────────────────────────
    if (opts.theme   !== undefined) root.theme       = opts.theme
    if (opts.silence !== undefined) root.silenceMode = opts.silence

    // ── "bar" — por tema, via set() (mesma cascata dos demais módulos) ──
    if (opts.autoHide       !== undefined) set("bar", "autoHide",       opts.autoHide)
    if (opts.position       !== undefined) set("bar", "position",       opts.position)
    if (opts.barSize        !== undefined) set("bar", "barSize",        opts.barSize)
    if (opts.barMargin      !== undefined) set("bar", "barMargin",      opts.barMargin)
    if (opts.pillWidth      !== undefined) set("bar", "pillWidth",      opts.pillWidth)
    if (opts.pillMinSpacing !== undefined) set("bar", "pillMinSpacing", opts.pillMinSpacing)

    // ── Listas de módulos do layout — por tema, via setModules() ───────
    if (opts.modulesLeft    !== undefined) setModules("left",   opts.modulesLeft)
    if (opts.modulesCenter  !== undefined) setModules("center", opts.modulesCenter)
    if (opts.modulesRight   !== undefined) setModules("right",  opts.modulesRight)
    if (opts.modulesTop     !== undefined) setModules("top",    opts.modulesTop)
    if (opts.modulesMiddle  !== undefined) setModules("middle", opts.modulesMiddle)
    if (opts.modulesBottom  !== undefined) setModules("bottom", opts.modulesBottom)

    // ── Por módulo (palette, mediaplayer, workspaces, etc) ──────────────
    // opts.modules = { mediaplayer: { bgColor: "primary", ... },
    //                  workspaces:  { common: {...}, icons: {...} } }
    if (opts.modules) {
      var th = root.theme
      var o  = {}
      try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
      if (!o[th]) o[th] = {}

      var modules = opts.modules
      for (var modId in modules) {
        var m = BarSchema.module(modId)
        if (!m) continue
        var modData = modules[modId]
        if (!o[th][modId]) o[th][modId] = {}

        if (m.perStyle) {
          // modData = { common: {key:val}, icons: {key:val}, dots: {key:val} }
          for (var section in modData) {
            if (section === "common") {
              // props comuns (não isoladas por estilo)
              for (var ck in modData.common)
                o[th][modId][ck] = modData.common[ck]
            } else {
              // props por estilo
              if (!o[th][modId][section]) o[th][modId][section] = {}
              for (var sk in modData[section])
                o[th][modId][section][sk] = modData[section][sk]
            }
          }
        } else {
          // módulo simples (ex: mediaplayer, clock, palette)
          for (var mk in modData)
            o[th][modId][mk] = modData[mk]
        }
      }
      stateAdapter.overrides = o
      stateFile.writeAdapter()
      _bump()
    }

    // ── Grava globais no Bar.json — preserva themes ─────────────────────
    barAdapter.bar = { theme: root.theme, silence: root.silenceMode }
    // Garante que themes não foi zerado antes de gravar
    if (!barAdapter.themes || Object.keys(barAdapter.themes).length === 0) {
      console.warn("[BarConfig] AVISO: barAdapter.themes está vazio antes de writeAdapter — themes serão perdidos")
    }
    barFile.writeAdapter()

    root._parsing = false
    root.modulesUpdated()
    console.log("[BarConfig] saveAll concluído")
  }

  // ── Cores resolvidas (para uso direto no QML) ──────────────────────────
  // NOTA: readonly property color X: resolve(get(...)) cria binding loop
  // porque get() lê _dep, e _dep muda quando overrides muda, o que dispara
  // a reavaliação das props, que pode mudar overrides de novo.
  // Solução: usar property (não readonly) com onDepChanged explícito.

  function resolve(paletteKey) {
    return Colors[paletteKey] !== undefined ? Colors[paletteKey] : Qt.color("transparent")
  }

  // Atualiza todas as cores resolvidas quando _dep muda
  on_DepChanged: _resolveAll()

  function _resolveAll() {
    paletteBarBg         = resolve(get("palette","barBg"))
    paletteBarBgPill     = resolve(get("palette","barBgPill"))
    paletteText          = resolve(get("palette","text"))
    paletteTextDim       = resolve(get("palette","textDim"))
    paletteAccent        = resolve(get("palette","accent"))
    paletteAccentBg      = resolve(get("palette","accentBg"))
    paletteAccentText    = resolve(get("palette","accentText"))
    palettePanelBg       = resolve(get("palette","panelBg"))
    paletteProgressBg    = resolve(get("palette","progressBg"))
    paletteProgressFg    = resolve(get("palette","progressFg"))
    paletteDivider       = resolve(get("palette","divider"))
    paletteMpBgColor         = resolve(get("mediaplayer","bgColor"))
    paletteMpBgColorActive   = resolve(get("mediaplayer","bgColorActive"))
    paletteMpTextColor       = resolve(get("mediaplayer","textColor"))
    paletteMpDimColor        = resolve(get("mediaplayer","dimColor"))
    paletteMpTextColorActive = resolve(get("mediaplayer","textColorActive"))
    paletteMpDimColorActive  = resolve(get("mediaplayer","dimColorActive"))
    paletteClkText       = resolve(get("clock","textColor"))
    paletteClkDim        = resolve(get("clock","dimColor"))
    paletteClkAccent     = resolve(get("clock","accentColor"))
    paletteClkTextColor  = paletteClkText
    paletteClkDimColor   = paletteClkDim
    paletteClkAccentColor= paletteClkAccent
    paletteVolText       = resolve(get("volume","textColor"))
    paletteVolDim        = resolve(get("volume","dimColor"))
    paletteVolAccent     = resolve(get("volume","accentColor"))
    paletteVolMuted      = resolve(get("volume","mutedColor"))
    paletteVolProgress   = resolve(get("volume","progressBg"))
    paletteQsText        = resolve(get("quicksettings","textColor"))
    paletteQsDim         = resolve(get("quicksettings","dimColor"))
    paletteQsAccent      = resolve(get("quicksettings","accentColor"))
    paletteQsMuted       = resolve(get("quicksettings","mutedColor"))
    paletteQsProgress    = resolve(get("quicksettings","progressBg"))
    paletteNotifText     = resolve(get("notifications","textColor"))
    paletteNotifDim      = resolve(get("notifications","dimColor"))
    paletteNotifAccent   = resolve(get("notifications","accentColor"))
    paletteNotifMuted    = resolve(get("notifications","mutedColor"))
    // workspaces resolved
    paletteWsBgColor             = resolve(pkWsBgColor)
    paletteWsBgBorderColor       = resolve(pkWsBgBorderColor)
    paletteWsDotColor            = resolve(pkWsDotColor)
    paletteWsDotActiveColor      = resolve(pkWsDotActiveColor)
    paletteWsDotOccupiedColor    = resolve(pkWsDotOccupiedColor)
    paletteWsDotUrgentColor      = resolve(pkWsDotUrgentColor)
    paletteWsIconMonoColor       = resolve(pkWsIconMonoColor)
    paletteWsIconMonoColorActive = resolve(pkWsIconMonoColorActive)
    paletteWsBgColorActive       = resolve(pkWsBgColorActive)
    paletteWsBgBorderColorActive = resolve(pkWsBgBorderColorActive)
  }

  property color paletteBarBg:          "#1a1a1a"
  property color paletteBarBgPill:      "#1a1a1a"
  property color paletteText:           "#e2e2e2"
  property color paletteTextDim:        "#9e9e9e"
  property color paletteAccent:         "#ffb4a9"
  property color paletteAccentBg:       "#5f3229"
  property color paletteAccentText:     "#ffffff"
  property color palettePanelBg:        "#2a2a2a"
  property color paletteProgressBg:     "#474747"
  property color paletteProgressFg:     "#ffb4a9"
  property color paletteDivider:        "#474747"

  property color paletteMpBgColor:         "#2a2a2a"
  property color paletteMpBgColorActive:   "#5f3229"
  property color paletteMpTextColor:       "#e2e2e2"
  property color paletteMpDimColor:        "#9e9e9e"
  property color paletteMpTextColorActive: "#ffffff"
  property color paletteMpDimColorActive:  "#9e9e9e"

  property color paletteClkText:         "#e2e2e2"
  property color paletteClkDim:          "#9e9e9e"
  property color paletteClkAccent:       "#ffb4a9"
  property color paletteClkTextColor:    "#e2e2e2"
  property color paletteClkDimColor:     "#9e9e9e"
  property color paletteClkAccentColor:  "#ffb4a9"

  property color paletteVolText:     "#e2e2e2"
  property color paletteVolDim:      "#9e9e9e"
  property color paletteVolAccent:   "#ffb4a9"
  property color paletteVolMuted:    "#cf6679"
  property color paletteVolProgress: "#474747"

  property color paletteQsText:     "#e2e2e2"
  property color paletteQsDim:      "#9e9e9e"
  property color paletteQsAccent:   "#ffb4a9"
  property color paletteQsMuted:    "#cf6679"
  property color paletteQsProgress: "#474747"

  property color paletteNotifText:  "#e2e2e2"
  property color paletteNotifDim:   "#9e9e9e"
  property color paletteNotifAccent:"#ffb4a9"
  property color paletteNotifMuted: "#cf6679"

  property color paletteWsBgColor:             "#2a2a2a"
  property color paletteWsBgBorderColor:       "#e2e2e2"
  property color paletteWsDotColor:            "#9e9e9e"
  property color paletteWsDotActiveColor:      "#e2e2e2"
  property color paletteWsDotOccupiedColor:    "#e2e2e2"
  property color paletteWsDotUrgentColor:      "#cf6679"
  property color paletteWsIconMonoColor:       "#e2e2e2"
  property color paletteWsIconMonoColorActive: "#ffb4a9"
  property color paletteWsBgColorActive:       "#5f3229"
  property color paletteWsBgBorderColorActive: "#ffb4a9"

  // workspaces — lidos do estilo atual
  property string wsStyle: get("workspaces","style") || "icons"

  function wsGet(key) { return get("workspaces", key, wsStyle) }

  readonly property real   wsBgOpacity:             wsGet("bgOpacity")
  readonly property real   wsBgPaddingH:            wsGet("bgPaddingH")
  readonly property real   wsBgPaddingV:            wsGet("bgPaddingV")
  readonly property string pkWsBgColor:             wsGet("bgColor")
  readonly property string pkWsBgBorderColor:       wsGet("bgBorderColor")
  readonly property string pkWsDotColor:            wsGet("dotColor")
  readonly property string pkWsDotActiveColor:      wsGet("dotActiveColor")
  readonly property string pkWsDotOccupiedColor:    wsGet("dotOccupiedColor")
  readonly property string pkWsDotUrgentColor:      wsGet("dotUrgentColor")
  readonly property string pkWsIconMonoColor:       wsGet("iconMonoColor")
  readonly property string pkWsIconMonoColorActive: wsGet("iconMonoColorActive")
  readonly property string pkWsBgColorActive:       wsGet("bgColorActive")
  readonly property real   wsBgOpacityActive:       wsGet("bgOpacityActive")
  readonly property string pkWsBgBorderColorActive: wsGet("bgBorderColorActive")
  readonly property real   wsBgBorderWidthActive:   wsGet("bgBorderWidthActive")
  readonly property real   wsBgPaddingHActive:      wsGet("bgPaddingHActive")
  readonly property real   wsBgPaddingVActive:      wsGet("bgPaddingVActive")
  readonly property real   wsBgRadiusActive:        wsGet("bgRadiusActive")

  // Props de ws comuns
  readonly property string wsIconsSort:      get("workspaces","iconsSort")     || "position"
  readonly property bool   wsIconMonochrome: get("workspaces","iconMonochrome") !== false
  readonly property int    wsIconSpacing:    get("workspaces","iconSpacing")    || 4
  readonly property bool   wsShowAddButton:  get("workspaces","showAddButton")  !== false
  readonly property int    wsSpacing:        get("workspaces","spacing")        || 2

  // mediaplayer genérico
  readonly property bool   mpShowText:       get("mediaplayer","showText")       !== false
  readonly property string mpTextMode:       get("mediaplayer","textMode")       || "artistAndTitle"
  readonly property int    mpScrollSpeed:    get("mediaplayer","scrollSpeed")    || 40
  readonly property int    mpScrollWidth:    get("mediaplayer","scrollWidth")    || 140
  readonly property bool   mpBgEnabled:      get("mediaplayer","bgEnabled")      === true
  readonly property real   mpBgOpacity:      get("mediaplayer","bgOpacity")      || 0.5
  readonly property real   mpBgOpacityActive:get("mediaplayer","bgOpacityActive")|| 0.8
  readonly property int    mpBgPaddingH:     get("mediaplayer","bgPaddingH")     || 8
  readonly property int    mpBgPaddingV:     get("mediaplayer","bgPaddingV")     || 4
  readonly property int    mpScrollPauseMs:  1800   // fixo — não exposto no schema ainda

  // clock
  readonly property int clkDismissDelayMs: get("clock","dismissDelayMs") || 8000

  // volume
  readonly property bool volShowSink:   get("volume","showSink")   !== false
  readonly property bool volShowSource: get("volume","showSource")  !== false
  readonly property real volMaxVol:     get("volume","maxVol")      || 1.5

  // ══════════════════════════════════════════════════════════════════════
  // FILE 1 — Bar.json (globais + defaults de tema)
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: barFile
    path:         Quickshell.shellDir + "/state/Bar.json"
    watchChanges: false

    JsonAdapter {
      id: barAdapter
      property var bar:    ({})
      property var themes: ({})

      onBarChanged: {
        var b = bar
        if (!b || Object.keys(b).length === 0) return
        if (b.theme   !== undefined) root.theme       = b.theme
        if (b.silence !== undefined) root.silenceMode = b.silence
        root._bump()
      }

      onThemesChanged: {
        root._bump()
        if (themes && Object.keys(themes).length > 0) {
          root.configLoaded = true
          startupTimer.stop()
          Qt.callLater(function() { root.modulesUpdated() })
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILE 2 — BarState.json (overrides do usuário)
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: stateFile
    path:         Quickshell.shellDir + "/state/BarState.json"
    watchChanges: false

    JsonAdapter {
      id: stateAdapter
      // overrides[tema][moduleId][key]  ou  overrides[tema][moduleId][style][key]
      // overrides[tema].bar.{autoHide,position,barSize,...} e
      // overrides[tema].bar.modules[slot] seguem a mesma convenção.
      property var overrides: ({})
      onOverridesChanged: root._bump()
    }
  }

  // ── Startup ────────────────────────────────────────────────────────────
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: { root._ready = true; startupTimer.start() }
  }

  // Fallback: se themes já vier populado antes do Process terminar, ou se
  // por algum motivo onThemesChanged não disparar (valores idênticos),
  // garante que configLoaded seja liberado mesmo assim.
  Timer {
    id: startupTimer
    interval: 600; repeat: false
    onTriggered: {
      if (root._parsing) root._parsing = false
      if (root.configLoaded) return
      if (barAdapter.themes && Object.keys(barAdapter.themes).length > 0) {
        root.configLoaded = true
        root._recalcBar()
        Qt.callLater(function() { root.modulesUpdated() })
      }
    }
  }

  Component.onCompleted: mkdirProc.running = true
}
