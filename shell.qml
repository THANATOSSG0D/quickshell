import Quickshell
import "modules/widgets/clock"
import "modules/default/bar"
import './modules/default/osd'        as OsdModule
import './modules/default/notifications' as NotifModule

Scope {
  ClockWidget {}

  OsdModule.Osd {
    id: osd
    clockContent: bar.clockContentRef
  }

  // ── Serviço de notificações (singleton) ──────────────────────────────
  NotifModule.NotificationService {
    id: notifService
  }

  // ── Toasts flutuantes — um PanelWindow por monitor ───────────────────
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
  }
}
