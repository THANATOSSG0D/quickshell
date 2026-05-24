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
    id: dmenuIpc
    barRoot:   bar
    showIcons: bar._dmenuShowIcons

    // Mesmas cores que o Bar usa internamente — atualizam automaticamente com o tema
    colorPanelBg:  bar.popupColorBg
    colorText:     bar.popupColorText
    colorTextDim:  bar.popupColorTextDim
    colorAccent:   bar.popupColorAccent
    colorSelected: bar.popupColorBg
    colorDivider:  bar.popupColorDivider
    colorInputBg:  bar.popupColorBg
  }

  // ── IPC do dmenu — ponto único de entrada para todos os modos ────────────
  // qs ipc call dmenu drun | run | window
  // Todos os modos passam pelo DmenuIpc (pilha de navegação, toggle, backspace).
  // O DmenuPopup separado no Bar.qml foi removido.
  IpcHandler {
    target: "dmenu"
    function drun() {
      dmenuIpc.openNative("drun", bar._dmenuLaunchCmd)
    }
    function run() {
      dmenuIpc.openNative("run", bar._dmenuLaunchCmd)
    }
    function window() {
      dmenuIpc.openNative("window", bar._dmenuLaunchCmd)
    }
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
