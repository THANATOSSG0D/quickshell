// ~/.config/quickshell/modules/default/screenlock/shell.qml
// Instância isolada: qs -c ~/.config/quickshell/modules/default/screenlock/
import QtQuick
import Quickshell
import Quickshell.Wayland

// Colors.qml está no mesmo diretório (proxy que re-exporta o original)
import "."

ShellRoot {
    id: root

    property bool sessionLocked: true

    Timer {
        id: quitTimer
        interval: 400
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: wlLock
        locked: root.sessionLocked

        WlSessionLockSurface {
            id: surface
            color: Colors.background

            LockContent {
                anchors.fill: parent
                // Passa o wlLock e um callback de unlock — sem chamar .unlock()
                sessionLock: wlLock
                isPrimary:   surface.screen === Quickshell.screens[0]

                onUnlockRequested: {
                    root.sessionLocked = false
                    quitTimer.start()
                }
            }
        }
    }
}
