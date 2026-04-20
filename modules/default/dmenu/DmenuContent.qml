import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property string mode: "drun"

  property color colorPanelBg: "#1f1f1f"
  property color colorText:    "#e2e2e2"
  property color colorTextDim: "#c6c6c6"
  property color colorAccent:  "#ffb4a9"
  property color colorDivider: "#474747"
  property color colorInputBg: "#131313"

  signal closeRequested()

  property string _query:       ""
  property int    _selectedIdx: 0
  property var    _dynamicList: []
  property bool   _loading:     false

  readonly property var _allApps: {
    var apps = DesktopEntries.applications.values
    var list = []
    for (var i = 0; i < apps.length; i++) {
      var a = apps[i]
      if (!a) continue
      var name = (a.name || "").trim()
      if (name === "") continue
      list.push({ name: name, app: a })
    }
    list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    console.log("[Dmenu] _allApps rebuilt:", list.length, "apps")
    return list
  }

  Process {
    id: loader
    running: false

    onRunningChanged: console.log("[Dmenu] loader.running →", running, "| cmd:", JSON.stringify(command))

    stdout: StdioCollector {
      onStreamFinished: {
        console.log("[Dmenu] StdioCollector finished, text length:", this.text.length)
        console.log("[Dmenu] raw output (first 300):", this.text.substring(0, 300))
        var lines = this.text.split("\n")
        var list = []
        for (var i = 0; i < lines.length; i++) {
          var t = lines[i].trim()
          if (t !== "") list.push({ display: t })
        }
        console.log("[Dmenu] parsed", list.length, "items")
        root._dynamicList = list
        root._loading = false
      }
    }

    onExited: (code, status) => {
      console.log("[Dmenu] loader exited code:", code, "status:", status)
    }
  }

  function _load() {
    console.log("[Dmenu] _load() called, mode:", mode)
    root._dynamicList = []
    root._loading = true

    if (mode === "window") {
      loader.command = ["bash", "-c",
        "hyprctl clients -j 2>/dev/null | python3 -c \"" +
        "import sys,json;" +
        "data=json.load(sys.stdin);" +
        "[print(c['class']+'  ->  '+c['title']+'\\t'+c['address'])" +
        " for c in data if c.get('class')]\""]
    } else if (mode === "run") {
      loader.command = ["bash", "-c",
        "grep '^- cmd:' ~/.local/share/fish/fish_history" +
        " | sed 's/^- cmd: //'" +
        " | awk '!seen[$0]++'" +
        " | tac 2>/dev/null || " +
        "grep '^- cmd:' ~/.local/share/fish/fish_history" +
        " | sed 's/^- cmd: //'" +
        " | awk '!seen[$0]++'" +
        " | tail -r"]
    }

    console.log("[Dmenu] command set:", JSON.stringify(loader.command))
    loader.running = false
    loader.running = true
    console.log("[Dmenu] loader.running set to true")
  }

  Process { id: runProc; running: false }

  function _launch() {
    var items = _displayList
    var sel = items[_selectedIdx]

    if (mode === "drun") {
      if (!sel) return
      sel.app.execute()
      root.closeRequested()
      return
    }

    if (mode === "run") {
      var cmd = _query.trim() !== "" ? _query.trim()
              : (sel ? sel.display : "")
      if (cmd === "") return
      runProc.command = ["bash", "-c", cmd + " &"]
      runProc.running = true
      root.closeRequested()
      return
    }

    if (mode === "window") {
      if (!sel) return
      var parts = sel.display.split("\t")
      var addr  = parts.length > 1 ? parts[1].trim() : ""
      if (addr === "") return
      runProc.command = ["bash", "-c", "hyprctl dispatch focuswindow address:" + addr]
      runProc.running = true
      root.closeRequested()
      return
    }
  }

  readonly property var _sourceList: {
    if (mode === "drun") return _allApps
    return _dynamicList
  }

  readonly property var _displayList: {
    if (_query === "") return _sourceList
    var q = _query.toLowerCase()
    return _sourceList.filter(function(item) {
      var label = mode === "drun" ? item.name : item.display
      return label.toLowerCase().indexOf(q) !== -1
    })
  }

  on_DisplayListChanged: {
    _selectedIdx = 0
    listView.positionViewAtIndex(0, ListView.Beginning)
  }

  function _visibleLabel(item) {
    if (mode === "drun")   return item.name
    if (mode === "window") return item.display.split("\t")[0]
    return item.display
  }

  function activate() {
    console.log("[Dmenu] activate(), mode:", mode)
    _query = ""
    inputField.text = ""
    _selectedIdx = 0
    if (mode === "window" || mode === "run") _load()
    Qt.callLater(function() { inputField.forceActiveFocus() })
  }

  // activate() é chamado pelo DmenuPopup via onPanelOpenChanged

  focus: true
  Keys.onPressed: function(ev) {
    if (ev.key === Qt.Key_Escape) {
      root.closeRequested(); ev.accepted = true
    } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
      _launch(); ev.accepted = true
    } else if (ev.key === Qt.Key_Down ||
               (ev.key === Qt.Key_N && (ev.modifiers & Qt.ControlModifier))) {
      if (_selectedIdx < _displayList.length - 1) {
        _selectedIdx++
        listView.positionViewAtIndex(_selectedIdx, ListView.Contain)
      }
      ev.accepted = true
    } else if (ev.key === Qt.Key_Up ||
               (ev.key === Qt.Key_P && (ev.modifiers & Qt.ControlModifier))) {
      if (_selectedIdx > 0) {
        _selectedIdx--
        listView.positionViewAtIndex(_selectedIdx, ListView.Contain)
      }
      ev.accepted = true
    } else if (ev.key === Qt.Key_Tab) {
      if (_displayList.length > 0) {
        var label = _visibleLabel(_displayList[_selectedIdx])
        inputField.text = label
        _query = label
        inputField.cursorPosition = label.length
      }
      ev.accepted = true
    }
  }

  ColumnLayout {
    anchors.fill:    parent
    anchors.margins: 10
    spacing:         6

    Rectangle {
      Layout.fillWidth: true
      height: 36; radius: 7
      color:  Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.85)

      RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        Text {
          text:  mode === "drun" ? "APPS" : mode === "run" ? "RUN" : "WIN"
          color: root.colorAccent
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
          verticalAlignment: Text.AlignVCenter
        }

        Rectangle { width: 1; height: 14; color: root.colorDivider }

        TextInput {
          id:               inputField
          Layout.fillWidth: true
          color:            root.colorText
          selectionColor:   Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
          selectedTextColor: root.colorText
          font { family: "Fira Sans"; pixelSize: 12 }
          verticalAlignment: TextInput.AlignVCenter
          height: parent.height

          Text {
            anchors.fill: parent
            text: mode === "run" ? "comando ou histórico..." : mode === "window" ? "pesquisar janela..." : "pesquisar app..."
            color: root.colorTextDim; font: inputField.font
            opacity: 0.4; verticalAlignment: Text.AlignVCenter
            visible: inputField.text === ""
          }

          onTextChanged: { root._query = text; root._selectedIdx = 0 }
          Keys.forwardTo: [root]
        }

        Text {
          visible: root._loading
          text: "..."
          color: root.colorTextDim
          font { pixelSize: 14 }
          opacity: 0.5
        }

        Text {
          visible: !root._loading && _displayList.length > 0
          text:    (_selectedIdx + 1) + "/" + _displayList.length
          color:   root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
          opacity: 0.45
        }
      }
    }

    ListView {
      id:               listView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip:             true
      model:            root._displayList
      currentIndex:     root._selectedIdx
      boundsBehavior:   Flickable.StopAtBounds

      delegate: Item {
        id:     dlg
        width:  listView.width
        height: 28

        required property var modelData
        required property int index

        readonly property bool   isSelected: index === root._selectedIdx
        readonly property string label: root._visibleLabel(modelData)

        Rectangle {
          anchors.fill: parent; radius: 5
          color: dlg.isSelected
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.14)
            : "transparent"
          Behavior on color { ColorAnimation { duration: 70 } }

          Rectangle {
            width: 3; height: 16; radius: 2
            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
            color: root.colorAccent
            opacity: dlg.isSelected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 70 } }
          }

          Text {
            anchors {
              left: parent.left; leftMargin: dlg.isSelected ? 14 : 9
              right: parent.right; rightMargin: 6
              verticalCenter: parent.verticalCenter
            }
            text:  dlg.label
            color: dlg.isSelected ? root.colorAccent : root.colorText
            elide: Text.ElideRight
            font { family: "Fira Sans"; pixelSize: 12 }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 70 } }
            Behavior on color              { ColorAnimation  { duration: 70 } }
          }
        }

        MouseArea {
          anchors.fill: parent; hoverEnabled: true
          onEntered:  root._selectedIdx = index
          onClicked:  { root._selectedIdx = index; root._launch() }
          cursorShape: Qt.PointingHandCursor
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !root._loading && root._displayList.length === 0 && root._query !== ""
        text: "nenhum resultado"
        color: root.colorTextDim
        font { family: "Fira Sans"; pixelSize: 11; italic: true }
        opacity: 0.38
      }
      Text {
        anchors.centerIn: parent
        visible: !root._loading && root._displayList.length === 0
                 && root._query === "" && mode !== "drun"
        text: mode === "window" ? "nenhuma janela" : "histórico vazio"
        color: root.colorTextDim
        font { family: "Fira Sans"; pixelSize: 11; italic: true }
        opacity: 0.38
      }
      Text {
        anchors.centerIn: parent
        visible: root._loading
        text: "carregando..."
        color: root.colorTextDim
        font { family: "Fira Sans"; pixelSize: 11; italic: true }
        opacity: 0.38
      }
    }
  }
}
