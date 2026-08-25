//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import "modules/widgets/clock"
import "modules/widgets/todo"
import "modules/widgets/calendar"
import "modules/widgets/weather"
import "modules/widgets/cpu"
import "modules/widgets/ram"
import "modules/widgets/gpu"
import "modules/widgets/network"
import "modules/widgets/disk"
import "modules/widgets/system"
import "modules/widgets/process"
import "modules/widgets/bluetooth"
import "modules/widgets/habits"
import "modules/widgets/mediaplayer"
import "modules/widgets/favorites"
import "modules/widgets"
import "modules/default/bar"
import './modules/default/osd'           as OsdModule
import './modules/default/notifications' as NotifModule
import './modules/default/powermenu'     as PowerModule
import './modules/default/screenlock'    as ScreenLockModule
import './modules/default/dmenu'         as DmenuModule
import './modules/default/config' as ConfigModule
import './modules/default/corners/' as CornersModule

Scope {
  ClockWidget {}
  TodoWidget {}
  CalendarWidget {}
  WeatherWidget {}
  CpuWidget {}
  RamWidget {}
  GpuWidget {}
  NetworkWidget {}
  DiskWidget {}
  SystemWidget {}
  ProcessWidget {}
  BluetoothWidget {}
  HabitsWidget {}
  MediaPlayerWidget {}
  FavoritesWidget {}
  WidgetHost {}

  // Lembretes de tarefa vencida/vencendo hoje via notify-send — instância
  // única (evita notificação duplicada; ver TodoReminderService.qml).
  TodoReminderService {}

  OsdModule.Osd {
    id: osd
    silenceMode: bar.silenceMode
  }

  NotifModule.NotificationService {
    id: notifService
    silenceMode: bar.silenceMode

    // Antes esses valores eram só defaults fixos dentro do próprio
    // NotificationService.qml — não existia nenhuma forma de configurá-los
    // pela UI. Agora vêm do BarConfig (aba Notificações), com o mesmo
    // fallback que o componente já usava como default.
    dndAllowCritical: bar.configRef ? (bar.configRef.get("notifications", "dndAllowCritical") ?? true) : true
    maxToasts:        bar.configRef ? (bar.configRef.get("notifications", "maxToasts")        ?? 5)    : 5
    toastTimeoutMs:   bar.configRef ? (bar.configRef.get("notifications", "toastTimeoutMs")   ?? 5000) : 5000
    toastTimeoutLow:  bar.configRef ? (bar.configRef.get("notifications", "toastTimeoutLow")  ?? 3000) : 3000
    toastTimeoutCrit: bar.configRef ? (bar.configRef.get("notifications", "toastTimeoutCrit") ?? 0)    : 0
    maxHistory:       bar.configRef ? (bar.configRef.get("notifications", "maxHistory")       ?? 50)   : 50

    // toastPosition é persistido em notifications-state.json (estado de
    // runtime) e sobrescrito no load — um binding direto seria destruído
    // assim que o arquivo carregasse. Por isso o valor do config só serve
    // de "configDefaultPosition": o NotificationService usa esse default
    // apenas quando ainda não existe estado salvo (primeira execução).
    configDefaultPosition: bar.configRef ? (bar.configRef.get("notifications", "toastPosition") || "top-right") : "top-right"
  }

  Variants {
    model: Quickshell.screens

    NotifModule.NotificationToast {
      required property var modelData
      screen:  modelData
      service: notifService
      // Toast é overlay do shell inteiro (um por tela), não pertence a
      // bar OU dock especificamente — usa a PopupConfig da instância
      // principal como fonte única pra sombra/etc.
      popupConfigRef: bar.popupConfigRef
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

  // ── Dock — segunda instância do Bar, rodando em paralelo ────────────────
  // Própria config/JSON (state/Dock.json + state/DockState.json), então
  // trocar de tema/ajustar cores na Dock NUNCA mexe nos overrides da barra
  // principal (e vice-versa). Nasce com autoHide=true e tema "Dock" (visual
  // de "ilhas" já existente), mas dá pra trocar de tema livremente — ela
  // reaproveita os MESMOS arquivos de tema e o mesmo pipeline de módulos.
  //
  // Pra DESLIGAR completamente uma das duas (nenhuma PanelWindow criada,
  // sem popups, sem zona reservada — não é só "esconder"):
  //   • Persistente: "enabled": false no bloco "bar" de Bar.json/Dock.json
  //     (ou initialPanelEnabled: false aqui embaixo, como default de 1ª execução)
  //   • Em runtime:  qs ipc call bar      disable   (ou enable/toggleEnabled)
  //                  qs ipc call bar_dock disable
  //   • Atalho global: togglePanelEnabled (bar) / togglePanelEnabled_dock (dock)
  Bar {
    id: dockBar
    instanceId:      "dock"
    barJsonPath:      Quickshell.shellDir + "/state/Dock.json"
    stateJsonPath:    Quickshell.shellDir + "/state/DockState.json"
    popupConfigJsonPath: Quickshell.shellDir + "/state/DockPopupConfig.json"
    initialTheme:     "Dock"
    initialAutoHide:  true
    // initialPanelEnabled: false   // ← descomente pra a Dock nascer desligada

    osdService:   osd.osdService
    notifService: notifService
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


  // ── Cantos da tela — máscara decorativa arredondando os 4 cantos do
  // monitor. Config única (Bar.json, aba Geral → "Cantos da Tela"); pega
  // também a posição/tamanho da Dock quando cornersMode = "dock"/"both".
  CornersModule.ScreenCorners {
    configBar:  bar.configRef
    configDock: dockBar.configRef
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

  // ── IPC de widgets ───────────────────────────────────────────────────
  // qs ipc call widgets toggle clock          → liga/desliga 1 widget
  // qs ipc call widgets toggleMany clock,cpu   → vários juntos (maioria
  //                                              desligada → liga todos;
  //                                              maioria ligada → desliga)
  // qs ipc call widgets toggleGroup sysmon     → liga/desliga o CARD
  //   inteiro do grupo com esse nome (dado na aba Combinar)
  WidgetLayoutConfig { id: widgetsLayoutCfg }

  IpcHandler {
    target: "widgets"

    function toggle(id: string): string {
      widgetsLayoutCfg.setEnabled(id, !widgetsLayoutCfg.isEnabled(id))
      return widgetsLayoutCfg.isEnabled(id) ? "on" : "off"
    }

    function enable(id: string): string  { widgetsLayoutCfg.setEnabled(id, true);  return "on" }
    function disable(id: string): string { widgetsLayoutCfg.setEnabled(id, false); return "off" }

    function toggleMany(ids: string): string {
      const list = ids.split(",").map(s => s.trim()).filter(Boolean)
      if (list.length === 0) return "lista vazia"
      const onCount = list.filter(id => widgetsLayoutCfg.isEnabled(id)).length
      const goingOn = onCount * 2 < list.length
      list.forEach(id => widgetsLayoutCfg.setEnabled(id, goingOn))
      return goingOn ? "on" : "off"
    }

    function toggleGroup(name: string): string {
      const g = widgetsLayoutCfg.findGroupByName(name)
      if (!g) return "grupo '" + name + "' não encontrado"
      const goingOn = !g.enabled
      widgetsLayoutCfg.setGroupEnabled(g.id, goingOn)
      return goingOn ? "on" : "off"
    }
  }

  // ── PowerMenuConfig — mesmo padrão do dmenuIpc.configRef: config própria
  // (entries + aparência) persistida em state/PowerMenu.json, editável pela
  // aba "Power Menu" do ConfigWindow.
  PowerModule.PowerMenuConfig {
    id: powerMenuConfig
  }

  PowerModule.PowerMenu {
    id: powerMenu
    config: powerMenuConfig
  }

  // ── ScreenLockConfig — mesmo padrão: config própria persistida em
  // state/ScreenLock.json, editável pela aba "Screenlock" do ConfigWindow.
  // O lock em si roda como processo ISOLADO (scripts/screenlock → qs -c),
  // então essa instância aqui é só pra a UI de config conseguir ler/escrever
  // o mesmo JSON — não afeta um lock já em andamento, só o PRÓXIMO.
  ScreenLockModule.ScreenLockConfig {
    id: screenLockConfig
  }

  // IPC screenLock (usado pelo PowerMenu "Bloquear" e por keybinds do
  // Hyprland) — não estava instanciado na shell principal ainda.
  ScreenLockModule.ScreenLock {
    id: screenLock
  }

  property bool configOpen: false

  ConfigModule.ConfigWindow {
    id: configWin
    panelOpen:   configOpen
    configBar:   bar.configRef
    configDock:  dockBar.configRef
    popupConfigBar:  bar.popupConfigRef       // ← config dos POPUPS (aba Painéis), separada bar/dock
    popupConfigDock: dockBar.popupConfigRef
    dmenuConfig: dmenuIpc.configRef   // ← novo: config separado para a aba dmenu
    configPowerMenu: powerMenuConfig  // ← config do Power Menu (entries + aparência)
    configScreenLock: screenLockConfig // ← config do Screenlock (botões + aparência)
    colors:      Colors
    onCloseRequested: configOpen = false
  }

  IpcHandler {
    target: "config"
    function toggle() { configOpen = !configOpen }
    function open()   { configOpen = true        }
    function close()  { configOpen = false       }
  }

  // ── IPC de cores ─────────────────────────────────────────────────────────
  // Chamado por wallpaper.sh logo após `wp matugen apply` terminar de
  // reescrever state/colors.json. Recarrega só o JsonAdapter do Colors —
  // reavalia os bindings (Colors.background, Colors.primary, ...) em toda
  // a shell sem precisar de restart do processo qs.
  // Uso: qs ipc call colors reload
  IpcHandler {
    target: "colors"
    function reload() { Colors.reload() }
  }
}
