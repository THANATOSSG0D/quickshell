//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import "modules/widgets/clock"
import "modules/default/bar"
import './modules/default/osd'           as OsdModule
import './modules/default/notifications' as NotifModule
import './modules/default/powermenu'     as PowerModule
import './modules/default/dmenu'         as DmenuModule
import './modules/default/config' as ConfigModule

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
  // Também gerencia os modos nativos (drun/run/window) via IpcHandler abaixo.
  // A config do dmenu fica em dmenuIpc.configRef (DmenuConfig / state/dmenu.json).
  DmenuModule.DmenuIpc {
    id: dmenuIpc
    barRoot:   bar

    // Fallbacks de cor — quando dmenuConfig não tem override, usa as cores da barra
    _fallbackBg:       bar.popupColorBg
    _fallbackText:     bar.popupColorText
    _fallbackTextDim:  bar.popupColorTextDim
    _fallbackAccent:   bar.popupColorAccent
    _fallbackSelected: bar.popupColorBg
    _fallbackDivider:  bar.popupColorDivider
    _fallbackInputBg:  bar.popupColorBg
    // showIcons, launchCmd, maxVisible, panelWidth/Height, etc. → dmenuIpc.configRef
  }

  // ── IPC do dmenu ──────────────────────────────────────────────────────────
  // qs ipc call dmenu drun | run | window
  // Modo padrão também pode ser aberto via dmenuConfig.dmenuDefaultMode no hotkey.
  IpcHandler {
    target: "dmenu"
    function drun()    { dmenuIpc.openNative("drun")    }
    function run()     { dmenuIpc.openNative("run")     }
    function window()  { dmenuIpc.openNative("window")  }
    // Conveniente para atalho universal — abre no modo padrão configurado
    function open()    { dmenuIpc.openNative(dmenuIpc.configRef.dmenuDefaultMode) }
  }

  PowerModule.PowerMenu {
    id: powerMenu
  }

  property bool configOpen: false

  ConfigModule.ConfigWindow {
    id: configWin
    panelOpen:   configOpen
    config:      bar.configRef
    dmenuConfig: dmenuIpc.configRef   // ← novo: config separado para a aba dmenu
    colors:      Colors
    onCloseRequested: configOpen = false
  }

  IpcHandler {
    target: "config"
    function toggle() { configOpen = !configOpen }
    function open()   { configOpen = true        }
    function close()  { configOpen = false       }
  }
}
