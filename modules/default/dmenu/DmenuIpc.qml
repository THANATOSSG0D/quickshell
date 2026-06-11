import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// ── DmenuIpc ──────────────────────────────────────────────────────────────────
// Ponto único de entrada para todos os modos do dmenu.
//
// Modos nativos (drun / run / window):
//   DmenuIpc.openNative("drun")   — abre/fecha como toggle
//
// Modo script (chamado por scripts externos via socket):
//   Automático — o servidor Python envia o request via stdout.
//
// Navegação com pilha:
//   • Backspace com query vazia → volta ao nível anterior da pilha.
//   • Se a pilha estiver vazia, fecha o painel.
//   • Isso permite submenus aninhados com navegação natural.
//
// Toggle:
//   • openNative() chamado com o mesmo modo enquanto o painel está aberto → fecha.
//   • Scripts: se o mesmo script chamar qs-dmenu enquanto o painel está aberto
//     (ex: atalho duplo), o request é empilhado normalmente — o toggle é gerenciado
//     pelo caller (rofi-config-for-menus.sh já era toggle via PID).

Item {
  id: root

  property var  barRoot:   null

  // ── DmenuConfig — configuração persistente deste módulo ──────────────────
  // Instanciado aqui e exposto como configRef para o ConfigWindow.
  // Shell.qml passa configRef para o ConfigWindow.dmenuConfig.
  readonly property DmenuConfig configRef: DmenuConfig { id: dmenuConfig }

  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#1f1f1f"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#1f1f1f"

  // ── Estado ───────────────────────────────────────────────────────────────
  // _stack:      pilha de requests — o topo é o request em exibição.
  //              Cada entry: { mode, entries, prompt, label, sep, fifo,
  //                            launchCmd, callback }
  //              Para modos nativos, fifo = "" e callback = null.
  // _closing:    true durante a animação de fechamento (cooldown ms).
  //              Bloqueia novos requests externos enquanto o painel ainda anima.
  property var    _stack:   []
  property bool   _closing: false

  // Exposto para que Bar.qml possa verificar se o painel está visível
  // e implementar o toggle corretamente.
  readonly property bool panelVisible: ipcPanel.panelOpen
  onPanelVisibleChanged: {
    if (root.barRoot) {
      root.barRoot.dmenuPanelOpen = panelVisible
    }
  }

  readonly property string currentNativeMode: {
    if (_stack.length === 0) return ""
    return _stack[_stack.length - 1].mode
  }

  // ── Servidor Python ───────────────────────────────────────────────────────
  Process {
    id: serverProc
    running: true

    property string _scriptPath: {
      var url = Qt.resolvedUrl("./qs-dmenu-server.py").toString()
      return url.replace(/^file:\/\//, "")
    }

    command: ["python3", _scriptPath]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: (line) => {
        var t = line.trim()
        if (t === "") return
        var msg
        try { msg = JSON.parse(t) } catch(e) { return }

        if (msg.ready === true) {
          console.log("DmenuIpc: servidor pronto —", msg.sock)
          return
        }

        // Request de script externo
        var req = {
          mode:         "script",
          entries:      msg.entries       || [],
          thumbnails:   msg.thumbnails    || [],
          previewImage: msg.preview_image || "",
          prompt:       msg.prompt        || ">",
          label:        msg.label         || "SCRIPT",
          sep:          msg.sep           || "",
          keybinds:     msg.keybinds      || {},
          password:     msg.password      || false,
          fifo:         msg._fifo         || "",
          launchCmd:    "",
          callback:     null   // será preenchido em _pushAndOpen
        }

        // Se fechando (cooldown pós-seleção), enfileira para depois
        if (root._closing) {
          _pendingExternal = req
          return
        }

        _pushAndOpen(req)
      }
    }

    onRunningChanged: {
      if (!running) {
        root._stack           = []
        root._closing         = false
        root._pendingExternal = null
        _cooldownTimer.stop()
        restartTimer.start()
      }
    }
  }

  // Request externo recebido durante cooldown — processado após _cooldownTimer
  property var _pendingExternal: null

  Timer { id: restartTimer; interval: 1500; repeat: false; onTriggered: serverProc.running = true }

  // Timer de cooldown: aguarda o painel anterior fechar completamente antes de
  // processar o próximo request externo (subscript).
  // Intervalo lido do config — padrão 450ms (animDuration 200 + safetyUnmap 200 + folga 50).
  Timer {
    id: _cooldownTimer
    interval: dmenuConfig.dmenuCooldownMs   // ← config, não hardcoded
    repeat:   false
    onTriggered: {
      root._closing = false
      if (root._pendingExternal !== null) {
        var req = root._pendingExternal
        root._pendingExternal = null
        root._pushAndOpen(req)
      }
    }
  }

  // ── openNative: abre um modo nativo (drun/run/window) como toggle ─────────
  // Se dmenuToggle=false, reabrir sempre recarrega (sem fechar).
  // Se o painel já está visível com o mesmo modo e toggle=true → fecha.
  // Se está visível com outro modo → troca (não empilha modos nativos).
  function openNative(mode) {
    var launchCmd = dmenuConfig.dmenuLaunchCmd   // ← config, não parâmetro externo

    if (ipcPanel.panelOpen) {
      if (dmenuConfig.dmenuToggle && root.currentNativeMode === mode) {
        _closeAll()
        return
      }
      _stack = []
    }

    var req = {
      mode:         mode,
      entries:      [],
      thumbnails:   [],
      previewImage: "",
      prompt:       mode === "drun" ? "pesquisar app..." : (mode === "run" ? "executar..." : "janela..."),
      label:        mode === "drun" ? "APLICATIVOS" : (mode === "run" ? "HISTÓRICO" : "JANELAS"),
      sep:          "",
      fifo:         "",
      launchCmd:    launchCmd,
      callback:     null
    }

    _pushAndOpen(req)
  }

  // ── _pushAndOpen: empilha um request e exibe o painel ────────────────────
  function _pushAndOpen(req) {
    var fifo = req.fifo
    req.callback = function(selected, key) {
      var s = root._stack.slice()
      s.pop()
      root._stack = s

      if (fifo !== "") {
        root._closing = true
        _respondFifo(selected, key || "", fifo)
        if (s.length > 0) {
          _cooldownTimer.restart()
        } else {
          _cooldownTimer.restart()
        }
      } else {
        if (s.length > 0) {
          _showTop()
        }
      }
    }

    var s = root._stack.slice()
    s.push(req)
    root._stack = s

    _showTop()
  }

  // ── _showTop: exibe o topo da pilha no ipcPanel ───────────────────────────
  function _showTop() {
    if (_stack.length === 0) return

    var req = _stack[_stack.length - 1]
    var activeBar = root.barRoot ? root.barRoot._activeBar() : null

    ipcPanel.barRef         = activeBar
    // Dimensões do painel lidas do config — fallback para barRoot (retrocompatibilidade)
    ipcPanel.popupW         = dmenuConfig.dmenuPanelWidth
    var baseH               = dmenuConfig.dmenuPanelHeight
    ipcPanel.popupH         = req.previewImage
                              ? Math.max(baseH, dmenuConfig.dmenuPanelHeightImg)
                              : baseH
    ipcPanel.popupXAlign    = dmenuConfig.dmenuPopupXAlign
    ipcPanel.popupYAnchor   = dmenuConfig.dmenuPopupYAnchor
    ipcPanel.popupXOffset   = dmenuConfig.dmenuPopupXOffset
    ipcPanel.popupYOffset   = dmenuConfig.dmenuPopupYOffset
    ipcPanel.showIcons      = dmenuConfig.dmenuShowIcons
    ipcPanel.maxVisible     = dmenuConfig.dmenuMaxVisible
    ipcPanel.sortMode       = dmenuConfig.dmenuSortMode
    ipcPanel.usageCount     = dmenuConfig.usageCount
    ipcPanel.onRecordUsage  = function(exec) { dmenuConfig.recordUsage(exec) }
    ipcPanel.mode           = req.mode
    ipcPanel.launchCmd      = req.launchCmd || dmenuConfig.dmenuLaunchCmd
    ipcPanel.scriptEntries  = req.entries
    ipcPanel.scriptThumbs   = req.thumbnails || []
    ipcPanel.scriptPreview  = req.previewImage || ""
    ipcPanel.scriptPrompt   = req.prompt
    ipcPanel.scriptLabel    = req.label
    ipcPanel.scriptSep      = req.sep
    ipcPanel.scriptKeybinds = req.keybinds || {}
    ipcPanel.scriptPassword = req.password || false
    ipcPanel.scriptCallback = req.callback
    ipcPanel.backCallback   = function() { root._goBack() }

    if (!ipcPanel.panelOpen) {
      ipcPanel._callbackFired = false
      ipcPanel.panelOpen = true
    } else {
      ipcPanel._callbackFired = false
      ipcPanel.dmenuContent.activate()
    }
  }

  // ── _goBack: Backspace com query vazia — volta um nível na pilha ──────────
  function _goBack() {
    if (!dmenuConfig.dmenuBackOnEmpty) return   // ← config
    if (_stack.length === 0) return

    var top = _stack[_stack.length - 1]

    if (_stack.length === 1) {
      if (top.fifo !== "") {
        root._closing = true
        _respondFifo(null, "", top.fifo)
        _cooldownTimer.restart()
      }
      root._stack        = []
      ipcPanel.panelOpen = false
    } else {
      if (top.fifo !== "") {
        root._closing = true
        _respondFifo(null, "", top.fifo)
      }
      var s2 = root._stack.slice(0, root._stack.length - 1)
      root._stack = s2

      if (top.fifo !== "") {
        _cooldownTimer.restart()
      } else {
        _showTop()
      }
    }
  }

  // ── _closeAll: fecha tudo e cancela requests pendentes ───────────────────
  function _closeAll() {
    for (var i = root._stack.length - 1; i >= 0; i--) {
      var r = root._stack[i]
      if (r.fifo !== "") _respondFifo(null, "", r.fifo)
    }
    root._stack   = []
    root._closing = false
    _cooldownTimer.stop()
    ipcPanel.panelOpen = false
  }

  // ── _respondFifo: escreve o resultado na FIFO exclusiva do request ────────
  Process { id: responseProc; running: false }

  function _respondFifo(selected, key, fifoPath) {
    if (!fifoPath) return
    if (responseProc.running) responseProc.running = false
    var payload = JSON.stringify({
      selected: (selected !== null && selected !== undefined) ? selected : null,
      key:      (key      !== null && key      !== undefined) ? key      : ""
    })
    responseProc.command = ["bash", "-c",
      "printf '%s\\n' " + JSON.stringify(payload) + " > " + JSON.stringify(fifoPath)]
    responseProc.running = true
  }

  // ── Painel ────────────────────────────────────────────────────────────────
  DmenuPanel {
    id: ipcPanel

    colorPanelBg:  root.colorPanelBg
    colorText:     root.colorText
    colorTextDim:  root.colorTextDim
    colorAccent:   root.colorAccent
    colorSelected: root.colorSelected
    colorDivider:  root.colorDivider
    colorInputBg:  root.colorInputBg

    onCloseRequested: {
      if (!_callbackFired) {
        _callbackFired = true
        root._closeAll()
      }
    }
  }
}
