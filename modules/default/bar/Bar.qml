import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import '../mediaPlayer' as MediaPanel
import '../volume' as VolumeModule
import '../clock' as ClockModule

Scope {
  id: barRoot

  BarState { id: barState }

  // ── Props do tema activo ───────────────────────────────────────────────
  property int  themeBarSize:    30
  property int  themeBarMargin:  0
  property bool themePill:       false
  property int  themePillWidth:  600
  property bool themeHasPanel:   false
  property int  themePanelWidth: 400

  // ── Controle de painéis — um aberto por vez ────────────────────────────
  property bool playerPanelOpen: false
  property bool sinkPanelOpen:   false
  property bool sourcePanelOpen: false
  property bool clockPanelOpen:  false

  readonly property bool anyPanelOpen:
    playerPanelOpen || sinkPanelOpen || sourcePanelOpen || clockPanelOpen

  function openPanel(which) {
    var wasOpen = (which === "player" && playerPanelOpen)
               || (which === "sink"   && sinkPanelOpen)
               || (which === "source" && sourcePanelOpen)
               || (which === "clock"  && clockPanelOpen)
    playerPanelOpen = false
    sinkPanelOpen   = false
    sourcePanelOpen = false
    clockPanelOpen  = false
    if (!wasOpen) {
      if      (which === "player") playerPanelOpen = true
      else if (which === "sink")   sinkPanelOpen   = true
      else if (which === "source") sourcePanelOpen = true
      else if (which === "clock")  clockPanelOpen  = true
    }
  }

  function closeAllPanels() {
    playerPanelOpen = false
    sinkPanelOpen   = false
    sourcePanelOpen = false
    clockPanelOpen  = false
  }

  property var barMediaPlayerRef: null
  property var barClockRef:       null

  // Referência ao OsdService do módulo OSD — injetada pelo shell.qml
  // e repassada aos widgets do tema via onLoaded.
  property var osdService: null

  property int position: barState.position

  // ── Barra + Popups (um conjunto por tela) ─────────────────────────────
  //
  // IMPORTANTE — por que os popups estão DENTRO do PanelWindow:
  //
  // PopupWindow em Quickshell é um xdg_popup Wayland. Para funcionar,
  // ele precisa de um `parentWindow` (a superfície pai). Quando declarado
  // como filho QML de um PanelWindow, o Quickshell automaticamente usa
  // aquele PanelWindow como parentWindow da superfície Wayland do popup.
  //
  // Tentativas anteriores declaravam os popups em Variants separados:
  //   • `screen` não pode ser setado (controlado pelo parentWindow)
  //   • `anchor.window: this` causava o erro "transient parent cannot be
  //     same as window" pois o popup tentava ancorar a si mesmo
  //   • Não havia como referenciar o `bar` correto por tela
  //
  // Solução: popups dentro do PanelWindow onde `bar` é visível por id.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      color:  "transparent"

      property int  barSize:   barRoot.themeBarSize
      property int  barMargin: barRoot.themeBarMargin
      property bool pill:      barRoot.themePill
      property int  pillWidth: barRoot.themePillWidth
      property int  position:  barRoot.position

      readonly property bool isVertical: position === 2 || position === 4

      property int pillSideMargin: {
        if (!pill) return 0
        if (isVertical)
          return Math.max(0, Math.floor((screen.height - pillWidth) / 2))
        return Math.max(0, Math.floor((screen.width - pillWidth) / 2))
      }

      property bool themeLoaded: barRoot.themeBarSize > 0

      anchors.top:    themeLoaded ? (position === 1 || position === 2 || position === 4) : false
      anchors.bottom: themeLoaded ? (position === 3 || position === 2 || position === 4) : false
      anchors.left:   themeLoaded ? (position === 1 || position === 3 || position === 4) : false
      anchors.right:  themeLoaded ? (position === 1 || position === 3 || position === 2) : false

      implicitHeight: {
        if (!themeLoaded) return 0
        if (!isVertical) return barSize
        return pill ? pillWidth : screen.height
      }
      implicitWidth: {
        if (!themeLoaded) return 0
        if (isVertical) return barSize
        return pill ? pillWidth : screen.width
      }

      property bool animating:    true
      property real marginOffset: 0

      Behavior on marginOffset {
        enabled: bar.animating
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
      }

      margins.top: {
        if (position === 1) return barMargin - marginOffset
        if (isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.bottom: {
        if (position === 3) return barMargin - marginOffset
        if (isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.left: {
        if (position === 4) return barMargin - marginOffset
        if (!isVertical && pill) return pillSideMargin
        return barMargin
      }
      margins.right: {
        if (position === 2) return barMargin - marginOffset
        if (!isVertical && pill) return pillSideMargin
        return barMargin
      }

      property real _edgeThreshold: barState.edgeThreshold

      onBarShowChanged: {
        _edgeThreshold = barShow ? (barSize + barMargin + 4) : barState.edgeThreshold
        marginOffset   = barShow ? 0 : barSize + barMargin + 1
      }

      WlrLayershell.layer: WlrLayershell.Top

      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: {
        if (!barState.autoHide) return barSize
        return 0
      }

      // ── Loader do tema ─────────────────────────────────────────────────
      Loader {
        id: loader
        anchors.fill: parent
        source: Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml"

        onLoaded: {
          barRoot.themeBarSize    = item.barSize       !== undefined ? item.barSize       : 30
          barRoot.themeBarMargin  = item.barMargin     !== undefined ? item.barMargin     : 0
          barRoot.themePill       = item.pill          !== undefined ? item.pill          : false
          barRoot.themePillWidth  = item.pillWidth     !== undefined ? item.pillWidth     : 600
          barRoot.themeHasPanel   = item.hasMediaPanel !== undefined ? item.hasMediaPanel : false
          barRoot.themePanelWidth = item.panelWidth    !== undefined ? item.panelWidth    : 400

          if ("monitorName" in item) item.monitorName = bar.screen.name
          if ("barPosition" in item) item.barPosition = barRoot.position
          if (item.mediaPlayer)      barRoot.barMediaPlayerRef = item.mediaPlayer

          // ── Clock — injeção do clockContent e captura da referência ────
          if (item.clock) {
            barRoot.barClockRef = item.clock
            if ("clockContent" in item.clock)
              item.clock.clockContent = clockPopup.clockContentRef
          }

          // Injeta osdService nos widgets do tema (só quando disponível)
          if (barRoot.osdService !== null) {
            if ("osdService" in item) item.osdService = barRoot.osdService
            var _vol = item.volumeWidget
            if (_vol && "osdService" in _vol) _vol.osdService = barRoot.osdService
            var _mp  = item.mediaPlayer
            if (_mp  && "osdService" in _mp)  _mp.osdService  = barRoot.osdService
          }

          // workspaces
          if ("cfgWsStyle"          in item) item.cfgWsStyle          = barState.config.wsStyle
          if ("cfgWsIconsSort"      in item) item.cfgWsIconsSort      = barState.config.wsIconsSort
          if ("cfgWsIconMonochrome" in item) item.cfgWsIconMonochrome = barState.config.wsIconMonochrome
          if ("cfgWsIconSpacing"    in item) item.cfgWsIconSpacing    = barState.config.wsIconSpacing
          if ("cfgWsBgOpacity"      in item) item.cfgWsBgOpacity      = barState.config.wsBgOpacity
          if ("cfgWsBgPaddingH"     in item) item.cfgWsBgPaddingH     = barState.config.wsBgPaddingH
          if ("cfgWsBgPaddingV"     in item) item.cfgWsBgPaddingV     = barState.config.wsBgPaddingV
          if ("cfgWsShowAddButton"  in item) item.cfgWsShowAddButton  = barState.config.wsShowAddButton
          // workspace ativa — fundo individual
          if ("cfgWsBgColorActive"       in item) item.cfgWsBgColorActive       = barState.config.paletteWsBgColorActive
          if ("cfgWsBgOpacityActive"     in item) item.cfgWsBgOpacityActive     = barState.config.wsBgOpacityActive
          if ("cfgWsBgBorderColorActive" in item) item.cfgWsBgBorderColorActive = barState.config.paletteWsBgBorderColorActive
          if ("cfgWsBgBorderWidthActive" in item) item.cfgWsBgBorderWidthActive = barState.config.wsBgBorderWidthActive
          if ("cfgWsBgPaddingHActive"    in item) item.cfgWsBgPaddingHActive    = barState.config.wsBgPaddingHActive
          if ("cfgWsBgPaddingVActive"    in item) item.cfgWsBgPaddingVActive    = barState.config.wsBgPaddingVActive
          if ("cfgWsBgRadiusActive"      in item) item.cfgWsBgRadiusActive      = barState.config.wsBgRadiusActive
          if ("colWsBgActive"            in item) item.colWsBgActive            = barState.config.paletteWsBgColorActive

          // mediaPlayer
          if ("cfgMpTextMode"        in item) item.cfgMpTextMode        = barState.config.mpTextMode
          if ("cfgMpScrollSpeed"     in item) item.cfgMpScrollSpeed     = barState.config.mpScrollSpeed
          if ("cfgMpScrollPauseMs"   in item) item.cfgMpScrollPauseMs  = barState.config.mpScrollPauseMs
          if ("cfgMpScrollWidth"     in item) item.cfgMpScrollWidth     = barState.config.mpScrollWidth
          if ("cfgMpBgEnabled"       in item) item.cfgMpBgEnabled       = barState.config.mpBgEnabled
          if ("cfgMpBgOpacity"       in item) item.cfgMpBgOpacity       = barState.config.mpBgOpacity
          if ("cfgMpBgOpacityActive" in item) item.cfgMpBgOpacityActive = barState.config.mpBgOpacityActive
          if ("cfgMpBgPaddingH"      in item) item.cfgMpBgPaddingH      = barState.config.mpBgPaddingH
          if ("cfgMpBgPaddingV"      in item) item.cfgMpBgPaddingV      = barState.config.mpBgPaddingV
          if ("cfgMpBgColor"         in item) item.cfgMpBgColor         = barState.config.paletteMpBgColor
          if ("cfgMpBgColorActive"   in item) item.cfgMpBgColorActive   = barState.config.paletteMpBgColorActive
          if ("cfgMpTextColor"       in item) item.cfgMpTextColor       = barState.config.paletteMpTextColor
          if ("cfgMpDimColor"        in item) item.cfgMpDimColor        = barState.config.paletteMpDimColor
          if ("cfgMpTextColorActive" in item) item.cfgMpTextColorActive = barState.config.paletteMpTextColorActive
          if ("cfgMpDimColorActive"  in item) item.cfgMpDimColorActive  = barState.config.paletteMpDimColorActive

          // volume
          if ("cfgVolShowSink"   in item) item.cfgVolShowSink   = barState.config.volShowSink   !== undefined ? barState.config.volShowSink   : true
          if ("cfgVolShowSource" in item) item.cfgVolShowSource = barState.config.volShowSource !== undefined ? barState.config.volShowSource : true
          if ("cfgVolTextColor"  in item) item.cfgVolTextColor  = barState.config.paletteText
          if ("cfgVolDimColor"   in item) item.cfgVolDimColor   = barState.config.paletteTextDim
          if ("cfgVolAccent"     in item) item.cfgVolAccent     = barState.config.paletteAccent
          if ("cfgVolMuted"      in item) item.cfgVolMuted      = barState.config.paletteWsDotUrgentColor

          // clock
          if ("cfgClkTextColor"    in item) item.cfgClkTextColor    = barState.config.paletteClkTextColor
          if ("cfgClkDimColor"     in item) item.cfgClkDimColor     = barState.config.paletteClkDimColor
          if ("cfgClkAccent"       in item) item.cfgClkAccent       = barState.config.paletteClkAccentColor
          if ("cfgClkDismissDelay" in item) item.cfgClkDismissDelay = barState.config.clkDismissDelayMs

          // paleta
          if ("colBarBg"          in item) item.colBarBg          = barState.config.paletteBarBg
          if ("colBarBgPill"      in item) item.colBarBgPill      = barState.config.paletteBarBgPill
          if ("colText"           in item) item.colText           = barState.config.paletteText
          if ("colTextDim"        in item) item.colTextDim        = barState.config.paletteTextDim
          if ("colAccent"         in item) item.colAccent         = barState.config.paletteAccent
          if ("colAccentBg"       in item) item.colAccentBg       = barState.config.paletteAccentBg
          if ("colAccentText"     in item) item.colAccentText     = barState.config.paletteAccentText
          if ("colWsDot"          in item) item.colWsDot          = barState.config.paletteWsDotColor
          if ("colWsDotActive"    in item) item.colWsDotActive    = barState.config.paletteWsDotActiveColor
          if ("colWsDotOccupied"  in item) item.colWsDotOccupied  = barState.config.paletteWsDotOccupiedColor
          if ("colWsDotUrgent"    in item) item.colWsDotUrgent    = barState.config.paletteWsDotUrgentColor
          if ("colWsBg"           in item) item.colWsBg           = barState.config.paletteWsBgColor
          if ("colWsBorder"       in item) item.colWsBorder       = barState.config.paletteWsBgBorderColor
          if ("colIconMono"       in item) item.colIconMono       = barState.config.paletteWsIconMonoColor
          if ("colIconMonoActive" in item) item.colIconMonoActive = barState.config.paletteWsIconMonoColorActive

          bar.animating    = false
          bar.marginOffset = bar.barShow ? 0 : bar.barSize + bar.barMargin + 1
          bar.animating    = true
        }
      }

      // ── Propagação runtime → tema ──────────────────────────────────────
      Connections {
        target: barState.config

        function onPaletteBarBgChanged()                { _set("colBarBg",           barState.config.paletteBarBg)                 }
        function onPaletteBarBgPillChanged()            { _set("colBarBgPill",       barState.config.paletteBarBgPill)             }
        function onPaletteTextChanged()                 { _set("colText",            barState.config.paletteText)
                                                          _set("cfgVolTextColor",    barState.config.paletteText)                  }
        function onPaletteTextDimChanged()              { _set("colTextDim",         barState.config.paletteTextDim)
                                                          _set("cfgVolDimColor",     barState.config.paletteTextDim)               }
        function onPaletteAccentChanged()               { _set("colAccent",          barState.config.paletteAccent)
                                                          _set("cfgVolAccent",       barState.config.paletteAccent)                }
        function onPaletteAccentBgChanged()             { _set("colAccentBg",        barState.config.paletteAccentBg)              }
        function onPaletteAccentTextChanged()           { _set("colAccentText",      barState.config.paletteAccentText)            }
        function onPaletteWsBgColorChanged()            { _set("colWsBg",            barState.config.paletteWsBgColor)             }
        function onPaletteWsBgBorderColorChanged()      { _set("colWsBorder",        barState.config.paletteWsBgBorderColor)       }
        function onPaletteWsDotColorChanged()           { _set("colWsDot",           barState.config.paletteWsDotColor)            }
        function onPaletteWsDotActiveColorChanged()     { _set("colWsDotActive",     barState.config.paletteWsDotActiveColor)      }
        function onPaletteWsDotOccupiedColorChanged()   { _set("colWsDotOccupied",   barState.config.paletteWsDotOccupiedColor)    }
        function onPaletteWsDotUrgentColorChanged()     { _set("colWsDotUrgent",     barState.config.paletteWsDotUrgentColor)
                                                          _set("cfgVolMuted",        barState.config.paletteWsDotUrgentColor)      }
        function onPaletteWsIconMonoColorChanged()      { _set("colIconMono",        barState.config.paletteWsIconMonoColor)       }
        function onPaletteWsIconMonoColorActiveChanged(){ _set("colIconMonoActive",  barState.config.paletteWsIconMonoColorActive) }
        function onWsStyleChanged()          { _set("cfgWsStyle",          barState.config.wsStyle)          }
        function onWsIconsSortChanged()      { _set("cfgWsIconsSort",      barState.config.wsIconsSort)      }
        function onWsIconMonochromeChanged() { _set("cfgWsIconMonochrome", barState.config.wsIconMonochrome) }
        function onWsIconSpacingChanged()    { _set("cfgWsIconSpacing",    barState.config.wsIconSpacing)    }
        function onWsBgOpacityChanged()      { _set("cfgWsBgOpacity",      barState.config.wsBgOpacity)      }
        function onWsBgPaddingHChanged()     { _set("cfgWsBgPaddingH",     barState.config.wsBgPaddingH)     }
        function onWsBgPaddingVChanged()     { _set("cfgWsBgPaddingV",     barState.config.wsBgPaddingV)     }
        function onWsShowAddButtonChanged()  { _set("cfgWsShowAddButton",  barState.config.wsShowAddButton)  }
        // workspace ativa — runtime
        function onPaletteWsBgColorActiveChanged()       { _set("cfgWsBgColorActive",       barState.config.paletteWsBgColorActive)
                                                           _set("colWsBgActive",             barState.config.paletteWsBgColorActive)       }
        function onWsBgOpacityActiveChanged()            { _set("cfgWsBgOpacityActive",      barState.config.wsBgOpacityActive)            }
        function onPaletteWsBgBorderColorActiveChanged() { _set("cfgWsBgBorderColorActive",  barState.config.paletteWsBgBorderColorActive) }
        function onWsBgBorderWidthActiveChanged()        { _set("cfgWsBgBorderWidthActive",  barState.config.wsBgBorderWidthActive)        }
        function onWsBgPaddingHActiveChanged()           { _set("cfgWsBgPaddingHActive",     barState.config.wsBgPaddingHActive)           }
        function onWsBgPaddingVActiveChanged()           { _set("cfgWsBgPaddingVActive",     barState.config.wsBgPaddingVActive)           }
        function onWsBgRadiusActiveChanged()             { _set("cfgWsBgRadiusActive",       barState.config.wsBgRadiusActive)             }
        function onMpTextModeChanged()            { _set("cfgMpTextMode",        barState.config.mpTextMode)            }
        function onMpScrollSpeedChanged()         { _set("cfgMpScrollSpeed",     barState.config.mpScrollSpeed)         }
        function onMpScrollPauseMsChanged()       { _set("cfgMpScrollPauseMs",   barState.config.mpScrollPauseMs)       }
        function onMpScrollWidthChanged()         { _set("cfgMpScrollWidth",     barState.config.mpScrollWidth)         }
        function onMpBgEnabledChanged()           { _set("cfgMpBgEnabled",       barState.config.mpBgEnabled)           }
        function onMpBgOpacityChanged()           { _set("cfgMpBgOpacity",       barState.config.mpBgOpacity)           }
        function onMpBgOpacityActiveChanged()     { _set("cfgMpBgOpacityActive", barState.config.mpBgOpacityActive)     }
        function onMpBgPaddingHChanged()          { _set("cfgMpBgPaddingH",      barState.config.mpBgPaddingH)          }
        function onMpBgPaddingVChanged()          { _set("cfgMpBgPaddingV",      barState.config.mpBgPaddingV)          }
        function onPaletteMpBgColorChanged()         { _set("cfgMpBgColor",         barState.config.paletteMpBgColor)         }
        function onPaletteMpBgColorActiveChanged()   { _set("cfgMpBgColorActive",   barState.config.paletteMpBgColorActive)   }
        function onPaletteMpTextColorChanged()       { _set("cfgMpTextColor",       barState.config.paletteMpTextColor)       }
        function onPaletteMpDimColorChanged()        { _set("cfgMpDimColor",        barState.config.paletteMpDimColor)        }
        function onPaletteMpTextColorActiveChanged() { _set("cfgMpTextColorActive", barState.config.paletteMpTextColorActive) }
        function onPaletteMpDimColorActiveChanged()  { _set("cfgMpDimColorActive",  barState.config.paletteMpDimColorActive)  }

        // clock
        function onPaletteClkTextColorChanged()   { _set("cfgClkTextColor",    barState.config.paletteClkTextColor)   }
        function onPaletteClkDimColorChanged()    { _set("cfgClkDimColor",     barState.config.paletteClkDimColor)    }
        function onPaletteClkAccentColorChanged() { _set("cfgClkAccent",       barState.config.paletteClkAccentColor) }
        function onClkDismissDelayMsChanged()     { _set("cfgClkDismissDelay", barState.config.clkDismissDelayMs)     }

        function _set(prop, value) {
          if (loader.item && prop in loader.item) loader.item[prop] = value
        }
      }

      Connections {
        target: barRoot
        function onPositionChanged() {
          if (loader.item && "barPosition" in loader.item)
            loader.item.barPosition = barRoot.position
        }
        function onOsdServiceChanged() {
          if (!loader.item) return
          if ("osdService" in loader.item) loader.item.osdService = barRoot.osdService
          var vol = loader.item.volumeWidget
          if (vol && "osdService" in vol) vol.osdService = barRoot.osdService
          var mp = loader.item.mediaPlayer
          if (mp  && "osdService" in mp)  mp.osdService  = barRoot.osdService
        }
        // Re-injeta clockContent quando barClockRef muda (hot-reload do tema)
        function onBarClockRefChanged() {
          var ck = barRoot.barClockRef
          if (ck && "clockContent" in ck)
            ck.clockContent = clockPopup.clockContentRef
        }
      }

      // ── Sinais do tema → abertura de painéis ───────────────────────────
      Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onSinkPanelRequested() {
          if (!volCooldown.running) { barRoot.openPanel("sink"); volCooldown.restart() }
        }
        function onSourcePanelRequested() {
          if (!volCooldown.running) { barRoot.openPanel("source"); volCooldown.restart() }
        }
        function onClockPanelRequested() {
          if (!clockCooldown.running) { barRoot.openPanel("clock"); clockCooldown.restart() }
        }
      }
      Timer { id: volCooldown;   interval: 100; repeat: false }
      Timer { id: clockCooldown; interval: 100; repeat: false }

      Connections {
        target: loader.item && loader.item.mediaPlayer ? loader.item.mediaPlayer : null
        ignoreUnknownSignals: true
        function onClicked() {
          if (!toggleCooldown.running) { barRoot.openPanel("player"); toggleCooldown.restart() }
        }
      }
      Timer { id: toggleCooldown; interval: 100; repeat: false }

      // ── Hot-reload do tema ─────────────────────────────────────────────
      FileView {
        path:         Quickshell.shellDir + "/modules/default/bar/themes/" + barState.currentTheme + ".qml"
        watchChanges: true
        onFileChanged: {
          var src = loader.source
          loader.source = ""
          loader.source = src
        }
      }

      // ── Auto-hide ──────────────────────────────────────────────────────
      property var hyprMonitor: null

      Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
          for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (m.name === bar.screen.name) { bar.hyprMonitor = m; return }
          }
          bar.hyprMonitor = null
        }
      }

      property bool hasWindows: {
        if (!hyprMonitor) return false
        var ws = hyprMonitor.activeWorkspace
        if (!ws) return false
        return ws.toplevels.values.length > 0
      }

      property bool cursorNearBar: {
        var threshold = _edgeThreshold
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barState.cursorX / scaleX
        var cy = barState.cursorY / scaleY
        var inScreen = cx >= screen.x && cx <= screen.x + screen.width
                    && cy >= screen.y && cy <= screen.y + screen.height
        if (!inScreen) return false
        var lx = cx - screen.x
        var ly = cy - screen.y
        if (position === 1) return ly <= threshold
        if (position === 2) return lx >= screen.width - threshold
        if (position === 3) return ly >= screen.height - threshold
        if (position === 4) return lx <= threshold
        return false
      }

      property bool cursorAtEdge: {
        var threshold = _edgeThreshold
        var scaleX = hyprMonitor ? hyprMonitor.width  / screen.width  : 1.0
        var scaleY = hyprMonitor ? hyprMonitor.height / screen.height : 1.0
        var cx = barState.cursorX / scaleX
        var cy = barState.cursorY / scaleY
        var inScreen = cx >= screen.x && cx <= screen.x + screen.width
                    && cy >= screen.y && cy <= screen.y + screen.height
        if (!inScreen) return false
        var lx = cx - screen.x
        var ly = cy - screen.y
        var tolerance = barSize / 2
        if (position === 1 || position === 3) {
          var atV = position === 1 ? ly <= threshold : ly >= screen.height - threshold
          if (!atV) return false
          if (pill) return lx >= pillSideMargin - tolerance && lx <= screen.width - pillSideMargin + tolerance
          return true
        }
        if (position === 2 || position === 4) {
          var atH = position === 4 ? lx <= threshold : lx >= screen.width - threshold
          if (!atH) return false
          if (pill) return ly >= pillSideMargin - tolerance && ly <= screen.height - pillSideMargin + tolerance
          return true
        }
        return false
      }

      property bool barVisible: {
        if (barRoot.playerPanelOpen) return true
        if (barRoot.sinkPanelOpen || barRoot.sourcePanelOpen) return true
        if (barRoot.clockPanelOpen) return true
        if (!barState.autoHide) return true
        var near = pill ? cursorAtEdge : cursorNearBar
        return near || !hasWindows
      }
      property bool barShow: true

      onBarVisibleChanged: {
        if (barVisible) { hideTimer.stop(); barShow = true }
        else hideTimer.restart()
      }

      Timer {
        id: hideTimer
        interval: barState.hideDelayMs
        repeat:   false
        onTriggered: bar.barShow = false
      }

      Component.onCompleted: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
          var m = Hyprland.monitors.values[i]
          if (m.name === bar.screen.name) { bar.hyprMonitor = m; break }
        }
        barShow = barVisible
        if (!barVisible) marginOffset = barSize + barMargin + 1
      }

      // ───────────────────────────────────────────────────────────────────
      // Popups declarados como filhos QML do PanelWindow.
      // ───────────────────────────────────────────────────────────────────

      // ── Popup Volume — Sink ────────────────────────────────────────────
      VolumeModule.VolumePopup {
        id: volSinkPopup

        anchor.window: bar
        anchor.rect: {
          var bw = bar.implicitWidth
          var bh = bar.implicitHeight
          var pw = barRoot.themePanelWidth
          var ph = 380
          if (!bar.isVertical)
            return Qt.rect(Math.max(0, (bw - pw) / 2), 0, pw, bh)
          return Qt.rect(0, Math.max(0, (bh - ph) / 2), bw, ph)
        }
        anchor.edges: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }
        anchor.gravity: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }

        popupW: barRoot.themePanelWidth
        popupH: 380

        showOnlySink: true
        panelOpen:    barRoot.sinkPanelOpen

        colorPanelBg:    barState.config.palettePanelBg
        colorText:       barState.config.paletteText
        colorTextDim:    barState.config.paletteTextDim
        colorAccent:     barState.config.paletteAccent
        colorProgressBg: barState.config.paletteProgressBg
        colorDivider:    barState.config.paletteDivider
        colorMuted:      barState.config.paletteWsDotUrgentColor

        onCloseRequested: barRoot.closeAllPanels()
      }

      // ── Popup Volume — Source ──────────────────────────────────────────
      VolumeModule.VolumePopup {
        id: volSourcePopup

        anchor.window: bar
        anchor.rect: {
          var bw = bar.implicitWidth
          var bh = bar.implicitHeight
          var pw = barRoot.themePanelWidth
          var ph = 380
          if (!bar.isVertical)
            return Qt.rect(Math.max(0, (bw - pw) / 2), 0, pw, bh)
          return Qt.rect(0, Math.max(0, (bh - ph) / 2), bw, ph)
        }
        anchor.edges: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }
        anchor.gravity: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }

        popupW: barRoot.themePanelWidth
        popupH: 380

        showOnlySource: true
        panelOpen:      barRoot.sourcePanelOpen

        colorPanelBg:    barState.config.palettePanelBg
        colorText:       barState.config.paletteText
        colorTextDim:    barState.config.paletteTextDim
        colorAccent:     barState.config.paletteAccent
        colorProgressBg: barState.config.paletteProgressBg
        colorDivider:    barState.config.paletteDivider
        colorMuted:      barState.config.paletteWsDotUrgentColor

        onCloseRequested: barRoot.closeAllPanels()
      }

      // ── Popup Media Player ─────────────────────────────────────────────
      MediaPanel.MediaPlayerPopup {
        id: mediaPopup

        anchor.window: bar
        anchor.rect: {
          var bw = bar.implicitWidth
          var bh = bar.implicitHeight
          var pw = barRoot.themePanelWidth
          var ph = 420
          if (!bar.isVertical)
            return Qt.rect(Math.max(0, (bw - pw) / 2), 0, pw, bh)
          return Qt.rect(0, Math.max(0, (bh - ph) / 2), bw, ph)
        }
        anchor.edges: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }
        anchor.gravity: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }

        popupW: barRoot.themePanelWidth
        popupH: 420

        panelOpen:      barRoot.playerPanelOpen && barRoot.themeHasPanel
        barMediaPlayer: barRoot.barMediaPlayerRef

        colorPanelBg:    barState.config.palettePanelBg
        colorText:       barState.config.paletteText
        colorTextDim:    barState.config.paletteTextDim
        colorAccent:     barState.config.paletteAccent
        colorProgressBg: barState.config.paletteProgressBg
        colorProgressFg: barState.config.paletteProgressFg

        onCloseRequested: barRoot.closeAllPanels()
      }

      // ── Popup Clock ────────────────────────────────────────────────────
      ClockModule.ClockPopup {
        id: clockPopup

        anchor.window: bar
        anchor.rect: {
          var bw = bar.implicitWidth
          var bh = bar.implicitHeight
          var pw = barRoot.themePanelWidth
          var ph = 480
          if (!bar.isVertical)
            return Qt.rect(Math.max(0, (bw - pw) / 2), 0, pw, bh)
          return Qt.rect(0, Math.max(0, (bh - ph) / 2), bw, ph)
        }
        anchor.edges: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }
        anchor.gravity: {
          if (bar.position === 1) return Edges.Bottom
          if (bar.position === 2) return Edges.Left
          if (bar.position === 3) return Edges.Top
          return Edges.Right
        }

        popupW: barRoot.themePanelWidth
        popupH: 480

        panelOpen: barRoot.clockPanelOpen

        colorPanelBg:    barState.config.palettePanelBg
        colorText:       barState.config.paletteText
        colorTextDim:    barState.config.paletteTextDim
        colorAccent:     barState.config.paletteAccent
        colorProgressBg: barState.config.paletteProgressBg
        colorDivider:    barState.config.paletteDivider

        onCloseRequested: barRoot.closeAllPanels()
      }

    } // PanelWindow bar
  } // Variants
}
