import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

WlSessionLock {
    id: root

    property bool lockRequested: false
    locked: lockRequested

    function lock() {
        console.log("[ScreenLock] lock() chamado")
        lockRequested = true
    }
    function unlock() {
        console.log("[ScreenLock] unlock() chamado")
        lockRequested = false
    }

    onLockedChanged: {
        console.log("[ScreenLock] onLockedChanged:", root.locked)
        if (root.locked) {
            writeLocked.running = true
        }
    }

    // Timer interval:0 evita ReferenceError de forward reference no onCompleted
    Timer {
        interval: 0; running: true; repeat: false
        onTriggered: writeUnlocked.running = true
    }
    Component.onDestruction: writeUnlocked.running = true

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
