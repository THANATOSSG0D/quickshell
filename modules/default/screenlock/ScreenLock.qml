import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

WlSessionLock {
    id: root

    function lock()   { root.locked = true  }
    function unlock() { root.locked = false }

    onLockedChanged: {
        if (root.locked) {
            writeLocked.running = true
        } else {
            writeUnlocked.running = true
        }
    }

    // Dois processos separados com comandos fixos — evita problema de
    // string interpolation não re-avaliar quando locked muda
    Process {
        id: writeLocked
        command: ["bash", "-c",
            "echo locked > " + Quickshell.env("HOME") + "/.cache/quickshell-lockstate"
        ]
    }

    Process {
        id: writeUnlocked
        command: ["bash", "-c",
            "echo unlocked > " + Quickshell.env("HOME") + "/.cache/quickshell-lockstate"
        ]
    }

    // Garante "unlocked" se o QS for morto/reiniciado
    Component.onDestruction: writeUnlocked.running = true

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
