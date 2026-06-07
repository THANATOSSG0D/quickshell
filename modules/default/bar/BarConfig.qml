import QtQuick
import Quickshell
import Quickshell.Io
import qs

// BarConfig — fonte única de verdade para todas as configurações do bar.
//
// Arquitetura de isolamento por tema e por estilo de workspace:
//
//   Bar.json  → defaults por tema/estilo:
//     themes.<Tema>.workspaces.<style>.{ visual/cores }
//     themes.<Tema>.workspaces.common.{ showAddButton, wsSpacing }
//     themes.<Tema>.mediaPlayer.{ ... }
//     themes.<Tema>.palette.{ ... }
//     themes.<Tema>.clock.{ ... }
//
//   BarState.json → overrides do usuário (mesma estrutura):
//     overrides.<Tema>.workspaces.<style>.{ só o que o user tocou }
//     overrides.<Tema>.mediaPlayer.{ ... }
//     overrides.<Tema>.palette.{ ... }
//
// Regra: mudar tema aplica defaults do tema. Mudar estilo de workspace aplica
// defaults do estilo dentro do tema atual. Configs de um tema/estilo nunca
// vazam para outro.

Item {
  id: root
  visible: false

  // ── bar.* ──────────────────────────────────────────────────────────────
  property string theme:           "Pill"
  property bool   autoHide:        true
  property bool   silenceMode:     false
  property int    position:        -2
  property int    barSize:         0
  property int    barMargin:       -1
  property int    pillWidth:       800
  property int    pillMinSpacing:  20

  // ── modules ────────────────────────────────────────────────────────────
  property var modulesLeft:   ["mediaplayer"]
  property var modulesCenter: ["workspaces"]
  property var modulesRight:  ["quicksettings", "separator", "clock", "separator", "volume"]
  property var modulesTop:    ["mediaplayer"]
  property var modulesMiddle: ["workspaces"]
  property var modulesBottom: ["quicksettings", "separator", "clock", "separator", "volume"]

  // ── workspaces — genérico (compartilhado entre estilos dentro do tema) ─
  property string wsStyle:          "icons"
  property string wsIconsSort:      "position"
  property bool   wsIconMonochrome: true
  property int    wsIconSpacing:    4
  property bool   wsShowAddButton:  true
  property int    wsSpacing:        2

  // ── workspaces — visual ATIVO (do estilo atual dentro do tema atual) ───
  // Lidos via _wsGet() — nunca escritos diretamente pelo usuário
  readonly property real   wsBgOpacity:             _wsGet("bgOpacity",         0.0)
  readonly property real   wsBgPaddingH:            _wsGet("bgPaddingH",        8)
  readonly property real   wsBgPaddingV:            _wsGet("bgPaddingV",        2)
  readonly property string pkWsBgColor:             _wsGet("bgColor",           "surface_variant")
  readonly property string pkWsBgBorderColor:       _wsGet("bgBorderColor",     "on_surface")
  readonly property string pkWsDotColor:            _wsGet("dotColor",          "on_surface")
  readonly property string pkWsDotActiveColor:      _wsGet("dotActiveColor",    "on_surface")
  readonly property string pkWsDotOccupiedColor:    _wsGet("dotOccupiedColor",  "on_surface")
  readonly property string pkWsDotUrgentColor:      _wsGet("dotUrgentColor",    "error")
  readonly property string pkWsIconMonoColor:       _wsGet("iconMonoColor",     "on_surface")
  readonly property string pkWsIconMonoColorActive: _wsGet("iconMonoColorActive","primary")
  readonly property string pkWsBgColorActive:       _wsGet("bgColorActive",     "primary_container")
  readonly property real   wsBgOpacityActive:       _wsGet("bgOpacityActive",   0.85)
  readonly property string pkWsBgBorderColorActive: _wsGet("bgBorderColorActive","primary")
  readonly property real   wsBgBorderWidthActive:   _wsGet("bgBorderWidthActive",0)
  readonly property real   wsBgPaddingHActive:      _wsGet("bgPaddingHActive",  6)
  readonly property real   wsBgPaddingVActive:      _wsGet("bgPaddingVActive",  2)
  readonly property real   wsBgRadiusActive:        _wsGet("bgRadiusActive",    99)

  // Retorna o valor do estilo atual com override do usuário sobre default do tema
  function _wsGet(key, fallback) {
    var th    = root.theme
    var style = root.wsStyle
    // 1. override do usuário
    try {
      var uo = stateAdapter.overrides
      if (uo && uo[th] && uo[th].workspaces && uo[th].workspaces[style] &&
          uo[th].workspaces[style][key] !== undefined)
        return uo[th].workspaces[style][key]
    } catch(e) {}
    // 2. default do tema/estilo no Bar.json
    try {
      var th2 = barAdapter.themes
      if (th2 && th2[th] && th2[th].workspaces && th2[th].workspaces[style] &&
          th2[th].workspaces[style][key] !== undefined)
        return th2[th].workspaces[style][key]
    } catch(e) {}
    return fallback
  }

  // Força reavaliação de todos os _wsGet quando tema, estilo ou overrides mudam
  property var _wsDep: ({ t: root.theme, s: root.wsStyle })
  onThemeChanged:   { _wsDep = ({ t: root.theme, s: root.wsStyle }); _syncBarToAdapter() }
  onWsStyleChanged: _wsDep = ({ t: root.theme, s: root.wsStyle })

  // ── mediaPlayer genérico ───────────────────────────────────────────────
  property string mpTextMode:      "artistAndTitle"
  property int    mpScrollSpeed:   40
  property int    mpScrollPauseMs: 1800
  property int    mpScrollWidth:   140

  // ── mediaPlayer visual (por tema) ─────────────────────────────────────
  property bool   mpBgEnabled:         false
  property real   mpBgOpacity:         0.5
  property real   mpBgOpacityActive:   0.8
  property real   mpBgPaddingH:        8
  property real   mpBgPaddingV:        4
  property string pkMpBgColor:         "surface_variant"
  property string pkMpBgColorActive:   "primary_container"
  property string pkMpTextColor:       "on_surface"
  property string pkMpDimColor:        "on_surface_variant"
  property string pkMpTextColorActive: "on_primary_container"
  property string pkMpDimColorActive:  "on_surface_variant"

  // ── clock visual (por tema) ────────────────────────────────────────────
  property string pkClkTextColor:    "on_surface"
  property string pkClkDimColor:     "on_surface_variant"
  property string pkClkAccentColor:  "primary"
  property int    clkDismissDelayMs: 8000

  // ── palette global (por tema) ──────────────────────────────────────────
  property string pkBarBg:      "surface_container_lowest"
  property string pkBarBgPill:  "background"
  property string pkText:       "on_surface"
  property string pkTextDim:    "on_surface_variant"
  property string pkAccent:     "primary"
  property string pkAccentBg:   "primary_container"
  property string pkAccentText: "on_primary"
  property string pkPanelBg:    "surface_container"
  property string pkProgressBg: "outline_variant"
  property string pkProgressFg: "primary"
  property string pkDivider:    "outline_variant"

  // ── Cores resolvidas ───────────────────────────────────────────────────
  function resolve(key) {
    return Colors[key] !== undefined ? Colors[key] : "transparent"
  }

  readonly property color paletteBarBg:      resolve(pkBarBg)
  readonly property color paletteBarBgPill:  resolve(pkBarBgPill)
  readonly property color paletteText:       resolve(pkText)
  readonly property color paletteTextDim:    resolve(pkTextDim)
  readonly property color paletteAccent:     resolve(pkAccent)
  readonly property color paletteAccentBg:   resolve(pkAccentBg)
  readonly property color paletteAccentText: resolve(pkAccentText)
  readonly property color palettePanelBg:    resolve(pkPanelBg)
  readonly property color paletteProgressBg: resolve(pkProgressBg)
  readonly property color paletteProgressFg: resolve(pkProgressFg)
  readonly property color paletteDivider:    resolve(pkDivider)

  readonly property color paletteWsBgColor:              resolve(pkWsBgColor)
  readonly property color paletteWsBgBorderColor:        resolve(pkWsBgBorderColor)
  readonly property color paletteWsDotColor:             resolve(pkWsDotColor)
  readonly property color paletteWsDotActiveColor:       resolve(pkWsDotActiveColor)
  readonly property color paletteWsDotOccupiedColor:     resolve(pkWsDotOccupiedColor)
  readonly property color paletteWsDotUrgentColor:       resolve(pkWsDotUrgentColor)
  readonly property color paletteWsIconMonoColor:        resolve(pkWsIconMonoColor)
  readonly property color paletteWsIconMonoColorActive:  resolve(pkWsIconMonoColorActive)
  readonly property color paletteWsBgColorActive:        resolve(pkWsBgColorActive)
  readonly property color paletteWsBgBorderColorActive:  resolve(pkWsBgBorderColorActive)

  readonly property color paletteMpBgColor:         resolve(pkMpBgColor)
  readonly property color paletteMpBgColorActive:   resolve(pkMpBgColorActive)
  readonly property color paletteMpTextColor:       resolve(pkMpTextColor)
  readonly property color paletteMpDimColor:        resolve(pkMpDimColor)
  readonly property color paletteMpTextColorActive: resolve(pkMpTextColorActive)
  readonly property color paletteMpDimColorActive:  resolve(pkMpDimColorActive)

  readonly property color paletteClkTextColor:   resolve(pkClkTextColor)
  readonly property color paletteClkDimColor:    resolve(pkClkDimColor)
  readonly property color paletteClkAccentColor: resolve(pkClkAccentColor)

  // ── Guards ─────────────────────────────────────────────────────────────
  property bool _ready:       false
  property bool _parsing:     false
  property bool configLoaded: false
  property bool _stateLoaded: false

  // ══════════════════════════════════════════════════════════════════════
  // FILE 1 — Bar.json
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: barFile
    path:         Quickshell.shellDir + "/state/Bar.json"
    watchChanges: false

    JsonAdapter {
      id: barAdapter

      property var bar:         ({})
      property var modules:     ({})
      property var workspaces:  ({})
      property var mediaPlayer: ({})
      property var themes:      ({})

      onBarChanged: {
        var b = bar
        if (!b || (b.theme === undefined && b.autoHide === undefined)) return
        if (b.theme          !== undefined) root.theme          = b.theme
        if (b.autoHide       !== undefined) root.autoHide       = b.autoHide
        if (b.silence        !== undefined) root.silenceMode    = b.silence
        if (b.position       !== undefined) root.position       = b.position
        if (b.barSize        !== undefined) root.barSize        = b.barSize
        if (b.barMargin      !== undefined) root.barMargin      = b.barMargin
        if (b.pillWidth      !== undefined) root.pillWidth      = b.pillWidth
        if (b.pillMinSpacing !== undefined) root.pillMinSpacing = b.pillMinSpacing
        Qt.callLater(function() { applyTheme(root.theme) })
      }

      onModulesChanged: {
        var m = JSON.parse(JSON.stringify(modules))
        if (!m) return
        var hasAny = (m.left   && m.left.length   > 0) ||
                     (m.center && m.center.length  > 0) ||
                     (m.right  && m.right.length   > 0) ||
                     (m.top    && m.top.length     > 0) ||
                     (m.middle && m.middle.length  > 0) ||
                     (m.bottom && m.bottom.length  > 0)
        if (!hasAny) return
        if (m.left   && m.left.length   > 0) root.modulesLeft   = m.left
        if (m.center && m.center.length  > 0) root.modulesCenter = m.center
        if (m.right  && m.right.length   > 0) root.modulesRight  = m.right
        if (m.top    && m.top.length     > 0) root.modulesTop    = m.top
        if (m.middle && m.middle.length  > 0) root.modulesMiddle = m.middle
        if (m.bottom && m.bottom.length  > 0) root.modulesBottom = m.bottom
        root.configLoaded = true
        startupTimer.stop()
        Qt.callLater(function() { root.modulesUpdated() })
      }

      onWorkspacesChanged: {
        var w = workspaces; if (!w) return
        if (w.style          !== undefined) root.wsStyle          = w.style
        if (w.iconsSort      !== undefined) root.wsIconsSort      = w.iconsSort
        if (w.iconMonochrome !== undefined) root.wsIconMonochrome = w.iconMonochrome
        if (w.iconSpacing    !== undefined) root.wsIconSpacing    = w.iconSpacing
        if (w.showAddButton  !== undefined) root.wsShowAddButton  = w.showAddButton
        if (w.spacing        !== undefined) root.wsSpacing        = w.spacing
      }

      onMediaPlayerChanged: {
        var m = mediaPlayer; if (!m) return
        if (m.textMode      !== undefined) root.mpTextMode      = m.textMode
        if (m.scrollSpeed   !== undefined) root.mpScrollSpeed   = m.scrollSpeed
        if (m.scrollPauseMs !== undefined) root.mpScrollPauseMs = m.scrollPauseMs
        if (m.scrollWidth   !== undefined) root.mpScrollWidth   = m.scrollWidth
      }

      onThemesChanged: Qt.callLater(function() { applyTheme(root.theme) })
    }
  }

  // applyTheme — lê themes.<name> do Bar.json e preenche pk* do tema
  // Workspace visual NÃO é preenchido aqui — é lido dinamicamente via _wsGet()
  function applyTheme(name) {
    var t = barAdapter.themes
    if (!t || !t[name]) return
    var th = t[name]
    console.log("[BarConfig] applyTheme:", name)

    // workspaces.common (showAddButton, spacing — compartilhados entre estilos)
    var wc = th.workspaces ? th.workspaces.common : null
    if (wc) {
      if (wc.showAddButton !== undefined) root.wsShowAddButton = wc.showAddButton
      if (wc.spacing       !== undefined) root.wsSpacing       = wc.spacing
    }

    var m = th.mediaPlayer
    if (m) {
      if (m.bgEnabled       !== undefined) root.mpBgEnabled       = m.bgEnabled
      if (m.bgOpacity       !== undefined) root.mpBgOpacity       = m.bgOpacity
      if (m.bgOpacityActive !== undefined) root.mpBgOpacityActive = m.bgOpacityActive
      if (m.bgPaddingH      !== undefined) root.mpBgPaddingH      = m.bgPaddingH
      if (m.bgPaddingV      !== undefined) root.mpBgPaddingV      = m.bgPaddingV
      if (m.bgColor         !== undefined) root.pkMpBgColor         = m.bgColor
      if (m.bgColorActive   !== undefined) root.pkMpBgColorActive   = m.bgColorActive
      if (m.textColor       !== undefined) root.pkMpTextColor       = m.textColor
      if (m.dimColor        !== undefined) root.pkMpDimColor        = m.dimColor
      if (m.textColorActive !== undefined) root.pkMpTextColorActive = m.textColorActive
      if (m.dimColorActive  !== undefined) root.pkMpDimColorActive  = m.dimColorActive
    }
    var ck = th.clock
    if (ck) {
      if (ck.textColor      !== undefined) root.pkClkTextColor    = ck.textColor
      if (ck.dimColor       !== undefined) root.pkClkDimColor     = ck.dimColor
      if (ck.accentColor    !== undefined) root.pkClkAccentColor  = ck.accentColor
      if (ck.dismissDelayMs !== undefined) root.clkDismissDelayMs = ck.dismissDelayMs
    }
    var p = th.palette
    if (p) {
      if (p.barBg      !== undefined) root.pkBarBg      = p.barBg
      if (p.barBgPill  !== undefined) root.pkBarBgPill  = p.barBgPill
      if (p.text       !== undefined) root.pkText       = p.text
      if (p.textDim    !== undefined) root.pkTextDim    = p.textDim
      if (p.accent     !== undefined) root.pkAccent     = p.accent
      if (p.accentBg   !== undefined) root.pkAccentBg   = p.accentBg
      if (p.accentText !== undefined) root.pkAccentText = p.accentText
      if (p.panelBg    !== undefined) root.pkPanelBg    = p.panelBg
      if (p.progressBg !== undefined) root.pkProgressBg = p.progressBg
      if (p.progressFg !== undefined) root.pkProgressFg = p.progressFg
      if (p.divider    !== undefined) root.pkDivider    = p.divider
    }

    // Força reavaliação dos _wsGet (mudar tema muda qual bloco de workspace é lido)
    root._wsDep = ({ t: root.theme, s: root.wsStyle })

    // Aplica overrides do usuário por cima
    if (root._stateLoaded) _applyState(stateAdapter.overrides, name)
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILE 2 — BarState.json
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: stateFile
    path:         Quickshell.shellDir + "/state/BarState.json"
    watchChanges: false

    JsonAdapter {
      id: stateAdapter
      // overrides[tema][secao]  ou  overrides[tema].workspaces[style]
      property var overrides: ({})

      onOverridesChanged: {
        var o = overrides
        if (!o || Object.keys(o).length === 0) return
        root._stateLoaded = true
        _applyState(o, root.theme)
        // Força _wsGet a reler os overrides
        root._wsDep = ({ t: root.theme, s: root.wsStyle })
      }
    }
  }

  // _applyState — aplica overrides do BarState.json para o tema atual
  // Workspace visual não é aplicado aqui — _wsGet() lê direto do stateAdapter
  function _applyState(o, themeName) {
    if (!o || !o[themeName]) return
    var th = o[themeName]
    console.log("[BarConfig] _applyState tema:", themeName)

    var m = th.mediaPlayer
    if (m) {
      if (m.bgEnabled         !== undefined) root.mpBgEnabled         = m.bgEnabled
      if (m.pkMpBgColor       !== undefined) root.pkMpBgColor         = m.pkMpBgColor
      if (m.pkMpBgColorActive !== undefined) root.pkMpBgColorActive   = m.pkMpBgColorActive
      if (m.pkMpTextColor     !== undefined) root.pkMpTextColor       = m.pkMpTextColor
      if (m.pkMpDimColor      !== undefined) root.pkMpDimColor        = m.pkMpDimColor
      if (m.pkMpTextColorActive !== undefined) root.pkMpTextColorActive = m.pkMpTextColorActive
      if (m.pkMpDimColorActive  !== undefined) root.pkMpDimColorActive  = m.pkMpDimColorActive
    }
    var ck = th.clock
    if (ck) {
      if (ck.pkClkTextColor   !== undefined) root.pkClkTextColor    = ck.pkClkTextColor
      if (ck.pkClkDimColor    !== undefined) root.pkClkDimColor     = ck.pkClkDimColor
      if (ck.pkClkAccentColor !== undefined) root.pkClkAccentColor  = ck.pkClkAccentColor
      if (ck.clkDismissDelayMs !== undefined) root.clkDismissDelayMs = ck.clkDismissDelayMs
    }
    var p = th.palette
    if (p) {
      if (p.pkBarBg      !== undefined) root.pkBarBg      = p.pkBarBg
      if (p.pkBarBgPill  !== undefined) root.pkBarBgPill  = p.pkBarBgPill
      if (p.pkText       !== undefined) root.pkText       = p.pkText
      if (p.pkTextDim    !== undefined) root.pkTextDim    = p.pkTextDim
      if (p.pkAccent     !== undefined) root.pkAccent     = p.pkAccent
      if (p.pkAccentBg   !== undefined) root.pkAccentBg   = p.pkAccentBg
      if (p.pkPanelBg    !== undefined) root.pkPanelBg    = p.pkPanelBg
      if (p.pkProgressBg !== undefined) root.pkProgressBg = p.pkProgressBg
      if (p.pkProgressFg !== undefined) root.pkProgressFg = p.pkProgressFg
      if (p.pkDivider    !== undefined) root.pkDivider    = p.pkDivider
    }
  }

  // _saveWsStyleOverride — grava override de UMA chave do estilo atual no BarState.json
  // Só toca em overrides[tema].workspaces[style] — outros temas/estilos intocados
  function _saveWsStyleOverride(key, value) {
    var th    = root.theme
    var style = root.wsStyle
    var o = {}
    try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
    if (!o[th])                    o[th]                    = {}
    if (!o[th].workspaces)         o[th].workspaces         = {}
    if (!o[th].workspaces[style])  o[th].workspaces[style]  = {}
    o[th].workspaces[style][key] = value
    stateAdapter.overrides = o
    stateFile.writeAdapter()
    root._wsDep = ({ t: root.theme, s: root.wsStyle })
    console.log("[BarConfig] _saveWsStyleOverride tema=" + th + " style=" + style + " " + key + "=" + value)
  }

  // _saveThemeOverride — grava override de uma secão (mp/clk/palette) do tema atual
  function _saveThemeOverride(section, patch) {
    var th = root.theme
    var o = {}
    try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
    if (!o[th])           o[th]           = {}
    if (!o[th][section])  o[th][section]  = {}
    for (var k in patch) o[th][section][k] = patch[k]
    stateAdapter.overrides = o
    stateFile.writeAdapter()
    console.log("[BarConfig] _saveThemeOverride tema=" + th + " section=" + section)
  }

  // ── Sync Bar.json ──────────────────────────────────────────────────────
  signal modulesUpdated()

  function _syncBarToAdapter() {
    if (!root._ready || root._parsing) return
    root._parsing = true
    barAdapter.bar = {
      theme: root.theme, autoHide: root.autoHide, silence: root.silenceMode,
      position: root.position, barSize: root.barSize, barMargin: root.barMargin,
      pillWidth: root.pillWidth, pillMinSpacing: root.pillMinSpacing
    }
    barFile.writeAdapter()
    root._parsing = false
  }
  onAutoHideChanged:       _syncBarToAdapter()
  onSilenceModeChanged:    _syncBarToAdapter()
  onPositionChanged:       _syncBarToAdapter()
  onBarSizeChanged:        _syncBarToAdapter()
  onBarMarginChanged:      _syncBarToAdapter()
  onPillWidthChanged:      _syncBarToAdapter()
  onPillMinSpacingChanged: _syncBarToAdapter()

  function _syncModulesToAdapter() {
    if (!root._ready || root._parsing) return
    root._parsing = true
    barAdapter.modules = {
      left: root.modulesLeft, center: root.modulesCenter, right: root.modulesRight,
      top: root.modulesTop, middle: root.modulesMiddle, bottom: root.modulesBottom
    }
    barFile.writeAdapter()
    root._parsing = false
  }
  onModulesLeftChanged:   _syncModulesToAdapter()
  onModulesCenterChanged: _syncModulesToAdapter()
  onModulesRightChanged:  _syncModulesToAdapter()
  onModulesTopChanged:    _syncModulesToAdapter()
  onModulesMiddleChanged: _syncModulesToAdapter()
  onModulesBottomChanged: _syncModulesToAdapter()

  // ── saveAll() — API pública chamada pelo ConfigWindow ─────────────────
  function saveAll(opts) {
    console.log("[BarConfig] saveAll() chamado")
    root._parsing = true

    // bar.*
    if (opts.theme          !== undefined) root.theme          = opts.theme
    if (opts.autoHide       !== undefined) root.autoHide       = opts.autoHide
    if (opts.silence        !== undefined) root.silenceMode    = opts.silence
    if (opts.position       !== undefined) root.position       = opts.position
    if (opts.barSize        !== undefined) root.barSize        = opts.barSize
    if (opts.barMargin      !== undefined) root.barMargin      = opts.barMargin
    if (opts.pillWidth      !== undefined) root.pillWidth      = opts.pillWidth
    if (opts.pillMinSpacing !== undefined) root.pillMinSpacing = opts.pillMinSpacing

    // modules
    if (opts.modulesLeft   !== undefined) root.modulesLeft   = opts.modulesLeft.slice()
    if (opts.modulesCenter !== undefined) root.modulesCenter = opts.modulesCenter.slice()
    if (opts.modulesRight  !== undefined) root.modulesRight  = opts.modulesRight.slice()
    if (opts.modulesTop    !== undefined) root.modulesTop    = opts.modulesTop.slice()
    if (opts.modulesMiddle !== undefined) root.modulesMiddle = opts.modulesMiddle.slice()
    if (opts.modulesBottom !== undefined) root.modulesBottom = opts.modulesBottom.slice()

    // workspaces genérico
    if (opts.wsStyle          !== undefined) root.wsStyle          = opts.wsStyle
    if (opts.wsIconsSort      !== undefined) root.wsIconsSort      = opts.wsIconsSort
    if (opts.wsIconMonochrome !== undefined) root.wsIconMonochrome = opts.wsIconMonochrome
    if (opts.wsIconSpacing    !== undefined) root.wsIconSpacing    = opts.wsIconSpacing
    if (opts.wsShowAddButton  !== undefined) root.wsShowAddButton  = opts.wsShowAddButton

    // workspaces visual — grava isolado por tema/estilo no BarState.json
    var wsPatch = {}
    if (opts.wsBgOpacity           !== undefined) wsPatch.bgOpacity           = opts.wsBgOpacity
    if (opts.wsBgOpacityActive     !== undefined) wsPatch.bgOpacityActive     = opts.wsBgOpacityActive
    if (opts.wsBgBorderWidthActive !== undefined) wsPatch.bgBorderWidthActive = opts.wsBgBorderWidthActive
    if (opts.wsBgPaddingH          !== undefined) wsPatch.bgPaddingH          = opts.wsBgPaddingH
    if (opts.wsBgPaddingV          !== undefined) wsPatch.bgPaddingV          = opts.wsBgPaddingV
    if (opts.wsBgPaddingHActive    !== undefined) wsPatch.bgPaddingHActive    = opts.wsBgPaddingHActive
    if (opts.wsBgPaddingVActive    !== undefined) wsPatch.bgPaddingVActive    = opts.wsBgPaddingVActive
    if (opts.wsBgRadiusActive      !== undefined) wsPatch.bgRadiusActive      = opts.wsBgRadiusActive
    if (opts.pkWsBgColor             !== undefined) wsPatch.bgColor             = opts.pkWsBgColor
    if (opts.pkWsBgColorActive       !== undefined) wsPatch.bgColorActive       = opts.pkWsBgColorActive
    if (opts.pkWsBgBorderColor       !== undefined) wsPatch.bgBorderColor       = opts.pkWsBgBorderColor
    if (opts.pkWsBgBorderColorActive !== undefined) wsPatch.bgBorderColorActive = opts.pkWsBgBorderColorActive
    if (opts.pkWsDotColor            !== undefined) wsPatch.dotColor            = opts.pkWsDotColor
    if (opts.pkWsDotActiveColor      !== undefined) wsPatch.dotActiveColor      = opts.pkWsDotActiveColor
    if (opts.pkWsDotOccupiedColor    !== undefined) wsPatch.dotOccupiedColor    = opts.pkWsDotOccupiedColor
    if (opts.pkWsDotUrgentColor      !== undefined) wsPatch.dotUrgentColor      = opts.pkWsDotUrgentColor
    if (opts.pkWsIconMonoColor       !== undefined) wsPatch.iconMonoColor       = opts.pkWsIconMonoColor
    if (opts.pkWsIconMonoColorActive !== undefined) wsPatch.iconMonoColorActive = opts.pkWsIconMonoColorActive

    if (Object.keys(wsPatch).length > 0) {
      var th = root.theme; var style = root.wsStyle
      var o = {}
      try { o = JSON.parse(JSON.stringify(stateAdapter.overrides)) } catch(e) {}
      if (!o[th])                   o[th]                   = {}
      if (!o[th].workspaces)        o[th].workspaces        = {}
      if (!o[th].workspaces[style]) o[th].workspaces[style] = {}
      for (var k in wsPatch) o[th].workspaces[style][k] = wsPatch[k]
      stateAdapter.overrides = o
      root._wsDep = ({ t: root.theme, s: root.wsStyle })
    }

    // mediaPlayer cores → override por tema
    var mpPatch = {}
    if (opts.pkMpBgColor    !== undefined) { root.pkMpBgColor         = opts.pkMpBgColor;    mpPatch.pkMpBgColor         = opts.pkMpBgColor    }
    if (opts.pkMpBgActive   !== undefined) { root.pkMpBgColorActive   = opts.pkMpBgActive;   mpPatch.pkMpBgColorActive   = opts.pkMpBgActive   }
    if (opts.pkMpText       !== undefined) { root.pkMpTextColor       = opts.pkMpText;       mpPatch.pkMpTextColor       = opts.pkMpText       }
    if (opts.pkMpDim        !== undefined) { root.pkMpDimColor        = opts.pkMpDim;        mpPatch.pkMpDimColor        = opts.pkMpDim        }
    if (opts.pkMpTextActive !== undefined) { root.pkMpTextColorActive = opts.pkMpTextActive; mpPatch.pkMpTextColorActive = opts.pkMpTextActive }
    if (opts.pkMpDimActive  !== undefined) { root.pkMpDimColorActive  = opts.pkMpDimActive;  mpPatch.pkMpDimColorActive  = opts.pkMpDimActive  }
    if (opts.mpBgEnabled    !== undefined) { root.mpBgEnabled         = opts.mpBgEnabled;    mpPatch.bgEnabled           = opts.mpBgEnabled    }
    if (Object.keys(mpPatch).length > 0) _saveThemeOverride("mediaPlayer", mpPatch)

    // clock → override por tema
    var ckPatch = {}
    if (opts.pkClkText       !== undefined) { root.pkClkTextColor    = opts.pkClkText;       ckPatch.pkClkTextColor   = opts.pkClkText       }
    if (opts.pkClkDim        !== undefined) { root.pkClkDimColor     = opts.pkClkDim;        ckPatch.pkClkDimColor    = opts.pkClkDim        }
    if (opts.pkClkAccent     !== undefined) { root.pkClkAccentColor  = opts.pkClkAccent;     ckPatch.pkClkAccentColor = opts.pkClkAccent     }
    if (opts.localClkDismiss !== undefined) { root.clkDismissDelayMs = opts.localClkDismiss; ckPatch.clkDismissDelayMs = opts.localClkDismiss }
    if (Object.keys(ckPatch).length > 0) _saveThemeOverride("clock", ckPatch)

    // palette → override por tema
    var palPatch = {}
    if (opts.pkBarBg      !== undefined) { root.pkBarBg      = opts.pkBarBg;      palPatch.pkBarBg      = opts.pkBarBg      }
    if (opts.pkBarBgPill  !== undefined) { root.pkBarBgPill  = opts.pkBarBgPill;  palPatch.pkBarBgPill  = opts.pkBarBgPill  }
    if (opts.pkText       !== undefined) { root.pkText       = opts.pkText;       palPatch.pkText       = opts.pkText       }
    if (opts.pkTextDim    !== undefined) { root.pkTextDim    = opts.pkTextDim;    palPatch.pkTextDim    = opts.pkTextDim    }
    if (opts.pkAccent     !== undefined) { root.pkAccent     = opts.pkAccent;     palPatch.pkAccent     = opts.pkAccent     }
    if (opts.pkAccentBg   !== undefined) { root.pkAccentBg   = opts.pkAccentBg;   palPatch.pkAccentBg   = opts.pkAccentBg   }
    if (opts.pkPanelBg    !== undefined) { root.pkPanelBg    = opts.pkPanelBg;    palPatch.pkPanelBg    = opts.pkPanelBg    }
    if (opts.pkProgressBg !== undefined) { root.pkProgressBg = opts.pkProgressBg; palPatch.pkProgressBg = opts.pkProgressBg }
    if (opts.pkProgressFg !== undefined) { root.pkProgressFg = opts.pkProgressFg; palPatch.pkProgressFg = opts.pkProgressFg }
    if (opts.pkDivider    !== undefined) { root.pkDivider    = opts.pkDivider;    palPatch.pkDivider    = opts.pkDivider    }
    if (Object.keys(palPatch).length > 0) _saveThemeOverride("palette", palPatch)

    // Grava Bar.json (estrutura — sem cores)
    barAdapter.bar = {
      theme: root.theme, autoHide: root.autoHide, silence: root.silenceMode,
      position: root.position, barSize: root.barSize, barMargin: root.barMargin,
      pillWidth: root.pillWidth, pillMinSpacing: root.pillMinSpacing
    }
    barAdapter.modules = {
      left: root.modulesLeft, center: root.modulesCenter, right: root.modulesRight,
      top: root.modulesTop, middle: root.modulesMiddle, bottom: root.modulesBottom
    }
    barAdapter.workspaces = {
      style: root.wsStyle, iconsSort: root.wsIconsSort,
      iconMonochrome: root.wsIconMonochrome, iconSpacing: root.wsIconSpacing,
      showAddButton: root.wsShowAddButton, spacing: root.wsSpacing
    }
    barAdapter.mediaPlayer = {
      textMode: root.mpTextMode, scrollSpeed: root.mpScrollSpeed,
      scrollWidth: root.mpScrollWidth
    }
    barFile.writeAdapter()

    // Grava BarState.json se teve patches
    if (Object.keys(wsPatch).length > 0 ||
        Object.keys(mpPatch).length  > 0 ||
        Object.keys(ckPatch).length  > 0 ||
        Object.keys(palPatch).length > 0) {
      stateFile.writeAdapter()
    }

    root._parsing = false
    root._stateLoaded = true
    root.modulesUpdated()
    console.log("[BarConfig] saveAll concluído")
  }

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
      var m = JSON.parse(JSON.stringify(barAdapter.modules))
      var hasAny = (m.left   && m.left.length   > 0) ||
                   (m.center && m.center.length  > 0) ||
                   (m.right  && m.right.length   > 0) ||
                   (m.top    && m.top.length     > 0) ||
                   (m.middle && m.middle.length  > 0) ||
                   (m.bottom && m.bottom.length  > 0)
      if (hasAny) {
        if (m.left   && m.left.length   > 0) root.modulesLeft   = m.left
        if (m.center && m.center.length  > 0) root.modulesCenter = m.center
        if (m.right  && m.right.length   > 0) root.modulesRight  = m.right
        if (m.top    && m.top.length     > 0) root.modulesTop    = m.top
        if (m.middle && m.middle.length  > 0) root.modulesMiddle = m.middle
        if (m.bottom && m.bottom.length  > 0) root.modulesBottom = m.bottom
        root.configLoaded = true
        Qt.callLater(function() { root.modulesUpdated() })
      }
    }
  }

  Component.onCompleted: mkdirProc.running = true
}
