import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  // ── API pública ────────────────────────────────────────────────────────────
  property string mode:       "drun"  // "drun" | "run" | "window" | "script"
  property string launchCmd:  "uwsm app -- {exec}"
  property bool   showIcons:  true
  property int    maxVisible: 12

  // Props do modo script (entries já prontas, vindas do DmenuIpc)
  property var    scriptEntries: []
  property string scriptPreview: ""   // path da imagem de preview no topo (opcional)
  property string scriptPrompt:  ">"
  property string scriptLabel:   "SCRIPT"
  property string scriptSep:     ""

  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  // selected: string com a entrada escolhida, ou null se cancelado
  signal closeRequested(var selected)
  // backRequested: emitido quando Backspace é pressionado com query vazia
  signal backRequested()

  // ── Estado ─────────────────────────────────────────────────────────────────
  property string _query:       ""
  property int    _selectedIdx: 0
  property var    _dynamicList: []
  property bool   _loading:     false

  // ── Apps via DesktopEntries (modo drun) ────────────────────────────────────
  readonly property var _allApps: {
    var apps = DesktopEntries.applications.values
    var list = []
    for (var i = 0; i < apps.length; i++) {
      var a = apps[i]
      if (!a || !a.name) continue
      var name = a.name.trim()
      if (name === "") continue
      var exec = (a.execString || "").replace(/%[uUfFdDnNickvm]/g, "").trim()
      list.push({ name: name, comment: (a.comment || "").trim(),
                  icon: a.icon || "", exec: exec, app: a })
    }
    list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return list
  }

  // ── Processo de listagem (modos run e window) ──────────────────────────────
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
        "[print(c['class']+'\\t'+c['title']+'\\t'+c['address'])" +
        " for c in data if c.get('class')]\""]
    } else if (mode === "run") {
      loader.command = ["bash", "-c",
        "grep '^- cmd:' ~/.local/share/fish/fish_history 2>/dev/null" +
        " | sed 's/^- cmd: //'" +
        " | awk '!seen[$0]++'" +
        " | tac 2>/dev/null"]
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
      if (sel.exec !== "" && launchCmd !== "")
        finalCmd = launchCmd.replace("{exec}", sel.exec)
      if (finalCmd !== "") {
        execProc.command = ["bash", "-c", finalCmd + " &"]
        execProc.running = true
      } else {
        sel.app.execute()
      }
      root.closeRequested(null)
      return
    }

    if (mode === "run") {
      var typed = _query.trim()
      var cmd   = (typed !== "" && (!sel || sel.display !== typed))
        ? typed : (sel ? sel.display : typed)
      if (cmd === "") return
      execProc.command = ["bash", "-c", cmd + " &"]
      execProc.running = true
      root.closeRequested(null)
      return
    }

    if (mode === "window") {
      if (!sel) return
      var parts = sel.display.split("\t")
      var addr  = parts.length > 2 ? parts[2].trim() : ""
      if (addr === "") return
      execProc.command = ["bash", "-c",
        "hyprctl dispatch focuswindow address:" + addr]
      execProc.running = true
      root.closeRequested(null)
      return
    }

    if (mode === "script") {
      // Retorna a entrada selecionada via closeRequested — DmenuIpc trata
      var text = sel ? sel.display : null
      root.closeRequested(text)
      return
    }
  }

  // ── Fonte de dados ─────────────────────────────────────────────────────────
  readonly property var _sourceList: {
    if (mode === "drun")   return _allApps
    if (mode === "script") return scriptEntries.map(function(e) { return { display: e } })
    return _dynamicList
  }

  // ── Filtro com ranking ─────────────────────────────────────────────────────
  function _score(item, q) {
    var name = (mode === "drun" ? item.name : item.display).toLowerCase()
    if (name === q)             return 0
    if (name.startsWith(q))     return 1
    var words = name.split(/[\s\-_]+/)
    for (var i = 1; i < words.length; i++)
      if (words[i].startsWith(q)) return 2
    if (name.indexOf(q) !== -1) return 3
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

  // ── Helpers de display ─────────────────────────────────────────────────────
  function _label(item) {
    if (mode === "drun") return item.name
    if (mode === "window") {
      var p = item.display.split("\t")
      return p[0] + "  →  " + (p[1] || "")
    }
    if (mode === "script" && scriptSep !== "")
      return item.display.split(scriptSep)[0].trim()
    return item.display
  }

  function _sub(item) {
    if (mode === "drun") return item.comment || ""
    if (mode === "script" && scriptSep !== "") {
      var cols = item.display.split(scriptSep)
      return cols.length > 1 ? cols.slice(1).join(scriptSep).trim() : ""
    }
    return ""
  }

  readonly property string _sectionLabel: {
    if (mode === "drun")   return "APLICATIVOS"
    if (mode === "run")    return "HISTÓRICO"
    if (mode === "window") return "JANELAS"
    if (mode === "script") return scriptLabel
    return ""
  }

  readonly property string _modeIcon: {
    if (mode === "drun")   return "󰀻"
    if (mode === "run")    return "󰆍"
    if (mode === "window") return "󱂬"
    return "󰈺"
  }

  readonly property string _placeholder: {
    if (mode === "run")    return "comando ou pesquise no histórico..."
    if (mode === "window") return "pesquisar janela..."
    if (mode === "script") return scriptPrompt !== ">" ? scriptPrompt : "filtrar..."
    return "pesquisar aplicativo..."
  }

  // ── Activate — chamado pelo painel ao abrir ────────────────────────────────
  function activate() {
    _query = ""
    inputField.text = ""
    _selectedIdx = 0
    if (mode === "window" || mode === "run") _load()
    // modo script: entries já estão em scriptEntries, nada a carregar
    Qt.callLater(function() { inputField.forceActiveFocus() })
  }

  // ── Teclado ────────────────────────────────────────────────────────────────
  focus: true
  Keys.onPressed: function(ev) {
    if (ev.key === Qt.Key_Backspace && _query === "") {
      root.backRequested(); ev.accepted = true

    } else if (ev.key === Qt.Key_Escape) {
      root.closeRequested(null); ev.accepted = true

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
    anchors.fill: parent; anchors.margins: 10; spacing: 8

    // Searchbar
    // (sempre no topo para foco imediato ao abrir)
    Rectangle {
      Layout.fillWidth: true; height: 42; radius: 10
      color: Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.95)
      border.width: 1
      border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)

      RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 10

        Text {
          text: root._modeIcon; color: root.colorAccent
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
          verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
          width: 1; height: 18
          color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.4)
        }

        TextInput {
          id: inputField
          Layout.fillWidth: true
          color: root.colorText
          selectionColor: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
          selectedTextColor: root.colorText
          font { family: "Fira Sans"; pixelSize: 13 }
          verticalAlignment: TextInput.AlignVCenter
          height: parent.height

          Text {
            anchors.fill: parent
            text: root._placeholder
            color: root.colorTextDim; font: inputField.font
            opacity: 0.35; verticalAlignment: Text.AlignVCenter
            visible: inputField.text === ""
          }

          onTextChanged: { root._query = text; root._selectedIdx = 0 }
          Keys.forwardTo: [root]
        }

        Text {
          visible: root._loading; text: "󰑓"
          color: root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
          opacity: 0.6
          RotationAnimator on rotation {
            running: root._loading
            from: 0; to: 360; duration: 900; loops: Animation.Infinite
          }
        }

        Text {
          visible: !root._loading && _displayList.length > 0
          text: (_selectedIdx + 1) + " / " + _displayList.length
          color: root.colorTextDim
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
          opacity: 0.38
        }
      }
    }

    // ── Preview de imagem ──────────────────────────────────────────────────
    // Fica entre a searchbar e a lista.
    // Layout.fillHeight=true: ocupa todo o espaço vertical disponível depois
    // da searchbar e antes da lista — quanto maior o painel, maior o preview.
    // Layout.minimumHeight garante que nunca fique menor que 180px.
    // Colapsado (max=0) quando não há preview.
    Rectangle {
      id: previewContainer
      visible: root.scriptPreview !== ""
      Layout.fillWidth: true
      Layout.fillHeight:   root.scriptPreview !== ""
      Layout.minimumHeight: root.scriptPreview !== "" ? 180 : 0
      Layout.maximumHeight: root.scriptPreview !== "" ? 99999 : 0
      Layout.preferredHeight: root.scriptPreview !== "" ? 240 : 0

      radius: 8
      color: Qt.rgba(0, 0, 0, 0.15)
      clip: true

      Image {
        id: previewImg
        anchors.fill: parent
        anchors.margins: 1
        source: root.scriptPreview !== "" ? ("file://" + root.scriptPreview) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: false

        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      // Placeholder enquanto carrega
      Text {
        anchors.centerIn: parent
        visible: previewImg.status !== Image.Ready && root.scriptPreview !== ""
        text: "󰋼"
        color: root.colorTextDim
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 32 }
        opacity: 0.2
      }

      Rectangle {
        anchors.fill: parent; radius: 8
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g,
                              root.colorDivider.b, 0.3)
      }
    }

    // Label de seção
    Item {
      Layout.fillWidth: true; height: 14
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.right: secLabel.left
        anchors.rightMargin: 8; height: 1
        color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.18)
      }
      Text {
        id: secLabel
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: root._sectionLabel; color: root.colorTextDim
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; letterSpacing: 1.5 }
        opacity: 0.3
      }
    }

    // Lista
    ListView {
      id: listView
      Layout.fillWidth: true
      // Quando há preview: altura fixa baseada nos itens (máx 6 × 34px = 204px)
      // Quando não há:     preenche todo o espaço disponível normalmente
      Layout.fillHeight:    root.scriptPreview === ""
      Layout.preferredHeight: root.scriptPreview !== ""
        ? Math.min(_displayList.length, 6) * 34
        : -1
      clip: true; model: root._displayList
      currentIndex: root._selectedIdx
      boundsBehavior: Flickable.StopAtBounds; spacing: 1

      delegate: Item {
        id: dlg
        width: listView.width
        readonly property string subText: root._sub(modelData)
        height: subText !== "" ? 46 : 32
        required property var modelData
        required property int index
        readonly property bool isSelected: index === root._selectedIdx

        Rectangle {
          anchors.fill: parent; radius: 7
          color: dlg.isSelected
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.13)
            : "transparent"
          Behavior on color { ColorAnimation { duration: 80 } }

          Rectangle {
            width: 3; radius: 2
            height: dlg.isSelected ? 22 : 0
            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
            color: root.colorAccent
            Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
          }

          RowLayout {
            anchors {
              fill: parent
              leftMargin: dlg.isSelected ? 16 : 10; rightMargin: 10
              topMargin: 2; bottomMargin: 2
            }
            spacing: 10
            Behavior on anchors.leftMargin { NumberAnimation { duration: 80 } }

            // Ícone (só drun)
            Item {
              visible: root.showIcons && mode === "drun"
              width: visible ? 24 : 0; height: 24
              Layout.alignment: Qt.AlignVCenter

              IconImage {
                anchors.centerIn: parent
                source: {
                  var ico = dlg.modelData.icon || ""
                  if (ico === "") return ""
                  if (ico.startsWith("/") || ico.startsWith("file://")) return ico
                  return "image://icon/" + ico
                }
                width: 20; height: 20; smooth: true
                opacity: status === Image.Ready ? 1.0 : 0.0
              }

              Text {
                anchors.centerIn: parent
                text: (dlg.modelData.name || "?").charAt(0).toUpperCase()
                color: root.colorAccent
                font { family: "Fira Sans"; pixelSize: 13; bold: true }
                opacity: 0.6
                visible: (dlg.modelData.icon || "") === ""
              }
            }

            ColumnLayout {
              Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1

              Text {
                Layout.fillWidth: true
                text: root._label(dlg.modelData)
                color: dlg.isSelected ? root.colorAccent : root.colorText
                elide: Text.ElideRight
                font { family: "Fira Sans"; pixelSize: 12 }
                Behavior on color { ColorAnimation { duration: 80 } }
              }

              Text {
                Layout.fillWidth: true
                visible: dlg.subText !== ""; text: dlg.subText
                color: root.colorTextDim; elide: Text.ElideRight
                font { family: "Fira Sans"; pixelSize: 10 }
                opacity: 0.55
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent; hoverEnabled: true
          onEntered: root._selectedIdx = index
          onClicked: { root._selectedIdx = index; root._launch() }
          cursorShape: Qt.PointingHandCursor
        }
      }

      // Estado vazio
      Item {
        anchors.centerIn: parent
        visible: root._displayList.length === 0 && !root._loading
        width: listView.width; height: 60

        ColumnLayout {
          anchors.centerIn: parent; spacing: 6
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._query !== "" ? "󰍉" : (mode === "window" ? "󱂬" : "󰋗")
            color: root.colorTextDim
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
            color: root.colorTextDim
            font { family: "Fira Sans"; pixelSize: 11; italic: true }
            opacity: 0.35
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: root._loading
        text: "carregando..."
        color: root.colorTextDim
        font { family: "Fira Sans"; pixelSize: 11; italic: true }
        opacity: 0.35
      }
    }
  }
}
