import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

Item {
  id: config
  visible: false

  // ── Posição (grid 3x3 da tela) ─────────────────────────────────────────
  property int position: 4
  property int edgeMargin: 48

  // ── Aparência ─────────────────────────────────────────────────────────
  property int    fontSizeValue: 36
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  // ── Tamanho fixo (não redimensiona quando os números mudam) ───────────
  property int fixedWidth:  200
  property int fixedHeight: 176

  // ── Detalhes exibidos ────────────────────────────────────────────────
  property bool showHistory: true   // sparkline com uso dos últimos ~60s
  property bool showPerCore: true   // mini-barras por núcleo
  property bool showFreq:    true   // frequência média (GHz)
  property bool showTemp:    true   // temperatura via lm-sensors
  property bool showModel:   true   // nome do modelo (ex: i7-8750H)
  property bool showGovernor: true  // governor atual (ex: performance)

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/CpuWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 36
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  200
      property int fixedHeight: 176

      property bool showHistory: true
      property bool showPerCore: true
      property bool showFreq:    true
      property bool showTemp:    true
      property bool showModel:   true
      property bool showGovernor: true

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onShowHistoryChanged:   config.showHistory   = showHistory
      onShowPerCoreChanged:   config.showPerCore   = showPerCore
      onShowFreqChanged:      config.showFreq      = showFreq
      onShowTempChanged:      config.showTemp      = showTemp
      onShowModelChanged:     config.showModel     = showModel
      onShowGovernorChanged:  config.showGovernor  = showGovernor
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onFontSizeValueChanged: adapter.fontSizeValue = fontSizeValue
  onColorValueChanged:    adapter.colorValue    = colorValue
  onColorLabelChanged:    adapter.colorLabel    = colorLabel
  onColorLineChanged:     adapter.colorLine     = colorLine
  onFixedWidthChanged:    adapter.fixedWidth    = fixedWidth
  onFixedHeightChanged:   adapter.fixedHeight   = fixedHeight
  onShowHistoryChanged:   adapter.showHistory   = showHistory
  onShowPerCoreChanged:   adapter.showPerCore   = showPerCore
  onShowFreqChanged:      adapter.showFreq      = showFreq
  onShowTempChanged:      adapter.showTemp      = showTemp
  onShowModelChanged:     adapter.showModel     = showModel
  onShowGovernorChanged:  adapter.showGovernor  = showGovernor

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  // garante que o JSON existe no disco mesmo se o usuário nunca
  // mexer em nenhum slider/toggle desse widget — sem isso,
  // writeAdapter() só dispara quando alguma propriedade muda, e o
  // arquivo nunca chega a ser criado (fica warnando pra sempre)
  Connections {
    target: StateDir
    function onReadyChanged() {
      if (StateDir.ready) {
        file.reload()
        initTimer.start()
      }
    }
  }

  Component.onCompleted: if (StateDir.ready) {
    file.reload()
    initTimer.start()
  }
}
