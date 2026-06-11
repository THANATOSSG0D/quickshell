import Quickshell
import Quickshell.Io
import QtQuick

// ── DmenuConfig ───────────────────────────────────────────────────────────────
// Config persistente do módulo dmenu.
// Instanciado em DmenuIpc.qml, exposto como dmenuIpc.configRef.
// Análogo ao BarConfig — lê/escreve ~/.config/quickshell/state/dmenu.json.
//
// API:
//   Leitura:  config.dmenuShowIcons  /  config["dmenuShowIcons"]
//   Escrita:  config.saveAll({ dmenuPanelWidth: 360 })   — merge + persist
//
// Consumidores:
//   DmenuIpc.qml     — dmenuPanelWidth/Height, dmenuCooldownMs, dmenuToggle
//   shell.qml        — passa para Bar (dmenuShowIcons, dmenuLaunchCmd)
//   DmenuContent.qml — dmenuMaxVisible, dmenuBackOnEmpty
//   DmenuTabConfig   — lê/escreve tudo

QtObject {
  id: root

  // ── Defaults ─────────────────────────────────────────────────────────────
  property string dmenuDefaultMode:    "drun"
  property bool   dmenuShowIcons:      true
  property int    dmenuMaxVisible:     12
  property string dmenuLaunchCmd:      "uwsm app -- {exec}"
  // Ordenação dos resultados no drun:
  //   "name"  — nome exato primeiro (comportamento original)
  //   "desc"  — descrição/comment tem peso extra (aparece antes de match parcial no nome)
  //   "usage" — apps mais usados sobem (rastreado via dmenu.json usageCount)
  property string dmenuSortMode: "name"
  // Contagem de uso por app exec — chave = exec string, valor = int
  // Usado quando dmenuSortMode = "usage"
  property var    usageCount:    ({})

  property int    dmenuPanelWidth:     320
  property int    dmenuPanelHeight:    460
  property int    dmenuPanelHeightImg: 580
  property int    dmenuPanelRadius:    14

  // Posicionamento do popup
  // popupXAlign:  "center" | "left" | "right"
  // popupYAnchor: "bar"    | "top"  | "bottom"
  // popupXOffset: px do lado (left/right) ou deslocamento do centro
  // popupYOffset: px do topo ou da base do monitor (quando yAnchor != "bar")
  property string dmenuPopupXAlign:  "center"
  property string dmenuPopupYAnchor: "bar"
  property int    dmenuPopupXOffset: 0
  property int    dmenuPopupYOffset: 0

  property bool   dmenuToggle:         true
  property bool   dmenuBackOnEmpty:    true
  property bool   dmenuPasswordMask:   true
  property int    dmenuCooldownMs:     450

  // ── Estado interno ────────────────────────────────────────────────────────
  property bool _ready:        false
  property bool _configLoaded: false
  property bool _parsing:      false

  readonly property string _configPath: {
    // Qt.resolvedUrl resolve relativo ao arquivo QML em modules/default/dmenu/state/
    // ../../../../state/ = quickshell/state/
    var url = Qt.resolvedUrl("../../../state/dmenu.json").toString()
    return url.replace(/^file:\/\//, "")
  }

  // ── I/O ───────────────────────────────────────────────────────────────────
  property FileView _file: FileView {
    path:         root._configPath
    watchChanges: false

    onLoaded: {
      if (root._parsing) return
      root._parsing = true

      var raw = this.text().trim()
      if (raw !== "") {
        try {
          _applyFromJson(JSON.parse(raw))
        } catch(e) {
          console.warn("[DmenuConfig] JSON inválido em", root._configPath, "—", e)
        }
      }

      root._configLoaded = true
      root._parsing      = false
      root._ready        = true
    }
  }

  Component.onCompleted: {
    // Defaults já são válidos — marca ready imediatamente
    // Se o arquivo existir, onLoaded sobrescreve com os valores persistidos
    root._ready = true
    _file.reload()
  }

  // ── _applyFromJson ────────────────────────────────────────────────────────
  function _applyFromJson(obj) {
    if (obj.dmenuDefaultMode    !== undefined) root.dmenuDefaultMode    = obj.dmenuDefaultMode
    if (obj.dmenuShowIcons      !== undefined) root.dmenuShowIcons      = !!obj.dmenuShowIcons
    if (obj.dmenuMaxVisible     !== undefined) root.dmenuMaxVisible     = obj.dmenuMaxVisible    | 0
    if (obj.dmenuLaunchCmd      !== undefined) root.dmenuLaunchCmd      = obj.dmenuLaunchCmd
    if (obj.dmenuPanelWidth     !== undefined) root.dmenuPanelWidth     = obj.dmenuPanelWidth    | 0
    if (obj.dmenuPanelHeight    !== undefined) root.dmenuPanelHeight    = obj.dmenuPanelHeight   | 0
    if (obj.dmenuPanelHeightImg !== undefined) root.dmenuPanelHeightImg = obj.dmenuPanelHeightImg| 0
    if (obj.dmenuPanelRadius    !== undefined) root.dmenuPanelRadius    = obj.dmenuPanelRadius   | 0
    if (obj.dmenuPopupXAlign    !== undefined) root.dmenuPopupXAlign    = obj.dmenuPopupXAlign
    if (obj.dmenuPopupYAnchor   !== undefined) root.dmenuPopupYAnchor   = obj.dmenuPopupYAnchor
    if (obj.dmenuPopupXOffset   !== undefined) root.dmenuPopupXOffset   = obj.dmenuPopupXOffset  | 0
    if (obj.dmenuPopupYOffset   !== undefined) root.dmenuPopupYOffset   = obj.dmenuPopupYOffset  | 0
    if (obj.dmenuToggle         !== undefined) root.dmenuToggle         = !!obj.dmenuToggle
    if (obj.dmenuBackOnEmpty    !== undefined) root.dmenuBackOnEmpty    = !!obj.dmenuBackOnEmpty
    if (obj.dmenuPasswordMask   !== undefined) root.dmenuPasswordMask   = !!obj.dmenuPasswordMask
    if (obj.dmenuCooldownMs     !== undefined) root.dmenuCooldownMs     = obj.dmenuCooldownMs    | 0
    if (obj.dmenuSortMode       !== undefined) root.dmenuSortMode       = obj.dmenuSortMode
    if (obj.usageCount          !== undefined) root.usageCount          = obj.usageCount
  }

  // ── recordUsage — incrementa contador de uso de um app ──────────────────
  // Chamado por DmenuContent após lançar em modo drun com sortMode="usage"
  function recordUsage(execKey) {
    if (!execKey || execKey === "") return
    var c = Object.assign({}, root.usageCount)
    c[execKey] = (c[execKey] || 0) + 1
    root.usageCount = c
    if (root._ready) _write()
  }

  // ── saveAll — merge + persist ─────────────────────────────────────────────
  function saveAll(opts) {
    if (!root._ready) return
    _applyFromJson(opts)
    _write()
  }

  // ── _write ────────────────────────────────────────────────────────────────
  function _write() {
    _file.setText(JSON.stringify({
      dmenuDefaultMode:    root.dmenuDefaultMode,
      dmenuShowIcons:      root.dmenuShowIcons,
      dmenuMaxVisible:     root.dmenuMaxVisible,
      dmenuLaunchCmd:      root.dmenuLaunchCmd,
      dmenuPanelWidth:     root.dmenuPanelWidth,
      dmenuPanelHeight:    root.dmenuPanelHeight,
      dmenuPanelHeightImg: root.dmenuPanelHeightImg,
      dmenuPanelRadius:    root.dmenuPanelRadius,
      dmenuPopupXAlign:    root.dmenuPopupXAlign,
      dmenuPopupYAnchor:   root.dmenuPopupYAnchor,
      dmenuPopupXOffset:   root.dmenuPopupXOffset,
      dmenuPopupYOffset:   root.dmenuPopupYOffset,
      dmenuToggle:         root.dmenuToggle,
      dmenuBackOnEmpty:    root.dmenuBackOnEmpty,
      dmenuPasswordMask:   root.dmenuPasswordMask,
      dmenuCooldownMs:     root.dmenuCooldownMs,
      dmenuSortMode:       root.dmenuSortMode,
      usageCount:          root.usageCount,
    }, null, 2))
    _file.write()
  }
}
