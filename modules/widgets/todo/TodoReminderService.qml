import QtQuick
import Quickshell
import Quickshell.Io

// ── TodoReminderService ─────────────────────────────────────────────────
// Serviço único (instanciado UMA vez em shell.qml, igual ao
// NotifModule.NotificationService) que fica de olho nas tarefas com prazo
// vencido ou vencendo hoje e dispara uma notificação via `notify-send`.
//
// Diferente do "Timer" do Clock (que usa a própria OSD do shell, com som e
// dismiss custom), aqui optei pelo caminho mais simples: notify-send puro.
// Como o NotifModule.NotificationService já roda como o daemon de
// notificações do sistema (org.freedesktop.Notifications), a notificação
// acaba renderizada pelo MESMO toast nativo do shell — com o dismiss,
// pause-on-hover e histórico que ele já tem — sem precisar duplicar nada
// disso aqui.
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

  // ids já notificados "hoje" — evita reenviar a cada tick enquanto o
  // shell continua rodando. Zera sozinho quando o dia muda (comparando
  // com _lastCheckedDay).
  property var _notifiedIds: ({})
  property string _lastCheckedDay: ""
  property var _queue: []

  function _todayStr() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }

  function _checkDue() {
    const today = root._todayStr()
    if (today !== root._lastCheckedDay) {
      root._notifiedIds = {}
      root._lastCheckedDay = today
    }

    for (const t of config.tasks) {
      if (t.done || !t.due) continue
      if (t.due > today) continue          // ainda não venceu
      if (root._notifiedIds[t.id]) continue
      root._notifiedIds[t.id] = true
      root._queue.push(t)
    }
    root._drainQueue()
  }

  // dispara notify-send um de cada vez (espera o processo anterior
  // terminar antes do próximo — evita reusar o mesmo Process concorrente)
  function _drainQueue() {
    if (notifyProc.running) return
    if (root._queue.length === 0) return
    const t = root._queue.shift()
    const today = root._todayStr()
    const overdue = t.due < today
    const urgency = t.priority === "alta" ? "critical" : (t.priority === "baixa" ? "low" : "normal")
    const title = overdue ? "Tarefa atrasada" : "Tarefa vence hoje"

    notifyProc.command = [
      "notify-send",
      "--app-name=Tarefas",
      "--urgency=" + urgency,
      title,
      t.text,
    ]
    notifyProc.running = true
  }

  Process {
    id: notifyProc
    onExited: root._drainQueue()
  }

  Timer {
    interval: 5 * 60 * 1000 // checa a cada 5 min
    running: true; repeat: true
    triggeredOnStart: true
    onTriggered: root._checkDue()
  }
}
