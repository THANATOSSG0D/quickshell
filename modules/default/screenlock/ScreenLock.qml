// ~/.config/quickshell/modules/default/screenlock/ScreenLock.qml
//
// Este arquivo é carregado pelo shell PRINCIPAL apenas para expor
// o IPC `screenLock` — usado pelo PowerMenu ("Bloquear") e keybinds.
// O lock em si é feito pela instância isolada (shell.qml).
//
// Quando lock() é chamado, lança a instância isolada via execDetached.
// O processo roda independente — sem bloquear o shell principal.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string lockDir: Quickshell.shellDir +
                                      "/modules/default/screenlock"
    readonly property string scriptPath: Quickshell.env("HOME") +
                                         "/.config/quickshell/scripts/screenlock"

    // Lança o shell script (que por sua vez roda qs -c)
    function lock() {
        Quickshell.execDetached(["bash", "-c",
            "nohup " + root.scriptPath + " >/dev/null 2>&1 &"])
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    // qs ipc call screenLock lock        → bloqueia a sessão
    // qs ipc call screenLock reload      → reload RÁPIDO (soft, reaproveita
    //                                       janelas) — usado automaticamente
    //                                       pelo script `screenlock` no unlock
    // qs ipc call screenLock reloadHard  → reload completo (recria janelas,
    //                                       mais lento) — só se o soft não
    //                                       for suficiente pra corrigir o bug
    //
    // QtObject não tem "default property", então o IpcHandler precisa ser
    // atribuído a uma property explícita em vez de aninhado implicitamente.
    property QtObject ipcHandler: IpcHandler {
        target: "screenLock"

        function lock(): void {
            root.lock()
        }

        function reload(): void {
            Quickshell.reload(false)
        }

        function reloadHard(): void {
            Quickshell.reload(true)
        }
    }
}
