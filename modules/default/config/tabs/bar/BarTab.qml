import QtQuick
import './bar' as Bar

// BarTab — router das subabas da Barra.
// Recebe o estado legado do ConfigWindow (props individuais) e
// constrói um shim de `config` compatível com os novos subtabs.

Item {
  id: root

  // ── Cores ─────────────────────────────────────────────────────────────
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorProgressBg
  required property color colorSidebar
  required property color colorDivider
  required property color colorError
  required property var   colors
  required property var   overlay

  // ── Subaba ativa ──────────────────────────────────────────────────────
  required property int activeSubtab

  // ── Contrato do tema ativo ───────────────────────────────────────────
  // JSON de <Tema>_contract.json já parseado (com "bar"/"palette"/"modules").
  // Repassado pra BarTabBar (filtra campos de dimensão/paleta) e
  // BarTabModulos (filtra quais módulos aparecem na pool pra adicionar).
  // Default {} = fail-open: sem contrato, tudo aparece (comportamento
  // antigo preservado enquanto o ConfigWindow não estiver passando isso).
  property var contract: ({})

  // ── Geral ─────────────────────────────────────────────────────────────
  required property string localTheme
  required property int    localPosition
  required property bool   localAutoHide
  required property bool   localSilence
  required property int    localBarSize
  required property int    localBarMargin
  required property int    localPillWidth
  required property int    localPillMinSpacing

  // ── Módulos ───────────────────────────────────────────────────────────
  required property var slotLeft
  required property var slotCenter
  required property var slotRight
  required property var slotTop
  required property var slotMiddle
  required property var slotBottom

  // ── Workspaces ────────────────────────────────────────────────────────
  required property string localWsStyle
  required property string localWsSort
  required property bool   localWsMono
  required property int    localWsSpacing
  required property bool   localWsAddBtn

  // ── Clock ─────────────────────────────────────────────────────────────
  required property string pkClkText
  required property string pkClkDim
  required property string pkClkAccent
  required property int    localClkDismiss

  // ── Volume ────────────────────────────────────────────────────────────
  required property bool   localShowSink
  required property bool   localShowSource
  required property string pkVolMuted

  // ── Mídia ─────────────────────────────────────────────────────────────
  required property string localMpTextMode
  required property int    localMpScrollSpeed
  required property int    localMpScrollWidth
  required property bool   localMpBgEnabled
  required property string pkMpBgColor
  required property string pkMpBgActive
  required property string pkMpText
  required property string pkMpDim
  required property string pkMpTextActive
  required property string pkMpDimActive

  // ── Paleta ────────────────────────────────────────────────────────────
  required property string pkBarBg
  required property string pkBarBgPill
  required property string pkText
  required property string pkTextDim
  required property string pkAccent
  required property string pkAccentBg
  required property string pkPanelBg
  required property string pkProgressBg
  required property string pkProgressFg
  required property string pkDivider

  signal changed(var opts)

  // ── Config shim ───────────────────────────────────────────────────────
  // Objeto fake com get(moduleId, key) que serve os novos subtabs
  // sem precisar mudar o ConfigWindow.
  readonly property QtObject _cfg: QtObject {
    function get(moduleId, key) {
      // bar / geral
      if (moduleId === "bar") {
        if (key === "theme")          return root.localTheme
        if (key === "position")       return root.localPosition
        if (key === "autoHide")       return root.localAutoHide
        if (key === "silenceMode")    return root.localSilence
        if (key === "barSize")        return root.localBarSize
        if (key === "barMargin")      return root.localBarMargin
        if (key === "pillWidth")      return root.localPillWidth
        if (key === "pillMinSpacing") return root.localPillMinSpacing
      }
      // workspaces
      if (moduleId === "workspaces") {
        if (key === "style")          return root.localWsStyle
        if (key === "iconsSort")      return root.localWsSort
        if (key === "iconMonochrome") return root.localWsMono
        if (key === "iconSpacing")    return root.localWsSpacing
        if (key === "showAddButton")  return root.localWsAddBtn
        // novos campos — defaults
        if (key === "bgOpacity")             return 0.0
        if (key === "bgOpacityActive")       return 0.18
        if (key === "bgPaddingH")            return 6
        if (key === "bgPaddingV")            return 3
        if (key === "bgPaddingHActive")      return 8
        if (key === "bgPaddingVActive")      return 4
        if (key === "bgRadiusActive")        return 6
        if (key === "bgBorderWidthActive")   return 0
        if (key === "bgColor")               return "surface_variant"
        if (key === "bgColorActive")         return "primary"
        if (key === "bgBorderColor")         return "outline_variant"
        if (key === "bgBorderColorActive")   return "primary"
        if (key === "dotColor")              return "on_surface_variant"
        if (key === "dotActiveColor")        return "primary"
        if (key === "dotOccupiedColor")      return "secondary"
        if (key === "dotUrgentColor")        return "error"
        if (key === "iconMonoColor")         return "on_surface_variant"
        if (key === "iconMonoColorActive")   return "on_primary"
      }
      // clock
      if (moduleId === "clock") {
        if (key === "textColor")      return root.pkClkText
        if (key === "dimColor")       return root.pkClkDim
        if (key === "accentColor")    return root.pkClkAccent
        if (key === "dismissDelayMs") return root.localClkDismiss
      }
      // volume
      if (moduleId === "volume") {
        if (key === "showSink")   return root.localShowSink
        if (key === "showSource") return root.localShowSource
        if (key === "mutedColor") return root.pkVolMuted
        if (key === "maxVol")     return 1.5
        if (key === "textColor")  return "on_surface"
        if (key === "dimColor")   return "on_surface_variant"
        if (key === "accentColor")return "primary"
        if (key === "progressBg") return "outline_variant"
      }
      // mediaplayer
      if (moduleId === "mediaplayer") {
        if (key === "textMode")        return root.localMpTextMode
        if (key === "scrollSpeed")     return root.localMpScrollSpeed
        if (key === "scrollWidth")     return root.localMpScrollWidth
        if (key === "bgEnabled")       return root.localMpBgEnabled
        if (key === "bgColor")         return root.pkMpBgColor
        if (key === "bgColorActive")   return root.pkMpBgActive
        if (key === "textColor")       return root.pkMpText
        if (key === "dimColor")        return root.pkMpDim
        if (key === "textColorActive") return root.pkMpTextActive
        if (key === "dimColorActive")  return root.pkMpDimActive
        if (key === "bgOpacity")       return 0.7
        if (key === "bgOpacityActive") return 0.9
        if (key === "bgPaddingH")      return 8
        if (key === "bgPaddingV")      return 4
      }
      // palette
      if (moduleId === "palette") {
        if (key === "barBg")      return root.pkBarBg
        if (key === "barBgPill")  return root.pkBarBgPill
        if (key === "text")       return root.pkText
        if (key === "textDim")    return root.pkTextDim
        if (key === "accent")     return root.pkAccent
        if (key === "accentBg")   return root.pkAccentBg
        if (key === "accentText") return "on_primary"
        if (key === "panelBg")    return root.pkPanelBg
        if (key === "progressBg") return root.pkProgressBg
        if (key === "progressFg") return root.pkProgressFg
        if (key === "divider")    return root.pkDivider
      }
      return undefined
    }
  }

  // ── Tradução changed({moduleId, key, value}) → opts legado ───────────
  function _translate(opts) {
    // subtabs novos emitem {moduleId, key, value}; os legados emitem opts direto
    if (opts && opts.moduleId !== undefined) {
      var mid = opts.moduleId, k = opts.key, v = opts.value
      var out = {}
      // bar
      if (mid === "bar") {
        if (k === "theme")          { out.theme         = v; return out }
        if (k === "position")       { out.position      = v; return out }
        if (k === "autoHide")       { out.autoHide      = v; return out }
        if (k === "silenceMode")    { out.silence        = v; return out }
        if (k === "barSize")        { out.barSize        = v; return out }
        if (k === "barMargin")      { out.barMargin      = v; return out }
        if (k === "pillWidth")      { out.pillWidth      = v; return out }
        if (k === "pillMinSpacing") { out.pillMinSpacing = v; return out }
      }
      // workspaces
      if (mid === "workspaces") {
        if (k === "style")          { out.wsStyle         = v; return out }
        if (k === "iconsSort")      { out.wsIconsSort     = v; return out }
        if (k === "iconMonochrome") { out.wsIconMonochrome = v; return out }
        if (k === "iconSpacing")    { out.wsIconSpacing    = v; return out }
        if (k === "showAddButton")  { out.wsShowAddButton  = v; return out }
        // novos campos — ignorar silenciosamente (sem chave legada)
        return null
      }
      // clock
      if (mid === "clock") {
        if (k === "textColor")      { out.pkClkText       = v; return out }
        if (k === "dimColor")       { out.pkClkDim        = v; return out }
        if (k === "accentColor")    { out.pkClkAccent     = v; return out }
        if (k === "dismissDelayMs") { out.localClkDismiss = v; return out }
      }
      // volume
      if (mid === "volume") {
        if (k === "showSink")   { out.localShowSink   = v; return out }
        if (k === "showSource") { out.localShowSource  = v; return out }
        if (k === "mutedColor") { out.pkVolMuted       = v; return out }
        // novos campos (maxVol, textColor, etc.) — sem chave legada
        return null
      }
      // mediaplayer
      if (mid === "mediaplayer") {
        if (k === "textMode")        { out.mpTextMode     = v; return out }
        if (k === "scrollSpeed")     { out.mpScrollSpeed   = v; return out }
        if (k === "scrollWidth")     { out.mpScrollWidth   = v; return out }
        if (k === "bgEnabled")       { out.mpBgEnabled     = v; return out }
        if (k === "bgColor")         { out.pkMpBgColor     = v; return out }
        if (k === "bgColorActive")   { out.pkMpBgActive    = v; return out }
        if (k === "textColor")       { out.pkMpText        = v; return out }
        if (k === "dimColor")        { out.pkMpDim         = v; return out }
        if (k === "textColorActive") { out.pkMpTextActive  = v; return out }
        if (k === "dimColorActive")  { out.pkMpDimActive   = v; return out }
        return null
      }
      // palette
      if (mid === "palette") {
        if (k === "barBg")      { out.pkBarBg      = v; return out }
        if (k === "barBgPill")  { out.pkBarBgPill  = v; return out }
        if (k === "text")       { out.pkText        = v; return out }
        if (k === "textDim")    { out.pkTextDim     = v; return out }
        if (k === "accent")     { out.pkAccent      = v; return out }
        if (k === "accentBg")   { out.pkAccentBg    = v; return out }
        if (k === "panelBg")    { out.pkPanelBg     = v; return out }
        if (k === "progressBg") { out.pkProgressBg  = v; return out }
        if (k === "progressFg") { out.pkProgressFg  = v; return out }
        if (k === "divider")    { out.pkDivider     = v; return out }
        return null
      }
      return null
    }
    // opts legado — repassar direto (BarTabGeral, BarTabModulos)
    return opts
  }

  function _emit(opts) {
    var out = _translate(opts)
    if (out) root.changed(out)
  }

  // ── Subtab 0 — Geral ─────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 0
    sourceComponent: Bar.BarTabGeral {
      config:          root._cfg
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorProgressBg: root.colorProgressBg
      onChanged: (opts) => root._emit(opts)
    }
  }

  // ── Subtab 1 — Módulos ────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 1
    sourceComponent: Bar.BarTabModulos {
      config:      root._cfg
      contract:    root.contract
      isH:         root.localPosition === 1 || root.localPosition === 3
      slotLeft:    root.slotLeft;   slotCenter: root.slotCenter; slotRight: root.slotRight
      slotTop:     root.slotTop;    slotMiddle: root.slotMiddle; slotBottom: root.slotBottom
      colorAccent:  root.colorAccent; colorTextDim: root.colorTextDim
      colorText:    root.colorText;   colorDivider: root.colorDivider
      onSlotChanged: (slot, arr) => {
        var opts = {}
        var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
        opts[key] = arr
        root.changed(opts)
      }
      onModuleAdded: (slot, id) => {
        var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
        var opts = {}
        opts[key] = root["slot" + slot.charAt(0).toUpperCase() + slot.slice(1)].concat([id])
        root.changed(opts)
      }
    }
  }

  // ── Subtab 2 — Workspaces ─────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 2
    sourceComponent: Bar.BarTabWorkspaces {
      config:          root._cfg
      colors:          root.colors
      overlay:         root.overlay
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorProgressBg: root.colorProgressBg
      colorSidebar:    root.colorSidebar
      colorDivider:    root.colorDivider
      onChanged: (opts) => root._emit(opts)
    }
  }

  // ── Subtab 3 — Relógio ────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 3
    sourceComponent: Bar.BarTabClock {
      config:          root._cfg
      colors:          root.colors
      overlay:         root.overlay
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorProgressBg: root.colorProgressBg
      colorSidebar:    root.colorSidebar
      colorDivider:    root.colorDivider
      onChanged: (opts) => root._emit(opts)
    }
  }

  // ── Subtab 4 — Volume ─────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 4
    sourceComponent: Bar.BarTabVolume {
      config:          root._cfg
      colors:          root.colors
      overlay:         root.overlay
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorError:      root.colorError
      colorSidebar:    root.colorSidebar
      colorDivider:    root.colorDivider
      colorProgressBg: root.colorProgressBg
      onChanged: (opts) => root._emit(opts)
    }
  }

  // ── Subtab 5 — Mídia ──────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 5
    sourceComponent: Bar.BarTabMidia {
      config:          root._cfg
      colors:          root.colors
      overlay:         root.overlay
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorProgressBg: root.colorProgressBg
      colorSidebar:    root.colorSidebar
      colorDivider:    root.colorDivider
      onChanged: (opts) => root._emit(opts)
    }
  }

  // ── Subtab 6 — Paleta ─────────────────────────────────────────────────
  // Era "Bar.BarTabPaleta" — componente que não existe (o real, com toda a
  // lógica de visibilidade por contrato, é BarTabBar.qml) — e nunca
  // recebia `contract`, então o filtro de paleta nunca rodava de verdade.
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 6
    sourceComponent: Bar.BarTabBar {
      config:          root._cfg
      contract:        root.contract
      colors:          root.colors
      overlay:         root.overlay
      colorAccent:     root.colorAccent
      colorTextDim:    root.colorTextDim
      colorText:       root.colorText
      colorProgressBg: root.colorProgressBg
      colorSidebar:    root.colorSidebar
      colorDivider:    root.colorDivider
      onChanged: (opts) => root._emit(opts)
    }
  }
}
