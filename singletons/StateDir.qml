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
// um jeito de "esperar" por esse momento.
//
// Uso (cada consumidor usa Connections, NÃO uma closure guardada aqui —
// ver nota mais abaixo sobre por quê):
//   import qs.singletons
//   ...
//   Connections {
//     target: StateDir
//     function onReadyChanged() {
//       if (StateDir.ready) file.reload()
//     }
//   }
//   Component.onCompleted: if (StateDir.ready) file.reload()

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

    // Rede de segurança: se o Process do mkdir falhar ao SPAWNAR (não só
    // terminar com erro — falhar de verdade, ex: EMFILE momentâneo durante
    // um reload sob estresse de recursos), não dá pra garantir que
    // onExited vai disparar, e sem isso `ready` ficaria travado em false
    // PRA SEMPRE — travando todo consumidor (Habits, Favorites, Todo,
    // monitoramento, WidgetLayoutConfig/WidgetHost, etc.) permanentemente
    // vazio, sem nenhum jeito de se autocorrigir.
    //
    // Na prática, a pasta state/ quase sempre JÁ EXISTE (só precisa ser
    // criada de verdade uma vez, no primeiro boot). Gatear tudo
    // indefinidamente atrás de um `mkdir -p` que é redundante 99% das
    // vezes é frágil demais — 2s é tempo de sobra pro caso normal
    // (onExited já disparou há muito) e um teto aceitável pro caso raro.
    property var _readyTimeout: Timer {
        interval: 2000
        running: true
        onTriggered: if (!root.ready) root.ready = true
    }

    Component.onCompleted: mkdirProc.running = true

    // NOTA: não existe mais whenReady(callback) aqui. Uma closure JS
    // guardada por este singleton e disparada depois, em cima de um
    // objeto que já foi destruído (settle de startup recriando widgets,
    // hot reload, etc.), falha no nível do engine QML antes de chegar a
    // qualquer try/catch — não dá pra proteger isso de dentro do
    // singleton. O jeito robusto é cada consumidor usar Connections
    // (um objeto filho, que morre junto com o pai) em vez de uma função
    // guardada externamente. Padrão:
    //
    //   import qs.singletons
    //   ...
    //   Connections {
    //     target: StateDir
    //     function onReadyChanged() {
    //       if (StateDir.ready) file.reload()
    //     }
    //   }
    //   Component.onCompleted: if (StateDir.ready) file.reload()
}
