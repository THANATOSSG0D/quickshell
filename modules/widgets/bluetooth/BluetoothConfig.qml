import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 28
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  200
  property int fixedHeight: 130

  property bool showDeviceNames: true
  property bool showBattery:     true

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/BluetoothWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 28
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  200
      property int fixedHeight: 130

      property bool showDeviceNames: true
      property bool showBattery:     true

      onPositionChanged:        config.position        = position
      onEdgeMarginChanged:      config.edgeMargin      = edgeMargin
      onFontSizeValueChanged:   config.fontSizeValue   = fontSizeValue
      onColorValueChanged:      config.colorValue      = colorValue
      onColorLabelChanged:      config.colorLabel      = colorLabel
      onColorLineChanged:       config.colorLine       = colorLine
      onFixedWidthChanged:      config.fixedWidth      = fixedWidth
      onFixedHeightChanged:     config.fixedHeight     = fixedHeight
      onShowDeviceNamesChanged: config.showDeviceNames = showDeviceNames
      onShowBatteryChanged:     config.showBattery     = showBattery
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
  onShowDeviceNamesChanged: adapter.showDeviceNames = showDeviceNames
  onShowBatteryChanged:     adapter.showBattery     = showBattery

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
