import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 4

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/ClockWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position: 4
      onPositionChanged: config.position = position
    }
  }

  onPositionChanged: adapter.position = position

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: file.reload()
  }

  Component.onCompleted: mkdirProc.running = true
}
