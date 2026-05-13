import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLock {
    id: root

    property bool lockRequested: false
    locked: lockRequested

    function lock()   { root.lockRequested = true  }
    function unlock() { root.lockRequested = false }

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
