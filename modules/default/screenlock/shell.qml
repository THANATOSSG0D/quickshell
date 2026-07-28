import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "." as Screenlock

ShellRoot {
    id: root

    property bool sessionLocked: true

    // ── Config ────────────────────────────────────────────────────────────────
    // Processo isolado — só precisa ler o JSON uma vez ao iniciar (não tem
    // "live sync" com a instância principal, e não precisa: cada bloqueio é
    // um processo `qs -c` novo). Ver comentário no topo de ScreenLockConfig.qml.
    ScreenLockConfig {
        id: lockConfig
    }

    // ── DPMS ─────────────────────────────────────────────────────────────────
    readonly property int    dpmsTimeout:  lockConfig.get("dpmsTimeoutMs", 90000)
    readonly property string dpmsLogFile:  "/tmp/screenlock-dpms.log"

    property bool dpmsIsOff:    false
    property bool dpmsCooldown: false

    // ── Log de DPMS ───────────────────────────────────────────────────────────
    // Escreve em dois destinos:
    //   • console.log   → capturado pelo QS em /run/user/1000/quickshell/.../log.qslog
    //   • dpmsLogFile   → /tmp/screenlock-dpms.log  (tail -f amigável)
    Process {
        id: logProc
        // command é definido em dpmsLog() antes de cada execução
    }

    function dpmsLog(action) {
        var ts   = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss.zzz")
        var line = "[" + ts + "]  " + action
        console.log("[DPMS]", line)
        if (!logProc.running) {
            logProc.command = ["sh", "-c",
                "printf '%s\\n' " + JSON.stringify(line) +
                " >> " + JSON.stringify(root.dpmsLogFile)]
            logProc.running = true
        }
    }

    // ── Cooldown pós-DPMS-off ─────────────────────────────────────────────────
    Timer {
        id: dpmsCooldownTimer
        interval: 2000
        repeat:   false
        onTriggered: {
            root.dpmsCooldown = false
            root.dpmsLog("cooldown expirado — input habilitado")
        }
    }

    // ── Timer de inatividade ──────────────────────────────────────────────────
    Timer {
        id: dpmsIdleTimer
        interval: root.dpmsTimeout
        repeat:   true
        onTriggered: {
            if (root.dpmsIsOff) return
            root.dpmsLog("MONITOR OFF  ← idle " + (root.dpmsTimeout / 1000) + "s")
            root.dpmsIsOff    = true
            root.dpmsCooldown = true
            dpmsCooldownTimer.restart()
            procDpmsOff.running = true
        }
    }

    Process { id: procDpmsOff; command: ["hyprctl", "dispatch", "hl.dsp.dpms({mode = \"off\"})"] }
    Process { id: procDpmsOn;  command: ["hyprctl", "dispatch", "hl.dsp.dpms({mode = \"on\"})"]  }

    // ── Handlers de input ─────────────────────────────────────────────────────
    function onUserActivity() {
        if (root.dpmsIsOff) {
            if (root.dpmsCooldown) {
                root.dpmsLog("input ignorado (cooldown ativo)")
                return
            }
            root.dpmsLog("MONITOR ON   ← input do usuário")
            root.dpmsIsOff = false
            procDpmsOn.running = true
        }
        dpmsIdleTimer.restart()
    }

    // ── Quit ──────────────────────────────────────────────────────────────────
    Timer {
        id: quitTimer
        interval: 100
        onTriggered: Qt.quit()
    }

    // ── Session lock ──────────────────────────────────────────────────────────
    WlSessionLock {
        id: wlLock
        locked: root.sessionLocked

        onLockedChanged: {
            if (locked) {
                root.dpmsLog("lock screen ativo — timer de " +
                             (root.dpmsTimeout / 1000) + "s iniciado")
                dpmsIdleTimer.restart()
            }
        }

        WlSessionLockSurface {
            id: surface
            color: Colors.background

            LockContent {
                anchors.fill: parent
                config: lockConfig

                onUnlockRequested: {
                    dpmsIdleTimer.stop()
                    dpmsCooldownTimer.stop()

                    if (root.dpmsIsOff) {
                        root.dpmsLog("MONITOR ON   ← unlock")
                        root.dpmsIsOff = false
                        procDpmsOn.running = true
                    }

                    root.dpmsLog("sessão desbloqueada — encerrando")
                    root.sessionLocked = false
                    quitTimer.start()
                }

                onDisplayOffRequested: {
                    if (root.dpmsIsOff) return
                    root.dpmsLog("MONITOR OFF  ← botão manual")
                    dpmsIdleTimer.restart()
                    root.dpmsIsOff    = true
                    root.dpmsCooldown = true
                    dpmsCooldownTimer.restart()
                    procDpmsOff.running = true
                }

                onUserActivity: root.onUserActivity()
            }
        }
    }
}
