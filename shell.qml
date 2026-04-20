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
    clockContent: bar.clockContentRef
  }

  NotifModule.NotificationService {
    id: notifService
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
  }
}
