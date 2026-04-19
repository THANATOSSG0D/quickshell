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
//
// NOTA: onAdapterUpdated não existe na API do Quickshell — foi removido.
// file.writeAdapter() é chamado explicitamente em _syncBarToAdapter() e
// _syncModulesToAdapter(), garantindo persistência real no disco.

Item {
  id: root
  visible: false

  // ── bar.* ──────────────────────────────────────────────────────────────
  property string theme:     "Pill"
  property bool   autoHide:  true
  property int    position:  -2
  property int    barSize:   0    // 0 = usa padrão do tema
  property int    barMargin: -1   // -1 = usa padrão do tema
  property int    pillWidth: 800

  // ── modules — listas de módulos por slot ───────────────────────────────
  // Defaults usados quando o JSON não tem a seção modules.
  // O tema Pill usa estes valores como layout padrão.
  property var modulesLeft:   ["mediaplayer"]
  property var modulesCenter: ["workspaces"]
  property var modulesRight:  ["quicksettings", "separator", "clock", "separator", "volume"]
  property var modulesTop:    ["mediaplayer"]
  property var modulesMiddle: ["workspaces"]
  property var modulesBottom: ["quicksettings", "separator", "clock", "separator", "volume"]

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
    path:         Quickshell.shellDir + "/state/Bar.json"
    watchChanges: true
    // onAdapterUpdated não existe na API do Quickshell — removido.
    // writeAdapter() é chamado explicitamente em _syncBarToAdapter() e
    // _syncModulesToAdapter() para garantir escrita real no disco.

    onFileChanged: {
      root._parsing = true
      reload()
      // Garante que seções novas existam no adapter
      // modulesUpdated() é emitido pelo onModulesChanged após os dados serem lidos
      Qt.callLater(function() {
        var needsWrite = false

        // Seção modules — inexistente em JSONs muito antigos.
        // Verifica TODOS os slots (h e v) — não só left/center/right,
        // senão barra vertical (top/middle/bottom) sempre parece vazia.
        var m = adapter.modules
        var hasModules = m && (
          Array.isArray(m.left)   || Array.isArray(m.center) || Array.isArray(m.right) ||
          Array.isArray(m.top)    || Array.isArray(m.middle) || Array.isArray(m.bottom)
        )
        if (!hasModules) {
          adapter.modules = {
            left:   root.modulesLeft,
            center: root.modulesCenter,
            right:  root.modulesRight,
            top:    root.modulesTop,
            middle: root.modulesMiddle,
            bottom: root.modulesBottom
          }
          needsWrite = true
        }

        // barSize/barMargin/pillWidth — inexistentes em JSONs antigos
        var b = adapter.bar
        if (b && (b.barSize === undefined || b.barMargin === undefined || b.pillWidth === undefined)) {
          adapter.bar = {
            theme:     root.theme,
            autoHide:  root.autoHide,
            position:  root.position,
            barSize:   root.barSize,
            barMargin: root.barMargin,
            pillWidth: root.pillWidth
          }
          needsWrite = true
        }

        if (needsWrite) file.writeAdapter()
      })
    }

    JsonAdapter {
      id: adapter

      property var bar:         ({})
      property var modules:     ({})
      property var workspaces:  ({})
      property var mediaPlayer: ({})
      property var themes:      ({})

      onBarChanged: {
        var b = bar
        if (!b) return
        if (b.theme     !== undefined) { root.theme     = b.theme; applyTheme(b.theme) }
        if (b.autoHide  !== undefined)   root.autoHide  = b.autoHide
        if (b.position  !== undefined)   root.position  = b.position
        if (b.barSize   !== undefined)   root.barSize   = b.barSize
        if (b.barMargin !== undefined)   root.barMargin = b.barMargin
        if (b.pillWidth !== undefined)   root.pillWidth = b.pillWidth
      }

      onModulesChanged: {
        var m = modules
        if (!m) return
        if (Array.isArray(m.left))   root.modulesLeft   = m.left
        if (Array.isArray(m.center)) root.modulesCenter = m.center
        if (Array.isArray(m.right))  root.modulesRight  = m.right
        if (Array.isArray(m.top))    root.modulesTop    = m.top
        if (Array.isArray(m.middle)) root.modulesMiddle = m.middle
        if (Array.isArray(m.bottom)) root.modulesBottom = m.bottom
        root._parsing     = false
        root.configLoaded = true
        Qt.callLater(function() { root.modulesUpdated() })
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

  // ── Guard: só persiste após o componente estar pronto ─────────────────
  // Os handlers on*Changed disparam durante a inicialização das propriedades,
  // antes de Component.onCompleted — nesse momento FileView.path ainda não
  // foi resolvido e writeAdapter() falha com "no path has been specified".
  property bool _ready:       false
  property bool configLoaded: false
  // Verdadeiro enquanto JSON está sendo parseado ou saveAll() está rodando.
  // Impede que _syncModulesToAdapter escreva no disco com valores parciais.
  property bool _parsing:     false

  // ── Sync interno — disparado por on*Changed das próprias propriedades ──
  //
  // IMPORTANTE: ambas as funções têm guard `_ready` no início.
  // O QML engine dispara on*Changed para CADA propriedade durante a
  // inicialização do componente (atribuição de valor default já emite o signal).
  // Sem o guard, adapter.bar/modules seria escrito com defaults ANTES do JSON
  // ser lido, causando onBarChanged/onModulesChanged prematuros que setariam
  // configLoaded=true com os valores errados e o Loader carregaria com defaults.
  function _syncBarToAdapter() {
    if (!root._ready) return
    adapter.bar = {
      theme:     root.theme,
      autoHide:  root.autoHide,
      position:  root.position,
      barSize:   root.barSize,
      barMargin: root.barMargin,
      pillWidth: root.pillWidth
    }
    file.writeAdapter()
  }
  onThemeChanged:     _syncBarToAdapter()
  onAutoHideChanged:  _syncBarToAdapter()
  onPositionChanged:  _syncBarToAdapter()
  onBarSizeChanged:   _syncBarToAdapter()
  onBarMarginChanged: _syncBarToAdapter()
  onPillWidthChanged: _syncBarToAdapter()

  function _syncModulesToAdapter() {
    if (!root._ready) return
    if (root._parsing) return
    adapter.modules = {
      left:   root.modulesLeft,
      center: root.modulesCenter,
      right:  root.modulesRight,
      top:    root.modulesTop,
      middle: root.modulesMiddle,
      bottom: root.modulesBottom
    }
    file.writeAdapter()
  }
  onModulesLeftChanged:   _syncModulesToAdapter()
  onModulesCenterChanged: _syncModulesToAdapter()
  onModulesRightChanged:  _syncModulesToAdapter()
  onModulesTopChanged:    _syncModulesToAdapter()
  onModulesMiddleChanged: _syncModulesToAdapter()
  onModulesBottomChanged: _syncModulesToAdapter()

  // ── saveAll() — API pública para o BarEditorPopup ──────────────────────
  //
  // O editor NÃO deve atribuir config.modulesLeft = [...] diretamente:
  // atribuições de array JS via referência externa em property var não
  // garantem que on*Changed dispare de forma confiável no QML engine.
  //
  // Em vez disso, o editor chama config.saveAll({...}) com todos os valores
  // de uma vez. saveAll() atualiza as propriedades, sincroniza o adapter e
  // chama writeAdapter() explicitamente — sem depender de signal propagation.
  // Emitido por saveAll() e após reload do JSON — garante que Bar.qml
  // propague os valores corretos para Pill.qml independente de on*Changed.
  signal modulesUpdated()

  function saveAll(opts) {
    // Bloqueia writes parciais durante as atribuições de props.
    // O único write real é o file.writeAdapter() ao final.
    root._parsing = true

    // bar.*
    if (opts.theme     !== undefined) root.theme     = opts.theme
    if (opts.autoHide  !== undefined) root.autoHide  = opts.autoHide
    if (opts.position  !== undefined) root.position  = opts.position
    if (opts.barSize   !== undefined) root.barSize   = opts.barSize
    if (opts.barMargin !== undefined) root.barMargin = opts.barMargin
    if (opts.pillWidth !== undefined) root.pillWidth = opts.pillWidth

    // modules — .slice() força nova referência JS para maximizar chance
    // de on*Changed disparar no engine QML
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

    // Escreve tudo no disco de uma vez
    adapter.bar = {
      theme:     root.theme,
      autoHide:  root.autoHide,
      position:  root.position,
      barSize:   root.barSize,
      barMargin: root.barMargin,
      pillWidth: root.pillWidth
    }
    adapter.modules = {
      left:   root.modulesLeft,
      center: root.modulesCenter,
      right:  root.modulesRight,
      top:    root.modulesTop,
      middle: root.modulesMiddle,
      bottom: root.modulesBottom
    }
    adapter.workspaces = {
      style:          root.wsStyle,
      iconsSort:      root.wsIconsSort,
      iconMonochrome: root.wsIconMonochrome,
      iconSpacing:    root.wsIconSpacing,
      showAddButton:  root.wsShowAddButton
    }
    file.writeAdapter()
    root._parsing = false
    root.modulesUpdated()
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      root._ready   = true
      root._parsing = true
      file.reload()
      Qt.callLater(function() {
        Qt.callLater(function() {
          root._parsing = false
          if (root.configLoaded) return
          // JSON sem modules — gravar defaults e ativar
          adapter.modules = {
            left:   root.modulesLeft,
            center: root.modulesCenter,
            right:  root.modulesRight,
            top:    root.modulesTop,
            middle: root.modulesMiddle,
            bottom: root.modulesBottom
          }
          file.writeAdapter()
          root.configLoaded = true
        })
      })
    }
  }
  Component.onCompleted: mkdirProc.running = true
}
