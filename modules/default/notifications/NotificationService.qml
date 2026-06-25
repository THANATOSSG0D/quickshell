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

Scope {
    id: root

    // ── Configuração ───────────────────────────────────────────────────────
    property string toastPosition:   "top-right"   // top-left/right, bottom-left/right, top-center, bottom-center
    property int    maxToasts:        5
    property int    toastTimeoutMs:   5000          // urgência normal
    property int    toastTimeoutLow:  3000          // urgência baixa
    property int    toastTimeoutCrit: 0             // 0 = persiste até o usuário dispensar
    property int    maxHistory:       50

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
                if (t.timeout > 0 && now - t.timestamp >= t.timeout) {
                    toastModel.remove(i)
                    root.toastRemoved(t.id)
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
            stateFile.setText(JSON.stringify({
                doNotDisturb:     root.doNotDisturb,
                dndAllowCritical: root.dndAllowCritical,
                toastPosition:    root.toastPosition
            }, null, 2))
        }
    }

    function _saveState() { saveDebounce.restart() }

    Component.onCompleted: stateFile.reload()

    // ── Lógica de recepção ─────────────────────────────────────────────────
    function _receive(notif) {
        var urgency    = notif.urgency ?? 1
        var isCritical = urgency >= 2

        // Silence suprime tudo; DND suprime não-críticos
        var showToast = !root.silenceMode &&
                        (!root.doNotDisturb || (root.dndAllowCritical && isCritical))

        if (root.silenceMode)
            console.log("[Silence] NotifService: toast bloqueado —", notif.appName, "»", notif.summary)

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
            actions:   _serializeActions(notif.actions)
        }

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
    }

    // Map id → objeto Notification vivo (não serializável no ListModel,
    // por isso fica fora dele). Ver invokeAction().
    property var _liveNotifs: ({})

    function _serializeActions(actions) {
        if (!actions) return []
        var arr = []
        for (var i = 0; i < actions.values.length; i++) {
            var a = actions.values[i]
            arr.push({ identifier: a.identifier, text: a.text })
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
        var acted = false
        for (var i = 0; i < notif.actions.values.length; i++) {
            var a = notif.actions.values[i]
            if (a.identifier === identifier) {
                if (typeof a.invoke === "function") a.invoke()
                acted = true
                break
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

    function dismissNotification(id) {
        dismissToast(id)
        delete root._liveNotifs[id]
        for (var i = notifModel.count - 1; i >= 0; i--) {
            if (notifModel.get(i).id === id) {
                notifModel.remove(i)
                _updateUnread()
                return
            }
        }
    }

    function clearAll() {
        toastModel.clear()
        notifModel.clear()
        root._liveNotifs = ({})
        root.unreadCount = 0
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
