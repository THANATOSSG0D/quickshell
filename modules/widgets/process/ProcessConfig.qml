import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int fixedWidth:  220
  property int fixedHeight: 170

  property int    fontSizeValue: 12
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property string sortBy: "cpu"  // "cpu" | "ram" — alternável clicando no próprio widget
  property int    count:  5      // quantos processos mostrar

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/ProcessWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int fixedWidth:  220
      property int fixedHeight: 170

      property int    fontSizeValue: 12
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property string sortBy: "cpu"
      property int    count:  5

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onSortByChanged:        config.sortBy        = sortBy
      onCountChanged:         config.count         = count
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
  onSortByChanged:        adapter.sortBy        = sortBy
  onCountChanged:         adapter.count         = count

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  // garante que o JSON existe no disco mesmo se o usuário nunca
  // mexer em nenhum slider/toggle desse widget — sem isso,
  // writeAdapter() só dispara quando alguma propriedade muda, e o
  // arquivo nunca chega a ser criado (fica warnando pra sempre)
  Component.onCompleted: StateDir.whenReady(() => {
    file.reload()
    initTimer.start()
  })
}
