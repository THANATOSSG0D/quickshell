import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

WlSessionLock {
    id: root

    function lock()   { root.locked = true  }
    function unlock() { root.locked = false }

    // Escreve o estado em arquivo para o bash script fazer polling
    onLockedChanged: stateWriter.running = true

    Process {
        id: stateWriter
        command: ["bash", "-c",
            "echo '" + (root.locked ? "locked" : "unlocked") + "' > " +
            Quickshell.env("HOME") + "/.cache/quickshell-lockstate"
        ]
    }

    // Garante estado "unlocked" ao sair/reiniciar o QS
    Component.onDestruction: {
        const p = Qt.createQmlObject(
            'import Quickshell.Io; Process { running: true; command: ["bash", "-c",' +
            '"echo unlocked > ' + Quickshell.env("HOME") + '/.cache/quickshell-lockstate"] }',
            root, "cleanup")
    }

    WlSessionLockSurface {
        id: surface
        color: "#0d0d0d"

        LockContent {
            anchors.fill: parent
            sessionLock:  root
            isPrimary:    surface.screen === Quickshell.screens[0]
        }
    }
}
