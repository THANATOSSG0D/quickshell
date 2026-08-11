import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.singletons

// ── ClockContent ───────────────────────────────────────────────────────────
// Fonte de verdade do timer/pomodoro.
//
// FIXES nesta versão:
// • barTimerActive agora usa timerDismissed — após zerar no modo livre,
//   o widget some da barra. É restaurado ao iniciar um novo timer.
// • timerDismissed = true quando: modo livre expira E o usuário não iniciou
//   um novo timer (expired=true → após N segundos sem interação, some).
// • Persistência correta: savedAt + elapsed corrigido para não subtrair
//   quando o timer estava parado.

Item {
  id: root

  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  signal closeRequested()
  signal timerElapsed(string mode, string phaseLabel)

  // ── Tick do relógio ───────────────────────────────────────────────────
  property bool _tick: false
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: root._tick = !root._tick
  }

  readonly property string currentTime: {
    var _ = _tick
    var d = new Date()
    return (d.getHours()  < 10 ? "0" : "") + d.getHours()   + ":"
         + (d.getMinutes()< 10 ? "0" : "") + d.getMinutes() + ":"
         + (d.getSeconds()< 10 ? "0" : "") + d.getSeconds()
  }
  readonly property string currentDate: {
    var _ = _tick
    var d    = new Date()
    var days = ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"]
    var mons = ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]
    return days[d.getDay()] + ", " + d.getDate() + " " + mons[d.getMonth()] + " " + d.getFullYear()
  }

  // ── Estado do timer ───────────────────────────────────────────────────
  property int    pomodoroWork:      25 * 60
  property int    pomodoroShort:      5 * 60
  property int    pomodoroLong:      15 * 60
  property int    pomodoroInterval:  4
  property int    pomodoroCount:     0
  property bool   pomodoroInWork:    true
  property int    freeTimerDuration: 5 * 60
  property string activeMode:        "free"
  property int    remaining:         0
  property bool   running:           false
  property bool   expired:           false

  // ── timerDismissed ─────────────────────────────────────────────────────
  //
  // Controla a visibilidade do timer no widget da barra (Clock.qml).
  //
  // Setado para true:
  //   • Modo livre: quando o countdown zera (expired=true) e o timer de
  //     auto-dismiss dispara (dismissDelay, padrão 8s).
  //   • Manualmente: resetTimer() → timer some da barra imediatamente.
  //
  // Setado para false (timer aparece de novo):
  //   • startFree(), startPomodoro(), toggleRunning() quando reinicia.
  //   • Modo pomodoro: nunca some da barra enquanto o ciclo estiver ativo.
  property bool timerDismissed: true

  // Delay antes de sumir da barra após expirar (modo livre apenas)
  property int dismissDelayMs: 8000

  Timer {
    id: dismissTimer
    interval: root.dismissDelayMs
    repeat:   false
    onTriggered: {
      // Só dismiss no modo livre; pomodoro fica na barra até resetar
      if (root.activeMode === "free" && root.expired)
        root.timerDismissed = true
    }
  }

  // O que Clock.qml lê para decidir se mostra o timer
  readonly property bool barTimerActive: {
    if (timerDismissed) return false
    if (activeMode === "free")     return running || (remaining > 0) || expired
    // pomodoro: fica ativo enquanto houver remaining ou estiver rodando
    return remaining > 0 || running || expired
  }
  readonly property int  barRemaining: remaining
  readonly property bool barRunning:   running
  readonly property bool barExpired:   expired

  readonly property string phaseLabel: {
    if (activeMode === "free") return "Timer"
    if (pomodoroInWork)        return "Foco · " + (pomodoroCount + 1) + "º ciclo"
    var isLongBreak = (pomodoroCount % pomodoroInterval === 0) && pomodoroCount > 0
    return isLongBreak ? "Descanso longo" : "Descanso curto"
  }

  // Duração completa da fase atual — usada pelo OSD para o botão "+intervalo"
  readonly property int phaseDuration: {
    if (activeMode === "pomodoro") {
      if (pomodoroInWork) return pomodoroWork
      var isLong = (pomodoroCount % pomodoroInterval === 0) && pomodoroCount > 0
      return isLong ? pomodoroLong : pomodoroShort
    }
    return freeTimerDuration
  }

  // ── Persistência ──────────────────────────────────────────────────────
  property bool _stateLoaded: false

  FileView {
    id: stateFile
    path:         Quickshell.shellDir + "/state/clock-state.json"
    watchChanges: false
    onAdapterUpdated: { if (!root._stateLoaded) root._loadState() }

    JsonAdapter {
      id: stateAdapter
      property string activeMode:        "free"
      property int    remaining:         0
      property bool   running:           false
      property bool   timerDismissed:    true
      property int    freeTimerDuration: 5 * 60
      property int    pomodoroWork:      25 * 60
      property int    pomodoroShort:      5 * 60
      property int    pomodoroLong:      15 * 60
      property int    pomodoroInterval:  4
      property int    pomodoroCount:     0
      property bool   pomodoroInWork:    true
      property real   savedAt:           0
    }
  }

  Component.onCompleted: StateDir.whenReady(() => stateFile.reload())

  function _loadState() {
    var s = stateAdapter
    root.activeMode        = s.activeMode        || "free"
    root.freeTimerDuration = s.freeTimerDuration || 5 * 60
    root.pomodoroWork      = s.pomodoroWork       || 25 * 60
    root.pomodoroShort     = s.pomodoroShort      ||  5 * 60
    root.pomodoroLong      = s.pomodoroLong       || 15 * 60
    root.pomodoroInterval  = s.pomodoroInterval   || 4
    root.pomodoroCount     = s.pomodoroCount      || 0
    root.pomodoroInWork    = (s.pomodoroInWork !== false)
    root.timerDismissed    = (s.timerDismissed  !== false)

    var rem        = s.remaining || 0
    var wasRunning = s.running   || false
    var saved      = s.savedAt   || 0

    if (wasRunning && saved > 0 && rem > 0) {
      // Timer estava rodando quando o shell fechou — subtrai tempo passado
      var elapsed = Math.floor((Date.now() - saved) / 1000)
      rem = Math.max(0, rem - elapsed)
      if (rem === 0) {
        root.remaining      = 0
        root.running        = false
        root.expired        = true
        root.timerDismissed = false   // mostra como expirado
        // Dispara o auto-dismiss (se o usuário não interagir em dismissDelayMs)
        dismissTimer.restart()
      } else {
        root.remaining = rem
        root.running   = true
        root.expired   = false
        root.timerDismissed = false
      }
    } else {
      root.remaining = rem
      root.running   = false
      root.expired   = false
      // timerDismissed já foi setado acima via stateAdapter
    }
    root._stateLoaded = true
  }

  function _saveState() {
    if (!_stateLoaded) return
    stateAdapter.activeMode        = root.activeMode
    stateAdapter.remaining         = root.remaining
    stateAdapter.running           = root.running
    stateAdapter.timerDismissed    = root.timerDismissed
    stateAdapter.freeTimerDuration = root.freeTimerDuration
    stateAdapter.pomodoroWork      = root.pomodoroWork
    stateAdapter.pomodoroShort     = root.pomodoroShort
    stateAdapter.pomodoroLong      = root.pomodoroLong
    stateAdapter.pomodoroInterval  = root.pomodoroInterval
    stateAdapter.pomodoroCount     = root.pomodoroCount
    stateAdapter.pomodoroInWork    = root.pomodoroInWork
    // savedAt só é útil quando rodando — assim o cálculo de elapsed é preciso
    stateAdapter.savedAt           = root.running ? Date.now() : 0
  }

  Timer { id: saveDebounce; interval: 400; repeat: false; onTriggered: root._saveState() }
  function _scheduleSave() { if (_stateLoaded) saveDebounce.restart() }

  onRemainingChanged:         _scheduleSave()
  onRunningChanged:           _scheduleSave()
  onActiveModeChanged:        _scheduleSave()
  onFreeTimerDurationChanged: _scheduleSave()
  onPomodoroWorkChanged:      _scheduleSave()
  onPomodoroShortChanged:     _scheduleSave()
  onPomodoroLongChanged:      _scheduleSave()
  onPomodoroIntervalChanged:  _scheduleSave()
  onPomodoroCountChanged:     _scheduleSave()
  onPomodoroInWorkChanged:    _scheduleSave()
  onTimerDismissedChanged:    _scheduleSave()

  // ── Som ───────────────────────────────────────────────────────────────
  // O alerta toca em loop até stopSound() ser chamado (dismiss/reinício).
  // Tenta vários backends — paplay (PulseAudio/Pipewire-pulse), pw-play
  // (Pipewire nativo) e pactl play-sample como fallback legacy.
  Process {
    id: soundProc
    command: [
      "sh", "-c",
      "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null"
      + " || pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null"
      + " || paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null"
      + " || pactl play-sample bell 2>/dev/null"
      + " || true"
    ]
    running: false
    // Quando o processo termina, agenda o próximo play imediatamente (sem esperar o timer).
    // soundRepeatTimer adiciona uma pequena pausa entre repetições para não soar como
    // um som contínuo sem respiração.
    onExited: { if (root.soundLooping) soundRepeatTimer.restart() }
  }

  // Pausa mínima entre repetições (ms). Reduzir para 0 toca sem gap.
  property bool soundLooping: false
  Timer {
    id: soundRepeatTimer
    interval: 600
    repeat:   false
    onTriggered: root._playOnce()
  }

  // Timer de heartbeat: garante que o loop retoma mesmo se onExited falhar
  // (ex: processo morto externamente sem disparar o sinal).
  Timer {
    id: soundHeartbeat
    interval: 5000
    repeat:   true
    running:  root.soundLooping
    onTriggered: { if (!soundProc.running && !soundRepeatTimer.running) root._playOnce() }
  }

  function _playOnce() {
    if (soundProc.running) return   // ainda tocando — aguarda onExited
    soundProc.running = true
  }

  // Inicia o loop: toca imediatamente
  function _playSound() {
    soundLooping = true
    _playOnce()
  }

  // Para o loop — chamado pelo OSD (dismiss/next) ou pelo IPC
  function stopSound() {
    soundLooping = false
    soundRepeatTimer.stop()
  }

  // ── Countdown ─────────────────────────────────────────────────────────
  Timer {
    id: countdownTimer
    interval: 1000
    repeat:   true
    running:  root.running && root.remaining > 0
    onTriggered: {
      root.remaining -= 1
      if (root.remaining <= 0) {
        root.remaining = 0
        root.running   = false
        root.expired   = true
        _onExpired()
      }
    }
  }

  function _onExpired() {
    var label = root.phaseLabel   // label da fase que ACABOU
    _playSound()

    if (root.activeMode === "free") {
      // Modo livre: emite sinal (remaining=0) e agenda auto-dismiss da barra
      root.timerElapsed(root.activeMode, label)
      dismissTimer.restart()
      return
    }

    // Pomodoro: avança a fase ANTES de emitir o sinal.
    // Assim o OSD lê barRemaining já com o tempo da nova fase.
    if (pomodoroInWork) {
      pomodoroCount++
      pomodoroInWork = false
      var isLong = (pomodoroCount % pomodoroInterval === 0)
      remaining = isLong ? pomodoroLong : pomodoroShort
    } else {
      pomodoroInWork = true
      remaining      = pomodoroWork
    }
    expired = false
    running = false
    // Pomodoro nunca some da barra automaticamente

    root.timerElapsed(root.activeMode, label)
  }

  // ── API pública ────────────────────────────────────────────────────────
  function startFree(seconds) {
    stopSound()
    dismissTimer.stop()
    activeMode      = "free"
    remaining       = seconds > 0 ? seconds : freeTimerDuration
    running         = true
    expired         = false
    timerDismissed  = false
  }

  function startPomodoro() {
    stopSound()
    dismissTimer.stop()
    activeMode      = "pomodoro"
    pomodoroInWork  = true
    pomodoroCount   = 0
    remaining       = pomodoroWork
    running         = true
    expired         = false
    timerDismissed  = false
  }

  function toggleRunning() {
    stopSound()
    if (expired) {
      dismissTimer.stop()
      expired        = false
      remaining      = activeMode === "pomodoro" ? pomodoroWork : freeTimerDuration
      running        = true
      timerDismissed = false
      return
    }
    if (remaining === 0 && !running) {
      remaining      = activeMode === "pomodoro" ? pomodoroWork : freeTimerDuration
      timerDismissed = false
    }
    if (!running) {
      dismissTimer.stop()
      timerDismissed = false
    }
    running = !running
  }

  function pomodoroNext() {
    stopSound()
    if (activeMode !== "pomodoro") return
    dismissTimer.stop()
    expired = false
    if (pomodoroInWork) {
      pomodoroCount++
      pomodoroInWork = false
      var isLong = (pomodoroCount % pomodoroInterval === 0)
      remaining = isLong ? pomodoroLong : pomodoroShort
    } else {
      pomodoroInWork = true
      remaining      = pomodoroWork
    }
    running        = true
    timerDismissed = false
  }

  function resetTimer() {
    stopSound()
    dismissTimer.stop()
    running        = false
    expired        = false
    timerDismissed = true    // ← some da barra imediatamente ao resetar
    if (activeMode === "pomodoro") {
      pomodoroInWork = true
      pomodoroCount  = 0
      remaining      = pomodoroWork
    } else {
      remaining = freeTimerDuration
    }
  }

  function adjustTimer(delta) {
    dismissTimer.stop()
    expired        = false
    timerDismissed = false
    remaining      = Math.max(0, Math.min(99 * 60 + 59, remaining + delta))
    if (activeMode === "free" && !running) freeTimerDuration = remaining
  }

  // ── API chamada pelo OSD (não para o som) ─────────────────────────────
  // toggleRunning para o som; estas versões mantêm o alerta até o dismiss.

  function toggleRunningKeepSound() {
    if (expired) {
      dismissTimer.stop()
      expired        = false
      remaining      = activeMode === "pomodoro" ? pomodoroWork : freeTimerDuration
      running        = true
      timerDismissed = false
      return
    }
    if (remaining === 0 && !running) {
      remaining      = activeMode === "pomodoro" ? pomodoroWork : freeTimerDuration
      timerDismissed = false
    }
    if (!running) {
      dismissTimer.stop()
      timerDismissed = false
    }
    running = !running
  }

  // Adiciona delta segundos e inicia imediatamente
  function adjustTimerAndStart(delta) {
    dismissTimer.stop()
    expired        = false
    timerDismissed = false
    remaining      = Math.max(0, Math.min(99 * 60 + 59, remaining + delta))
    if (activeMode === "free") freeTimerDuration = remaining
    running = true
  }

  // Adiciona uma fase completa (freeTimerDuration ou fase pomodoro atual) e inicia
  function addInterval() {
    dismissTimer.stop()
    expired        = false
    timerDismissed = false
    remaining      = Math.max(0, Math.min(99 * 60 + 59, remaining + phaseDuration))
    running        = true
  }

  // Avança fase pomodoro sem parar o som
  function pomodoroNextKeepSound() {
    if (activeMode !== "pomodoro") return
    dismissTimer.stop()
    expired = false
    if (pomodoroInWork) {
      pomodoroCount++
      pomodoroInWork = false
      var isLong = (pomodoroCount % pomodoroInterval === 0)
      remaining = isLong ? pomodoroLong : pomodoroShort
    } else {
      pomodoroInWork = true
      remaining      = pomodoroWork
    }
    running        = true
    timerDismissed = false
  }

  function fmtSec(s) {
    if (s < 0) s = 0
    var m = Math.floor(s / 60)
    var sec = s % 60
    return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
  }

  // ── UI ────────────────────────────────────────────────────────────────
  ColumnLayout {
    anchors.fill:    parent
    anchors.margins: 16
    spacing:         12

    // Relógio — sempre visível
    Item {
      Layout.fillWidth:       true
      Layout.preferredHeight: clockCol.implicitHeight

      Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           { var _ = root._tick; return root.currentTime }
          color:          root.colorText
          font.pixelSize: 34
          font.weight:    Font.Light
          font.family:    "JetBrainsMono Nerd Font"
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text:           { var _ = root._tick; return root.currentDate }
          color:          root.colorTextDim
          font.pixelSize: 11
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      height: 1
      color:  Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.4)
    }

    // Seletor de modo
    Item {
      Layout.fillWidth:       true
      Layout.preferredHeight: modeRow.implicitHeight

      Row {
        id: modeRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
          model: [
            { id: "free",     label: "\uf017  Timer"     },
            { id: "pomodoro", label: "\uf0ae  Pomodoro"  }
          ]
          Rectangle {
            required property var modelData
            readonly property bool active: root.activeMode === modelData.id
            height: 24
            width:  ml.implicitWidth + 18
            radius: height / 2
            color: active ? root.colorAccent : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: modeMA.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Text {
              id: ml
              anchors.centerIn: parent
              text:           parent.modelData.label
              font.pixelSize: 10
              font.weight:    parent.active ? Font.DemiBold : Font.Normal
              font.family:    "JetBrainsMono Nerd Font"
              color:          parent.active ? "#1a1a1a" : root.colorTextDim
              Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
              id: modeMA
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.activeMode !== parent.modelData.id) {
                  root.activeMode = parent.modelData.id
                  root.resetTimer()
                }
              }
            }
          }
        }
      }
    }

    // Timer display
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        Layout.fillWidth:       true
        Layout.alignment:       Qt.AlignHCenter
        horizontalAlignment:    Text.AlignHCenter
        text:           root.fmtSec(root.remaining)
        color:          root.expired ? root.colorAccent : root.running ? root.colorText : root.colorTextDim
        font.pixelSize: 42
        font.weight:    Font.Light
        font.family:    "JetBrainsMono Nerd Font"
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      Item {
        Layout.fillWidth:       true
        Layout.preferredHeight: 4

        readonly property real progress: {
          var total = root.activeMode === "pomodoro"
            ? (root.pomodoroInWork
                ? root.pomodoroWork
                : ((root.pomodoroCount % root.pomodoroInterval === 0 && root.pomodoroCount > 0)
                    ? root.pomodoroLong : root.pomodoroShort))
            : root.freeTimerDuration
          return total > 0 ? Math.max(0, Math.min(1, root.remaining / total)) : 0
        }

        Rectangle {
          anchors.fill: parent
          radius: 2
          color:  Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.4)
        }
        Rectangle {
          anchors.left:   parent.left
          anchors.top:    parent.top
          anchors.bottom: parent.bottom
          radius:  2
          color:   root.colorAccent
          opacity: root.running ? 1.0 : 0.5
          width:   parent.width * parent.progress
          Behavior on width   { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
          Behavior on opacity { NumberAnimation { duration: 200 } }
        }
      }

      Text {
        Layout.fillWidth:    true
        Layout.alignment:    Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        visible:        root.activeMode === "pomodoro"
        text:           root.phaseLabel
        color:          root.colorTextDim
        font.pixelSize: 11
      }
    }

    // Controles
    Item {
      Layout.fillWidth:       true
      Layout.preferredHeight: 48

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        // Reset
        Item {
          width: 32; height: 32
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: ra.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: ra.pressed ? 0.88 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
          }
          Text {
            anchors.centerIn: parent
            text:           "\uf0e2"
            color:          root.colorTextDim
            font.pixelSize: 14
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetTimer() }
        }

        // Play/Pause
        Item {
          width: 48; height: 48
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color:   root.colorAccent
            scale:   pa.pressed ? 0.9 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
          }
          Text {
            anchors.centerIn: parent
            text:           root.expired ? "\uf0e2" : root.running ? "\uf04c" : "\uf04b"
            color:          root.colorPanelBg
            font.pixelSize: 20
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea { id: pa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleRunning() }
        }

        // +1 min
        Item {
          width: 32; height: 32
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: aa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: aa.pressed ? 0.88 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
          }
          Text {
            anchors.centerIn: parent
            text:           "+1"
            color:          root.colorTextDim
            font.pixelSize: 11
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea { id: aa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.adjustTimer(60) }
        }

        // Próxima fase (pomodoro)
        Item {
          visible: root.activeMode === "pomodoro"
          width: 32; height: 32
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: na.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: na.pressed ? 0.88 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
          }
          Text {
            anchors.centerIn: parent
            text:           "\uf051"
            color:          root.colorTextDim
            font.pixelSize: 13
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea { id: na; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pomodoroNext() }
        }
      }
    }

    // Presets (livre)
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: root.activeMode === "free"

      Text {
        text:           "Presets"
        color:          root.colorTextDim
        font.pixelSize: 10
        font.weight:    Font.Medium
      }
      Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: [
            { label: "5 min",  secs: 300  }, { label: "10 min", secs: 600  },
            { label: "15 min", secs: 900  }, { label: "20 min", secs: 1200 },
            { label: "25 min", secs: 1500 }, { label: "30 min", secs: 1800 },
            { label: "45 min", secs: 2700 }, { label: "60 min", secs: 3600 }
          ]
          Rectangle {
            required property var modelData
            readonly property bool active: root.freeTimerDuration === modelData.secs && root.activeMode === "free"
            height: 22
            width:  pl.implicitWidth + 14
            radius: height / 2
            color:        active ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                                 : Qt.rgba(1, 1, 1, 0.05)
            border.color: active ? root.colorAccent : "transparent"
            border.width: 1
            Text {
              id: pl
              anchors.centerIn: parent
              text:           parent.modelData.label
              font.pixelSize: 10
              color:          parent.active ? root.colorAccent : root.colorTextDim
            }
            MouseArea {
              anchors.fill: parent
              onClicked: {
                root.freeTimerDuration = parent.modelData.secs
                root.startFree(parent.modelData.secs)
              }
            }
          }
        }
      }
    }

    // Config pomodoro
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.activeMode === "pomodoro"

      Text {
        text:           "Configuração"
        color:          root.colorTextDim
        font.pixelSize: 10
        font.weight:    Font.Medium
      }
      Repeater {
        model: [
          { label: "Foco",            prop: "pomodoroWork",     step: 60, min: 60, max: 5400 },
          { label: "Descanso curto",  prop: "pomodoroShort",    step: 60, min: 60, max: 1800 },
          { label: "Descanso longo",  prop: "pomodoroLong",     step: 60, min: 60, max: 3600 },
          { label: "Ciclos p/ longo", prop: "pomodoroInterval", step: 1,  min: 1,  max: 10   }
        ]
        RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 8

          Text {
            text:                  parent.modelData.label
            color:                 root.colorTextDim
            font.pixelSize:        10
            Layout.preferredWidth: 110
          }
          Item { Layout.fillWidth: true }

          Item {
            width: 20; height: 20
            Rectangle {
              anchors.fill: parent; radius: width / 2; color: Qt.rgba(1,1,1,0.06)
              scale: stepDownMA.pressed ? 0.85 : 1.0
              Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
            Text {
              anchors.centerIn: parent
              text:           "\uf068"
              color:          root.colorTextDim
              font.pixelSize: 9
              font.family:    "JetBrainsMono Nerd Font"
            }
            MouseArea {
              id: stepDownMA
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var md = parent.parent.modelData
                root[md.prop] = Math.max(md.min, root[md.prop] - md.step)
              }
            }
          }

          Text {
            text: {
              var md = parent.modelData
              var v  = root[md.prop]
              return md.prop === "pomodoroInterval" ? v + "x" : Math.floor(v / 60) + " min"
            }
            color:                 root.colorText
            font.pixelSize:        10
            font.family:           "JetBrainsMono Nerd Font"
            Layout.preferredWidth: 42
            horizontalAlignment:   Text.AlignHCenter
          }

          Item {
            width: 20; height: 20
            Rectangle {
              anchors.fill: parent; radius: width / 2; color: Qt.rgba(1,1,1,0.06)
              scale: stepUpMA.pressed ? 0.85 : 1.0
              Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
            Text {
              anchors.centerIn: parent
              text:           "\uf067"
              color:          root.colorTextDim
              font.pixelSize: 9
              font.family:    "JetBrainsMono Nerd Font"
            }
            MouseArea {
              id: stepUpMA
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var md = parent.parent.modelData
                root[md.prop] = Math.min(md.max, root[md.prop] + md.step)
              }
            }
          }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        visible: !root.running && !root.expired
        height: 28
        width:  spl.implicitWidth + 24
        radius: height / 2
        color:  root.colorAccent
        scale:  startPomoMA.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Text {
          id: spl
          anchors.centerIn: parent
          text:           "Iniciar Pomodoro"
          color:          "#1a1a1a"
          font.pixelSize: 10
          font.weight:    Font.DemiBold
        }
        MouseArea { id: startPomoMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.startPomodoro() }
      }
    }

    Item { Layout.fillHeight: true }
  }
}
