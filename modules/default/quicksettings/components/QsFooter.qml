import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Rodapé: botões de energia ─────────────────────────────────────────────────
// Linha 1 (ações rápidas, sem confirmação): lock, suspend
// Linha 2 (ações destrutivas, com confirmação de 4s): exit, reboot, shutdown
//
// Fluxo de confirmação:
//   1º clique → confirmPending = actionId, timer de 4s inicia
//   2º clique → executa o comando, confirmPending = ""
//   Timeout   → confirmPending = "" (cancela silenciosamente)
Item {
    id: root

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorText:  "#e2e2e2"
    property color colorMuted: "#cf6679"

    // ── Estado de confirmação pendente ─────────────────────────────────────
    property string confirmPending: ""

    height: col.implicitHeight

    // ── Processo reutilizado para todos os comandos de energia ─────────────
    Process { id: powerProc }

    // ── Timer de cancelamento automático (4s) ─────────────────────────────
    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: root.confirmPending = ""
    }

    // ── Execução centralizada do script de energia ─────────────────────────
    // Usa $HOME para garantir expansão correta dentro de `bash -c`.
    // O ~ não é expandido quando passado como string para exec, mas $HOME sim.
    function _execute(actionId) {
        powerProc.command = [ "/bin/bash", "-c",
            "$HOME/.config/hypr/scripts/power.sh " + actionId ]
        powerProc.running = true
    }

    // ── Manipulador de clique com confirmação ──────────────────────────────
    function _handleDanger(actionId) {
        if (root.confirmPending === actionId) {
            _execute(actionId)
            root.confirmPending = ""
        } else {
            root.confirmPending = actionId
            confirmTimer.restart()
        }
    }

    // ── Definição das ações ────────────────────────────────────────────────
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
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: 6

        // ── Linha 1: ações rápidas (sem confirmação) ───────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.quickActions

                delegate: Rectangle {
                    id: quickBtn
                    required property var modelData

                    Layout.fillWidth: true
                    height: 26; radius: 13
                    color: Qt.rgba(1, 1, 1, 0.07)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text:           quickBtn.modelData.icon
                            color:          root.colorText
                            font.pixelSize: 11
                            font.family:    "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text:           quickBtn.modelData.label
                            color:          root.colorText
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked:    root._execute(quickBtn.modelData.id)
                    }
                }
            }
        }

        // ── Linha 2: ações destrutivas (com confirmação inline) ────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.dangerActions

                delegate: Rectangle {
                    id: dangerBtn
                    required property var modelData

                    readonly property bool pending: root.confirmPending === dangerBtn.modelData.id

                    Layout.fillWidth: true
                    height: 26; radius: 13
                    color: dangerBtn.pending
                        ? Qt.rgba(root.colorMuted.r, root.colorMuted.g, root.colorMuted.b, 0.15)
                        : Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text:           dangerBtn.modelData.icon
                            color:          dangerBtn.pending ? root.colorMuted : root.colorText
                            font.pixelSize: 11
                            font.family:    "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text:           dangerBtn.pending ? "Confirmar?" : dangerBtn.modelData.label
                            color:          dangerBtn.pending ? root.colorMuted : root.colorText
                            font.pixelSize: 10
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked:    root._handleDanger(dangerBtn.modelData.id)
                    }
                }
            }
        }
    }
}
