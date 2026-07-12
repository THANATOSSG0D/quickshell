import QtQuick
import Quickshell
import Quickshell.Io

// ── TodoReminderService ─────────────────────────────────────────────────
// Serviço único (instanciado UMA vez em shell.qml, igual ao
// NotifModule.NotificationService) que fica de olho nas tarefas e dispara
// notificações via `notify-send`. Três situações:
//
//  1. Tarefa atrasada (due < hoje, não concluída) → notifica individual,
//     uma vez, assim que detectada.
//  2. Tarefa de hoje COM horário próprio (task.time = "HH:mm") → notifica
//     individual assim que o relógio bate aquele horário.
//  3. Tarefas de hoje SEM horário → não notificam uma por uma; entram num
//     resumo único, disparado nos horários de config.summaryTimes
//     (ex.: "08:00", "20:00" — configurável na aba Tarefas).
//
// Como o NotifModule.NotificationService já roda como o daemon de
// notificações do sistema (org.freedesktop.Notifications), essas
// notificações caem no MESMO toast nativo do shell — dismiss, pause-on-
// hover e histórico de graça.
//
// Resiliência a PC desligado / tela bloqueada / quickshell parado: nada
// aqui depende de disparar EXATAMENTE no segundo certo. Tanto o lembrete
// individual (`t.time <= now`) quanto o resumo (`hm <= now`) comparam com
// "menor ou igual", não "igual" — então se o horário passou enquanto
// nada disso estava rodando, a primeira checagem depois que o quickshell
// voltar (`triggeredOnStart: true` no Timer, mais o ciclo de 1 min) já
// pega o que ficou pra trás e notifica. Atrasada (due < hoje) já
// funcionava assim desde o início, por natureza.
//
// Uso (uma única vez, em shell.qml):
//   TodoReminderService {}
//
// Não escreve nada — só lê state/TodoWidget.json (mesma TodoConfig usada
// em todo o módulo) pra decidir quando notificar.

Item {
  id: root
  visible: false

  TodoConfig { id: config }

  // ids já notificados "hoje" (atrasada OU horário batido) — evita
  // reenviar a cada tick. horários de resumo já disparados "hoje"
  // (chave = "08:00" etc.). Ambos zeram sozinhos quando o dia muda.
  property var _notifiedIds: ({})
  property var _notifiedSummaries: ({})
  property string _lastCheckedDay: ""
  property var _queue: []

  function _todayStr() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
  function _nowHM() {
    const d = new Date()
    return (d.getHours()   < 10 ? "0" : "") + d.getHours() + ":" +
           (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
  }

  function _resetIfNewDay() {
    const today = root._todayStr()
    if (today !== root._lastCheckedDay) {
      root._notifiedIds = {}
      root._notifiedSummaries = {}
      root._lastCheckedDay = today
    }
  }

  function _checkDue() {
    root._resetIfNewDay()
    const today = root._todayStr()
    const now   = root._nowHM()

    // 1) atrasadas + 2) horário específico batido hoje
    for (const t of config.tasks) {
      if (t.done || !t.due || root._notifiedIds[t.id]) continue

      if (t.due < today) {
        root._notifiedIds[t.id] = true
        root._queue.push({ type: "task", task: t, overdue: true })
      } else if (t.due === today && t.time && t.time <= now) {
        root._notifiedIds[t.id] = true
        root._queue.push({ type: "task", task: t, overdue: false })
      }
    }

    // 3) resumo agendado — tarefas de hoje SEM horário próprio.
    // Usa "hm <= now" (não "hm === now"): se o PC estava desligado, a tela
    // bloqueada ou o quickshell parado exatamente nesse horário, ele ainda
    // pega na primeira checagem depois que tudo voltar — não perde o
    // resumo do dia só porque não estava rodando no minuto exato.
    for (const hm of (config.summaryTimes || [])) {
      if (hm > now || root._notifiedSummaries[hm]) continue
      root._notifiedSummaries[hm] = true

      const pending = config.tasks.filter(function(t) {
        return !t.done && t.due === today && !t.time
      })
      if (pending.length > 0) root._queue.push({ type: "summary", tasks: pending })
    }

    root._drainQueue()
  }

  // dispara notify-send um de cada vez (espera o processo anterior
  // terminar antes do próximo — evita reusar o mesmo Process concorrente)
  function _drainQueue() {
    if (notifyProc.running) return
    if (root._queue.length === 0) return
    const item = root._queue.shift()

    if (item.type === "summary") {
      const names = item.tasks.slice(0, 5).map(function(t) { return t.text }).join(", ")
      const extra = item.tasks.length > 5 ? " e mais " + (item.tasks.length - 5) : ""
      notifyProc.command = [
        "notify-send", "--app-name=Tarefas", "--urgency=normal",
        "Resumo de hoje · " + item.tasks.length + " tarefa(s)",
        names + extra,
      ]
      notifyProc.running = true
      return
    }

    const t = item.task
    const urgency = t.priority === "alta" ? "critical" : (t.priority === "baixa" ? "low" : "normal")
    const title = item.overdue ? "Tarefa atrasada" : "Tarefa agora"
    const body  = item.overdue ? t.text : ((t.time ? t.time + " · " : "") + t.text)

    notifyProc.command = [
      "notify-send", "--app-name=Tarefas", "--urgency=" + urgency, title, body,
    ]
    notifyProc.running = true
  }

  Process {
    id: notifyProc
    onExited: root._drainQueue()
  }

  Timer {
    // 1 min — precisa dessa granularidade pra bater exatamente no horário
    // configurado de cada tarefa/resumo, não só "algum minuto depois"
    interval: 60 * 1000
    running: true; repeat: true
    triggeredOnStart: true
    onTriggered: root._checkDue()
  }
}
