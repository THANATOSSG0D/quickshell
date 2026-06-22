import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsPowerProfile ────────────────────────────────────────────────────────────
// Lê e troca o perfil de energia/térmico via `thermal-profile` (script em
// ~/.config/hypr/scripts/, fora do padrão dos outros scripts que ficam em
// ~/.config/hypr/scripts também, mas thermal-profile é uma exceção mencionada
// pelo usuário como não estando lá — assume-se que está no PATH).
//
// `thermal-profile waybar` retorna JSON {"text","class","tooltip"} — usamos
// o campo "class" para saber o perfil ativo. Trocar de perfil roda
// `thermal-profile <nome>` (requer sudo, conforme o script original).
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property string activeProfile: ""   // performance | gaming | balanced | balanced_cool | cool
    property bool   loading:       false
    property bool   hasError:      false

    readonly property var profiles: [
        { id: "performance",   icon: "\uf06d", label: "Performance",    tdp: "45/65W" },
        { id: "gaming",        icon: "\uf11b", label: "Gaming",         tdp: "42/60W" },
        { id: "balanced",      icon: "\uf24e", label: "Balanced",       tdp: "28/45W" },
        { id: "balanced_cool", icon: "\uf2c9", label: "Balanced Cool",  tdp: "20/30W" },
        { id: "cool",          icon: "\uf2c7", label: "Cool",           tdp: "15/25W" }
    ]

    function refresh() {
        if (statusProc.running) return
        root.loading = true; root.hasError = false
        statusProc.command = ["bash", "-c", "thermal-profile waybar 2>/dev/null"]
        statusProc.running = true
    }

    function setProfile(id) {
        if (id === root.activeProfile) return
        applyProc.command = ["bash", "-c",
            "thermal-profile \"" + id + "\" 2>/dev/null || sudo -n thermal-profile \"" + id + "\" 2>/dev/null"]
        applyProc.running = true
        root.activeProfile = id   // otimista — refresh confirma depois
        refreshDelay.restart()
    }

    Process {
        id: statusProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => statusProc._buf += l }
        onRunningChanged: {
            if (running) return
            var out = statusProc._buf.trim(); statusProc._buf = ""
            root.loading = false
            if (out === "") { root.hasError = true; return }
            try {
                var data = JSON.parse(out)
                root.activeProfile = (data.class || "").replace("-", "_")
            } catch (e) {
                root.hasError = true
            }
        }
    }

    Process { id: applyProc }
    Timer { id: refreshDelay; interval: 800; onTriggered: root.refresh() }

    Component.onCompleted: refresh()

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 6

        Text {
            visible: root.loading
            text: "Carregando…"; color: root.colorTextDim; font.pixelSize: 10
        }
        Text {
            visible: root.hasError && !root.loading
            text: "thermal-profile indisponível"; color: root.colorTextDim; font.pixelSize: 10
        }

        Repeater {
            model: root.hasError ? [] : root.profiles
            delegate: Rectangle {
                required property var modelData
                readonly property bool isActive: root.activeProfile === modelData.id
                Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 8
                color: isActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                    : (pMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                border.color: isActive ? root.colorAccent : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    Text {
                        text: modelData.icon
                        color: isActive ? root.colorAccent : root.colorText
                        font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: modelData.label
                        color: isActive ? root.colorAccent : root.colorText
                        font.pixelSize: 10; Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.tdp + " TDP"
                        color: root.colorTextDim; font.pixelSize: 8
                    }
                    Text {
                        visible: isActive
                        text: "\uf00c"; color: root.colorAccent
                        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                    }
                }
                MouseArea { id: pMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setProfile(modelData.id) }
            }
        }
    }
}
