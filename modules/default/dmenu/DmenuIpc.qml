import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs

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

  // Registra este barRoot como referência de desempate do PanelRouter pra
  // rotas "auto" com searchModuleName (ver PanelRouter._defaultCaller) —
  // sem isso, a UI de config (PanelTab "Dmenu" → dropdown "Abre em:" e o
  // offset de conexão) podia editar o PopupConfig de uma instância diferente
  // da que _showTop() realmente resolve, quando "workspaces" existisse em
  // mais de uma barra ao mesmo tempo.
  onBarRootChanged: {
    if (root.barRoot) PanelRouter.setDefaultCaller(root.barRoot)
  }

  // ── DmenuConfig — configuração persistente deste módulo ──────────────────
  // Instanciado aqui e exposto como configRef para o ConfigWindow.
  // Shell.qml passa configRef para o ConfigWindow.dmenuConfig.
  readonly property DmenuConfig configRef: DmenuConfig { id: dmenuConfig }

  // Fallbacks — recebem os valores do shell.qml (bar.popupColorXxx)

  property color _fallbackBg:       "#1f1f1f"
  property color _fallbackText:     "#e2e2e2"
  property color _fallbackTextDim:  "#c6c6c6"
  property color _fallbackAccent:   "#ffb4a9"
  property color _fallbackSelected: "#1f1f1f"
  property color _fallbackDivider:  "#474747"
  property color _fallbackInputBg:  "#1f1f1f"

  // Cores efetivas — chave do config sobrescreve o fallback se preenchida
  readonly property color colorPanelBg:  _resolveColor(dmenuConfig.dmenuColorBg,       _fallbackBg)
  readonly property color colorText:     _resolveColor(dmenuConfig.dmenuColorText,      _fallbackText)
  readonly property color colorTextDim:  _resolveColor(dmenuConfig.dmenuColorTextDim,   _fallbackTextDim)
  readonly property color colorAccent:   _resolveColor(dmenuConfig.dmenuColorAccent,    _fallbackAccent)
  readonly property color colorSelected: _resolveColor(dmenuConfig.dmenuColorSelected,  _fallbackSelected)
  readonly property color colorDivider:  _resolveColor(dmenuConfig.dmenuColorDivider,   _fallbackDivider)
  readonly property color colorInputBg:  _resolveColor(dmenuConfig.dmenuColorInputBg,   _fallbackInputBg)

  // ── Estado ───────────────────────────────────────────────────────────────
  // _stack:      pilha de requests — o topo é o request em exibição.
  //              Cada entry: { mode, entries, prompt, label, sep, fifo,
  //                            launchCmd, callback }
  //              Para modos nativos, fifo = "" e callback = null.
  // _closing:    true durante a animação de fechamento (cooldown ms).
  //              Bloqueia novos requests externos enquanto o painel ainda anima.
  property var    _stack:   []
  property bool   _closing: false

  // Instância (bar/dock) pra qual o dmenu foi roteado da ÚLTIMA vez que abriu
  // (ver _showTop → PanelRouter.resolveInstance). O flag "dmenuPanelOpen"/
  // "dmenuPanelWidth" que a Pill usa pra se expandir precisa ser setado NELA,
  // não sempre em root.barRoot — senão a barra principal "pisca" de expandir
  // mesmo quando o dmenu abriu na dock, e a dock nunca reage.
  property var    _routedInstance: null

  // Exposto para que Bar.qml possa verificar se o painel está visível
  // e implementar o toggle corretamente.
  readonly property bool panelVisible: ipcPanel.panelOpen
  onPanelVisibleChanged: {
    if (root._routedInstance) {
      root._routedInstance.dmenuPanelOpen = panelVisible
      // A largura (dmenuPanelWidth) é sincronizada em _showTop(), com o MESMO
      // valor efetivo aplicado a ipcPanel.popupW (respeitando o override de
      // PopupConfig/DockPopupConfig) — não recalculamos aqui pra evitar
      // dessincronia com o que está realmente sendo renderizado.
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

    // Reforço do lado QML: garante que o processo Python recebe SIGTERM
    // quando este item é destruído (ex.: reload do Quickshell recriando
    // DmenuIpc). O script agora tem sua própria defesa via pidfile
    // (qs-dmenu-server.py mata a instância anterior antes de assumir o
    // socket), mas isso evita a corrida de precisar disso na maioria dos
    // casos — não conta com o próprio processo pra se limpar sozinho.
    Component.onDestruction: {
      restartTimer.stop()
      if (serverProc.running) serverProc.running = false
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

  // ── _resolveColor: resolve chave matugen → cor, com fallback ────────────
  // Map explícito — bracket notation não funciona em singletons QML.
  function _resolveColor(key, fallback) {
    if (!key || key === "") return fallback
    var map = {
      "background":                Colors.background,
      "error":                     Colors.error,
      "error_container":           Colors.error_container,
      "inverse_on_surface":        Colors.inverse_on_surface,
      "inverse_primary":           Colors.inverse_primary,
      "inverse_surface":           Colors.inverse_surface,
      "on_background":             Colors.on_background,
      "on_error":                  Colors.on_error,
      "on_primary":                Colors.on_primary,
      "on_primary_container":      Colors.on_primary_container,
      "on_secondary":              Colors.on_secondary,
      "on_secondary_container":    Colors.on_secondary_container,
      "on_surface":                Colors.on_surface,
      "on_surface_variant":        Colors.on_surface_variant,
      "on_tertiary":               Colors.on_tertiary,
      "on_tertiary_container":     Colors.on_tertiary_container,
      "outline":                   Colors.outline,
      "outline_variant":           Colors.outline_variant,
      "primary":                   Colors.primary,
      "primary_container":         Colors.primary_container,
      "scrim":                     Colors.scrim,
      "secondary":                 Colors.secondary,
      "secondary_container":       Colors.secondary_container,
      "shadow":                    Colors.shadow,
      "source_color":              Colors.source_color,
      "surface":                   Colors.surface,
      "surface_bright":            Colors.surface_bright,
      "surface_container":         Colors.surface_container,
      "surface_container_high":    Colors.surface_container_high,
      "surface_container_highest": Colors.surface_container_highest,
      "surface_container_low":     Colors.surface_container_low,
      "surface_container_lowest":  Colors.surface_container_lowest,
      "surface_dim":               Colors.surface_dim,
      "surface_variant":           Colors.surface_variant,
      "tertiary":                  Colors.tertiary,
      "tertiary_container":        Colors.tertiary_container,
    }
    var v = map[key]
    return (v !== undefined && v !== null) ? v : fallback
  }

  // ── _pushAndOpen: empilha um request e exibe o painel ────────────────────
  function _pushAndOpen(req) {
    var fifo = req.fifo
    req.callback = function(selected, key) {
      var _t0 = Date.now()
      console.log("[dmenu][T+" + _t0 + "] _pushAndOpen.callback — selected:", JSON.stringify(selected), "fifo:", fifo)
      var s = root._stack.slice()
      s.pop()
      root._stack = s

      if (fifo !== "") {
        root._closing = true
        console.log("[dmenu][T+" + Date.now() + "] chamando _respondFifo (dt=" + (Date.now()-_t0) + "ms)")
        _respondFifo(selected, key || "", fifo)
        console.log("[dmenu][T+" + Date.now() + "] _respondFifo RETORNOU, reiniciando cooldown (dt=" + (Date.now()-_t0) + "ms)")
        _cooldownTimer.restart()
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
    // Roteamento próprio do dmenu — chave "dmenu" no PanelRouter, independente
    // do roteamento do módulo "workspaces". O dmenu não tem módulo próprio no
    // layout da barra, então em modo "auto" usamos a posição de "workspaces"
    // (3º argumento, searchModuleName) só como pista de onde abrir — mas o
    // override manual salvo (Barra/Dock/Automático) é do dmenu, não é mais
    // compartilhado com o de workspaces. root.barRoot continua sendo o
    // fallback quando não há resolução melhor, e também decide o desempate
    // quando "workspaces" aparece nas duas instâncias ao mesmo tempo.
    // Ajustável via config UI (PanelRouter.set("dmenu", "bar"|"dock"|"auto")).
    var routedInstance = root.barRoot
        ? PanelRouter.resolveInstance("dmenu", root.barRoot, "workspaces")
        : null
    var activeBar = routedInstance ? routedInstance._activeBar()
                                    : (root.barRoot ? root.barRoot._activeBar() : null)

    // Se o roteamento mudou de instância desde a última abertura (ex: você
    // moveu "workspaces" de bar pra dock no meio da sessão) e a anterior
    // ainda estava marcada como expandida, limpa ela antes de trocar —
    // senão fica uma pill "presa" expandida em quem não tem mais o dmenu.
    if (root._routedInstance && root._routedInstance !== routedInstance) {
      root._routedInstance.dmenuPanelOpen = false
    }
    root._routedInstance = routedInstance || root.barRoot

    ipcPanel.barRef         = activeBar
    // Reaplica cornerMode/bgRadius/animationStyle/etc SEMPRE aqui, e não só
    // via onBarRefChanged. Motivo: se o primeiro _showTop() da sessão rodar
    // antes de root.barRoot terminar de inicializar (ex: dmenu disparado
    // muito cedo por um keybind/autostart), activeBar resolve pra null — e
    // como ipcPanel.barRef já COMEÇA null, atribuir null de novo não é uma
    // mudança de valor real, então onBarRefChanged nunca dispara e
    // _applyConfig() nunca roda com um _pc válido. cornerMode fica preso no
    // default hardcoded do BarPopup ("all") até fechar e abrir de novo (aí
    // sim barRef muda de verdade). Chamando direto aqui, incondicional,
    // garante que a config correta é aplicada nesta abertura, mesmo quando
    // barRef não mudou de identidade.
    ipcPanel._applyConfig()
    // Lê popupW/popupH da PopupConfig DESTA instância (bar ou dock — a mesma
    // que _showTop() acabou de resolver para o roteamento), com fallback pra
    // dmenuConfig. Isso garante que o slider do ConfigWindow (que grava via
    // root.s("popupW") na PopupConfig do alvo selecionado ali) seja
    // refletido aqui também — cada instância com o próprio tamanho/posição.
    var _pcRef = routedInstance ? routedInstance.popupConfigRef
                                 : (root.barRoot ? root.barRoot.popupConfigRef : null)
    var _pcW  = _pcRef ? _pcRef.get("DmenuPopup", "popupW", undefined) : undefined
    var _pcH  = _pcRef ? _pcRef.get("DmenuPopup", "popupH", undefined) : undefined
    ipcPanel.popupW = (_pcW  !== undefined) ? _pcW  : dmenuConfig.dmenuPanelWidth
    var baseH       = (_pcH  !== undefined) ? _pcH  : dmenuConfig.dmenuPanelHeight
    ipcPanel.popupH = req.previewImage
                      ? Math.max(baseH, dmenuConfig.dmenuPanelHeightImg)
                      : baseH

    // Sincroniza a largura que a Pill usa pra se expandir (activePopupW) com
    // o MESMO valor que acabamos de aplicar em ipcPanel.popupW — precisa ser
    // setado ANTES de ipcPanel.panelOpen = true (abaixo), pois é isso que
    // dispara onPanelVisibleChanged → _routedInstance.dmenuPanelOpen = true,
    // e a Pill lê dmenuPanelWidth no mesmo instante em que entra no ramo de
    // expansão (Bar.qml: activePopupW → if (dmenuPanelOpen) return dmenuPanelWidth).
    // Sempre na instância roteada — não mais sempre em root.barRoot.
    if (root._routedInstance) root._routedInstance.dmenuPanelWidth = ipcPanel.popupW
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
  Process {
    id: responseProc
    running: false
    onRunningChanged: {
      if (!running) {
        console.log("[dmenu][T+" + Date.now() + "] responseProc terminou (FIFO escrito)")
      }
    }
  }

  function _respondFifo(selected, key, fifoPath) {
    if (!fifoPath) return
    var _t0 = Date.now()
    console.log("[dmenu][T+" + _t0 + "] _respondFifo — fifo:", fifoPath, "| running:", responseProc.running)
    if (responseProc.running) {
      console.log("[dmenu][T+" + Date.now() + "] responseProc ainda rodando, parando (dt=" + (Date.now()-_t0) + "ms)")
      responseProc.running = false
      console.log("[dmenu][T+" + Date.now() + "] responseProc parado (dt=" + (Date.now()-_t0) + "ms)")
    }
    var payload = JSON.stringify({
      selected: (selected !== null && selected !== undefined) ? selected : null,
      key:      (key      !== null && key      !== undefined) ? key      : ""
    })
    console.log("[dmenu][T+" + Date.now() + "] escrevendo FIFO payload:", payload, "(dt=" + (Date.now()-_t0) + "ms)")
    responseProc.command = ["bash", "-c",
      "printf '%s\\n' " + JSON.stringify(payload) + " > " + JSON.stringify(fifoPath)]
    responseProc.running = true
    console.log("[dmenu][T+" + Date.now() + "] responseProc.running=true (dt=" + (Date.now()-_t0) + "ms)")
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
