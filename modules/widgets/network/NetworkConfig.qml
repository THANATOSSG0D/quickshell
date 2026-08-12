import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 20
  property string colorValue: "primary"
  property string colorUp:    "outline"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  200
  property int fixedHeight: 150

  property bool showHistory: true
  property bool showIface:   true  // nome da interface / SSID
  property bool showIP:      true  // IP local
  property bool showDNS:     true  // servidores DNS (/etc/resolv.conf)
  property bool showVPN:     true  // conexão VPN ativa

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/NetworkWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 20
      property string colorValue: "primary"
      property string colorUp:    "outline"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  200
      property int fixedHeight: 150

      property bool showHistory: true
      property bool showIface:   true
      property bool showIP:      true
      property bool showDNS:     true
      property bool showVPN:     true

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorUpChanged:       config.colorUp       = colorUp
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onShowHistoryChanged:   config.showHistory   = showHistory
      onShowIfaceChanged:     config.showIface     = showIface
      onShowIPChanged:        config.showIP        = showIP
      onShowDNSChanged:       config.showDNS       = showDNS
      onShowVPNChanged:       config.showVPN       = showVPN
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onFontSizeValueChanged: adapter.fontSizeValue = fontSizeValue
  onColorValueChanged:    adapter.colorValue    = colorValue
  onColorUpChanged:       adapter.colorUp       = colorUp
  onColorLabelChanged:    adapter.colorLabel    = colorLabel
  onColorLineChanged:     adapter.colorLine     = colorLine
  onFixedWidthChanged:    adapter.fixedWidth    = fixedWidth
  onFixedHeightChanged:   adapter.fixedHeight   = fixedHeight
  onShowHistoryChanged:   adapter.showHistory   = showHistory
  onShowIfaceChanged:     adapter.showIface     = showIface
  onShowIPChanged:        adapter.showIP        = showIP
  onShowDNSChanged:       adapter.showDNS       = showDNS
  onShowVPNChanged:       adapter.showVPN       = showVPN

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
