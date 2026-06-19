import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "../../.." // Colors singleton

// ── Osd.qml ──────────────────────────────────────────────────────────────
// Scope raiz do OSD. Instancia OsdService (lógica) + PanelWindows (UI).

Scope {
  id: osdRoot

  readonly property alias osdService: osdService

  // ── Silence mode ────────────────────────────────────────────────────────
  property bool silenceMode: false
  onSilenceModeChanged: {
    if (silenceMode) {
      console.log("[Silence] OSD: ativado — PwObjectTracker esvaziado, showRequested bloqueado")
    } else {
      console.log("[Silence] OSD: desativado — PwObjectTracker restaurado")
    }
  }

  PwObjectTracker {
    objects: osdRoot.silenceMode
      ? []
      : [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
    onObjectsChanged: console.log("[Silence] PwObjectTracker objects:", objects.length,
                                  osdRoot.silenceMode ? "(silence ativo)" : "(normal)")
  }

  OsdService { id: osdService }

  IpcHandler {
    target: "osd"

    function outputUp(arg: double)   { osdService.doSinkStep( arg > 0 ? arg : 5)  }
    function outputDown(arg: double) { osdService.doSinkStep(-(arg > 0 ? arg : 5)) }
    function outputSet(arg: double)  { osdService.doSinkSet(arg / 100) }
    function outputMute()            { osdService.doSinkMuteToggle()   }
    function outputMuteOn()          { osdService.doSinkMuteSet(true)  }
    function outputMuteOff()         { osdService.doSinkMuteSet(false) }

    function inputUp(arg: double)    { osdService.doSourceStep( arg > 0 ? arg : 5)  }
    function inputDown(arg: double)  { osdService.doSourceStep(-(arg > 0 ? arg : 5)) }
    function inputSet(arg: double)   { osdService.doSourceSet(arg / 100) }
    function inputMute()             { osdService.doSourceMuteToggle()   }
    function inputMuteOn()           { osdService.doSourceMuteSet(true)  }
    function inputMuteOff()          { osdService.doSourceMuteSet(false) }

    function deviceInputMute(name: string)    { osdService.doDeviceMuteToggle(name, true)        }
    function deviceInputMuteOn(name: string)  { osdService.doDeviceMuteSet(name, true,  true)    }
    function deviceInputMuteOff(name: string) { osdService.doDeviceMuteSet(name, true,  false)   }

    function deviceOutputMute(name: string)    { osdService.doDeviceMuteToggle(name, false)       }
    function deviceOutputMuteOn(name: string)  { osdService.doDeviceMuteSet(name, false, true)    }
    function deviceOutputMuteOff(name: string) { osdService.doDeviceMuteSet(name, false, false)   }

    function mediaPlayPause() { osdService.doMediaPlayPause() }
    function mediaPlay()      { osdService.doMediaPlay()      }
    function mediaPause()     { osdService.doMediaPause()     }
    function mediaStop()      { osdService.doMediaStop()      }
    function mediaNext()      { osdService.doMediaNext()      }
    function mediaPrev()      { osdService.doMediaPrev()      }

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

      visible: !osdRoot.silenceMode && (osdWin.osdVisible || fadeItem.opacity > 0)

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
      property string osdArtUrl:       ""
      property bool   osdMuted:        false
      property string osdTimerLabel:   ""
      property string osdTimerPhase:   ""
      property bool   osdTimerIsPom:   false
      property bool   osdTimerRunning: false
      property int    osdTimerPhaseD:  0

      HyprlandFocusGrab {
        id: timerFocusGrab
        windows: [ osdWin ]
        active:  osdWin.osdVisible && osdWin.osdType === "timer"
        onCleared: {
          if (osdWin.osdType === "timer") {
            osdService.stopTimerSound()
            osdWin.osdVisible = false
          }
        }
      }

      Connections {
        target: osdService
        function onShowRequested(data) {
          if (osdRoot.silenceMode) {
            console.log("[Silence] OSD: showRequested bloqueado (tipo:", data.type || "volume", ")")
            return
          }

          osdWin.osdType    = data.type  || "volume"
          osdWin.osdIcon    = data.icon  || ""
          osdWin.osdLabel   = data.label || ""
          osdWin.osdArtUrl  = data.artUrl || ""
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
          if (data.type !== "timer") hideTimer.restart()
          else hideTimer.stop()
        }
      }

      Timer {
        id: hideTimer; repeat: false
        onTriggered: osdWin.osdVisible = false
      }

      // ── Fade com leve scale-up na entrada ─────────────────────────────
      Item {
        id: fadeItem
        anchors.fill: parent
        opacity: osdWin.osdVisible ? 1.0 : 0.0
        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Scale suave na entrada/saída
        transform: Scale {
          origin.x: fadeItem.width  / 2
          origin.y: fadeItem.height / 2
          xScale: osdWin.osdVisible ? 1.0 : 0.94
          yScale: osdWin.osdVisible ? 1.0 : 0.94
          Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
          Behavior on yScale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }

        OsdContent {
          id: osdContent
          anchors.fill: parent

          icon:   osdWin.osdIcon
          artUrl: osdWin.osdArtUrl
          value:  osdWin.osdValue
          label:  osdWin.osdLabel
          muted:  osdWin.osdMuted

          timerMode:          osdWin.osdType === "timer"
          timerLabel:         osdWin.osdTimerLabel
          timerPhase:         osdWin.osdTimerPhase
          timerIsPomodoro:    osdWin.osdTimerIsPom
          timerRunning:       osdWin.osdTimerRunning
          timerPhaseDuration: osdWin.osdTimerPhaseD

          // Cores via Colors singleton — dinâmicas (matugen)
          colorBg:     Colors.surface_container_low
          colorAccent: Colors.primary
          colorMuted:  Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.22)
          colorTrack:  Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.10)
          colorText:   Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.55)
          colorIcon:   Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.90)

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
