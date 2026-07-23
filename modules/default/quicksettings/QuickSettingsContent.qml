import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "./components" as Qs
import "../../widgets/todo" as TodoMod
import "../../widgets/habits" as HabitsMod

// ── QuickSettingsContent ─────────────────────────────────────────────────────
// API CORRETA do Quickshell para ler stdout de processos:
//   Process.stdout NÃO é uma string — é um DataStream.
//   Para ler o output, OBRIGATORIAMENTE anexe um SplitParser:
//
//   Process {
//       property string _buf: ""
//       stdout: SplitParser {
//           onRead: (line) => parent._buf += line + "\n"
//       }
//       onRunningChanged: if (!running) { var txt = _buf; _buf = ""; /* usa txt */ }
//   }
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property color colorPanelBg:    "#1f1f1f"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    signal closeRequested()
    property bool   panelOpen:    false
    property var    parentWindow: null

    // Injetado de fora (Bar.qml → QuickSettingsPanel/Popup → aqui), mesmo
    // padrão que osdService/notifService já usam em outros módulos. null-safe
    // em tudo que usa isso — se não for conectado, o botão de DND some.
    property var    notifService: null
    readonly property bool dndActive: root.notifService ? root.notifService.doNotDisturb === true : false
    // Aba fixa no topo: "dashboard" | "media" | "performance"
    property string activeTab:    "dashboard"
    // Sub-tela com botão voltar, válida dentro da aba ativa:
    //   Dashboard:   "" | "wifi" | "ethernet" | "bluetooth"
    //   Mídia:       "" | "devices" | "easyeffects"
    //   Performance: "" | "power" | "shader"
    property string subPage:      ""
    // Verdadeiro enquanto um menu de tray estiver aberto — suspende FocusGrab
    readonly property bool trayMenuOpen: tabTray.menuOpen

    // ── Resumo leve do shader, só para exibir no QsNavRow da home ───────────
    // (a leitura completa — incluindo lista de shaders e gamma — vive dentro
    // do QsShaderStatus, instanciado só quando a sub-tela abre)
    property string shaderSummary: "Carregando…"

    Process {
        id: shaderSummaryProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => shaderSummaryProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = shaderSummaryProc._buf.split("---")
            shaderSummaryProc._buf = ""
            if (parts.length < 2) return
            var shader = parts[0].trim()
            var mode   = parts[1].trim()
            var modeLabel = mode === "auto" ? "Automático" : mode === "off" ? "Desligado" : "Manual"
            root.shaderSummary = (shader !== "" ? shader : "Nenhum shader") + " · " + modeLabel
        }
    }
    function _refreshShaderSummary() {
        if (shaderSummaryProc.running) return
        shaderSummaryProc.command = ["bash", "-c",
            "hyprshade current 2>/dev/null; echo '---'; cat ~/.cache/hyprnight/shader-mode 2>/dev/null"]
        shaderSummaryProc.running = true
    }

    // Resumo do perfil de energia — NÃO tem estado próprio aqui. A fonte de
    // verdade é a instância única de Qs.QsPowerProfile (id: powerProfileState,
    // declarada dentro da subpágina "power", mas sempre viva — QML não destrói
    // itens filhos só por estarem com visible:false). Ter um processo próprio
    // aqui, além do que já existe dentro do QsPowerProfile, foi o que causava
    // o atalho do Dashboard e a lista de dentro mostrarem estados diferentes.

    readonly property string ctl: Quickshell.shellDir + "/scripts/network-ctl.sh"

    // ═══════════════════════════════════════════════════════════════════════
    // Cabeçalho — hora/data. Atualiza a cada 20s (sobra pra não notar atraso
    // no minuto, sem gastar um Timer de 1s à toa igual um relógio de verdade).
    // ═══════════════════════════════════════════════════════════════════════
    property var _now: new Date()
    Timer { interval: 20000; running: true; repeat: true; onTriggered: root._now = new Date() }

    readonly property var _weekDayNames: ["domingo","segunda","terça","quarta","quinta","sexta","sábado"]
    readonly property var _monthNamesShort: ["jan","fev","mar","abr","mai","jun","jul","ago","set","out","nov","dez"]
    readonly property string _headerDateLabel:
        root._weekDayNames[root._now.getDay()] + ", " + root._now.getDate() + " " + root._monthNamesShort[root._now.getMonth()]

    // ═══════════════════════════════════════════════════════════════════════
    // Bateria — cabeçalho. Todo control center de laptop mostra isso; esse
    // painel não mostrava em lugar nenhum antes.
    // ═══════════════════════════════════════════════════════════════════════
    readonly property var _battDevice: UPower.displayDevice
    // UPower.displayDevice "nunca é null, mas pode não estar inicializado
    // ainda" (doc oficial) — daí o check de `ready` além de isLaptopBattery,
    // pra não mostrar 0%/ícone errado por um instante logo no boot do shell.
    readonly property bool hasBattery:
        root._battDevice && root._battDevice.ready === true && root._battDevice.isLaptopBattery === true
    readonly property int  batteryPct: root._battDevice ? Math.round(root._battDevice.percentage * 100) : 0
    readonly property bool batteryCharging:
        root._battDevice && root._battDevice.state === UPowerDeviceState.Charging
    readonly property color batteryColor: root.batteryCharging ? root.colorAccent
        : (root.batteryPct <= 15 ? root.colorMuted : root.colorTextDim)
    readonly property string batteryIcon: {
        if (root.batteryCharging) return "\uf0e7"   // nf-fa-bolt
        var p = root.batteryPct
        if (p >= 90) return "\uf240"
        if (p >= 65) return "\uf241"
        if (p >= 40) return "\uf242"
        if (p >= 15) return "\uf243"
        return "\uf244"
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Todo — só leitura, pra marcar dias com tarefa no QsCalendar do Dashboard.
    // Mesmo arquivo (state/TodoWidget.json) que o TodoWidget/TodoDashboard já
    // usam — não chama nenhuma função de escrita (addTask/toggleTask/etc.),
    // só lê `tasks` reativamente.
    // ═══════════════════════════════════════════════════════════════════════
    TodoMod.TodoConfig { id: todoConfig }

    readonly property var _taskPriorityColor: ({
        alta:  "#e5484d",
        media: "#f5a524",
        baixa: "#45a249"
    })

    // ═══════════════════════════════════════════════════════════════════════
    // Habits — mesma ideia do Todo acima: só leitura + as duas ações do dia
    // (toggleToday/logCount), pro widget compacto ao lado do calendário.
    // Os tokens de cor do hábito (primary/secondary/etc.) vêm do tema Material
    // You e esse arquivo não importa o singleton Colors — mapeei pra hex fixo
    // só pra esse widget compacto; a cor "de verdade" continua no Habits.
    // ═══════════════════════════════════════════════════════════════════════
    HabitsMod.HabitsConfig { id: habitsConfig }

    readonly property var _habitColorHex: ({
        primary:           root.colorAccent,
        secondary:         "#7986cb",
        tertiary:          "#45a249",
        error:             "#e5484d",
        primary_container: "#f5a524"
    })

    readonly property var todayHabits: {
        var out      = []
        var todayKey = Qt.formatDate(new Date(), "yyyy-MM-dd")
        var list     = habitsConfig.habits || []
        for (var i = 0; i < list.length; i++) {
            var h      = list[i]
            var amount = habitsConfig.amountOn(h, todayKey)
            var status = habitsConfig.habitStatus(h, todayKey)
            out.push({
                id:             h.id,
                name:           h.name,
                kind:           h.kind,
                target:         h.target,
                amount:         amount,
                status:         status,
                colorHex:       root._habitColorHex[h.color] || root.colorAccent,
                statusColorHex: habitsConfig.statusColor(status) || ""
            })
        }
        return out
    }

    // "2/4 hoje" — resumo pro cabeçalho quando o card está recolhido
    readonly property string habitsSubtitle: {
        var total = root.todayHabits.length
        if (total === 0) return "nenhum hábito"
        var done = 0
        for (var i = 0; i < total; i++) {
            var s = root.todayHabits[i].status
            if (s === "hit" || s === "limit") done++
        }
        return done + "/" + total + " hoje"
    }

    // { "yyyy-MM-dd": "#cor" } — cor da tarefa pendente de maior prioridade
    // naquele dia; dias sem tarefa pendente não entram no mapa.
    readonly property var calendarTaskDates: {
        var order = ({ alta: 0, media: 1, baixa: 2 })
        var best  = ({})   // "yyyy-MM-dd" -> { prio: number }
        var out   = ({})   // "yyyy-MM-dd" -> "#cor" (o que o QsCalendar consome)
        var tasks = todoConfig.tasks || []
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i]
            if (!t.due || t.done) continue
            var p = order[t.priority] !== undefined ? order[t.priority] : 1
            if (!best[t.due] || p < best[t.due].prio) {
                best[t.due] = { prio: p }
                out[t.due]  = root._taskPriorityColor[t.priority] || root.colorAccent
            }
        }
        return out
    }

    // Tarefas pendentes com prazo hoje ou atrasado — pra lista direta no
    // Dashboard (os pontinhos do calendário mostram ONDE tem prazo, isso aqui
    // mostra efetivamente O QUÊ, sem precisar abrir o Todo).
    readonly property var todayTasks: {
        var order    = ({ alta: 0, media: 1, baixa: 2 })
        var todayStr = Qt.formatDate(new Date(), "yyyy-MM-dd")
        var tasks    = todoConfig.tasks || []
        var out = []
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i]
            if (!t.due || t.done) continue
            if (t.due > todayStr) continue   // prazo no futuro — não é "de hoje"
            out.push({
                id:       t.id,
                text:     t.text,
                priority: t.priority || "media",
                overdue:  t.due < todayStr,
                done:     false
            })
        }
        out.sort(function(a, b) {
            if (a.overdue !== b.overdue) return a.overdue ? -1 : 1
            var pa = order[a.priority] !== undefined ? order[a.priority] : 1
            var pb = order[b.priority] !== undefined ? order[b.priority] : 1
            return pa - pb
        })
        return out
    }

    // ── Dia selecionado no calendário do Dashboard (clique) ──────────────────
    // "" = nada selecionado → a lista mostra "hoje + atrasadas" (todayTasks).
    property string selectedCalendarDate: ""
    readonly property bool showingSelectedDate: root.selectedCalendarDate !== ""

    // Calendário completo vem recolhido por padrão — é o item mais alto do
    // Dashboard e a maior parte do tempo só a lista de tarefas já basta.
    // Ver princípio geral: abas não devem precisar de scroll pra mostrar o
    // conteúdo essencial; seções "boas de ter, mas não sempre necessárias"
    // (como o mês inteiro) ficam colapsadas até o usuário pedir.
    // Calendário e Hábitos ficam lado a lado, cada um com seu próprio estado
    // de expansão independente — MAS sempre com a mesma altura entre os dois
    // quando exibidos juntos (ver Layout.preferredHeight sincronizado no
    // RowLayout abaixo). Sem isso, um card fechado do lado de um aberto fica
    // torto (uma caixa bem mais baixa que a outra, no mesmo eixo horizontal).
    property bool calendarExpanded: false
    property bool habitsExpanded:   true

    readonly property string calendarSubtitle: {
        var d = new Date()
        var months = ["janeiro","fevereiro","março","abril","maio","junho",
                       "julho","agosto","setembro","outubro","novembro","dezembro"]
        return d.getDate() + " de " + months[d.getMonth()]
    }

    // Todas as tarefas com prazo EXATAMENTE no dia selecionado — inclui as já
    // concluídas (diferente de todayTasks), porque aqui o usuário está
    // inspecionando um dia específico, não só "o que falta fazer agora".
    readonly property var selectedDateTasks: {
        if (root.selectedCalendarDate === "") return []
        var order = ({ alta: 0, media: 1, baixa: 2 })
        var tasks = todoConfig.tasks || []
        var out = []
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i]
            if (t.due !== root.selectedCalendarDate) continue
            out.push({
                id: t.id, text: t.text, priority: t.priority || "media",
                overdue: false, done: !!t.done
            })
        }
        out.sort(function(a, b) {
            if (a.done !== b.done) return a.done ? 1 : -1   // concluídas por último
            var pa = order[a.priority] !== undefined ? order[a.priority] : 1
            var pb = order[b.priority] !== undefined ? order[b.priority] : 1
            return pa - pb
        })
        return out
    }

    readonly property var displayedTasks: root.showingSelectedDate ? root.selectedDateTasks : root.todayTasks

    // "18/07" — rótulo curto do dia selecionado, sem depender de locale
    readonly property string selectedDateLabel: {
        if (!root.showingSelectedDate) return ""
        var parts = root.selectedCalendarDate.split("-")
        return parts[2] + "/" + parts[1]
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Estado de rede — lido via "network-ctl.sh status"
    // ═══════════════════════════════════════════════════════════════════════
    property bool   wifiEnabled:  false
    property string wifiBadge:    ""
    property bool   ethConnected: false
    property string ethDevice:    ""
    property string ethConnName:  ""

    Process {
        id: statusProc
        command: ["bash", root.ctl, "status"]
        property string _buf: ""

        stdout: SplitParser {
            onRead: (line) => statusProc._buf += line + "\n"
        }

        onRunningChanged: {
            if (!running) {
                var text = statusProc._buf
                statusProc._buf = ""
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim()
                    if (ln === "") continue
                    var eq = ln.indexOf("=")
                    if (eq < 0) continue
                    var key = ln.slice(0, eq).trim()
                    var val = ln.slice(eq + 1).trim()
                    if      (key === "WIFI_RADIO")    root.wifiEnabled  = (val === "on")
                    else if (key === "WIFI_SSID")     root.wifiBadge    = val
                    else if (key === "ETH_CONNECTED") root.ethConnected = (val === "true")
                    else if (key === "ETH_DEV")       root.ethDevice    = val
                    else if (key === "ETH_CONN")      root.ethConnName  = val
                }
            }
        }
    }

    function _refreshStatus() {
        if (!statusProc.running) statusProc.running = true
    }

    // ── WiFi toggle ────────────────────────────────────────────────────────
    Process {
        id: wifiToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) wifiToggleProc._buf = "" }
    }
    Timer { id: wifiRefreshTimer; interval: 1800; onTriggered: _refreshStatus() }

    function _toggleWifi() {
        wifiToggleProc.command = ["bash", root.ctl,
            "wifi", root.wifiEnabled ? "off" : "on"]
        wifiToggleProc.running = true
        root.wifiEnabled = !root.wifiEnabled
        wifiRefreshTimer.restart()
    }

    // ── Ethernet toggle ────────────────────────────────────────────────────
    Process {
        id: ethToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) ethToggleProc._buf = "" }
    }
    Timer { id: ethRefreshTimer; interval: 1800; onTriggered: _refreshStatus() }

    function _toggleEth() {
        if (root.ethDevice === "") return
        ethToggleProc.command = ["bash", root.ctl,
            "eth", root.ethConnected ? "off" : "on", root.ethDevice]
        ethToggleProc.running = true
        root.ethConnected = !root.ethConnected
        ethRefreshTimer.restart()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WiFi — lista de redes
    // ═══════════════════════════════════════════════════════════════════════
    property string wifiListRaw:  ""
    property bool   wifiScanning: false

    Process {
        id: wifiListProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiListProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.wifiListRaw  = wifiListProc._buf
                root.wifiScanning = false
                wifiListProc._buf = ""
            }
        }
    }

    Process {
        id: wifiScanProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => wifiScanProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                wifiScanProc._buf = ""
                _refreshWifiList()
            }
        }
    }

    function _refreshWifiList() {
        wifiListProc.command = ["bash", root.ctl, "wifi", "list"]
        if (!wifiListProc.running) wifiListProc.running = true
    }

    function _requestWifiScan() {
        if (root.wifiScanning) return
        root.wifiScanning = true
        wifiScanProc.command = ["bash", root.ctl, "wifi", "scan"]
        if (!wifiScanProc.running) wifiScanProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Ethernet — lista (aba QsTabNetworks)
    // ═══════════════════════════════════════════════════════════════════════
    property string ethListRaw: ""

    Process {
        id: ethListProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => ethListProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.ethListRaw  = ethListProc._buf
                ethListProc._buf = ""
            }
        }
    }

    function _refreshEthList() {
        ethListProc.command = ["bash", root.ctl, "eth", "list"]
        if (!ethListProc.running) ethListProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Bluetooth
    // ═══════════════════════════════════════════════════════════════════════
    property bool btEnabled: false

    Process {
        id: btStatusProc
        command: ["bash", "-c", "systemctl is-active bluetooth.service 2>/dev/null"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btStatusProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.btEnabled    = btStatusProc._buf.trim() === "active"
                btStatusProc._buf = ""
            }
        }
    }

    Process {
        id: btToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => btToggleProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                btToggleProc._buf = ""
                btRefreshTimer.restart()   // confirma estado real após systemctl
            }
        }
    }
    Timer { id: btRefreshTimer; interval: 1800; onTriggered: _refreshBt() }

    function _refreshBt() { if (!btStatusProc.running) btStatusProc.running = true }
    function _toggleBluetooth() {
        btToggleProc.command = root.btEnabled
            ? ["bash", "-c", "systemctl stop bluetooth.service 2>/dev/null"]
            : ["bash", "-c", "systemctl start bluetooth.service 2>/dev/null"]
        btToggleProc.running = true
        root.btEnabled = !root.btEnabled   // optimistic
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Modo Avião — desliga Wi-Fi + Bluetooth juntos. "Ativo" é derivado
    // direto do estado real dos dois rádios (não é uma flag própria) — se o
    // usuário desligar os dois manualmente pelos tiles, o botão já reflete
    // isso sozinho, sem ficar dessincronizado.
    // ═══════════════════════════════════════════════════════════════════════
    property bool _preAirplaneWifi: true
    property bool _preAirplaneBt:   true
    readonly property bool airplaneActive: !root.wifiEnabled && !root.btEnabled

    function _toggleAirplane() {
        if (root.airplaneActive) {
            // Desligando o modo avião → restaura o que estava ligado antes
            if (root._preAirplaneWifi) root._toggleWifi()
            if (root._preAirplaneBt)   root._toggleBluetooth()
        } else {
            // Ligando o modo avião → guarda o estado atual e desliga os dois
            root._preAirplaneWifi = root.wifiEnabled
            root._preAirplaneBt   = root.btEnabled
            if (root.wifiEnabled) root._toggleWifi()
            if (root.btEnabled)   root._toggleBluetooth()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Caffeine
    // ═══════════════════════════════════════════════════════════════════════
    property bool dndEnabled:     false
    property bool caffeineActive: false

    Process {
        id: caffeineStatusProc
        command: ["bash", "-c", "systemctl --user is-active hypridle 2>/dev/null"]
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => caffeineStatusProc._buf += l + "\n" }
        onRunningChanged: {
            if (!running) {
                root.caffeineActive        = caffeineStatusProc._buf.trim() !== "active"
                caffeineStatusProc._buf    = ""
            }
        }
    }

    Process {
        id: caffeineToggleProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => caffeineToggleProc._buf += l + "\n" }
        onRunningChanged: { if (!running) caffeineToggleProc._buf = "" }
    }

    function _toggleCaffeine() {
        caffeineToggleProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/caffeine-toggle.sh --quiet 2>/dev/null || " +
            (root.caffeineActive
                ? "systemctl --user start hypridle 2>/dev/null"
                : "systemctl --user stop hypridle 2>/dev/null")]
        caffeineToggleProc.running = true
        root.caffeineActive = !root.caffeineActive
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Volume Pipewire
    // ═══════════════════════════════════════════════════════════════════════
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
    readonly property var  sink:  Pipewire.defaultAudioSink
    readonly property real vol:   sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted  : false
    readonly property string volIcon:
        muted || vol <= 0 ? "\uf026" : vol <= 0.33 ? "\uf027" : "\uf028"

    // ═══════════════════════════════════════════════════════════════════════
    // Inicialização
    // ═══════════════════════════════════════════════════════════════════════
    Component.onCompleted: Qt.callLater(function() {
        statusProc.running         = true
        btStatusProc.running       = true
        caffeineStatusProc.running = true
        _refreshWifiList()
        _refreshEthList()
    })

    onPanelOpenChanged: {
        if (panelOpen) {
            _refreshStatus()
            if (!btStatusProc.running)       btStatusProc.running       = true
            if (!caffeineStatusProc.running) caffeineStatusProc.running = true
            _refreshWifiList()
            _refreshEthList()
        } else {
            // Painel fechado: fecha qualquer sub-página aberta (wifi/ethernet/bluetooth/etc.)
            root.subPage = ""
        }
    }

    // ── Auto-refresh da sub-página ativa (1x por segundo) ──────────────────
    // Enquanto uma sub-página com dados "vivos" estiver aberta (Wi-Fi, Ethernet,
    // Bluetooth), atualiza status/listas periodicamente, sem precisar de ação
    // manual do usuário (botão de refresh).
    Timer {
        id: subPageRefreshTimer
        interval: 1000
        repeat: true
        running: root.panelOpen && (root.subPage === "wifi" || root.subPage === "ethernet" || root.subPage === "bluetooth")
        onTriggered: {
            if (root.subPage === "wifi") {
                root._refreshStatus()
                if (!wifiListProc.running && !wifiScanProc.running) root._refreshWifiList()
            } else if (root.subPage === "ethernet") {
                root._refreshStatus()
                if (!ethListProc.running) root._refreshEthList()
            } else if (root.subPage === "bluetooth") {
                root._refreshBt()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // UI — abas fixas no topo + sub-telas (Wi-Fi/Bluetooth) dentro do Dashboard
    // ═══════════════════════════════════════════════════════════════════════
    // activeTab nunca usa botão de voltar — é navegação principal, sempre
    // visível. subPage é usado SOMENTE dentro da aba Dashboard, para abrir
    // detalhes de Wi-Fi/Ethernet/Bluetooth com um cabeçalho + botão voltar.
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Cabeçalho: hora + data ────────────────────────────────────────────
        // Compacto de propósito (uma linha só) — o objetivo é dar identidade de
        // "tela própria" ao painel, não competir por espaço com o conteúdo.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 12
            spacing: 6

            Text {
                text: Qt.formatDateTime(root._now, "HH:mm")
                color: root.colorText
                font.pixelSize: 16; font.weight: Font.DemiBold
            }
            Text {
                text: root._headerDateLabel
                color: root.colorTextDim
                font.pixelSize: 10
                opacity: 0.75
            }
            Item { Layout.fillWidth: true }

            // ── Não Perturbe ────────────────────────────────────────────────
            // Some sozinho se o notifService não foi conectado (ver prop
            // notifService acima) — não fica um botão morto no ar.
            Rectangle {
                visible: root.notifService !== null
                implicitWidth: 24; implicitHeight: 24; radius: 12
                color: root.dndActive ? root.colorAccent : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: dndMA.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: root.dndActive ? "\uf1f6" : "\uf0f3"   // bell-slash / bell
                    color: root.dndActive ? "#1a1a1a" : root.colorTextDim
                    font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: dndMA
                    anchors.fill: parent; anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.notifService) root.notifService.toggleDnd()
                }
            }

            // ── Modo Avião ─────────────────────────────────────────────────
            Rectangle {
                implicitWidth: 24; implicitHeight: 24; radius: 12
                color: root.airplaneActive ? root.colorAccent : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: airplaneMA.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf072"   // nf-fa-plane
                    color: root.airplaneActive ? "#1a1a1a" : root.colorTextDim
                    font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: airplaneMA
                    anchors.fill: parent; anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._toggleAirplane()
                }
            }

            // ── Bateria ─────────────────────────────────────────────────────
            Rectangle {
                visible: root.hasBattery
                implicitHeight: 22
                implicitWidth: battRow.implicitWidth + 14
                radius: 11
                color: root.batteryPct <= 15 && !root.batteryCharging
                    ? Qt.rgba(root.colorMuted.r, root.colorMuted.g, root.colorMuted.b, 0.15)
                    : Qt.rgba(1, 1, 1, 0.07)

                RowLayout {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: root.batteryIcon
                        color: root.batteryColor
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: root.batteryPct + "%"
                        color: root.colorTextDim
                        font.pixelSize: 10
                    }
                }
            }
        }

        // ── Barra de abas fixa ──────────────────────────────────────────────
        Qs.QsTabBar {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.topMargin: 4
            Layout.bottomMargin: 0
            activeTab: root.activeTab
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            tabs: [
                { id: "dashboard",   label: "\uf2dc  Dashboard"   },
                { id: "media",       label: "\uf001  Mídia"       },
                { id: "performance", label: "\uf2db  Performance" }
            ]
            onTabClicked: (id) => { root.activeTab = id; root.subPage = "" }
        }

        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10
            height: 1; color: root.colorDivider; opacity: 0.4 }

        // ── Conteúdo das abas ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // ── ABA: Dashboard ──────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "dashboard"

                // ── Tela principal do Dashboard (tiles, tray, footer) ────────
                Flickable {
                    anchors.fill: parent; clip: true
                    visible: root.subPage === ""
                    contentWidth:  width
                    contentHeight: dashCol.implicitHeight + 24
                    boundsMovement: Flickable.StopAtBounds

                    ColumnLayout {
                        id: dashCol; x: 14; y: 10
                        width: parent.width - 28; spacing: 10

                        // ── Card: tarefas de hoje ────────────────────────────────
                        Qs.QsSectionCard {
                            Layout.fillWidth: true
                            colorTextDim: root.colorTextDim

                            // Cabeçalho da lista — muda conforme "hoje" ou um dia
                            // específico clicado no calendário abaixo.
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text {
                                    text: root.showingSelectedDate ? ("Tarefas · " + root.selectedDateLabel) : "Hoje"
                                    color: root.colorTextDim
                                    font.pixelSize: 9; font.weight: Font.DemiBold
                                    opacity: 0.65
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: root.showingSelectedDate
                                    text: "\uf00d"   // nf-fa-times — limpa a seleção, volta pra "hoje"
                                    color: root.colorTextDim
                                    font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font"
                                    opacity: 0.6
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedCalendarDate = ""
                                    }
                                }
                            }

                            // Tarefas de hoje/atrasadas (padrão) ou do dia clicado no
                            // calendário — direto do TodoConfig, com checkbox pra
                            // concluir sem sair do Dashboard.
                            Qs.QsTaskList {
                                Layout.fillWidth: true
                                tasks: root.displayedTasks
                                emptyText: root.showingSelectedDate ? "Nenhuma tarefa nesse dia" : "Nenhuma tarefa por hoje"
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onToggle: (id) => todoConfig.toggleTask(id)
                            }
                        }

                        // ── Calendário + Hábitos lado a lado — altura sempre
                        // sincronizada entre os dois (a do maior), pra nunca ficar
                        // torto quando só um dos dois está expandido ──────────────
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Qs.QsCollapsibleCard {
                                id: calCard
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                Layout.preferredHeight: Math.max(calCard.implicitHeight, habCard.implicitHeight)
                                icon: "\uf133"; title: "Calendário"
                                subtitle: root.calendarSubtitle
                                expanded: root.calendarExpanded
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onToggleRequested: root.calendarExpanded = !root.calendarExpanded

                                Qs.QsCalendar {
                                    Layout.fillWidth: true
                                    compact: true
                                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                    taskDates:    root.calendarTaskDates
                                    selectedDate: root.selectedCalendarDate
                                    onDateClicked: (date) => {
                                        // clicar de novo no mesmo dia desmarca — volta pra "hoje"
                                        root.selectedCalendarDate = (root.selectedCalendarDate === date) ? "" : date
                                    }
                                }
                            }

                            Qs.QsCollapsibleCard {
                                id: habCard
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                Layout.preferredHeight: Math.max(calCard.implicitHeight, habCard.implicitHeight)
                                icon: "\uf058"; title: "Hábitos"
                                subtitle: root.habitsSubtitle
                                expanded: root.habitsExpanded
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onToggleRequested: root.habitsExpanded = !root.habitsExpanded

                                Qs.QsHabitList {
                                    Layout.fillWidth: true
                                    habits: root.todayHabits
                                    colorText: root.colorText; colorTextDim: root.colorTextDim
                                    onToggleCheck: (id) => habitsConfig.toggleToday(id)
                                    onLogCount:    (id, delta) => habitsConfig.logCount(id, delta)
                                }
                            }
                        }

                        // ── Card "Controles rápidos": tiles de rede/BT/caffeine ──
                        Qs.QsSectionCard {
                            Layout.fillWidth: true
                            title: "Controles rápidos"; colorTextDim: root.colorTextDim

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2; rowSpacing: 6; columnSpacing: 6

                                Qs.QsToggleTile {
                                    Layout.fillWidth: true; Layout.preferredHeight: 60
                                    icon: "\uf1eb"; label: "Wi-Fi"
                                    badge: root.wifiEnabled ? (root.wifiBadge || "ligado") : "desligado"
                                    active: root.wifiEnabled
                                    showSwitch: true   // liga/desliga na hora; card abre a lista de redes
                                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                    onClicked:       root.subPage = "wifi"
                                    onSwitchToggled: root._toggleWifi()
                                }
                                Qs.QsToggleTile {
                                    Layout.fillWidth: true; Layout.preferredHeight: 60
                                    icon: "\uf6ff"; label: "Ethernet"
                                    badge: root.ethConnected
                                        ? (root.ethDevice || "cabo")
                                        : (root.ethDevice ? "desconectado" : "indisponível")
                                    active: root.ethConnected
                                    showSwitch: root.ethDevice !== ""   // sem cabo detectado, não faz sentido ter switch
                                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                    onClicked:       root.subPage = "ethernet"
                                    onSwitchToggled: root._toggleEth()
                                }
                                Qs.QsToggleTile {
                                    Layout.fillWidth: true; Layout.preferredHeight: 60
                                    icon: "\uf294"; label: "Bluetooth"
                                    badge: root.btEnabled ? "ligado" : "desligado"
                                    active: root.btEnabled
                                    showSwitch: true   // liga/desliga na hora; card abre pareados/scan
                                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                    onClicked:       root.subPage = "bluetooth"
                                    onSwitchToggled: root._toggleBluetooth()
                                }
                                Qs.QsToggleTile {
                                    Layout.fillWidth: true; Layout.preferredHeight: 60
                                    icon: root.caffeineActive ? "\uf0f4" : "\uf017"
                                    label: "Caffeine"
                                    badge: root.caffeineActive ? "suspensão off" : ""
                                    active: root.caffeineActive
                                    // Sem subpágina — não faz sentido duplicar o alvo com um switch,
                                    // o card inteiro já é o toggle.
                                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                    onClicked: root._toggleCaffeine()
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.3 }

                            // Atalho de Perfil de Energia — lê direto da instância única
                            // (powerProfileState, dentro da subpágina "power" abaixo);
                            // clicar leva direto pra lá.
                            Qs.QsNavRow {
                                Layout.fillWidth: true
                                icon: "\uf2db"; label: "Perfil de energia"
                                sub:     powerProfileState.currentLabel
                                loading: powerProfileState.loading
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                                onClicked: { root.activeTab = "performance"; root.subPage = "power" }
                            }
                        }

                        // ── Tray inline (compacto, sem card — mantém leve) ──────
                        Qs.QsTabTray {
                            id: tabTray
                            Layout.fillWidth: true; Layout.preferredHeight: 36
                            colorText: root.colorText; colorTextDim: root.colorTextDim
                            parentWindow: root.parentWindow
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsFooter {
                            Layout.fillWidth: true
                            colorText: root.colorText; colorMuted: root.colorMuted
                        }

                        Item { height: 0 }
                    }
                }

                // ── Sub-tela: Wi-Fi ──────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "wifi"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Wi-Fi"; icon: "\uf1eb"
                            actionIcon: "\uf021"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked:   root.subPage = ""
                            onActionClicked: root._refreshWifiList()
                        }

                        // Toggle real do Wi-Fi — vive aqui, não no tile da home
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Wi-Fi"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.wifiEnabled
                                colorAccent: root.colorAccent
                                onToggled: root._toggleWifi()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsWifiList {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent:  root.colorAccent
                            colorText:    root.colorText
                            colorTextDim: root.colorTextDim
                            colorMuted:   root.colorMuted
                            wifiEnabled:  root.wifiEnabled
                            wifiListRaw:  root.wifiListRaw
                            wifiScanning: root.wifiScanning
                            onRequestScan:    root._requestWifiScan()
                            onRequestRefresh: root._refreshWifiList()
                        }
                    }
                }

                // ── Sub-tela: Ethernet ───────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "ethernet"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Ethernet"; icon: "\uf6ff"
                            actionIcon: "\uf021"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked:   root.subPage = ""
                            onActionClicked: root._refreshEthList()
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: root.ethDevice !== ""
                            Text { text: "Conexão principal"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.ethConnected
                                colorAccent: root.colorAccent
                                onToggled: root._toggleEth()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsEthernetList {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent:  root.colorAccent
                            colorText:    root.colorText
                            colorTextDim: root.colorTextDim
                            colorMuted:   root.colorMuted
                            ethConnected: root.ethConnected
                            ethDevice:    root.ethDevice
                            ethConnName:  root.ethConnName
                            ethListRaw:   root.ethListRaw
                            onRequestRefresh:  root._refreshEthList()
                        }
                    }
                }

                // ── Sub-tela: Bluetooth ──────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "bluetooth"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Bluetooth"; icon: "\uf294"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Bluetooth"; color: root.colorText; font.pixelSize: 11; Layout.fillWidth: true }
                            Qs.QsSwitch {
                                checked: root.btEnabled
                                colorAccent: root.colorAccent
                                onToggled: root._toggleBluetooth()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsTabBluetooth {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorMuted: root.colorMuted
                            btEnabled: root.btEnabled
                        }
                    }
                }
            }

            // ── ABA: Mídia ────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "media"

                // ── Tela principal (compacta, sempre cabe sem rolar) ────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === ""

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 12

                        Qs.QsMediaPlayerFull {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsVolumeSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                            colorMuted: root.colorMuted
                        }
                        Qs.QsMicSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                            colorMuted: root.colorMuted
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        // ── Navegação para sub-telas ───────────────────────────
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf2db"; label: "Dispositivos"
                            sub:  "Saída e entrada padrão"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "devices"
                        }
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf028"; label: "EasyEffects"
                            sub:  "Status, bypass e presets"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "easyeffects"
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ── Sub-tela: Dispositivos ────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "devices"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Dispositivos"; icon: "\uf2db"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: devCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsAudioDevices {
                                id: devCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }

                // ── Sub-tela: EasyEffects ──────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "easyeffects"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "EasyEffects"; icon: "\uf028"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: root.subPage = ""
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: eeCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsEasyEffects {
                                id: eeCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }
            }

            // ── ABA: Performance ──────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeTab === "performance"

                // ── Tela principal (compacta) ───────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === ""

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 12

                        Qs.QsSystemStats {
                            Layout.fillWidth: true
                            active: root.activeTab === "performance" && root.subPage === ""
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsNightMode {
                            Layout.fillWidth: true; panelOpen: root.panelOpen && root.activeTab === "performance"
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }
                        Qs.QsBrightnessSlider {
                            Layout.fillWidth: true
                            colorAccent: root.colorAccent; colorText: root.colorText
                            colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf2db"; label: "Perfil de energia"
                            sub:     powerProfileState.currentLabel
                            loading: powerProfileState.loading
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "power"
                        }
                        Qs.QsNavRow {
                            Layout.fillWidth: true
                            icon: "\uf185"; label: "Shader"
                            sub:     root.shaderSummary
                            loading: root.shaderSummary === "Carregando…"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onClicked: root.subPage = "shader"

                            Component.onCompleted: root._refreshShaderSummary()
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ── Sub-tela: Perfil de energia ─────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "power"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Perfil de energia"; icon: "\uf2db"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: { root.subPage = ""; powerProfileState.refresh() }
                        }

                        Qs.QsPowerProfile {
                            id: powerProfileState
                            Layout.fillWidth: true; Layout.fillHeight: true
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                        }
                    }
                }

                // ── Sub-tela: Shader ─────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.subPage === "shader"

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 10

                        Qs.QsPageHeader {
                            Layout.fillWidth: true
                            title: "Shader"; icon: "\uf185"
                            colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            onBackClicked: { root.subPage = ""; root._refreshShaderSummary() }
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            contentWidth: width
                            contentHeight: shCol.implicitHeight
                            boundsMovement: Flickable.StopAtBounds

                            Qs.QsShaderStatus {
                                id: shCol
                                width: parent.width
                                colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                            }
                        }
                    }
                }
            }
        }
    }
}
