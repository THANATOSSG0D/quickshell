import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  // ── API pública ────────────────────────────────────────────────────────────
  property string mode:      "drun"    // "drun" | "run" | "window"
  property string launchCmd: "uwsm app -- {exec}"  // {exec} = Exec do .desktop
  property bool   showIcons: true

  property color colorPanelBg: "#1f1f1f"
  property color colorText:    "#e2e2e2"
  property color colorTextDim: "#c6c6c6"
  property color colorAccent:  "#ffb4a9"
  property color colorDivider: "#474747"
  property color colorInputBg: "#131313"

  signal closeRequested()

  // ── Estado ─────────────────────────────────────────────────────────────────
  property string _query:       ""
  property int    _selectedIdx: 0
  property var    _dynamicList: []
  property bool   _loading:     false

  // ── Apps via DesktopEntries ────────────────────────────────────────────────
  readonly property var _allApps: {
    var apps = DesktopEntries.applications.values
    var list = []
    for (var i = 0; i < apps.length; i++) {
      var a = apps[i]
      if (!a || !a.name) continue
      var name = a.name.trim()
      if (name === "") continue
      // Limpa placeholders do Exec (%f %u %F %U etc.)
      var exec = (a.execString || "").replace(/%[uUfFdDnNickvm]/g, "").trim()
      list.push({
        name:    name,
        comment: (a.comment || "").trim(),
        icon:    a.icon || "",
        exec:    exec,
        app:     a
      })
    }
    list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return list
  }

  // ── Processo: window / run ─────────────────────────────────────────────────
  Process {
    id: loader
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.split("\n")
        var list = []
        for (var i = 0; i < lines.length; i++) {
          var t = lines[i].trim()
          if (t !== "") list.push({ display: t })
        }
        root._dynamicList = list
        root._loading = false
      }
    }
  }

  function _load() {
    root._dynamicList = []
    root._loading = true
    if (mode === "window") {
      loader.command = ["bash", "-c",
        "hyprctl clients -j 2>/dev/null | python3 -c \"" +
        "import sys,json;" +
        "data=json.load(sys.stdin);" +
        "[print(c['class']+'\t'+c['title']+'\t'+c['address'])" +
        " for c in data if c.get('class')]\""]
    } else if (mode === "run") {
      loader.command = ["bash", "-c",
        "grep '^- cmd:' ~/.local/share/fish/fish_history 2>/dev/null" +
        " | sed 's/^- cmd: //'" +
        " | awk '!seen[$0]++'" +
        " | tac 2>/dev/null" +
        " || grep '^- cmd:' ~/.local/share/fish/fish_history 2>/dev/null" +
        " | sed 's/^- cmd: //'" +
        " | awk '!seen[$0]++'" +
        " | tail -r 2>/dev/null"]
    }
    loader.running = false
    loader.running = true
  }

  Process { id: execProc; running: false }

  // ── Launch ─────────────────────────────────────────────────────────────────
  function _launch() {
    var items = _displayList
    var sel   = items[_selectedIdx]

    if (mode === "drun") {
      if (!sel) return
      var finalCmd = ""
      if (sel.exec !== "" && launchCmd !== "") {
        finalCmd = launchCmd.replace("{exec}", sel.exec)
      }
      if (finalCmd !== "") {
        execProc.command = ["bash", "-c", finalCmd + " &"]
        execProc.running = true
      } else {
        sel.app.execute()
      }
      root.closeRequested()
      return
    }

    if (mode === "run") {
      // Se digitou algo diferente do item selecionado, usa o texto digitado
      var typed = _query.trim()
      var cmd   = (typed !== "" && (!sel || sel.display !== typed))
        ? typed : (sel ? sel.display : typed)
      if (cmd === "") return
      execProc.command = ["bash", "-c", cmd + " &"]
      execProc.running = true
      root.closeRequested()
      return
    }

    if (mode === "window") {
      if (!sel) return
      var parts = sel.display.split("\t")
      var addr  = parts.length > 2 ? parts[2].trim() : ""
      if (addr === "") return
      execProc.command = ["bash", "-c", "hyprctl dispatch focuswindow address:" + addr]
      execProc.running = true
      root.closeRequested()
      return
    }
  }

  // ── Listas ─────────────────────────────────────────────────────────────────
  readonly property var _sourceList: mode === "drun" ? _allApps : _dynamicList

  // ── Busca com ranking de relevância ───────────────────────────────────────
  // Prioridade (menor = melhor):
  //   0 — correspondência exata do nome
  //   1 — nome começa com a query
  //   2 — palavra do nome começa com a query
  //   3 — nome contém a query
  //   4 — comment contém a query (só drun)
  function _score(item, q) {
    var name = (mode === "drun" ? item.name : item.display).toLowerCase()
    if (name === q)              return 0
    if (name.startsWith(q))     return 1
    var words = name.split(/[\s\-_]+/)
    for (var i = 1; i < words.length; i++)
      if (words[i].startsWith(q)) return 2
    if (name.indexOf(q) !== -1)  return 3
    if (mode === "drun" && item.comment &&
        item.comment.toLowerCase().indexOf(q) !== -1) return 4
    return 99
  }

  readonly property var _displayList: {
    if (_query === "") return _sourceList
    var q = _query.toLowerCase()
    var scored = []
    for (var i = 0; i < _sourceList.length; i++) {
      var s = _score(_sourceList[i], q)
      if (s < 99) scored.push({ item: _sourceList[i], score: s })
    }
    scored.sort(function(a, b) {
      if (a.score !== b.score) return a.score - b.score
      // desempate alfabético
      var na = mode === "drun" ? a.item.name : a.item.display
      var nb = mode === "drun" ? b.item.name : b.item.display
      return na.localeCompare(nb)
    })
    return scored.map(function(s) { return s.item })
  }

  on_DisplayListChanged: {
    _selectedIdx = 0
    listView.positionViewAtIndex(0, ListView.Beginning)
  }

  function _label(item) {
    if (mode === "drun")   return item.name
    if (mode === "window") return item.display.split("\t")[0] + "  →  " + (item.display.split("\t")[1] || "")
    return item.display
  }

  function _sub(item) {
    if (mode === "drun") return item.comment || ""
    return ""
  }

  // ── Activate (chamado pelo DmenuPopup) ─────────────────────────────────────
  function activate() {
    _query = ""
    inputField.text = ""
    _selectedIdx = 0
    if (mode === "window" || mode === "run") _load()
    Qt.callLater(function() { inputField.forceActiveFocus() })
  }

  // ── Teclado ────────────────────────────────────────────────────────────────
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
        var lbl = mode === "drun"
          ? _displayList[_selectedIdx].name
          : _displayList[_selectedIdx].display.split("\t")[0]
        inputField.text = lbl
        _query = lbl
        inputField.cursorPosition = lbl.length
      }
      ev.accepted = true
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  ColumnLayout {
    anchors.fill:    parent
    anchors.margins: 10
    spacing:         8

    // ── Searchbar ─────────────────────────────────────────────────────────
    Rectangle {
      Layout.fillWidth: true
      height: 42
      radius: 10
      color:  Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.95)
      border.width: 1
      border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)

      RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 10

        // Ícone do modo
        Text {
          text: mode === "drun" ? "󰀻" : mode === "run" ? "󰆍" : "󱂬"
          color:   root.colorAccent
          font   { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
          verticalAlignment: Text.AlignVCenter
        }

        // Divisor
        Rectangle {
          width: 1; height: 18
          color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.4)
        }

        // Input
        TextInput {
          id:               inputField
          Layout.fillWidth: true
          color:            root.colorText
          selectionColor:   Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
          selectedTextColor: root.colorText
          font { family: "Fira Sans"; pixelSize: 13 }
          verticalAlignment: TextInput.AlignVCenter
          height: parent.height

          Text {
            anchors.fill: parent
            text: {
              if (mode === "run")    return "comando ou pesquise no histórico..."
              if (mode === "window") return "pesquisar janela..."
              return "pesquisar aplicativo..."
            }
            color:   root.colorTextDim
            font:    inputField.font
            opacity: 0.35
            verticalAlignment: Text.AlignVCenter
            visible: inputField.text === ""
          }

          onTextChanged: { root._query = text; root._selectedIdx = 0 }
          Keys.forwardTo: [root]
        }

        // Loading / contador
        Text {
          visible: root._loading
          text:    "󰑓"
          color:   root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
          opacity: 0.6

          RotationAnimator on rotation {
            running: root._loading
            from: 0; to: 360; duration: 900
            loops: Animation.Infinite
          }
        }

        Text {
          visible: !root._loading && _displayList.length > 0
          text:    (_selectedIdx + 1) + " / " + _displayList.length
          color:   root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
          opacity: 0.38
        }
      }
    }

    // ── Label de seção ────────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true
      height: 14

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.right: sectionLabel.left
        anchors.rightMargin: 8
        height: 1
        color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.18)
      }

      Text {
        id: sectionLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: {
          if (mode === "drun")   return "APLICATIVOS"
          if (mode === "run")    return "HISTÓRICO"
          return "JANELAS"
        }
        color:   root.colorTextDim
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; letterSpacing: 1.5 }
        opacity: 0.3
      }
    }

    // ── Lista ──────────────────────────────────────────────────────────────
    ListView {
      id:               listView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip:             true
      model:            root._displayList
      currentIndex:     root._selectedIdx
      boundsBehavior:   Flickable.StopAtBounds
      spacing:          1

      delegate: Item {
        id:     dlg
        width:  listView.width
        // altura maior quando tem subtítulo
        readonly property string subText: root._sub(modelData)
        height: (mode === "drun" && subText !== "") ? 46 : 32

        required property var modelData
        required property int index

        readonly property bool isSelected: index === root._selectedIdx

        // Fundo do item
        Rectangle {
          anchors.fill: parent
          radius: 7
          color: dlg.isSelected
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.13)
            : "transparent"
          Behavior on color { ColorAnimation { duration: 80 } }

          // Barra lateral esquerda
          Rectangle {
            width: 3; radius: 2
            height: dlg.isSelected ? 22 : 0
            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
            color: root.colorAccent
            Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
          }

          RowLayout {
            anchors {
              fill:        parent
              leftMargin:  dlg.isSelected ? 16 : 10
              rightMargin: 10
              topMargin:   2
              bottomMargin: 2
            }
            spacing: 10

            Behavior on anchors.leftMargin { NumberAnimation { duration: 80 } }

            // Ícone (só no modo drun e se showIcons=true)
            Item {
              visible: root.showIcons && mode === "drun"
              width:   visible ? 24 : 0
              height:  24
              Layout.alignment: Qt.AlignVCenter

              IconImage {
                anchors.centerIn: parent
                source: {
                  var ico = dlg.modelData.icon || ""
                  if (ico === "") return ""
                  if (ico.startsWith("/") || ico.startsWith("file://")) return ico
                  return "image://icon/" + ico
                }
                width:  20; height: 20
                smooth: true
                // fallback invisível se ícone não carrega
                opacity: status === Image.Ready ? 1.0 : 0.0
              }

              // Fallback: inicial do app
              Text {
                anchors.centerIn: parent
                text: (dlg.modelData.name || "?").charAt(0).toUpperCase()
                color:   root.colorAccent
                font { family: "Fira Sans"; pixelSize: 13; bold: true }
                opacity: 0.6
                visible: {
                  var ico = dlg.modelData.icon || ""
                  return ico === ""
                }
              }
            }

            // Textos
            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text:  root._label(dlg.modelData)
                color: dlg.isSelected ? root.colorAccent : root.colorText
                elide: Text.ElideRight
                font { family: "Fira Sans"; pixelSize: 12 }
                Behavior on color { ColorAnimation { duration: 80 } }
              }

              Text {
                Layout.fillWidth: true
                visible: dlg.subText !== ""
                text:    dlg.subText
                color:   root.colorTextDim
                elide:   Text.ElideRight
                font { family: "Fira Sans"; pixelSize: 10 }
                opacity: 0.55
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered:  root._selectedIdx = index
          onClicked:  { root._selectedIdx = index; root._launch() }
          cursorShape: Qt.PointingHandCursor
        }
      }

      // ── Estados vazios ─────────────────────────────────────────────────
      Item {
        anchors.centerIn: parent
        visible: root._displayList.length === 0 && !root._loading
        width: listView.width
        height: 60

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._query !== "" ? "󰍉" : (mode === "window" ? "󱂬" : "󰋗")
            color:   root.colorTextDim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 22 }
            opacity: 0.25
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
              if (root._query !== "") return "nenhum resultado para \"" + root._query + "\""
              if (mode === "window")  return "nenhuma janela aberta"
              if (mode === "run")     return "histórico vazio"
              return "carregando..."
            }
            color:   root.colorTextDim
            font { family: "Fira Sans"; pixelSize: 11; italic: true }
            opacity: 0.35
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: root._loading
        text:    "carregando..."
        color:   root.colorTextDim
        font { family: "Fira Sans"; pixelSize: 11; italic: true }
        opacity: 0.35
      }
    }
  }
}
