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

    // IPC: qs ipc call screenLock lock
    // Lança o shell script (que por sua vez roda qs -c)
    function lock() {
        Quickshell.execDetached(["bash", "-c",
            "nohup " + root.scriptPath + " >/dev/null 2>&1 &"])
    }
}
