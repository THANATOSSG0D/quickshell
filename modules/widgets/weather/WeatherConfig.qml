import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 2
  property int edgeMargin: 48

  // Belo Horizonte como padrão — ajuste em Config UI → Widgets → Clima
  property real latitude:  -19.9167
  property real longitude: -43.9345
  property string cityLabel: "Belo Horizonte"

  // celsius | fahrenheit
  property string units: "celsius"
  property int updateIntervalMin: 15

  property int fontSizeTemp: 48
  property int fontSizeDesc: 14
  property bool showFeelsLike: true
  property bool showIcon: true

  property string colorTemp: "primary"
  property string colorDesc: "on_surface"

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/WeatherWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position: 2
      property int edgeMargin: 48
      property real latitude:  -19.9167
      property real longitude: -43.9345
      property string cityLabel: "Belo Horizonte"
      property string units: "celsius"
      property int updateIntervalMin: 15
      property int fontSizeTemp: 48
      property int fontSizeDesc: 14
      property bool showFeelsLike: true
      property bool showIcon: true
      property string colorTemp: "primary"
      property string colorDesc: "on_surface"

      onPositionChanged:          config.position          = position
      onEdgeMarginChanged:        config.edgeMargin         = edgeMargin
      onLatitudeChanged:          config.latitude           = latitude
      onLongitudeChanged:         config.longitude          = longitude
      onCityLabelChanged:         config.cityLabel          = cityLabel
      onUnitsChanged:             config.units              = units
      onUpdateIntervalMinChanged: config.updateIntervalMin  = updateIntervalMin
      onFontSizeTempChanged:      config.fontSizeTemp       = fontSizeTemp
      onFontSizeDescChanged:      config.fontSizeDesc       = fontSizeDesc
      onShowFeelsLikeChanged:     config.showFeelsLike      = showFeelsLike
      onShowIconChanged:          config.showIcon           = showIcon
      onColorTempChanged:         config.colorTemp          = colorTemp
      onColorDescChanged:         config.colorDesc          = colorDesc
    }
  }

  onPositionChanged:          adapter.position         = position
  onEdgeMarginChanged:        adapter.edgeMargin        = edgeMargin
  onLatitudeChanged:          adapter.latitude          = latitude
  onLongitudeChanged:         adapter.longitude         = longitude
  onCityLabelChanged:         adapter.cityLabel         = cityLabel
  onUnitsChanged:             adapter.units             = units
  onUpdateIntervalMinChanged: adapter.updateIntervalMin = updateIntervalMin
  onFontSizeTempChanged:      adapter.fontSizeTemp      = fontSizeTemp
  onFontSizeDescChanged:      adapter.fontSizeDesc      = fontSizeDesc
  onShowFeelsLikeChanged:     adapter.showFeelsLike     = showFeelsLike
  onShowIconChanged:          adapter.showIcon          = showIcon
  onColorTempChanged:         adapter.colorTemp         = colorTemp
  onColorDescChanged:         adapter.colorDesc         = colorDesc

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
