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
import './modules/default/dmenu'         as DmenuModule
// import './modules/default/screenlock'    as LockModule

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

  // ── DmenuIpc — habilita scripts externos via: cmd | qs-dmenu ────────────
  // O dmenu normal (drun/run/window) continua gerenciado pelo Bar via IpcHandler.
  // Este componente adiciona o modo pipe para scripts externos.
  //
  // Posições disponíveis (panelAnchor):
  //   "top-center"    painel centrado no topo (padrão — igual ao rofi)
  //   "top-left"      topo esquerda
  //   "top-right"     topo direita
  //   "center"        centro absoluto do monitor
  //   "bottom-center" rodapé centrado
  DmenuModule.DmenuIpc {
    screen:      Quickshell.screens[0]
    panelAnchor: "top-center"
    showIcons:   true

    colorPanelBg:  Colors.surface_container   // "#1f1f1f"
    colorText:     Colors.on_surface          // "#e2e2e2"
    colorTextDim:  Colors.on_surface_variant  // "#c6c6c6"
    colorAccent:   Colors.primary             // "#81cfff"
    colorSelected: Colors.surface_variant     // "#474747"
    colorDivider:  Colors.outline_variant     // "#474747"
    colorInputBg:  Colors.surface             // "#131313"
  }

  PowerModule.PowerMenu {
    id: powerMenu
  }

  // ── Screen Lock ───────────────────────────────────────────────────────────
  // LockModule.ScreenLock { id: screenLock }
  // IpcHandler {
  //   target: "screenLock"
  //   function lock()     { screenLock.lock()                          }
  //   function unlock()   { screenLock.unlock()                        }
  //   function isLocked() { return screenLock.locked ? "true" : "false" }
  // }
}
