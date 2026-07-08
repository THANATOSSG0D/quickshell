import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  // ── Posição (grid 3x3 da tela) ─────────────────────────────────────────
  property int position: 4
  // Margem entre o widget e a borda da tela, em px
  property int edgeMargin: 48

  // ── Hora ──────────────────────────────────────────────────────────────
  property int    fontSizeTime: 72
  property bool   use24h:       true
  // chave de paleta (ex: "primary", "on_surface", "outline" — mesmas usadas
  // pelo CfgPalette em outras abas do config)
  property string colorTime: "primary"

  // ── Data ──────────────────────────────────────────────────────────────
  property bool   showDate:     true
  property int    fontSizeDate: 16
  property string dateFormat:   "dddd · MMM dd"
  property string colorDate:    "on_surface"

  // ── Linha divisória entre hora e data ────────────────────────────────
  property bool   showLine:  true
  property string colorLine: "outline"

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/ClockWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeTime: 72
      property bool   use24h:       true
      property string colorTime:    "primary"

      property bool   showDate:     true
      property int    fontSizeDate: 16
      property string dateFormat:   "dddd · MMM dd"
      property string colorDate:    "on_surface"

      property bool   showLine:  true
      property string colorLine: "outline"

      onPositionChanged:     config.position     = position
      onEdgeMarginChanged:   config.edgeMargin   = edgeMargin
      onFontSizeTimeChanged: config.fontSizeTime = fontSizeTime
      onUse24hChanged:       config.use24h       = use24h
      onColorTimeChanged:    config.colorTime    = colorTime
      onShowDateChanged:     config.showDate     = showDate
      onFontSizeDateChanged: config.fontSizeDate = fontSizeDate
      onDateFormatChanged:   config.dateFormat   = dateFormat
      onColorDateChanged:    config.colorDate    = colorDate
      onShowLineChanged:     config.showLine     = showLine
      onColorLineChanged:    config.colorLine    = colorLine
    }
  }

  onPositionChanged:     adapter.position     = position
  onEdgeMarginChanged:   adapter.edgeMargin   = edgeMargin
  onFontSizeTimeChanged: adapter.fontSizeTime = fontSizeTime
  onUse24hChanged:       adapter.use24h       = use24h
  onColorTimeChanged:    adapter.colorTime    = colorTime
  onShowDateChanged:     adapter.showDate     = showDate
  onFontSizeDateChanged: adapter.fontSizeDate = fontSizeDate
  onDateFormatChanged:   adapter.dateFormat   = dateFormat
  onColorDateChanged:    adapter.colorDate    = colorDate
  onShowLineChanged:     adapter.showLine     = showLine
  onColorLineChanged:    adapter.colorLine    = colorLine

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
