//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "modules/widgets/clock"
import "modules/default/bar"
import './modules/default/osd'           as OsdModule
import './modules/default/notifications' as NotifModule
import './modules/default/powermenu'     as PowerModule
import './modules/default/screenlock'    as LockModule

Scope {
  ClockWidget {}

  OsdModule.Osd {
    id: osd
    silenceMode: bar.silenceMode
  }

  NotifModule.NotificationService {
    id: notifService
    silenceMode: bar.silenceMode
  }

  Variants {
    model: Quickshell.screens

    NotifModule.NotificationToast {
      required property var modelData
      screen:  modelData
      service: notifService
    }
  }

  Bar {
    id: bar
    osdService:   osd.osdService
    notifService: notifService

    onSilenceModeChanged: {
      if (silenceMode)
        console.log("[Silence] *** ATIVADO *** — OSD, toasts e fullscreen-peek suprimidos")
      else
        console.log("[Silence] *** DESATIVADO *** — comportamento normal restaurado")
    }
  }

  PowerModule.PowerMenu {
    id: powerMenu
  }

  // ── Screen Lock ───────────────────────────────────────────────────────────
  // qs ipc call screenLock lock      → ativa
  // qs ipc call screenLock isLocked  → retorna "true" ou "false" (usado pelo script bash)
  LockModule.ScreenLock {
    id: screenLock
  }

  IpcHandler {
    target: "screenLock"
    function lock()     { screenLock.lock()                          }
    function unlock()   { screenLock.unlock()                        }
    function isLocked() { return screenLock.locked ? "true" : "false" }
  }
}
