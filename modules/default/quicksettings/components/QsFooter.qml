import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Rodapé: botões de energia ─────────────────────────────────────────────────
// Linha 1 (imediatos): lock, suspend
// Linha 2 (confirmação 4s): exit, reboot, shutdown
// Usa systemctl para power actions (funciona via logind/polkit sem sudo extra).
// Mantém compatibilidade com power.sh se preferir.
Item {
    id: root

    property color colorText:  "#e2e2e2"
    property color colorMuted: "#cf6679"

    property string confirmPending: ""
    height: col.implicitHeight

    Process { id: powerProc }
    Timer { id: confirmTimer; interval: 4000; onTriggered: root.confirmPending = "" }

    function _execute(actionId) {
        var cmd
        switch (actionId) {
            case "lock":     cmd = [ "loginctl", "lock-session" ]; break
            case "suspend":  cmd = [ "systemctl", "suspend" ];     break
            case "exit":     cmd = [ "bash", "-c", "uwsm stop 2>/dev/null || hyprctl dispatch exit" ]; break
            case "reboot":   cmd = [ "systemctl", "reboot" ];      break
            case "shutdown": cmd = [ "systemctl", "poweroff" ];    break
            default: return
        }
        powerProc.command = cmd
        powerProc.running = true
    }

    function _handleDanger(actionId) {
        if (root.confirmPending === actionId) {
            _execute(actionId)
            root.confirmPending = ""
        } else {
            root.confirmPending = actionId
            confirmTimer.restart()
        }
    }

    readonly property var quickActions: [
        { id: "lock",    icon: "\uf023", label: "Bloquear"  },
        { id: "suspend", icon: "\uf28b", label: "Suspender" }
    ]
    readonly property var dangerActions: [
        { id: "exit",     icon: "\uf2f5", label: "Sair"      },
        { id: "reboot",   icon: "\uf021", label: "Reiniciar" },
        { id: "shutdown", icon: "\uf011", label: "Desligar"  }
    ]

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 6

        // Linha 1
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: root.quickActions
                delegate: Rectangle {
                    id: qBtn; required property var modelData
                    Layout.fillWidth: true; height: 26; radius: 13
                    color: qBtnMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout { anchors.centerIn: parent; spacing: 5
                        Text { text: qBtn.modelData.icon; color: root.colorText; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: qBtn.modelData.label; color: root.colorText; font.pixelSize: 10 }
                    }
                    MouseArea { id: qBtnMA; anchors.fill: parent; hoverEnabled: true; onClicked: root._execute(qBtn.modelData.id) }
                }
            }
        }

        // Linha 2
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: root.dangerActions
                delegate: Rectangle {
                    id: dBtn; required property var modelData
                    readonly property bool pending: root.confirmPending === dBtn.modelData.id
                    Layout.fillWidth: true; height: 26; radius: 13
                    color: dBtn.pending
                        ? Qt.rgba(root.colorMuted.r, root.colorMuted.g, root.colorMuted.b, 0.18)
                        : dBtnMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 5
                        Text {
                            text: dBtn.modelData.icon
                            color: dBtn.pending ? root.colorMuted : root.colorText
                            font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: dBtn.pending ? "Confirmar?" : dBtn.modelData.label
                            color: dBtn.pending ? root.colorMuted : root.colorText
                            font.pixelSize: 10
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    MouseArea { id: dBtnMA; anchors.fill: parent; hoverEnabled: true; onClicked: root._handleDanger(dBtn.modelData.id) }
                }
            }
        }
    }
}
