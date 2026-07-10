import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 5
  property int edgeMargin: 48

  property int fontSize: 13
  property int fontSizeHeader: 16
  property bool weekStartsMonday: true
  property bool showWeekNumbers: false

  property string colorToday:   "primary"
  property string colorWeekend: "on_surface"
  property string colorText:    "on_surface"

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/CalendarWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position: 5
      property int edgeMargin: 48
      property int fontSize: 13
      property int fontSizeHeader: 16
      property bool weekStartsMonday: true
      property bool showWeekNumbers: false
      property string colorToday:   "primary"
      property string colorWeekend: "on_surface"
      property string colorText:    "on_surface"

      onPositionChanged:         config.position         = position
      onEdgeMarginChanged:       config.edgeMargin        = edgeMargin
      onFontSizeChanged:         config.fontSize          = fontSize
      onFontSizeHeaderChanged:   config.fontSizeHeader    = fontSizeHeader
      onWeekStartsMondayChanged: config.weekStartsMonday  = weekStartsMonday
      onShowWeekNumbersChanged:  config.showWeekNumbers   = showWeekNumbers
      onColorTodayChanged:       config.colorToday        = colorToday
      onColorWeekendChanged:     config.colorWeekend      = colorWeekend
      onColorTextChanged:        config.colorText         = colorText
    }
  }

  onPositionChanged:         adapter.position        = position
  onEdgeMarginChanged:       adapter.edgeMargin       = edgeMargin
  onFontSizeChanged:         adapter.fontSize         = fontSize
  onFontSizeHeaderChanged:   adapter.fontSizeHeader   = fontSizeHeader
  onWeekStartsMondayChanged: adapter.weekStartsMonday = weekStartsMonday
  onShowWeekNumbersChanged:  adapter.showWeekNumbers  = showWeekNumbers
  onColorTodayChanged:       adapter.colorToday       = colorToday
  onColorWeekendChanged:     adapter.colorWeekend     = colorWeekend
  onColorTextChanged:        adapter.colorText        = colorText

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
