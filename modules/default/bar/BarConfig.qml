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

  // ── Props estruturais (não por tema) ───────────────────────────────────
  property string theme:          "Pill"
  property bool   autoHide:       false
  property bool   silenceMode:    false
  property int    position:       4
  property int    barSize:        30
  property int    barMargin:      3
  property int    pillWidth:      400
  property int    pillMinSpacing: 20

  property var modulesLeft:   ["mediaplayer","separator","quicksettings"]
  property var modulesCenter: ["workspaces"]
  property var modulesRight:  ["clock","separator","volume","separator","notifications"]
  property var modulesTop:    ["mediaplayer","separator","quicksettings"]
  property var modulesMiddle: ["workspaces"]
  property var modulesBottom: ["clock","separator","volume","separator","notifications"]

  signal modulesUpdated()

  // ── Guards ─────────────────────────────────────────────────────────────
  property bool _ready:       false
  property bool _parsing:     false
  property bool configLoaded: false

  // ── Dep token — força reavaliação de get() quando tema/overrides mudam ─
  property int _dep: 0
  function _bump() { _dep++ }

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

    // ── Estruturais (não por tema) ─────────────────────────────────────
    if (opts.theme          !== undefined) root.theme          = opts.theme
    if (opts.autoHide       !== undefined) root.autoHide       = opts.autoHide
    if (opts.silence        !== undefined) root.silenceMode    = opts.silence
    if (opts.position       !== undefined) root.position       = opts.position
    if (opts.barSize        !== undefined) root.barSize        = opts.barSize
    if (opts.barMargin      !== undefined) root.barMargin      = opts.barMargin
    if (opts.pillWidth      !== undefined) root.pillWidth      = opts.pillWidth
    if (opts.pillMinSpacing !== undefined) root.pillMinSpacing = opts.pillMinSpacing
    if (opts.modulesLeft    !== undefined) root.modulesLeft    = opts.modulesLeft.slice()
    if (opts.modulesCenter  !== undefined) root.modulesCenter  = opts.modulesCenter.slice()
    if (opts.modulesRight   !== undefined) root.modulesRight   = opts.modulesRight.slice()
    if (opts.modulesTop     !== undefined) root.modulesTop     = opts.modulesTop.slice()
    if (opts.modulesMiddle  !== undefined) root.modulesMiddle  = opts.modulesMiddle.slice()
    if (opts.modulesBottom  !== undefined) root.modulesBottom  = opts.modulesBottom.slice()

    // ── Por módulo ─────────────────────────────────────────────────────
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

    // ── Grava estrutura no Bar.json — preserva themes ───────────────────
    barAdapter.bar = {
      theme: root.theme, autoHide: root.autoHide, silence: root.silenceMode,
      position: root.position, barSize: root.barSize, barMargin: root.barMargin,
      pillWidth: root.pillWidth, pillMinSpacing: root.pillMinSpacing
    }
    barAdapter.modules = {
      left: root.modulesLeft, center: root.modulesCenter, right: root.modulesRight,
      top: root.modulesTop, middle: root.modulesMiddle, bottom: root.modulesBottom
    }
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
  // FILE 1 — Bar.json (estrutura + defaults de tema)
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: barFile
    path:         Quickshell.shellDir + "/state/Bar.json"
    watchChanges: false

    JsonAdapter {
      id: barAdapter
      property var bar:     ({})
      property var modules: ({})
      property var themes:  ({})

      onBarChanged: {
        var b = bar
        if (!b || Object.keys(b).length === 0) return
        if (b.theme          !== undefined) root.theme          = b.theme
        if (b.autoHide       !== undefined) root.autoHide       = b.autoHide
        if (b.silence        !== undefined) root.silenceMode    = b.silence
        if (b.position       !== undefined) root.position       = b.position
        if (b.barSize        !== undefined) root.barSize        = b.barSize
        if (b.barMargin      !== undefined) root.barMargin      = b.barMargin
        if (b.pillWidth      !== undefined) root.pillWidth      = b.pillWidth
        if (b.pillMinSpacing !== undefined) root.pillMinSpacing = b.pillMinSpacing
        root._bump()
      }

      onModulesChanged: {
        var m = JSON.parse(JSON.stringify(modules))
        if (!m) return
        var hasAny = ["left","center","right","top","middle","bottom"]
          .some(function(k){ return m[k] && m[k].length > 0 })
        if (!hasAny) return
        if (m.left   && m.left.length   > 0) root.modulesLeft   = m.left
        if (m.center && m.center.length > 0) root.modulesCenter = m.center
        if (m.right  && m.right.length  > 0) root.modulesRight  = m.right
        if (m.top    && m.top.length    > 0) root.modulesTop    = m.top
        if (m.middle && m.middle.length > 0) root.modulesMiddle = m.middle
        if (m.bottom && m.bottom.length > 0) root.modulesBottom = m.bottom
        root.configLoaded = true
        startupTimer.stop()
        Qt.callLater(function() { root.modulesUpdated() })
      }

      onThemesChanged: root._bump()
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
      property var overrides: ({})
      onOverridesChanged: {
        // Migração automática: formato legado (chaves flat em overrides{})
        // para o novo formato (overrides[tema][moduleId][key])
        var o = overrides
        if (o && typeof o === "object") {
          var keys = Object.keys(o)
          // Detecta formato legado: chaves que não são nomes de temas conhecidos
          // (temas são strings começando com maiúscula como "Pill", "Minimal")
          var isLegacy = keys.length > 0 && keys.some(function(k) {
            return k.charAt(0) === k.charAt(0).toLowerCase() || k.startsWith("pk") || k.startsWith("ws")
          })
          if (isLegacy) {
            console.log("[BarConfig] Migrando BarState.json do formato legado...")
            // Descarta o formato antigo — será regravado no novo formato quando
            // o usuário fizer a próxima alteração via ConfigWindow
            stateAdapter.overrides = {}
            stateFile.writeAdapter()
            return
          }
        }
        root._bump()
      }
    }
  }

  // ── Sync Bar.json estrutural ───────────────────────────────────────────
  function _syncBar() {
    if (!root._ready || root._parsing) return
    root._parsing = true
    // Preserva modules existentes — só atualiza bar{}
    barAdapter.bar = {
      theme: root.theme, autoHide: root.autoHide, silence: root.silenceMode,
      position: root.position, barSize: root.barSize, barMargin: root.barMargin,
      pillWidth: root.pillWidth, pillMinSpacing: root.pillMinSpacing
    }
    if (!barAdapter.modules || Object.keys(barAdapter.modules).length === 0) {
      barAdapter.modules = {
        left: root.modulesLeft, center: root.modulesCenter, right: root.modulesRight,
        top: root.modulesTop, middle: root.modulesMiddle, bottom: root.modulesBottom
      }
    }
    barFile.writeAdapter()
    root._parsing = false
    root._bump()
  }
  onThemeChanged:          _syncBar()
  onAutoHideChanged:       _syncBar()
  onSilenceModeChanged:    _syncBar()
  onPositionChanged:       _syncBar()
  onBarSizeChanged:        _syncBar()
  onBarMarginChanged:      _syncBar()
  onPillWidthChanged:      _syncBar()
  onPillMinSpacingChanged: _syncBar()

  function _syncModules() {
    if (!root._ready || root._parsing) return
    root._parsing = true
    barAdapter.modules = {
      left: root.modulesLeft, center: root.modulesCenter, right: root.modulesRight,
      top: root.modulesTop, middle: root.modulesMiddle, bottom: root.modulesBottom
    }
    // Preserva bar existente
    if (!barAdapter.bar || Object.keys(barAdapter.bar).length === 0) {
      barAdapter.bar = {
        theme: root.theme, autoHide: root.autoHide, silence: root.silenceMode,
        position: root.position, barSize: root.barSize, barMargin: root.barMargin,
        pillWidth: root.pillWidth, pillMinSpacing: root.pillMinSpacing
      }
    }
    barFile.writeAdapter()
    root._parsing = false
  }
  onModulesLeftChanged:   _syncModules()
  onModulesCenterChanged: _syncModules()
  onModulesRightChanged:  _syncModules()
  onModulesTopChanged:    _syncModules()
  onModulesMiddleChanged: _syncModules()
  onModulesBottomChanged: _syncModules()

  // ── Startup ────────────────────────────────────────────────────────────
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: { root._ready = true; startupTimer.start() }
  }

  Timer {
    id: startupTimer
    interval: 600; repeat: false
    onTriggered: {
      if (root._parsing) root._parsing = false
      if (root.configLoaded) return
      var m = barAdapter.modules
      var hasAny = ["left","center","right","top","middle","bottom"]
        .some(function(k){ return m[k] && m[k].length > 0 })
      if (hasAny) {
        if (m.left   && m.left.length   > 0) root.modulesLeft   = m.left
        if (m.center && m.center.length > 0) root.modulesCenter = m.center
        if (m.right  && m.right.length  > 0) root.modulesRight  = m.right
        if (m.top    && m.top.length    > 0) root.modulesTop    = m.top
        if (m.middle && m.middle.length > 0) root.modulesMiddle = m.middle
        if (m.bottom && m.bottom.length > 0) root.modulesBottom = m.bottom
        root.configLoaded = true
        Qt.callLater(function() { root.modulesUpdated() })
      }
    }
  }

  Component.onCompleted: mkdirProc.running = true
}
