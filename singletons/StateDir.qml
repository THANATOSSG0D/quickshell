// ~/.config/quickshell/singletons/StateDir.qml
//
// Garante que ~/.config/quickshell/state existe — UMA vez por geração do
// shell, não uma vez por Config.qml. Antes, ~20 arquivos (ClockConfig,
// WeatherConfig, TodoConfig, BarConfig, PanelRouter, etc.) cada um
// spawnava seu próprio `mkdir -p` no Component.onCompleted. Num reload,
// isso disparava ~20 Process simultâneos e estourava ulimit -n (EMFILE),
// derrubando até hyprctl calls que não tinham nada a ver.
//
// A maioria dos Config.qml usa o onExited do próprio mkdir pra fazer
// file.reload() / writeAdapter() logo depois que a pasta é garantida —
// então não basta só criar a pasta uma vez, o resto do shell precisa de
// um jeito de "esperar" por esse momento. É pra isso que serve
// whenReady(): entrega o callback na hora certa, seja ela já ter
// passado ou ainda estar por vir.
//
// Uso:
//   import qs.singletons
//   ...
//   Component.onCompleted: StateDir.whenReady(() => {
//     file.reload()
//     initTimer.start()
//   })

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string path: Quickshell.shellDir + "/state"

    // true assim que o mkdir -p terminar (sucesso ou não — best-effort,
    // igual ao comportamento anterior fire-and-forget de cada Config.qml)
    property bool ready: false

    property var _mkdirProc: Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.path]
        onExited: root.ready = true
    }

    Component.onCompleted: mkdirProc.running = true

    // Chama `callback` imediatamente se a pasta já existe, ou assim que
    // o mkdir terminar, o que vier primeiro. Cobre os dois casos:
    //   - Config.qml instanciado ANTES do mkdir terminar → aguarda
    //   - Config.qml instanciado DEPOIS (ex: painel aberto sob demanda,
    //     como popups) → dispara na hora, sem re-executar mkdir
    function whenReady(callback) {
        if (root.ready) {
            callback()
            return
        }

        function handler() {
            if (!root.ready) return
            root.readyChanged.disconnect(handler)
            callback()
        }
        root.readyChanged.connect(handler)
    }
}
