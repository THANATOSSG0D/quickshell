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
  // Ordenação dos resultados drun — "name" | "desc" | "usage"
  property string sortMode:   "name"
  // Contagens de uso — passado de DmenuConfig.usageCount (leitura apenas)
  property var    usageCount: ({})
  // Callback para registrar uso — ligado a DmenuConfig.recordUsage
  property var    onRecordUsage: null

  // Props do modo script (entries já prontas, vindas do DmenuIpc)
  property var    scriptEntries:  []
  property var    scriptThumbs:   []  // array paralelo a scriptEntries com paths de thumbnail
  property string scriptPreview: ""   // preview estático inicial (usado quando scriptThumbs vazio)
  property string scriptPrompt:  ">"
  property string scriptLabel:   "SCRIPT"
  property string scriptSep:     ""
  property var    scriptKeybinds: {}  // { actionName: "Alt+t", ... }
  property bool   scriptPassword: false  // true → echoMode Password, sem lista

  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  // selected: string com a entrada escolhida, ou null se cancelado
  // key: nome do atalho acionado (string vazia = Enter normal)
  signal closeRequested(var selected, string key)
  // backRequested: emitido quando Backspace é pressionado com query vazia
  signal backRequested()

  // ── Estado ─────────────────────────────────────────────────────────────────
  property string _query:       ""
  property int    _selectedIdx: 0
  property var    _dynamicList: []
  property bool   _loading:     false

  // Preview efetivo: atualizado imperativamente.
  // Binding JS complexo em QML não rastreia sub-propriedades de elementos
  // de arrays — os handlers onXChanged garantem atualização em qualquer mudança.
  property string _activePreview: ""

  function _updateActivePreview() {
    if (mode !== "script") { _activePreview = ""; return }
    if (scriptThumbs && scriptThumbs.length > 0) {
      var items = _displayList
      if (_selectedIdx >= 0 && _selectedIdx < items.length) {
        var tidx = items[_selectedIdx]._thumbIdx
        if (tidx !== undefined && tidx >= 0 && tidx < scriptThumbs.length) {
          var t = scriptThumbs[tidx]
          if (t && t !== "") { _activePreview = t; return }
        }
      }
    }
    _activePreview = scriptPreview
  }

  on_SelectedIdxChanged:  _updateActivePreview()
  onScriptThumbsChanged:  _updateActivePreview()
  onScriptPreviewChanged: _updateActivePreview()

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
    // Ordenação base da lista completa (sem query)
    // "usage": apps mais usados primeiro; qualquer outro: alfabético
    if (sortMode === "usage") {
      list.sort(function(a, b) {
        var ua = usageCount[a.exec] || 0
        var ub = usageCount[b.exec] || 0
        if (ua !== ub) return ub - ua
        return a.name.localeCompare(b.name)
      })
    } else {
      list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    }
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

  // Guard contra duplo disparo — reset em activate()
  property bool _launched: false

  // ── Launch ─────────────────────────────────────────────────────────────────
  function _launch() {
    // Guard contra duplo disparo (ex: TypeError em recordUsage reprocessando o handler)
    if (_launched) {
      console.warn("[dmenu] _launch ignorado — _launched=true (duplo disparo bloqueado)")
      return
    }
    _launched = true

    var items = _displayList
    var sel   = items[_selectedIdx]

    if (mode === "drun") {
      if (!sel) return
      var _t0 = Date.now()
      console.log("[dmenu][T+" + _t0 + "] _launch drun — app:", sel.name,
                  "| exec:", sel.exec, "| launchCmd:", launchCmd)
      var isDefaultUwsm = (launchCmd === "uwsm app -- {exec}" || launchCmd === "")
      if (!isDefaultUwsm && sel.exec !== "") {
        var finalCmd = launchCmd.replace("{exec}", sel.exec)
        console.log("[dmenu][T+" + Date.now() + "] execProc launch — cmd:", finalCmd)
        execProc.running = false
        execProc.command = ["bash", "-c",
          "nohup " + finalCmd + " </dev/null >/dev/null 2>&1 &"]
        execProc.running = true
        console.log("[dmenu][T+" + Date.now() + "] execProc.running=true (dt=" + (Date.now()-_t0) + "ms)")
      } else {
        console.log("[dmenu][T+" + Date.now() + "] sel.app.execute() — dt=" + (Date.now()-_t0) + "ms")
        sel.app.execute()
        console.log("[dmenu][T+" + Date.now() + "] sel.app.execute() RETORNOU — dt=" + (Date.now()-_t0) + "ms")
      }
      if (onRecordUsage && sel.exec !== "") onRecordUsage(sel.exec)
      console.log("[dmenu][T+" + Date.now() + "] emitindo closeRequested — dt=" + (Date.now()-_t0) + "ms")
      root.closeRequested(null, "")
      console.log("[dmenu][T+" + Date.now() + "] _launch drun FIM — dt=" + (Date.now()-_t0) + "ms")
      return
    }

    if (mode === "run") {
      var typed = _query.trim()
      var cmd   = (typed !== "" && (!sel || sel.display !== typed))
        ? typed : (sel ? sel.display : typed)
      if (cmd === "") return
      execProc.running = false
      execProc.command = ["bash", "-c", cmd + " &"]
      execProc.running = true
      root.closeRequested(null, "")
      return
    }

    if (mode === "window") {
      if (!sel) return
      var parts = sel.display.split("\t")
      var addr  = parts.length > 2 ? parts[2].trim() : ""
      if (addr === "") return
      execProc.running = false
      execProc.command = ["bash", "-c",
        "hyprctl dispatch focuswindow address:" + addr]
      execProc.running = true
      root.closeRequested(null, "")
      return
    }

    if (mode === "script") {
      // Retorna a entrada selecionada via closeRequested — DmenuIpc trata
      var text = sel ? sel.display : (_query.trim() !== "" ? _query.trim() : null)
      root.closeRequested(text, "")
      return
    }
  }

  // ── Fonte de dados ─────────────────────────────────────────────────────────
  readonly property var _sourceList: {
    if (mode === "drun")   return _allApps
    if (mode === "script") return scriptEntries.map(function(e, i) {
      return { display: e, _thumbIdx: i }
    })
    return _dynamicList
  }

  // ── Filtro com ranking ─────────────────────────────────────────────────────
  // Scores base (independente de sortMode):
  //   0 = nome exato
  //   1 = nome começa com q
  //   2 = palavra interna do nome começa com q
  //   3 = nome contém q em qualquer posição
  //   4 = descrição/comment contém q
  //   99 = sem match
  //
  // sortMode "name":  desempate por nome alfabético
  // sortMode "desc":  match em comment sobe para score 2.5 (entre palavra e substring)
  //                   na prática: comment match → score 2, nome-substring → score 3
  // sortMode "usage": desempate por usageCount[exec] desc (mais usados primeiro)
  function _score(item, q) {
    if (mode !== "drun") {
      var d = item.display.toLowerCase()
      if (d === q)             return 0
      if (d.startsWith(q))     return 1
      if (d.indexOf(q) !== -1) return 3
      return 99
    }

    var name    = item.name.toLowerCase()
    var comment = (item.comment || "").toLowerCase()

    if (name === q)             return 0
    if (name.startsWith(q))     return 1

    var words = name.split(/[\s\-_]+/)
    for (var i = 1; i < words.length; i++)
      if (words[i].startsWith(q)) return 2

    // sortMode "desc": match em comment tem prioridade sobre substring do nome
    if (sortMode === "desc") {
      if (comment.indexOf(q) !== -1) return 3
      if (name.indexOf(q)    !== -1) return 4
    } else {
      if (name.indexOf(q)    !== -1) return 3
      if (comment.indexOf(q) !== -1) return 4
    }
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
      // Desempate por sortMode
      if (mode === "drun" && sortMode === "usage") {
        var ua = usageCount[a.item.exec] || 0
        var ub = usageCount[b.item.exec] || 0
        if (ua !== ub) return ub - ua   // mais usado primeiro
      }
      var na = mode === "drun" ? a.item.name : a.item.display
      var nb = mode === "drun" ? b.item.name : b.item.display
      return na.localeCompare(nb)
    })
    return scored.map(function(s) { return s.item })
  }

  on_DisplayListChanged: {
    _selectedIdx = 0
    listView.positionViewAtIndex(0, ListView.Beginning)
    _updateActivePreview()
  }

  // ── Helpers de display ─────────────────────────────────────────────────────

  // Retorna a cor hexadecimal se a string começa com #RRGGBB ou #RRGGBBAA,
  // case-insensitive. Retorna "" se não houver.
  function _parseHexColor(str) {
    if (!str) return ""
    var m = str.match(/^(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)\b/)
    return m ? m[1] : ""
  }

  function _label(item) {
    if (mode === "drun") return item.name
    if (mode === "window") {
      var p = item.display.split("\t")
      return p[0] + "  →  " + (p[1] || "")
    }
    if (mode === "script" && scriptSep !== "")
      return item.display.split(scriptSep)[0].trim()
    // Strip hex color prefix (#RRGGBB) do início da entry, se presente
    if (mode === "script") {
      var hex = _parseHexColor(item.display)
      if (hex !== "") return item.display.slice(hex.length).trim()
    }
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
    if (scriptPassword)    return scriptPrompt !== ">" ? scriptPrompt : "senha..."
    if (_freeText)         return scriptPrompt !== ">" ? scriptPrompt : "texto..."
    if (mode === "run")    return "comando ou pesquise no histórico..."
    if (mode === "window") return "pesquisar janela..."
    if (mode === "script") return scriptPrompt !== ">" ? scriptPrompt : "filtrar..."
    return "pesquisar aplicativo..."
  }

  // true quando não há entries E não é modo nativo — campo de texto livre
  readonly property bool _freeText: mode === "script" && scriptEntries.length === 0 && !scriptPassword
  // Converte {"sync":"Alt+r","lock":"Alt+l",...} em uma lista de objetos
  // {name, mod, key} para comparação rápida no handler de teclado.
  readonly property var _parsedKeybinds: {
    var result = []
    if (!scriptKeybinds) return result
    var keys = Object.keys(scriptKeybinds)
    for (var i = 0; i < keys.length; i++) {
      var name  = keys[i]
      var combo = scriptKeybinds[name] || ""
      if (combo === "") continue
      var parts = combo.split("+")
      var k     = parts[parts.length - 1].trim().toLowerCase()
      var mods  = Qt.NoModifier
      for (var j = 0; j < parts.length - 1; j++) {
        var m = parts[j].trim().toLowerCase()
        if (m === "ctrl")  mods |= Qt.ControlModifier
        if (m === "alt")   mods |= Qt.AltModifier
        if (m === "shift") mods |= Qt.ShiftModifier
        if (m === "meta")  mods |= Qt.MetaModifier
      }
      result.push({ name: name, mod: mods, key: k })
    }
    return result
  }

  // Mapa Qt.Key_* → string usada no keybind (ex: Qt.Key_Delete → "delete")
  // Necessário porque ev.text retorna "" para teclas especiais e também
  // para qualquer tecla quando um modificador como Alt está pressionado no Wayland.
  readonly property var _qtKeyNames: ({
    [Qt.Key_Delete]:    "delete",
    [Qt.Key_Return]:    "return",
    [Qt.Key_Enter]:     "enter",
    [Qt.Key_Escape]:    "escape",
    [Qt.Key_Tab]:       "tab",
    [Qt.Key_Backspace]: "backspace",
    [Qt.Key_Up]:        "up",
    [Qt.Key_Down]:      "down",
    [Qt.Key_Left]:      "left",
    [Qt.Key_Right]:     "right",
    [Qt.Key_Home]:      "home",
    [Qt.Key_End]:       "end",
    [Qt.Key_PageUp]:    "pageup",
    [Qt.Key_PageDown]:  "pagedown",
    [Qt.Key_F1]: "f1", [Qt.Key_F2]: "f2", [Qt.Key_F3]:  "f3",  [Qt.Key_F4]:  "f4",
    [Qt.Key_F5]: "f5", [Qt.Key_F6]: "f6", [Qt.Key_F7]:  "f7",  [Qt.Key_F8]:  "f8",
    [Qt.Key_F9]: "f9", [Qt.Key_F10]:"f10",[Qt.Key_F11]: "f11", [Qt.Key_F12]: "f12",
    // Alfanuméricos — necessário porque ev.text="" quando Alt está pressionado
    [Qt.Key_0]:"0",[Qt.Key_1]:"1",[Qt.Key_2]:"2",[Qt.Key_3]:"3",[Qt.Key_4]:"4",
    [Qt.Key_5]:"5",[Qt.Key_6]:"6",[Qt.Key_7]:"7",[Qt.Key_8]:"8",[Qt.Key_9]:"9",
    [Qt.Key_A]:"a",[Qt.Key_B]:"b",[Qt.Key_C]:"c",[Qt.Key_D]:"d",[Qt.Key_E]:"e",
    [Qt.Key_F]:"f",[Qt.Key_G]:"g",[Qt.Key_H]:"h",[Qt.Key_I]:"i",[Qt.Key_J]:"j",
    [Qt.Key_K]:"k",[Qt.Key_L]:"l",[Qt.Key_M]:"m",[Qt.Key_N]:"n",[Qt.Key_O]:"o",
    [Qt.Key_P]:"p",[Qt.Key_Q]:"q",[Qt.Key_R]:"r",[Qt.Key_S]:"s",[Qt.Key_T]:"t",
    [Qt.Key_U]:"u",[Qt.Key_V]:"v",[Qt.Key_W]:"w",[Qt.Key_X]:"x",[Qt.Key_Y]:"y",
    [Qt.Key_Z]:"z"
  })

  // Retorna o nome da ação se o evento corresponde a um keybind, senão "".
  function _matchKeybind(ev) {
    var kb = _parsedKeybinds
    // Sempre usa o mapa Qt.Key_* como fonte primária — é o único método confiável
    // no Wayland com Hyprland:
    //   • Alt+r  → ev.text = ""  (Alt consumido pelo compositor)
    //   • Ctrl+r → ev.text = "" (caractere de controle, não "r")
    //   • Delete → ev.text = ""
    // ev.key é sempre o código numérico correto independente de modificadores.
    var evKey = _qtKeyNames[ev.key] || ""
    // Fallback para ev.text apenas se for um caractere imprimível normal (sem modificadores)
    if (evKey === "") {
      var t = ev.text.toLowerCase()
      if (t.length === 1 && t.charCodeAt(0) >= 32 && t.charCodeAt(0) < 127) evKey = t
    }
    if (evKey === "") return ""
    for (var i = 0; i < kb.length; i++) {
      if (evKey !== kb[i].key) continue
      if ((ev.modifiers & kb[i].mod) !== kb[i].mod) continue
      return kb[i].name
    }
    return ""
  }

  // ── Activate — chamado pelo painel ao abrir ────────────────────────────────
  function activate() {
    _launched = false   // reset guard — novo ciclo de uso
    _query = ""
    inputField.text = ""
    _selectedIdx = 0
    if (mode === "window" || mode === "run") _load()
    // modo script: entries já estão em scriptEntries, nada a carregar
    // modo password: campo de texto livre, lista oculta
    Qt.callLater(function() { inputField.forceActiveFocus() })
  }

  // ── Teclado ────────────────────────────────────────────────────────────────
  focus: true
  Keys.onPressed: function(ev) {
    // ── Keybinds personalizados (modo script com keybinds ativos) ─────────
    if (mode === "script" && Object.keys(scriptKeybinds).length > 0) {
      var actionName = _matchKeybind(ev)
      if (actionName !== "") {
        var items2    = _displayList
        var selItem   = items2[_selectedIdx]
        var selText2  = selItem ? selItem.display : null
        // Alguns keybinds globais (sync, lock, etc.) não requerem item selecionado
        root.closeRequested(selText2, actionName)
        ev.accepted = true
        return
      }
    }

    if (ev.key === Qt.Key_Backspace && _query === "") {
      root.backRequested(); ev.accepted = true

    } else if (ev.key === Qt.Key_Escape) {
      root.closeRequested(null, ""); ev.accepted = true

    } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
      _launch(); ev.accepted = true

    } else if (!scriptPassword && (ev.key === Qt.Key_Down ||
               (ev.key === Qt.Key_N && (ev.modifiers & Qt.ControlModifier)))) {
      if (_selectedIdx < _displayList.length - 1) {
        _selectedIdx++
        listView.positionViewAtIndex(_selectedIdx, ListView.Contain)
      }
      ev.accepted = true

    } else if (!scriptPassword && (ev.key === Qt.Key_Up ||
               (ev.key === Qt.Key_P && (ev.modifiers & Qt.ControlModifier)))) {
      if (_selectedIdx > 0) {
        _selectedIdx--
        listView.positionViewAtIndex(_selectedIdx, ListView.Contain)
      }
      ev.accepted = true

    } else if (!scriptPassword && ev.key === Qt.Key_Tab) {
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
          echoMode: root.scriptPassword ? TextInput.Password : TextInput.Normal

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
    // Colapsado (max=0) quando não há preview ou em modo password.
    Rectangle {
      id: previewContainer
      visible: root._activePreview !== "" && !root.scriptPassword && !root._freeText
      Layout.fillWidth: true
      Layout.fillHeight:   root._activePreview !== ""
      Layout.minimumHeight: root._activePreview !== "" ? 180 : 0
      Layout.maximumHeight: root._activePreview !== "" ? 99999 : 0
      Layout.preferredHeight: root._activePreview !== "" ? 240 : 0

      radius: 8
      color: Qt.rgba(0, 0, 0, 0.15)
      clip: true

      Image {
        id: previewImg
        anchors.fill: parent
        anchors.margins: 1
        source: root._activePreview !== "" ? ("file://" + root._activePreview) : ""
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
        visible: previewImg.status !== Image.Ready && root._activePreview !== ""
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
      visible: !root.scriptPassword && !root._freeText
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

    // Lista + rodapé de keybinds
    Item {
      Layout.fillWidth: true
      Layout.fillHeight:      root._activePreview === ""
      Layout.preferredHeight: root._activePreview !== ""
        ? Math.min(_displayList.length, 6) * 34
        : -1

      // ── Rodapé de keybinds ───────────────────────────────────────────────
      // Ancorado ao bottom do Item wrapper; a lista ancora seu bottom aqui.
      Rectangle {
        id: keybindFooter
        visible: mode === "script" && _parsedKeybinds.length > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        // Altura dinâmica baseada no conteúdo real do Flow + padding
        height: visible ? (keybindFlow.implicitHeight + 14) : 0
        radius: 6
        // Cor sólida — sem transparência para não vazar o conteúdo atrás
        color: root.colorInputBg
        border.width: 1
        border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g,
                              root.colorDivider.b, 0.40)

        Flow {
          id: keybindFlow
          anchors { left: parent.left; right: parent.right; top: parent.top }
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          anchors.topMargin: 7
          spacing: 6

          Repeater {
            model: _parsedKeybinds
            delegate: Row {
              spacing: 4
              Rectangle {
                width: badgeTxt.implicitWidth + 10
                height: 18
                radius: 4
                color: Qt.rgba(root.colorAccent.r, root.colorAccent.g,
                               root.colorAccent.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g,
                                      root.colorAccent.b, 0.30)
                Text {
                  id: badgeTxt
                  anchors.centerIn: parent
                  text: {
                    var parts = []
                    var m = modelData.mod
                    if (m & Qt.ControlModifier) parts.push("Ctrl")
                    if (m & Qt.AltModifier)     parts.push("Alt")
                    if (m & Qt.ShiftModifier)   parts.push("Shift")
                    if (m & Qt.MetaModifier)    parts.push("Meta")
                    var k = modelData.key
                    parts.push(k.charAt(0).toUpperCase() + k.slice(1))
                    return parts.join("+")
                  }
                  color: root.colorAccent
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  var labels = {
                    "sync": "sync", "search_url": "URL",
                    "search_folder": "pasta", "copy_totp": "TOTP",
                    "copy_username": "usuário", "copy_password": "senha",
                    "copy_uri": "URI", "autotype_all": "autotype",
                    "autotype_user": "type user", "autotype_pass": "type pass",
                    "show_details": "detalhes", "lock": "bloquear",
                    "generate_password": "gerar senha", "create_new": "criar",
                    "import_totp": "imp. TOTP", "map_totp": "map TOTP",
                    "remove_totp_map": "rem. TOTP", "delete_totp": "del. TOTP"
                  }
                  return labels[modelData.name] || modelData.name
                }
                color: root.colorTextDim
                font { family: "Fira Sans"; pixelSize: 10 }
                opacity: 0.70
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: index < _parsedKeybinds.length - 1
                text: "·"
                color: root.colorDivider
                font { pixelSize: 10 }
                opacity: 0.35
              }
            }
          }
        }
      }

      ListView {
        id: listView
        visible: !root.scriptPassword && !root._freeText
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          bottom: keybindFooter.visible ? keybindFooter.top : parent.bottom
          bottomMargin: keybindFooter.visible ? 6 : 0
        }
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

            // Swatch de cor hexadecimal (só modo script, quando a entry começa com #RRGGBB)
            Item {
              readonly property string _swatchHex: root._parseHexColor(dlg.modelData.display || "")
              visible: mode === "script" && _swatchHex !== ""
              width: visible ? 28 : 0
              height: 28
              Layout.alignment: Qt.AlignVCenter

              Rectangle {
                anchors.centerIn: parent
                width: 22; height: 22; radius: 5
                color: parent._swatchHex !== "" ? parent._swatchHex : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                // Indicador de seleção: borda accent quando o item está selecionado
                Rectangle {
                  anchors.fill: parent
                  anchors.margins: -2
                  radius: 7
                  color: "transparent"
                  border.width: dlg.isSelected ? 2 : 0
                  border.color: root.colorAccent
                  Behavior on border.width { NumberAnimation { duration: 80 } }
                }
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
}
