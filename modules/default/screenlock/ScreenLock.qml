import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLock {
    id: root

    function lock()   { root.locked = true  }
    function unlock() { root.locked = false }

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
