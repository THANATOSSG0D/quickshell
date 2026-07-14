import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 36
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  200
  property int fixedHeight: 110

  property bool showHistory: true
  property bool showSwap:    true

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/RamWidget.json"
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
      property int fixedHeight: 110

      property bool showHistory: true
      property bool showSwap:    true

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onShowHistoryChanged:   config.showHistory   = showHistory
      onShowSwapChanged:      config.showSwap      = showSwap
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
  onShowSwapChanged:      adapter.showSwap      = showSwap

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      file.reload()
      // garante que o JSON existe no disco mesmo se o usuário nunca
      // mexer em nenhum slider/toggle desse widget — sem isso,
      // writeAdapter() só dispara quando alguma propriedade muda, e o
      // arquivo nunca chega a ser criado (fica warnando pra sempre)
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
