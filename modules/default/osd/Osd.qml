import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// ── Osd.qml ──────────────────────────────────────────────────────────────
// Scope raiz do OSD. Instancia OsdService (lógica) + PanelWindows (UI).
//
// Adições em relação à versão anterior:
//   • Recebe clockContent (injetado pelo shell.qml) para conectar timerElapsed
//   • Modo timer usa HyprlandFocusGrab para capturar cliques nos botões
//   • OSD timer tem dismiss automático após 8s sem interação
//   • OSD volume/media fecha em 1600/2200ms como antes
//   • IPC deviceInputMute / deviceOutputMute para mutear dispositivo por nome

Scope {
  id: osdRoot

  readonly property alias osdService: osdService

  // ── Silence mode ────────────────────────────────────────────────────────
  // Injetado pelo shell.qml: osd.silenceMode: bar.silenceMode
  property bool silenceMode: false
  onSilenceModeChanged: {
    if (silenceMode) {
      console.log("[Silence] OSD: ativado — PwObjectTracker esvaziado, showRequested bloqueado")
      // Fecha qualquer OSD visível imediatamente
      // (propagado via silenceMode binding nos PanelWindows)
    } else {
      console.log("[Silence] OSD: desativado — PwObjectTracker restaurado")
    }
  }

  PwObjectTracker {
    // Em silence esvaziamos a lista — para de rastrear PipeWire sem usar "active"
    objects: osdRoot.silenceMode
      ? []
      : [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
    onObjectsChanged: console.log("[Silence] PwObjectTracker objects:", objects.length,
                                  osdRoot.silenceMode ? "(silence ativo)" : "(normal)")
  }

  OsdService { id: osdService }

  IpcHandler {
    target: "osd"

    // ── Ações de OUTPUT (sink padrão) ────────────────────────────────────
    function outputUp(arg: double)   { osdService.doSinkStep( arg > 0 ? arg : 5)  }
    function outputDown(arg: double) { osdService.doSinkStep(-(arg > 0 ? arg : 5)) }
    function outputSet(arg: double)  { osdService.doSinkSet(arg / 100) }
    function outputMute()            { osdService.doSinkMuteToggle()   }
    function outputMuteOn()          { osdService.doSinkMuteSet(true)  }
    function outputMuteOff()         { osdService.doSinkMuteSet(false) }

    // ── Ações de INPUT (source padrão) ───────────────────────────────────
    function inputUp(arg: double)    { osdService.doSourceStep( arg > 0 ? arg : 5)  }
    function inputDown(arg: double)  { osdService.doSourceStep(-(arg > 0 ? arg : 5)) }
    function inputSet(arg: double)   { osdService.doSourceSet(arg / 100) }
    function inputMute()             { osdService.doSourceMuteToggle()   }
    function inputMuteOn()           { osdService.doSourceMuteSet(true)  }
    function inputMuteOff()          { osdService.doSourceMuteSet(false) }

    // ── Dispositivo INPUT específico por nome (--device) ─────────────────
    // name: nome exato do nó Pipewire (ex: alsa_input.usb-Generic_Blue...)
    function deviceInputMute(name: string)    { osdService.doDeviceMuteToggle(name, true)        }
    function deviceInputMuteOn(name: string)  { osdService.doDeviceMuteSet(name, true,  true)    }
    function deviceInputMuteOff(name: string) { osdService.doDeviceMuteSet(name, true,  false)   }

    // ── Dispositivo OUTPUT específico por nome (--device) ─────────────────
    function deviceOutputMute(name: string)    { osdService.doDeviceMuteToggle(name, false)       }
    function deviceOutputMuteOn(name: string)  { osdService.doDeviceMuteSet(name, false, true)    }
    function deviceOutputMuteOff(name: string) { osdService.doDeviceMuteSet(name, false, false)   }

    // ── Mídia — player padrão ────────────────────────────────────────────
    function mediaPlayPause() { osdService.doMediaPlayPause() }
    function mediaPlay()      { osdService.doMediaPlay()      }
    function mediaPause()     { osdService.doMediaPause()     }
    function mediaStop()      { osdService.doMediaStop()      }
    function mediaNext()      { osdService.doMediaNext()      }
    function mediaPrev()      { osdService.doMediaPrev()      }

    // ── Mídia — player específico (--player) ─────────────────────────────
    // name: identity ou desktopEntry do player (ex: "spotify", "firefox")
    // Comparação sem case; aceita match parcial como fallback.
    function mediaPlayPausePlayer(name: string) { osdService.doMediaPlayPausePlayer(name) }
    function mediaPlayPlayer(name: string)      { osdService.doMediaPlayPlayer(name)      }
    function mediaPausePlayer(name: string)     { osdService.doMediaPausePlayer(name)     }
    function mediaStopPlayer(name: string)      { osdService.doMediaStopPlayer(name)      }
    function mediaNextPlayer(name: string)      { osdService.doMediaNextPlayer(name)      }
    function mediaPrevPlayer(name: string)      { osdService.doMediaPrevPlayer(name)      }

    function sinkShow()   { osdService.sinkShow()   }
    function sourceShow() { osdService.sourceShow() }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: osdWin
      required property var modelData

      screen: modelData
      color:  "transparent"

      WlrLayershell.layer:         WlrLayershell.Overlay
      WlrLayershell.keyboardFocus: WlrLayershell.None
      exclusionMode:               ExclusionMode.Ignore

      anchors.top:    true
      anchors.bottom: true
      anchors.left:   true
      anchors.right:  true

      readonly property int pillW: osdContent.implicitWidth
      readonly property int pillH: osdContent.implicitHeight

      // Em silence: torna a window invisível para o compositor não a processar
      visible: !osdRoot.silenceMode && (osdWin.osdVisible || fadeItem.opacity > 0)

      // Centralizado horizontalmente; verticalmente a 72% do topo
      // Usa Math.max(..., 0) para evitar margens negativas em telas pequenas
      margins.left:   Math.max(0, Math.round((screen.width  - pillW) / 2))
      margins.right:  Math.max(0, Math.round((screen.width  - pillW) / 2))
      margins.top:    Math.max(0, Math.round((screen.height - pillH) * 0.72))
      margins.bottom: Math.max(0, Math.round((screen.height - pillH) * 0.28))

      implicitWidth:  pillW
      implicitHeight: pillH

      // ── Estado ────────────────────────────────────────────────────────
      property bool   osdVisible:      false
      property string osdType:         "volume"
      property string osdIcon:         "\uf028"
      property real   osdValue:        0.0
      property string osdLabel:        ""
      property bool   osdMuted:        false
      // Dados específicos do timer
      property string osdTimerLabel:   ""
      property string osdTimerPhase:   ""
      property bool   osdTimerIsPom:   false
      property bool   osdTimerRunning: false
      property int    osdTimerPhaseD:  0

      // ── Focus grab — só ativo no modo timer ───────────────────────────
      HyprlandFocusGrab {
        id: timerFocusGrab
        windows: [ osdWin ]
        active:  osdWin.osdVisible && osdWin.osdType === "timer"
        onCleared: {
          if (osdWin.osdType === "timer") {
            // Usuário clicou fora do OSD — para o som e fecha
            osdService.stopTimerSound()
            osdWin.osdVisible = false
          }
        }
      }

      Connections {
        target: osdService
        function onShowRequested(data) {
          // Silence suprime todo OSD
          if (osdRoot.silenceMode) {
            console.log("[Silence] OSD: showRequested bloqueado (tipo:", data.type || "volume", ")")
            return
          }

          osdWin.osdType    = data.type  || "volume"
          osdWin.osdIcon    = data.icon  || ""
          osdWin.osdLabel   = data.label || ""
          osdWin.osdValue   = data.value !== undefined ? data.value : 0
          osdWin.osdMuted   = data.muted || false

          if (data.type === "timer") {
            osdWin.osdTimerLabel   = data.timerLabel      || ""
            osdWin.osdTimerPhase   = data.timerPhase      || ""
            osdWin.osdTimerIsPom   = data.isPomodoro      || false
            osdWin.osdTimerRunning = data.isRunning       || false
            osdWin.osdTimerPhaseD  = data.phaseDuration   || 0
            hideTimer.interval = 8000
          } else {
            hideTimer.interval = (data.type === "media") ? 2200 : 1600
          }

          osdWin.osdVisible = true
          // Timer: fica visível até dismiss explícito (botão X ou clique fora).
          // Volume/media: fecha automaticamente após o delay.
          if (data.type !== "timer") hideTimer.restart()
          else hideTimer.stop()
        }
      }

      Timer {
        id: hideTimer; repeat: false
        onTriggered: osdWin.osdVisible = false
      }

      // Fade
      Item {
        id: fadeItem
        anchors.fill: parent
        opacity: osdWin.osdVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        OsdContent {
          id: osdContent
          anchors.fill: parent

          // Volume / media
          icon:   osdWin.osdIcon
          value:  osdWin.osdValue
          label:  osdWin.osdLabel
          muted:  osdWin.osdMuted

          // Timer
          timerMode:            osdWin.osdType === "timer"
          timerLabel:           osdWin.osdTimerLabel
          timerPhase:           osdWin.osdTimerPhase
          timerIsPomodoro:      osdWin.osdTimerIsPom
          timerRunning:         osdWin.osdTimerRunning
          timerPhaseDuration:   osdWin.osdTimerPhaseD

          colorBg:     Qt.rgba(0.08, 0.08, 0.08, 0.92)
          colorAccent: "#ffb4a9"
          colorMuted:  Qt.rgba(1, 1, 1, 0.22)
          colorTrack:  Qt.rgba(1, 1, 1, 0.12)
          colorText:   Qt.rgba(1, 1, 1, 0.55)
          colorIcon:   Qt.rgba(1, 1, 1, 0.90)

          // Botões do timer — chamam o ClockContent via osdRoot.clockContent
          onTimerToggle: {
            var cc = osdService.clockContentRef; if (!cc) return
            osdService.stopTimerSound()
            cc.toggleRunningKeepSound()
            osdWin.osdVisible = false
          }
          onTimerAddMin: {
            var cc = osdService.clockContentRef; if (!cc) return
            osdService.stopTimerSound()
            cc.adjustTimerAndStart(60)
            osdWin.osdVisible = false
          }
          onTimerAddInterval: {
            var cc = osdService.clockContentRef; if (!cc) return
            osdService.stopTimerSound()
            cc.addInterval()
            osdWin.osdVisible = false
          }
          onTimerNext: {
            var cc = osdService.clockContentRef; if (!cc) return
            osdService.stopTimerSound()
            cc.pomodoroNextKeepSound()
            osdWin.osdVisible = false
          }
          onTimerDismiss: {
            osdService.stopTimerSound()
            osdWin.osdVisible = false
          }
        }
      }
    }
  }
}
