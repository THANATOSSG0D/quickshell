import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "modules/widgets/clock"
import "modules/default/bar"
import './modules/default/osd'           as OsdModule
import './modules/default/notifications' as NotifModule

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

    // ── Log central do Silence ─────────────────────────────────────────
    onSilenceModeChanged: {
      if (silenceMode)
        console.log("[Silence] *** ATIVADO *** — OSD, toasts e fullscreen-peek suprimidos")
      else
        console.log("[Silence] *** DESATIVADO *** — comportamento normal restaurado")
    }
  }
}
