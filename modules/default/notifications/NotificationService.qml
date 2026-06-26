import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick

// ── NotificationService ───────────────────────────────────────────────────────
// Singleton (instanciar UMA VEZ em shell.qml).
// Gerencia o servidor DBus, histórico, toasts e estado DND.
//
// Uso em shell.qml:
//   NotificationService { id: notifService }
//   NotificationToast { service: notifService; ... }
//
// Propriedades de configuração (lidas do Bar.json via BarConfig):
//   toastPosition    — onde os toasts aparecem na tela
//   toastTimeoutMs   — timeout padrão (normal)
//   toastTimeoutLow  — timeout para urgência baixa
//   toastTimeoutCrit — timeout para crítico (0 = nunca expira sozinho)
//   maxToasts        — máximo de toasts simultâneos
//   maxHistory       — máximo de notificações no histórico
//   toastWidth/toastMargin/toastSpacing — geometria do toast
//   cardRadius       — raio dos cards (painel E toast)
//   dndBypassApps    — apps (regex, separados por vírgula) que ignoram DND
//   blockedToastApps — apps (regex, separados por vírgula) sem toast

Scope {
    id: root

    // ── Configuração ───────────────────────────────────────────────────────
    property string toastPosition:   "top-right"   // top-left/right, bottom-left/right, top-center, bottom-center
    property int    maxToasts:        5
    property int    toastTimeoutMs:   5000          // urgência normal
    property int    toastTimeoutLow:  3000          // urgência baixa
    property int    toastTimeoutCrit: 0             // 0 = persiste até o usuário dispensar
    property int    maxHistory:       50

    // Geometria do toast — antes hardcoded no NotificationToast.qml, sem
    // nenhuma config exposta. Agora a fonte de verdade é o service (mesmo
    // padrão de toastPosition), e o NotificationToast só lê via service.*.
    property int    toastWidth:   340
    property int    toastMargin:  12
    property int    toastSpacing: 8

    // Raio dos cards — usado tanto pelo painel (NotificationsContent) quanto
    // pelo toast (NotificationToast). Antes o toast lia o bgRadius global do
    // PopupConfig em vez disso, então o slider "Raio dos cards" da aba só
    // afetava o painel e não o toast.
    property int    cardRadius: 10

    // Regras por app (mesmo espírito do playerPriority da Mídia: lista
    // separada por vírgula, cada termo é regex case-insensitive contra
    // appName). Duas listas independentes:
    //   dndBypassApps    — essas notificações sempre mostram toast, mesmo
    //                       com Não Perturbe ativo (além das críticas).
    //   blockedToastApps — essas notificações nunca mostram toast (mas
    //                       continuam indo pro histórico normalmente).
    property string dndBypassApps:    ""
    property string blockedToastApps: ""

    // Default vindo do BarConfig (aba Notificações), usado só quando ainda
    // não existe notifications-state.json (primeira execução) — depois
    // disso, quem manda é o valor salvo via setPosition().
    property string configDefaultPosition: "top-right"

    // ── Estado DND ─────────────────────────────────────────────────────────
    property bool doNotDisturb:    false
    property bool dndAllowCritical: true    // crítico sempre aparece mesmo com DND ativo

    // ── Modo Silence ───────────────────────────────────────────────────────
    // Injetado pelo shell.qml. Suprime TODOS os toasts (incluindo críticos).
    property bool silenceMode: false
    onSilenceModeChanged: {
      if (silenceMode) {
        console.log("[Silence] NotifService: ativado — toasts bloqueados, timer de expiração pausado")
        // Limpa toasts visíveis imediatamente
        toastModel.clear()
      } else {
        console.log("[Silence] NotifService: desativado — toasts restaurados")
      }
    }

    // ── Models expostos ────────────────────────────────────────────────────
    // `notifications` — histórico completo (painel de notificações)
    // `toasts`        — notificações ativamente visíveis como toasts
    property alias notifications: notifModel
    property alias toasts:        toastModel
    property int   unreadCount:   0

    // ── Sinais ─────────────────────────────────────────────────────────────
    signal toastAdded(int id)
    signal toastRemoved(int id)
    signal dndToggled(bool active)

    // ── DBus Notification Server ───────────────────────────────────────────
    NotificationServer {
        id: server
        keepOnReload:           true
        // Sem isso o servidor nunca anuncia a capability "actions" no DBus,
        // então clientes (notify-send -A, notificações web do Vivaldi/Chrome
        // com botões, etc.) detectam que não há suporte e nem tentam enviar
        // as ações — exatamente o erro "Actions are not supported".
        actionsSupported:       true
        actionIconsSupported:   false
        bodyMarkupSupported:    true
        bodyHyperlinksSupported: false
        persistenceSupported:   true
        imageSupported:         true

        onNotification: (notif) => { root._receive(notif) }
    }

    // ── Models internos ────────────────────────────────────────────────────
    ListModel { id: notifModel }
    ListModel { id: toastModel }

    // ── Timer de expiração de toasts ───────────────────────────────────────
    // Verifica a cada 200 ms quais toasts devem ser removidos.
    // Pausado em silence: não há toasts para expirar.
    Timer {
        id: expireTimer
        interval: 200
        repeat:   true
        running:  toastModel.count > 0 && !root.silenceMode

        onTriggered: {
            var now = Date.now()
            for (var i = toastModel.count - 1; i >= 0; i--) {
                var t = toastModel.get(i)
                if (t.pausedSince && t.pausedSince > 0) continue   // hover ativo: não expira
                if (t.timeout > 0) {
                    var elapsed = now - t.timestamp - (t.pausedMs || 0)
                    if (elapsed >= t.timeout) {
                        toastModel.remove(i)
                        root.toastRemoved(t.id)
                    }
                }
            }
        }
    }

    // ── Persistência do estado DND ─────────────────────────────────────────
    property string _statePath: Quickshell.shellDir + "/state/notifications-state.json"

    FileView {
        id: stateFile
        path: root._statePath
        watchChanges: false
        onLoaded: {
            try {
                var j = JSON.parse(stateFile.text())
                root.doNotDisturb     = j.doNotDisturb    ?? false
                root.dndAllowCritical = j.dndAllowCritical ?? true
                root.toastPosition    = j.toastPosition   ?? root.configDefaultPosition

                // Restaura o histórico (não os toasts — esses são efêmeros
                // por natureza, não faz sentido reaparecerem depois de um
                // reload do shell). Ações desses itens restaurados não têm
                // referência DBus viva; clicar nelas só dispensa o card,
                // igual ao caso normal de "notificação sem referência viva".
                if (Array.isArray(j.history)) {
                    notifModel.clear()
                    var arr = j.history.slice(0, root.maxHistory)
                    for (var i = 0; i < arr.length; i++)
                        notifModel.append(arr[i])
                    root._updateUnread()
                }
            } catch (_) {}
        }
    }

    // Debounce de save: agrupa mudanças rápidas em uma única escrita de arquivo
    // sem spawnar processo bash.
    Timer {
        id: saveDebounce
        interval: 300
        repeat:   false
        onTriggered: {
            var hist = []
            for (var i = 0; i < notifModel.count; i++)
                hist.push(notifModel.get(i))
            stateFile.setText(JSON.stringify({
                doNotDisturb:     root.doNotDisturb,
                dndAllowCritical: root.dndAllowCritical,
                toastPosition:    root.toastPosition,
                history:          hist
            }, null, 2))
        }
    }

    function _saveState() { saveDebounce.restart() }

    Component.onCompleted: stateFile.reload()

    // Testa appName contra uma lista de termos separados por vírgula,
    // cada termo é regex case-insensitive (mesma convenção do
    // playerPriority em BarTabMidia). Lista vazia nunca casa com nada.
    function _matchesAppRule(appName, csv) {
        if (!csv || csv.trim() === "" || !appName) return false
        var terms = csv.split(",")
        for (var i = 0; i < terms.length; i++) {
            var t = terms[i].trim()
            if (t === "") continue
            try {
                if (new RegExp(t, "i").test(appName)) return true
            } catch (e) {
                console.warn("[Notifications] regex inválida em regra de app:", t)
            }
        }
        return false
    }

    // ── Lógica de recepção ─────────────────────────────────────────────────
    function _receive(notif) {
        var urgency    = notif.urgency ?? 1
        var isCritical = urgency >= 2

        var bypassesDnd = root._matchesAppRule(notif.appName, root.dndBypassApps)
        var blockedApp  = root._matchesAppRule(notif.appName, root.blockedToastApps)

        // Silence suprime tudo; DND suprime não-críticos (exceto apps na
        // lista de bypass); blockedToastApps suprime toast independente de
        // DND (mas a notificação ainda vai pro histórico normalmente).
        var showToast = !root.silenceMode && !blockedApp &&
                        (!root.doNotDisturb || (root.dndAllowCritical && isCritical) || bypassesDnd)

        if (root.silenceMode)
            console.log("[Silence] NotifService: toast bloqueado —", notif.appName, "»", notif.summary)
        if (blockedApp)
            console.log("[Notifications] toast bloqueado por regra de app —", notif.appName)

        // Timeout baseado na urgência
        var timeout = isCritical          ? root.toastTimeoutCrit
                    : urgency === 0       ? root.toastTimeoutLow
                    :                       root.toastTimeoutMs

        var item = {
            id:        notif.id,
            appName:   notif.appName  || "",
            appIcon:   notif.appIcon  || "",
            // Apps Electron/Chromium (Vivaldi entre eles) costumam mandar a
            // imagem como icon_data embutido em vez de um nome de ícone de
            // tema — o appIcon fica vazio nesse caso. O Quickshell expõe
            // esse dado já decodificado em notif.image (path utilizável),
            // então usamos como alternativa quando appIcon não resolve nada.
            image:     notif.image    || "",
            summary:   notif.summary  || "",
            body:      notif.body     || "",
            urgency:   urgency,
            timestamp: Date.now(),
            timeout:   timeout,
            read:      !showToast,
            actions:   _serializeActions(notif.actions),
            // Usados só por toasts, pra pausar o timeout enquanto o
            // mouse está sobre o card (ver setToastPaused()).
            pausedSince: 0,
            pausedMs:    0
        }

        // Diagnóstico: ajuda a confirmar se o app está mandando ações de
        // verdade pelo DBus ou se o problema é em outra camada. Olhe o log
        // do Quickshell quando uma notificação com botão chegar.
        if (item.actions.length > 0)
            console.log("[Notifications] ações recebidas de", item.appName, "→", JSON.stringify(item.actions))

        // Diagnóstico temporário pro bug do ícone quadriculado — mostra a
        // string exata que cada notificação manda, pra ver o esquema real
        // (file://, image://, nome de tema cru, etc).
        console.log("[Notifications] icon debug —", item.appName,
                     "| appIcon:", item.appIcon, "| image:", item.image)

        // Referência viva da notificação — precisamos dela pra invocar a
        // ação de verdade via DBus depois (o array serializado em
        // item.actions só guarda identifier/text pro QML, sem o vínculo
        // com o objeto real). Antes isso não existia: clicar numa ação só
        // dispensava a notificação, sem nunca chamar o app remetente.
        root._liveNotifs[notif.id] = notif

        // Remover notificação anterior do mesmo app+summary (substituição)
        for (var k = notifModel.count - 1; k >= 0; k--) {
            var n = notifModel.get(k)
            if (n.id === item.id) { notifModel.remove(k); break }
        }

        // Adicionar ao histórico (mais recente primeiro)
        if (notifModel.count >= root.maxHistory) {
            var old = notifModel.get(notifModel.count - 1)
            delete root._liveNotifs[old.id]
            notifModel.remove(notifModel.count - 1)
        }
        notifModel.insert(0, item)

        if (showToast) {
            root.unreadCount++
            _addToast(item)
            root.toastAdded(item.id)
        }

        // Conecta o fechamento pelo app-remetente
        notif.onClosed.connect(function() {
            root.dismissToast(notif.id)
            delete root._liveNotifs[notif.id]
        })

        root._saveState()
    }

    // Map id → objeto Notification vivo (não serializável no ListModel,
    // por isso fica fora dele). Ver invokeAction().
    property var _liveNotifs: ({})

    function _serializeActions(actions) {
        if (!actions) return []
        // Quickshell pode expor isso como objeto com .values (modelo Qt) ou
        // como array direto, dependendo da versão/contexto. Antes só
        // tentava actions.values — se isso não existisse, actions.values.length
        // estourava TypeError e abortava a função inteira sem try/catch,
        // o que (suspeita) pode ter feito notificações com ações de certos
        // remetentes nunca chegarem a aparecer.
        var list = (actions.values !== undefined) ? actions.values : actions
        if (!list || typeof list.length !== "number") {
            console.warn("[Notifications] formato de actions não reconhecido:", JSON.stringify(actions))
            return []
        }
        var arr = []
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            if (!a) continue
            arr.push({ identifier: a.identifier, text: a.text || a.identifier })
        }
        return arr
    }

    function _addToast(item) {
        // Remove toasts mais antigos se atingir o limite
        while (toastModel.count >= root.maxToasts)
            toastModel.remove(0)
        toastModel.append(item)
    }

    // ── API pública ────────────────────────────────────────────────────────

    // Invoca a ação de verdade no app remetente (via DBus), em vez de só
    // remover a notificação da tela. Antes, clicar num botão de ação
    // (ex: "Responder", "Marcar como lida") não fazia nada além de
    // dispensar o card — agora chama notif.actions de fato.
    function invokeAction(id, identifier) {
        var notif = root._liveNotifs[id]
        if (!notif || !notif.actions) {
            console.warn("[Notifications] invokeAction: notificação", id, "não tem mais referência viva")
            dismissNotification(id)
            return
        }
        var list = (notif.actions.values !== undefined) ? notif.actions.values : notif.actions
        var acted = false
        if (list && typeof list.length === "number") {
            for (var i = 0; i < list.length; i++) {
                var a = list[i]
                if (a && a.identifier === identifier) {
                    if (typeof a.invoke === "function") a.invoke()
                    acted = true
                    break
                }
            }
        }
        if (!acted)
            console.warn("[Notifications] invokeAction: identifier", identifier, "não encontrado em", id)
        dismissNotification(id)
    }

    function dismissToast(id) {
        for (var i = toastModel.count - 1; i >= 0; i--) {
            if (toastModel.get(i).id === id) {
                toastModel.remove(i)
                root.toastRemoved(id)
                return
            }
        }
    }

    // Pausa/retoma o timeout de expiração de um toast — chamado pelo
    // NotificationToast quando o mouse entra/sai do card. Ao retomar,
    // acumula o tempo pausado em pausedMs em vez de só zerar pausedSince,
    // pra não "perder" o tempo que já tinha decorrido antes do hover.
    function setToastPaused(id, paused) {
        for (var i = 0; i < toastModel.count; i++) {
            var t = toastModel.get(i)
            if (t.id !== id) continue
            if (paused) {
                toastModel.setProperty(i, "pausedSince", Date.now())
            } else {
                var since = t.pausedSince || 0
                if (since > 0) {
                    var extra = Date.now() - since
                    toastModel.setProperty(i, "pausedMs", (t.pausedMs || 0) + extra)
                }
                toastModel.setProperty(i, "pausedSince", 0)
            }
            return
        }
    }

    function dismissNotification(id) {
        dismissToast(id)
        delete root._liveNotifs[id]
        for (var i = notifModel.count - 1; i >= 0; i--) {
            if (notifModel.get(i).id === id) {
                notifModel.remove(i)
                _updateUnread()
                root._saveState()
                return
            }
        }
    }

    function clearAll() {
        toastModel.clear()
        notifModel.clear()
        root._liveNotifs = ({})
        root.unreadCount = 0
        root._saveState()
    }

    function clearToasts() {
        toastModel.clear()
    }

    function markAllRead() {
        for (var i = 0; i < notifModel.count; i++)
            notifModel.setProperty(i, "read", true)
        root.unreadCount = 0
    }

    function toggleDnd() {
        root.doNotDisturb = !root.doNotDisturb
        root.dndToggled(root.doNotDisturb)
        root._saveState()
    }

    function setPosition(pos) {
        root.toastPosition = pos
        root._saveState()
    }

    function _updateUnread() {
        var count = 0
        for (var i = 0; i < notifModel.count; i++)
            if (!notifModel.get(i).read) count++
        root.unreadCount = count
    }
}
