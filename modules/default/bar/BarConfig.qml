import QtQuick
import Quickshell
import Quickshell.Io
import qs

// BarConfig — fonte única de verdade para todas as configurações do bar.
//
// Dois arquivos JSON separados:
//   Bar.json     → estrutura: bar.*, modules.*, workspaces.*, mediaPlayer.*
//                  (inclui themes.* do Bar.json original para compatibilidade)
//   BarState.json → overrides visuais do usuário: mp.*, clk.*, pal.*, ws.*
//                   Criado automaticamente na primeira customização.
//                   Lido DEPOIS do Bar.json e sobrescreve applyTheme().
//
// Fluxo de leitura no boot:
//   1. Bar.json carrega → applyTheme() preenche pk* com defaults do tema
//   2. BarState.json carrega → _applyState() sobrescreve com customizações
//
// Fluxo de escrita (saveAll):
//   1. Atualiza propriedades root.pk* diretamente
//   2. Grava Bar.json (bar/modules/workspaces/mediaPlayer — sem themes)
//   3. Grava BarState.json com todos os overrides visuais atuais

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

  // ── workspaces genérico ────────────────────────────────────────────────
  property string wsStyle:          "icons"
  property string wsIconsSort:      "position"
  property bool   wsIconMonochrome: true
  property int    wsIconSpacing:    4
  property bool   wsShowAddButton:  true

  // ── workspaces visual ──────────────────────────────────────────────────
  property real   wsBgOpacity:             0.0
  property real   wsBgPaddingH:            8
  property real   wsBgPaddingV:            2
  property string pkWsBgColor:             "surface_variant"
  property string pkWsBgBorderColor:       "on_surface"
  property string pkWsDotColor:            "on_surface"
  property string pkWsDotActiveColor:      "on_surface"
  property string pkWsDotOccupiedColor:    "on_surface"
  property string pkWsDotUrgentColor:      "error"
  property string pkWsIconMonoColor:       "on_surface"
  property string pkWsIconMonoColorActive: "primary"
  property string pkWsBgColorActive:       "primary_container"
  property real   wsBgOpacityActive:       0.85
  property string pkWsBgBorderColorActive: "primary"
  property real   wsBgBorderWidthActive:   0
  property real   wsBgPaddingHActive:      6
  property real   wsBgPaddingVActive:      2
  property real   wsBgRadiusActive:        99

  // ── mediaPlayer genérico ───────────────────────────────────────────────
  property string mpTextMode:      "artistAndTitle"
  property int    mpScrollSpeed:   40
  property int    mpScrollPauseMs: 1800
  property int    mpScrollWidth:   140

  // ── mediaPlayer visual ─────────────────────────────────────────────────
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

  // ── clock visual ───────────────────────────────────────────────────────
  property string pkClkTextColor:    "on_surface"
  property string pkClkDimColor:     "on_surface_variant"
  property string pkClkAccentColor:  "primary"
  property int    clkDismissDelayMs: 8000

  // ── palette global ─────────────────────────────────────────────────────
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
  property bool _ready:        false
  property bool _parsing:      false
  property bool configLoaded:  false
  property bool _stateLoaded:  false

  // ═══════════════════════════════════════════════════════════════════════
  // FILE 1 — Bar.json  (estrutura: bar, modules, workspaces, mediaPlayer, themes)
  // ═══════════════════════════════════════════════════════════════════════
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
        console.log("[BarConfig] barAdapter.onBarChanged:", JSON.stringify(b))
        if (b.theme          !== undefined) root.theme          = b.theme
        if (b.autoHide       !== undefined) root.autoHide       = b.autoHide
        if (b.silence        !== undefined) root.silenceMode    = b.silence
        if (b.position       !== undefined) root.position       = b.position
        if (b.barSize        !== undefined) root.barSize        = b.barSize
        if (b.barMargin      !== undefined) root.barMargin      = b.barMargin
        if (b.pillWidth      !== undefined) root.pillWidth      = b.pillWidth
        if (b.pillMinSpacing !== undefined) root.pillMinSpacing = b.pillMinSpacing
        // Aplica o tema após ler bar — themes pode já estar carregado
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
        console.log("[BarConfig] barAdapter.onModulesChanged:", JSON.stringify(m))
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

  // applyTheme — lê themes.<name> do Bar.json e preenche pk*
  // Chamado no boot; depois disso BarState.json sobrescreve com overrides do user.
  function applyTheme(name) {
    var t = barAdapter.themes
    if (!t || !t[name]) return
    var th = t[name]
    console.log("[BarConfig] applyTheme:", name)

    var w = th.workspaces
    if (w) {
      if (w.bgOpacity          !== undefined) root.wsBgOpacity          = w.bgOpacity
      if (w.bgPaddingH         !== undefined) root.wsBgPaddingH         = w.bgPaddingH
      if (w.bgPaddingV         !== undefined) root.wsBgPaddingV         = w.bgPaddingV
      if (w.bgColor            !== undefined) root.pkWsBgColor          = w.bgColor
      if (w.bgBorderColor      !== undefined) root.pkWsBgBorderColor    = w.bgBorderColor
      if (w.dotColor           !== undefined) root.pkWsDotColor         = w.dotColor
      if (w.dotActiveColor     !== undefined) root.pkWsDotActiveColor   = w.dotActiveColor
      if (w.dotOccupiedColor   !== undefined) root.pkWsDotOccupiedColor = w.dotOccupiedColor
      if (w.dotUrgentColor     !== undefined) root.pkWsDotUrgentColor   = w.dotUrgentColor
      if (w.iconMonoColor      !== undefined) root.pkWsIconMonoColor    = w.iconMonoColor
      if (w.iconMonoColorActive !== undefined) root.pkWsIconMonoColorActive = w.iconMonoColorActive
      if (w.bgColorActive      !== undefined) root.pkWsBgColorActive    = w.bgColorActive
      if (w.bgOpacityActive    !== undefined) root.wsBgOpacityActive    = w.bgOpacityActive
      if (w.bgBorderColorActive !== undefined) root.pkWsBgBorderColorActive = w.bgBorderColorActive
      if (w.bgBorderWidthActive !== undefined) root.wsBgBorderWidthActive   = w.bgBorderWidthActive
      if (w.bgPaddingHActive   !== undefined) root.wsBgPaddingHActive   = w.bgPaddingHActive
      if (w.bgPaddingVActive   !== undefined) root.wsBgPaddingVActive   = w.bgPaddingVActive
      if (w.bgRadiusActive     !== undefined) root.wsBgRadiusActive     = w.bgRadiusActive
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

    // Após aplicar o tema, aplica overrides do usuário (BarState.json) se já carregado
    if (root._stateLoaded) _applyState(stateAdapter.overrides)
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILE 2 — BarState.json  (overrides visuais do usuário)
  // ═══════════════════════════════════════════════════════════════════════
  FileView {
    id: stateFile
    path:         Quickshell.shellDir + "/state/BarState.json"
    watchChanges: false

    JsonAdapter {
      id: stateAdapter

      // Um único objeto "overrides" — simples, sem aninhamento de tema
      property var overrides: ({})

      onOverridesChanged: {
        var o = overrides
        if (!o || Object.keys(o).length === 0) return
        console.log("[BarConfig] stateAdapter.onOverridesChanged:", JSON.stringify(o))
        root._stateLoaded = true
        _applyState(o)
      }
    }
  }

  // _applyState — aplica os overrides do BarState.json nas propriedades pk*
  // Chamado após applyTheme() e também no boot quando BarState carrega
  function _applyState(o) {
    if (!o) return
    console.log("[BarConfig] _applyState:", JSON.stringify(o))
    // mediaPlayer
    if (o.mpBgEnabled         !== undefined) root.mpBgEnabled         = o.mpBgEnabled
    if (o.pkMpBgColor         !== undefined) root.pkMpBgColor         = o.pkMpBgColor
    if (o.pkMpBgColorActive   !== undefined) root.pkMpBgColorActive   = o.pkMpBgColorActive
    if (o.pkMpTextColor       !== undefined) root.pkMpTextColor       = o.pkMpTextColor
    if (o.pkMpDimColor        !== undefined) root.pkMpDimColor        = o.pkMpDimColor
    if (o.pkMpTextColorActive !== undefined) root.pkMpTextColorActive = o.pkMpTextColorActive
    if (o.pkMpDimColorActive  !== undefined) root.pkMpDimColorActive  = o.pkMpDimColorActive
    // clock
    if (o.pkClkTextColor    !== undefined) root.pkClkTextColor    = o.pkClkTextColor
    if (o.pkClkDimColor     !== undefined) root.pkClkDimColor     = o.pkClkDimColor
    if (o.pkClkAccentColor  !== undefined) root.pkClkAccentColor  = o.pkClkAccentColor
    if (o.clkDismissDelayMs !== undefined) root.clkDismissDelayMs = o.clkDismissDelayMs
    // palette
    if (o.pkBarBg      !== undefined) root.pkBarBg      = o.pkBarBg
    if (o.pkBarBgPill  !== undefined) root.pkBarBgPill  = o.pkBarBgPill
    if (o.pkText       !== undefined) root.pkText       = o.pkText
    if (o.pkTextDim    !== undefined) root.pkTextDim    = o.pkTextDim
    if (o.pkAccent     !== undefined) root.pkAccent     = o.pkAccent
    if (o.pkAccentBg   !== undefined) root.pkAccentBg   = o.pkAccentBg
    if (o.pkAccentText !== undefined) root.pkAccentText = o.pkAccentText
    if (o.pkPanelBg    !== undefined) root.pkPanelBg    = o.pkPanelBg
    if (o.pkProgressBg !== undefined) root.pkProgressBg = o.pkProgressBg
    if (o.pkProgressFg !== undefined) root.pkProgressFg = o.pkProgressFg
    if (o.pkDivider    !== undefined) root.pkDivider    = o.pkDivider
  }

  // _saveState — persiste todos os overrides visuais atuais em BarState.json
  function _saveState() {
    stateAdapter.overrides = {
      // mediaPlayer visual
      mpBgEnabled:         root.mpBgEnabled,
      pkMpBgColor:         root.pkMpBgColor,
      pkMpBgColorActive:   root.pkMpBgColorActive,
      pkMpTextColor:       root.pkMpTextColor,
      pkMpDimColor:        root.pkMpDimColor,
      pkMpTextColorActive: root.pkMpTextColorActive,
      pkMpDimColorActive:  root.pkMpDimColorActive,
      // clock visual
      pkClkTextColor:    root.pkClkTextColor,
      pkClkDimColor:     root.pkClkDimColor,
      pkClkAccentColor:  root.pkClkAccentColor,
      clkDismissDelayMs: root.clkDismissDelayMs,
      // palette
      pkBarBg:      root.pkBarBg,
      pkBarBgPill:  root.pkBarBgPill,
      pkText:       root.pkText,
      pkTextDim:    root.pkTextDim,
      pkAccent:     root.pkAccent,
      pkAccentBg:   root.pkAccentBg,
      pkAccentText: root.pkAccentText,
      pkPanelBg:    root.pkPanelBg,
      pkProgressBg: root.pkProgressBg,
      pkProgressFg: root.pkProgressFg,
      pkDivider:    root.pkDivider,
    }
    stateFile.writeAdapter()
    console.log("[BarConfig] _saveState → BarState.json gravado")
  }

  // ── Sync Bar.json — somente estrutura (bar/modules/workspaces/mediaPlayer)
  function _syncBarToAdapter() {
    if (!root._ready) return
    if (root._parsing) return
    root._parsing = true
    barAdapter.bar = {
      theme:          root.theme,
      autoHide:       root.autoHide,
      silence:        root.silenceMode,
      position:       root.position,
      barSize:        root.barSize,
      barMargin:      root.barMargin,
      pillWidth:      root.pillWidth,
      pillMinSpacing: root.pillMinSpacing
    }
    barFile.writeAdapter()
    root._parsing = false
  }
  onThemeChanged:          _syncBarToAdapter()
  onAutoHideChanged:       _syncBarToAdapter()
  onSilenceModeChanged:    _syncBarToAdapter()
  onPositionChanged:       _syncBarToAdapter()
  onBarSizeChanged:        _syncBarToAdapter()
  onBarMarginChanged:      _syncBarToAdapter()
  onPillWidthChanged:      _syncBarToAdapter()
  onPillMinSpacingChanged: _syncBarToAdapter()

  function _syncModulesToAdapter() {
    if (!root._ready) return
    if (root._parsing) return
    root._parsing = true
    barAdapter.modules = {
      left:   root.modulesLeft,
      center: root.modulesCenter,
      right:  root.modulesRight,
      top:    root.modulesTop,
      middle: root.modulesMiddle,
      bottom: root.modulesBottom
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

  // ── saveAll() — API pública ────────────────────────────────────────────
  signal modulesUpdated()

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

    // mediaPlayer genérico
    if (opts.mpTextMode    !== undefined) root.mpTextMode    = opts.mpTextMode
    if (opts.mpScrollSpeed !== undefined) root.mpScrollSpeed = opts.mpScrollSpeed
    if (opts.mpScrollWidth !== undefined) root.mpScrollWidth = opts.mpScrollWidth
    if (opts.mpBgEnabled   !== undefined) root.mpBgEnabled   = opts.mpBgEnabled

    // mediaPlayer cores (nomes do ConfigWindow/BarTabMidia)
    if (opts.pkMpBgColor    !== undefined) root.pkMpBgColor         = opts.pkMpBgColor
    if (opts.pkMpBgActive   !== undefined) root.pkMpBgColorActive   = opts.pkMpBgActive
    if (opts.pkMpText       !== undefined) root.pkMpTextColor       = opts.pkMpText
    if (opts.pkMpDim        !== undefined) root.pkMpDimColor        = opts.pkMpDim
    if (opts.pkMpTextActive !== undefined) root.pkMpTextColorActive = opts.pkMpTextActive
    if (opts.pkMpDimActive  !== undefined) root.pkMpDimColorActive  = opts.pkMpDimActive

    // clock cores
    if (opts.pkClkText      !== undefined) root.pkClkTextColor    = opts.pkClkText
    if (opts.pkClkDim       !== undefined) root.pkClkDimColor     = opts.pkClkDim
    if (opts.pkClkAccent    !== undefined) root.pkClkAccentColor  = opts.pkClkAccent
    if (opts.localClkDismiss !== undefined) root.clkDismissDelayMs = opts.localClkDismiss

    // palette global
    if (opts.pkBarBg      !== undefined) root.pkBarBg      = opts.pkBarBg
    if (opts.pkBarBgPill  !== undefined) root.pkBarBgPill  = opts.pkBarBgPill
    if (opts.pkText       !== undefined) root.pkText       = opts.pkText
    if (opts.pkTextDim    !== undefined) root.pkTextDim    = opts.pkTextDim
    if (opts.pkAccent     !== undefined) root.pkAccent     = opts.pkAccent
    if (opts.pkAccentBg   !== undefined) root.pkAccentBg   = opts.pkAccentBg
    if (opts.pkPanelBg    !== undefined) root.pkPanelBg    = opts.pkPanelBg
    if (opts.pkProgressBg !== undefined) root.pkProgressBg = opts.pkProgressBg
    if (opts.pkProgressFg !== undefined) root.pkProgressFg = opts.pkProgressFg
    if (opts.pkDivider    !== undefined) root.pkDivider    = opts.pkDivider

    // Grava Bar.json (estrutura) — sem colors, sem themes
    barAdapter.bar = {
      theme:          root.theme,
      autoHide:       root.autoHide,
      silence:        root.silenceMode,
      position:       root.position,
      barSize:        root.barSize,
      barMargin:      root.barMargin,
      pillWidth:      root.pillWidth,
      pillMinSpacing: root.pillMinSpacing
    }
    barAdapter.modules = {
      left:   root.modulesLeft,
      center: root.modulesCenter,
      right:  root.modulesRight,
      top:    root.modulesTop,
      middle: root.modulesMiddle,
      bottom: root.modulesBottom
    }
    barAdapter.workspaces = {
      style:          root.wsStyle,
      iconsSort:      root.wsIconsSort,
      iconMonochrome: root.wsIconMonochrome,
      iconSpacing:    root.wsIconSpacing,
      showAddButton:  root.wsShowAddButton
    }
    barAdapter.mediaPlayer = {
      textMode:    root.mpTextMode,
      scrollSpeed: root.mpScrollSpeed,
      scrollWidth: root.mpScrollWidth
    }
    barFile.writeAdapter()
    console.log("[BarConfig] saveAll → Bar.json gravado")

    // Grava BarState.json (overrides visuais) — separado, não conflita com Bar.json
    _saveState()

    root._parsing = false
    root._stateLoaded = true
    root.modulesUpdated()
    console.log("[BarConfig] saveAll concluído")
  }

  // ── Startup ────────────────────────────────────────────────────────────
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      console.log("[BarConfig] mkdirProc exited → _ready=true")
      root._ready = true
      startupTimer.start()
    }
  }

  Timer {
    id: startupTimer
    interval: 600
    repeat:   false
    onTriggered: {
      if (root._parsing) root._parsing = false
      if (root.configLoaded) return
      var raw = JSON.stringify(barAdapter.modules)
      var m   = JSON.parse(raw)
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
        return
      }
      console.log("[BarConfig] AVISO: adapter.modules vazio após 600ms — gravando defaults")
      root._parsing = true
      barAdapter.bar = {
        theme:          root.theme,
        autoHide:       root.autoHide,
        silence:        root.silenceMode,
        position:       root.position,
        barSize:        root.barSize,
        barMargin:      root.barMargin,
        pillWidth:      root.pillWidth,
        pillMinSpacing: root.pillMinSpacing
      }
      barAdapter.modules = {
        left:   root.modulesLeft,
        center: root.modulesCenter,
        right:  root.modulesRight,
        top:    root.modulesTop,
        middle: root.modulesMiddle,
        bottom: root.modulesBottom
      }
      barFile.writeAdapter()
      root._parsing = false
      root.configLoaded = true
    }
  }

  Component.onCompleted: mkdirProc.running = true
}
