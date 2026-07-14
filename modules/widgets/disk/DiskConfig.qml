import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  // Ponto de montagem monitorado — não tem UI pra isso na aba de config
  // (nenhum outro widget expõe campo de texto livre ainda), mas dá pra
  // editar direto no JSON em state/DiskWidget.json se quiser apontar pra
  // outro filesystem além da raiz.
  property string mountPoint: "/"

  property int    fontSizeValue: 32
  property string colorValue: "primary"
  property string colorWrite: "outline"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  200
  property int fixedHeight: 110

  property bool showHistory: true
  property bool showIO:      true

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/DiskWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property string mountPoint: "/"

      property int    fontSizeValue: 32
      property string colorValue: "primary"
      property string colorWrite: "outline"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  200
      property int fixedHeight: 110

      property bool showHistory: true
      property bool showIO:      true

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onMountPointChanged:    config.mountPoint    = mountPoint
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorWriteChanged:    config.colorWrite    = colorWrite
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onShowHistoryChanged:   config.showHistory   = showHistory
      onShowIOChanged:        config.showIO        = showIO
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onMountPointChanged:    adapter.mountPoint    = mountPoint
  onFontSizeValueChanged: adapter.fontSizeValue = fontSizeValue
  onColorValueChanged:    adapter.colorValue    = colorValue
  onColorWriteChanged:    adapter.colorWrite    = colorWrite
  onColorLabelChanged:    adapter.colorLabel    = colorLabel
  onColorLineChanged:     adapter.colorLine     = colorLine
  onFixedWidthChanged:    adapter.fixedWidth    = fixedWidth
  onFixedHeightChanged:   adapter.fixedHeight   = fixedHeight
  onShowHistoryChanged:   adapter.showHistory   = showHistory
  onShowIOChanged:        adapter.showIO        = showIO

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
