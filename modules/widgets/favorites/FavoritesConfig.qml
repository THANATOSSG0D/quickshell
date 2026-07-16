import QtQuick
import Quickshell
import Quickshell.Io

// ── FavoritesConfig ─────────────────────────────────────────────────────
// Config do widget de apps favoritos: lista curada de atalhos, cada item
// { id, name, command, icon }. `icon` é um nome de ícone do tema (ou
// caminho absoluto) — mesma convenção usada pelo DesktopEntries no dmenu
// (renderizado via "image://icon/<nome>"), com fallback pra avatar-letra
// quando vazio ou não resolvível. Entradas normalmente vêm da busca
// automática em DesktopEntries.applications (aba de config), mas também
// dá pra cadastrar manualmente (nome + comando, ícone opcional) pra apps
// que não têm .desktop instalado. Clique dispara `command` via `sh -c`.
// Mesmo esqueleto de BluetoothConfig.

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 20   // tamanho do ícone
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  220
  property int fixedHeight: 140

  property int columns:  4
  property int iconSize: 22

  // [{ id, name, command, icon }]
  property var apps: []

  function _uid() {
    return "a" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
  }

  function addApp(name, command, icon) {
    const a = apps.slice()
    a.push({
      id: _uid(),
      name: (name && name.trim().length > 0) ? name.trim() : "App",
      command: command || "",
      icon: icon || "",
    })
    apps = a
  }

  function removeApp(id) {
    apps = apps.filter(a => a.id !== id)
  }

  function updateApp(id, patch) {
    apps = apps.map(a => a.id === id ? Object.assign({}, a, patch) : a)
  }

  function hasCommand(command) {
    return apps.some(a => a.command === command)
  }

  function moveApp(id, dir) {
    const list = apps.slice()
    const idx = list.findIndex(a => a.id === id)
    if (idx === -1) return
    const newIdx = idx + dir
    if (newIdx < 0 || newIdx >= list.length) return
    const tmp = list[idx]; list[idx] = list[newIdx]; list[newIdx] = tmp
    apps = list
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/FavoritesWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 20
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  220
      property int fixedHeight: 140

      property int columns:  4
      property int iconSize: 22

      property var apps: []

      onPositionChanged:        config.position        = position
      onEdgeMarginChanged:      config.edgeMargin      = edgeMargin
      onFontSizeValueChanged:   config.fontSizeValue   = fontSizeValue
      onColorValueChanged:      config.colorValue      = colorValue
      onColorLabelChanged:      config.colorLabel      = colorLabel
      onColorLineChanged:       config.colorLine       = colorLine
      onFixedWidthChanged:      config.fixedWidth      = fixedWidth
      onFixedHeightChanged:     config.fixedHeight     = fixedHeight
      onColumnsChanged:         config.columns         = columns
      onIconSizeChanged:        config.iconSize        = iconSize

      onAppsChanged: {
        if (JSON.stringify(apps) !== JSON.stringify(config.apps))
          config.apps = apps
      }
    }
  }

  onPositionChanged:        adapter.position        = position
  onEdgeMarginChanged:      adapter.edgeMargin      = edgeMargin
  onFontSizeValueChanged:   adapter.fontSizeValue   = fontSizeValue
  onColorValueChanged:      adapter.colorValue      = colorValue
  onColorLabelChanged:      adapter.colorLabel      = colorLabel
  onColorLineChanged:       adapter.colorLine       = colorLine
  onFixedWidthChanged:      adapter.fixedWidth      = fixedWidth
  onFixedHeightChanged:     adapter.fixedHeight     = fixedHeight
  onColumnsChanged:         adapter.columns         = columns
  onIconSizeChanged:        adapter.iconSize        = iconSize

  onAppsChanged: {
    if (JSON.stringify(apps) !== JSON.stringify(adapter.apps))
      adapter.apps = apps
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      file.reload()
      initTimer.start()
    }
  }

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  Component.onCompleted: mkdirProc.running = true
}
