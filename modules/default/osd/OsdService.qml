import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick

// ── OsdService ────────────────────────────────────────────────────────────
// Fonte única de eventos do OSD. Separa lógica de negócio da UI.

QtObject {
  id: service

  // ── Sinal único de saída → conectado pelo Osd.qml ─────────────────────
  // type: "volume" | "source" | "media" | "timer"
  signal showRequested(var data)

  // ── Referência ao ClockContent ────────────────────────────────────────
  // Injetada por Bar.qml via onClockContentRefChanged / onOsdServiceChanged.
  property var clockContentRef: null

  function stopTimerSound() {
    if (clockContentRef) clockContentRef.stopSound()
  }

  // ── Pipewire ──────────────────────────────────────────────────────────
  readonly property var sink:   Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property real maxVol: 1.5

  // ── Coalescing de volume (debounce 80ms) ──────────────────────────────
  property string _pendingType: ""
  property var _debounceTimer: Timer {
    interval: 80; repeat: false
    onTriggered: {
      if      (service._pendingType === "volume") service._emitSink()
      else if (service._pendingType === "source") service._emitSource()
      service._pendingType = ""
    }
  }

  // ── API pública — Volume ──────────────────────────────────────────────
  function sinkShow()   { _pendingType = "volume"; _debounceTimer.restart() }
  function sourceShow() { _pendingType = "source"; _debounceTimer.restart() }
  function sinkVolume(vol, muted)   { sinkShow()   }
  function sourceVolume(vol, muted) { sourceShow() }

  // ── API pública — Media ───────────────────────────────────────────────
  function media(icon, label) {
    showRequested({ type: "media", icon: icon, label: label, value: -1, muted: false })
  }

  // ── API pública — Timer ───────────────────────────────────────────────
  // Chamado pelo Osd.qml quando ClockContent emite timerElapsed.
  // remaining: segundos restantes já na nova fase (para mostrar no OSD)
  // isPomodoro: true → mostra botão "próxima fase"
  // isRunning:  estado de play/pause atual
  function timerOsd(phaseLabel, remaining, isPomodoro, isRunning, phaseDuration) {
    var mm = Math.floor(remaining / 60)
    var ss = remaining % 60
    var label = (mm < 10 ? "0" : "") + mm + ":" + (ss < 10 ? "0" : "") + ss
    showRequested({
      type:          "timer",
      timerLabel:    label,
      timerPhase:    phaseLabel,
      isPomodoro:    isPomodoro,
      isRunning:     isRunning,
      phaseDuration: phaseDuration || 0,
      value:         -2,
      icon:          "\uf017",
      label:         label,
      muted:         false
    })
  }

  // ── Emissores internos ─────────────────────────────────────────────────
  function _emitSink() {
    var s = sink; var vol = (s && s.audio) ? s.audio.volume : 0; var muted = (s && s.audio) ? s.audio.muted : false
    showRequested({
      type:  "volume",
      icon:  (muted || vol <= 0) ? "\uf026" : vol < 0.34 ? "\uf026" : vol < 0.67 ? "\uf027" : "\uf028",
      label: muted ? "" : (Math.round(vol * 100) + "%"),
      value: Math.min(1.0, vol / maxVol),
      muted: muted || vol <= 0
    })
  }

  function _emitSource() {
    var s = source; var vol = (s && s.audio) ? s.audio.volume : 0; var muted = (s && s.audio) ? s.audio.muted : false
    showRequested({
      type:  "source",
      icon:  (muted || vol <= 0) ? "\uf131" : "\uf130",
      label: muted ? "" : (Math.round(vol * 100) + "%"),
      value: Math.min(1.0, vol / maxVol),
      muted: muted || vol <= 0
    })
  }

  // ── Dispositivo específico por nome ───────────────────────────────────
  // Procura em Pipewire.nodes pelo node.name exato.
  // Retorna null se não encontrar.
  function _findNode(name) {
    var nodes = Pipewire.nodes.values
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].name === name) return nodes[i]
    }
    return null
  }

  // Emite OSD para um nó encontrado por nome.
  // isSource: true → ícone de microfone, false → ícone de alto-falante
  function _emitDevice(node, isSource) {
    if (!node || !node.audio) return
    var vol    = node.audio.volume
    var muted  = node.audio.muted

    var icon
    if (isSource) {
      icon = (muted || vol <= 0) ? "\uf131" : "\uf130"
    } else {
      icon = (muted || vol <= 0) ? "\uf026" : vol < 0.34 ? "\uf026" : vol < 0.67 ? "\uf027" : "\uf028"
    }

    showRequested({
      type:  isSource ? "source" : "volume",
      icon:  icon,
      label: muted ? "" : (Math.round(vol * 100) + "%"),
      value: Math.min(1.0, vol / maxVol),
      muted: muted || vol <= 0
    })
  }

  // Toggle mute em qualquer nó Pipewire pelo nome.
  // isSource: controla qual ícone o OSD exibe.
  function doDeviceMuteToggle(name, isSource) {
    var node = _findNode(name)
    if (!node || !node.audio) return
    node.audio.muted = !node.audio.muted
    _emitDevice(node, isSource)
  }

  // Força mute ligado/desligado em qualquer nó pelo nome.
  function doDeviceMuteSet(name, isSource, val) {
    var node = _findNode(name)
    if (!node || !node.audio) return
    node.audio.muted = val
    _emitDevice(node, isSource)
  }

  // ── Ações com efeito (IPC) ────────────────────────────────────────────
  function doSinkStep(stepPct) {
    var s = sink; if (!s || !s.audio) return
    var next = Math.max(0, Math.min(maxVol, s.audio.volume + stepPct / 100))
    s.audio.volume = next
    if (next > 0 && s.audio.muted) s.audio.muted = false
    sinkShow()
  }
  function doSinkSet(v) { var s = sink; if (!s || !s.audio) return; s.audio.volume = Math.max(0, Math.min(maxVol, v)); sinkShow() }
  function doSinkMuteToggle() { var s = sink; if (!s || !s.audio) return; s.audio.muted = !s.audio.muted; sinkShow() }
  function doSinkMuteSet(val) { var s = sink; if (!s || !s.audio) return; s.audio.muted = val; sinkShow() }

  function doSourceStep(stepPct) {
    var s = source; if (!s || !s.audio) return
    var next = Math.max(0, Math.min(maxVol, s.audio.volume + stepPct / 100))
    s.audio.volume = next
    if (next > 0 && s.audio.muted) s.audio.muted = false
    sourceShow()
  }
  function doSourceSet(v) { var s = source; if (!s || !s.audio) return; s.audio.volume = Math.max(0, Math.min(maxVol, v)); sourceShow() }
  function doSourceMuteToggle() { var s = source; if (!s || !s.audio) return; s.audio.muted = !s.audio.muted; sourceShow() }
  function doSourceMuteSet(val) { var s = source; if (!s || !s.audio) return; s.audio.muted = val; sourceShow() }

  // ── Ações de mídia ────────────────────────────────────────────────────
  readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

  function _mediaLabel(p) {
    if (!p) p = activePlayer
    if (!p) return ""
    var t = p.trackTitle || ""; var a = p.trackArtist || ""
    return (a && t) ? a + " – " + t : (t || a)
  }

  // Busca um player MPRIS pelo nome (identity ou desktopEntry),
  // comparação sem case. Retorna null se não encontrar.
  function _findPlayer(name) {
    if (!name) return activePlayer
    var lower = name.toLowerCase()
    var players = Mpris.players.values
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if ((p.identity      || "").toLowerCase() === lower) return p
      if ((p.desktopEntry  || "").toLowerCase() === lower) return p
    }
    // Segunda passagem: match parcial (ex: "spotify" bate em "Spotify Premium")
    for (var j = 0; j < players.length; j++) {
      var q = players[j]
      if ((q.identity     || "").toLowerCase().indexOf(lower) !== -1) return q
      if ((q.desktopEntry || "").toLowerCase().indexOf(lower) !== -1) return q
    }
    return null
  }

  // ── Ações padrão (primeiro player ativo) ─────────────────────────────
  function doMediaPlayPause() {
    var p = activePlayer; if (!p) return
    var playing = p.playbackState === MprisPlaybackState.Playing
    p.togglePlaying()
    media(playing ? "\uf04c" : "\uf04b", _mediaLabel(p))
  }
  function doMediaPlay()  { var p = activePlayer; if (!p) return; p.play();    media("\uf04b", _mediaLabel(p)) }
  function doMediaPause() { var p = activePlayer; if (!p) return; p.pause();   media("\uf04c", _mediaLabel(p)) }
  function doMediaStop()  { var p = activePlayer; if (!p) return; p.stop();    media("\uf04d", "Parado") }
  function doMediaNext()  { var p = activePlayer; if (!p) return; p.next();    Qt.callLater(function() { media("\uf051", _mediaLabel(p)) }) }
  function doMediaPrev()  { var p = activePlayer; if (!p) return; p.previous();Qt.callLater(function() { media("\uf048", _mediaLabel(p)) }) }

  // ── Ações com player específico (--player) ───────────────────────────
  function doMediaPlayPausePlayer(name) {
    var p = _findPlayer(name); if (!p) return
    var playing = p.playbackState === MprisPlaybackState.Playing
    p.togglePlaying()
    media(playing ? "\uf04c" : "\uf04b", _mediaLabel(p))
  }
  function doMediaPlayPlayer(name)  {
    var p = _findPlayer(name); if (!p) return; p.play();    media("\uf04b", _mediaLabel(p))
  }
  function doMediaPausePlayer(name) {
    var p = _findPlayer(name); if (!p) return; p.pause();   media("\uf04c", _mediaLabel(p))
  }
  function doMediaStopPlayer(name)  {
    var p = _findPlayer(name); if (!p) return; p.stop();    media("\uf04d", "Parado")
  }
  function doMediaNextPlayer(name)  {
    var p = _findPlayer(name); if (!p) return; p.next();    Qt.callLater(function() { media("\uf051", _mediaLabel(p)) })
  }
  function doMediaPrevPlayer(name)  {
    var p = _findPlayer(name); if (!p) return; p.previous();Qt.callLater(function() { media("\uf048", _mediaLabel(p)) })
  }
}
