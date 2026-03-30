import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Aba: Sistema ─────────────────────────────────────────────────────────────
// Exibe hostname, versão do kernel e uptime.
// Todos os valores são lidos via Process no onCompleted.
Item {
    id: root

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorAccent:  "#ffb4a9"

    // ── Processos de leitura ───────────────────────────────────────────────
    Process { id: hostnameProc; command: [ "hostname" ] }
    Process { id: unameProc;    command: [ "uname", "-r" ] }
    Process { id: uptimeProc;   command: [ "uptime", "-p" ] }

    Component.onCompleted: {
        hostnameProc.running = true
        unameProc.running = true
        uptimeProc.running = true
    }

    // Bindings reativos ao stdout dos processos
    readonly property string hostnameVal: (hostnameProc.stdout || "").trim() || "–"
    readonly property string kernelVal:   (unameProc.stdout || "").trim()    || "–"
    readonly property string uptimeVal:   (uptimeProc.stdout || "").trim()   || "–"

    // ── Linhas de informação ───────────────────────────────────────────────
    readonly property var rows: [
        { icon: "\uf108", label: "Hostname", valueOf: root.hostnameVal },
        { icon: "\uf17c", label: "Kernel",   valueOf: root.kernelVal   },
        { icon: "\uf017", label: "Uptime",   valueOf: root.uptimeVal   }
    ]

    ColumnLayout {
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        spacing: 10

        Repeater {
            model: root.rows

            delegate: RowLayout {
                id: sysRow
                required property var modelData

                Layout.fillWidth: true
                spacing: 10

                // ── Ícone ─────────────────────────────────────────────
                Text {
                    text:           sysRow.modelData.icon
                    color:          root.colorAccent
                    font.pixelSize: 13
                    font.family:    "JetBrainsMono Nerd Font"
                }

                // ── Label + valor ──────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text:           sysRow.modelData.label
                        color:          root.colorTextDim
                        font.pixelSize: 9
                    }
                    Text {
                        text:           sysRow.modelData.valueOf
                        color:          root.colorText
                        font.pixelSize: 10
                        elide:          Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
