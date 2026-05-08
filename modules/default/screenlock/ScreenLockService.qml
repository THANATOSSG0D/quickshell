pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// ── ScreenLockService ─────────────────────────────────────────────────────────
// Singleton que gerencia o estado do session lock.
//
// IPC:
//   qs ipc call screenLock lock     → ativa o lock
//   qs ipc call screenLock unlock   → desbloqueia (apenas via senha correta)
//
// Expõe:
//   locked       → bool, se a tela está bloqueada agora
//   lock()       → função IPC
//   unlock()     → função IPC (chamado internamente após senha correta)
// ─────────────────────────────────────────────────────────────────────────────
Scope {
    id: root

    // ── Estado público ──────────────────────────────────────────────────────
    readonly property bool locked: sessionLock.locked

    // ── Session Lock (ext-session-lock-v1) ──────────────────────────────────
    SessionLock {
        id: sessionLock
        locked: false
    }

    // ── IPC ─────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "screenLock"

        function lock() {
            sessionLock.locked = true
        }

        function unlock() {
            sessionLock.locked = false
        }
    }
}
