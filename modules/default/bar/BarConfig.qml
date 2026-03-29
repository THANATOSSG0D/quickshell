import QtQuick
import Quickshell
import Quickshell.Io
import qs

// BarConfig — fonte única de verdade para todas as configurações do bar.
//
// Estrutura do Bar.json:
//   bar.*          → tema ativo, autoHide, position          (genérico)
//   workspaces.*   → style, iconsSort, iconMonochrome, …     (genérico)
//   mediaPlayer.*  → textMode, scrollSpeed, …               (genérico)
//   themes.<Nome>  → configs visuais específicas do tema     (tema-específico)
//     .workspaces  → bgOpacity, bgColorActive, bgPaddingH, cores dos dots…
//     .mediaPlayer → bgEnabled, bgColor, textColor, …
//     .palette     → mapeamento nome→chave Colors
//
// Ao trocar de tema (bar.theme), o bloco themes.<NovoTema> é relido
// e sobrescreve os valores visuais.

Item {
  id: root
  visible: false

  // ── bar.* ──────────────────────────────────────────────────────────────
  property string theme:    "Pill"
  property bool   autoHide: true
  property int    position: -2

  // ── workspaces.* — genérico ────────────────────────────────────────────
  property string wsStyle:          "icons"
  property string wsIconsSort:      "position"
  property bool   wsIconMonochrome: true
  property int    wsIconSpacing:    4
  property bool   wsShowAddButton:  true

  // ── workspaces — visual (tema-específico) ──────────────────────────────
  // Fundo global (container)
  property real   wsBgOpacity:  0.0
  property real   wsBgPaddingH: 8
  property real   wsBgPaddingV: 2
  property string pkWsBgColor:           "surface_variant"
  property string pkWsBgBorderColor:     "on_surface"
  property string pkWsDotColor:          "on_surface"
  property string pkWsDotActiveColor:    "on_surface"
  property string pkWsDotOccupiedColor:  "on_surface"
  property string pkWsDotUrgentColor:    "error"
  property string pkWsIconMonoColor:     "on_surface"
  property string pkWsIconMonoColorActive: "primary"

  // Fundo individual da workspace ativa
  property string pkWsBgColorActive:       "primary_container"
  property real   wsBgOpacityActive:       0.85
  property string pkWsBgBorderColorActive: "primary"
  property real   wsBgBorderWidthActive:   0
  property real   wsBgPaddingHActive:      6
  property real   wsBgPaddingVActive:      2
  property real   wsBgRadiusActive:        99   // 99=pill, 4=rounded, 0=square

  // ── mediaPlayer.* — genérico ───────────────────────────────────────────
  property string mpTextMode:      "artistAndTitle"
  property int    mpScrollSpeed:   40
  property int    mpScrollPauseMs: 1800
  property int    mpScrollWidth:   140

  // ── mediaPlayer — visual (tema-específico) ─────────────────────────────
  property bool   mpBgEnabled:       false
  property real   mpBgOpacity:       0.5
  property real   mpBgOpacityActive: 0.8
  property real   mpBgPaddingH:      8
  property real   mpBgPaddingV:      4
  property string pkMpBgColor:           "surface_variant"
  property string pkMpBgColorActive:     "primary_container"
  property string pkMpTextColor:         "on_surface"
  property string pkMpDimColor:          "on_surface_variant"
  property string pkMpTextColorActive:   "on_primary_container"
  property string pkMpDimColorActive:    "on_surface_variant"

  // ── clock — visual (tema-específico) ──────────────────────────────────
  property string pkClkTextColor:   "on_surface"
  property string pkClkDimColor:    "on_surface_variant"
  property string pkClkAccentColor: "primary"
  property int    clkDismissDelayMs: 8000

  // ── palette — chaves (tema-específico) ─────────────────────────────────
  property string pkBarBg:          "surface_container_lowest"
  property string pkBarBgPill:      "background"
  property string pkText:           "on_surface"
  property string pkTextDim:        "on_surface_variant"
  property string pkAccent:         "primary"
  property string pkAccentBg:       "primary_container"
  property string pkAccentText:     "on_primary"
  property string pkPanelBg:        "surface_container"
  property string pkProgressBg:     "outline_variant"
  property string pkProgressFg:     "primary"
  property string pkDivider:        "outline_variant"

  // ── Cores resolvidas via Colors singleton ──────────────────────────────
  function resolve(key) {
    return Colors[key] !== undefined ? Colors[key] : "transparent"
  }

  // palette global
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

  // workspaces visuais — global
  readonly property color paletteWsBgColor:           resolve(pkWsBgColor)
  readonly property color paletteWsBgBorderColor:     resolve(pkWsBgBorderColor)
  readonly property color paletteWsDotColor:          resolve(pkWsDotColor)
  readonly property color paletteWsDotActiveColor:    resolve(pkWsDotActiveColor)
  readonly property color paletteWsDotOccupiedColor:  resolve(pkWsDotOccupiedColor)
  readonly property color paletteWsDotUrgentColor:    resolve(pkWsDotUrgentColor)
  readonly property color paletteWsIconMonoColor:     resolve(pkWsIconMonoColor)
  readonly property color paletteWsIconMonoColorActive: resolve(pkWsIconMonoColorActive)

  // workspaces visuais — ativa
  readonly property color paletteWsBgColorActive:       resolve(pkWsBgColorActive)
  readonly property color paletteWsBgBorderColorActive: resolve(pkWsBgBorderColorActive)

  // mediaPlayer visuais
  readonly property color paletteMpBgColor:           resolve(pkMpBgColor)
  readonly property color paletteMpBgColorActive:     resolve(pkMpBgColorActive)
  readonly property color paletteMpTextColor:         resolve(pkMpTextColor)
  readonly property color paletteMpDimColor:          resolve(pkMpDimColor)
  readonly property color paletteMpTextColorActive:   resolve(pkMpTextColorActive)
  readonly property color paletteMpDimColorActive:    resolve(pkMpDimColorActive)

  // clock visuais
  readonly property color paletteClkTextColor:   resolve(pkClkTextColor)
  readonly property color paletteClkDimColor:    resolve(pkClkDimColor)
  readonly property color paletteClkAccentColor: resolve(pkClkAccentColor)

  // ── I/O ────────────────────────────────────────────────────────────────
  FileView {
    id: file
    path:             Quickshell.shellDir + "/state/Bar.json"
    watchChanges:     true
    onFileChanged:    reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter

      property var bar:         ({})
      property var workspaces:  ({})
      property var mediaPlayer: ({})
      property var themes:      ({})

      onBarChanged: {
        var b = bar
        if (!b) return
        if (b.theme    !== undefined) { root.theme    = b.theme;    applyTheme(b.theme) }
        if (b.autoHide !== undefined)   root.autoHide = b.autoHide
        if (b.position !== undefined)   root.position = b.position
      }

      onWorkspacesChanged: {
        var w = workspaces
        if (!w) return
        if (w.style          !== undefined) root.wsStyle          = w.style
        if (w.iconsSort      !== undefined) root.wsIconsSort      = w.iconsSort
        if (w.iconMonochrome !== undefined) root.wsIconMonochrome = w.iconMonochrome
        if (w.iconSpacing    !== undefined) root.wsIconSpacing    = w.iconSpacing
        if (w.showAddButton  !== undefined) root.wsShowAddButton  = w.showAddButton
      }

      onMediaPlayerChanged: {
        var m = mediaPlayer
        if (!m) return
        if (m.textMode      !== undefined) root.mpTextMode      = m.textMode
        if (m.scrollSpeed   !== undefined) root.mpScrollSpeed   = m.scrollSpeed
        if (m.scrollPauseMs !== undefined) root.mpScrollPauseMs = m.scrollPauseMs
        if (m.scrollWidth   !== undefined) root.mpScrollWidth   = m.scrollWidth
      }

      onThemesChanged: applyTheme(root.theme)

      function applyTheme(name) {
        var t = themes
        if (!t || !t[name]) return
        var th = t[name]

        // workspaces visual
        var w = th.workspaces
        if (w) {
          if (w.bgOpacity   !== undefined) root.wsBgOpacity   = w.bgOpacity
          if (w.bgPaddingH  !== undefined) root.wsBgPaddingH  = w.bgPaddingH
          if (w.bgPaddingV  !== undefined) root.wsBgPaddingV  = w.bgPaddingV
          if (w.bgColor             !== undefined) root.pkWsBgColor             = w.bgColor
          if (w.bgBorderColor       !== undefined) root.pkWsBgBorderColor       = w.bgBorderColor
          if (w.dotColor            !== undefined) root.pkWsDotColor            = w.dotColor
          if (w.dotActiveColor      !== undefined) root.pkWsDotActiveColor      = w.dotActiveColor
          if (w.dotOccupiedColor    !== undefined) root.pkWsDotOccupiedColor    = w.dotOccupiedColor
          if (w.dotUrgentColor      !== undefined) root.pkWsDotUrgentColor      = w.dotUrgentColor
          if (w.iconMonoColor       !== undefined) root.pkWsIconMonoColor       = w.iconMonoColor
          if (w.iconMonoColorActive !== undefined) root.pkWsIconMonoColorActive = w.iconMonoColorActive
          // workspace ativa
          if (w.bgColorActive       !== undefined) root.pkWsBgColorActive       = w.bgColorActive
          if (w.bgOpacityActive     !== undefined) root.wsBgOpacityActive       = w.bgOpacityActive
          if (w.bgBorderColorActive !== undefined) root.pkWsBgBorderColorActive = w.bgBorderColorActive
          if (w.bgBorderWidthActive !== undefined) root.wsBgBorderWidthActive   = w.bgBorderWidthActive
          if (w.bgPaddingHActive    !== undefined) root.wsBgPaddingHActive      = w.bgPaddingHActive
          if (w.bgPaddingVActive    !== undefined) root.wsBgPaddingVActive      = w.bgPaddingVActive
          if (w.bgRadiusActive      !== undefined) root.wsBgRadiusActive        = w.bgRadiusActive
        }

        // mediaPlayer visual
        var m = th.mediaPlayer
        if (m) {
          if (m.bgEnabled       !== undefined) root.mpBgEnabled       = m.bgEnabled
          if (m.bgOpacity       !== undefined) root.mpBgOpacity       = m.bgOpacity
          if (m.bgOpacityActive !== undefined) root.mpBgOpacityActive = m.bgOpacityActive
          if (m.bgPaddingH      !== undefined) root.mpBgPaddingH      = m.bgPaddingH
          if (m.bgPaddingV      !== undefined) root.mpBgPaddingV      = m.bgPaddingV
          if (m.bgColor           !== undefined) root.pkMpBgColor          = m.bgColor
          if (m.bgColorActive     !== undefined) root.pkMpBgColorActive    = m.bgColorActive
          if (m.textColor         !== undefined) root.pkMpTextColor        = m.textColor
          if (m.dimColor          !== undefined) root.pkMpDimColor         = m.dimColor
          if (m.textColorActive   !== undefined) root.pkMpTextColorActive  = m.textColorActive
          if (m.dimColorActive    !== undefined) root.pkMpDimColorActive   = m.dimColorActive
        }

        // clock visual
        var ck = th.clock
        if (ck) {
          if (ck.textColor      !== undefined) root.pkClkTextColor    = ck.textColor
          if (ck.dimColor       !== undefined) root.pkClkDimColor     = ck.dimColor
          if (ck.accentColor    !== undefined) root.pkClkAccentColor  = ck.accentColor
          if (ck.dismissDelayMs !== undefined) root.clkDismissDelayMs = ck.dismissDelayMs
        }

        // palette do tema
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
      }
    }
  }

  function _syncBarToAdapter() {
    adapter.bar = { theme: root.theme, autoHide: root.autoHide, position: root.position }
  }
  onThemeChanged:    _syncBarToAdapter()
  onAutoHideChanged: _syncBarToAdapter()
  onPositionChanged: _syncBarToAdapter()

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }
  Component.onCompleted: mkdirProc.running = true
}
