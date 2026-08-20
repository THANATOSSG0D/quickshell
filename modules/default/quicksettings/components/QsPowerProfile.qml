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
//
// O perfil "auto" é diferente dos outros: em vez de thermal-profile (fixo),
// liga o serviço auto-cpufreq.service, que ajusta o governor/EPP sozinho
// conforme a carga. Como power-profiles-daemon.service e cpupower.service
// também mexem em governor/EPP, os três brigando ao mesmo tempo dá estado
// inconsistente — então:
//   entrar em "auto"    = stop power-profiles-daemon + cpupower, start auto-cpufreq
//   sair de "auto" pra um perfil fixo = stop auto-cpufreq, start power-profiles-
//   daemon + cpupower, só depois aplica o thermal-profile
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property string activeProfile: ""   // auto | performance | gaming | balanced | balanced_cool | cool
    property bool   loading:       false
    property bool   hasError:      false
    property bool applying: false   // junto das outras properties no topo

    readonly property var profiles: [
        { id: "auto",           icon: "\uf021", label: "Automático",     tdp: "auto-cpufreq" },
        { id: "performance",    icon: "\uf06d", label: "Performance",    tdp: "45/65W" },
        { id: "gaming",         icon: "\uf11b", label: "Gaming",         tdp: "42/60W" },
        { id: "balanced",       icon: "\uf24e", label: "Balanced",       tdp: "28/45W" },
        { id: "balanced_cool",  icon: "\uf2c9", label: "Balanced Cool",  tdp: "20/30W" },
        { id: "cool",           icon: "\uf2c7", label: "Cool",           tdp: "15/25W" }
    ]

    // Fonte única de verdade pro nome do perfil atual — quem precisa mostrar
    // isso fora daqui (ex.: atalho no Dashboard) lê daqui, em vez de ter seu
    // próprio processo lendo `thermal-profile waybar` por conta própria.
    // Ter duas leituras independentes foi o que causava o atalho e a lista
    // mostrarem nomes diferentes/desatualizados entre si.
    readonly property string currentLabel: {
        if (root.loading) return "Carregando…"
        if (root.hasError) return "Indisponível"
        for (var i = 0; i < root.profiles.length; i++) {
            if (root.profiles[i].id === root.activeProfile) return root.profiles[i].label
        }
        return root.activeProfile || "—"
    }

    function refresh() {
        if (statusProc.running) return
        root.loading = true; root.hasError = false
        statusProc.command = ["bash", "-c",
            "systemctl is-active auto-cpufreq.service 2>/dev/null; echo '---'; thermal-profile waybar 2>/dev/null"]
        statusProc.running = true
    }

    function setProfile(id) {
        if (id === root.activeProfile) return
        if (applyProc.running) return   // ← NOVO: ignora cliques enquanto uma troca já está em voo

        var previousProfile = root.activeProfile
        applyProc._pendingId = id
        applyProc._previousProfile = previousProfile

        var cmd
        if (id === "auto") {
            cmd = "sudo -n systemctl stop power-profiles-daemon.service cpupower.service 2>&1; " +
                  "sudo -n systemctl start auto-cpufreq.service 2>&1; echo EXIT:$?"
        } else if (previousProfile === "auto") {
            cmd = "sudo -n systemctl stop auto-cpufreq.service 2>&1; " +
                  "sudo -n systemctl start power-profiles-daemon.service cpupower.service 2>&1; " +
                  "sudo -n thermal-profile \"" + id + "\" 2>&1; echo EXIT:$?"
        } else {
            cmd = "sudo -n thermal-profile \"" + id + "\" 2>&1; echo EXIT:$?"
        }
        applyProc.command = ["bash", "-c", cmd]
        applyProc.running = true
        root.activeProfile = id   // otimista — corrigido em onExited se falhar
        root.applying = true      // ← NOVO: flag pra UI (ver abaixo)
    }

    Process {
        id: applyProc
        property string _pendingId: ""
        property string _previousProfile: ""
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => applyProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var out = applyProc._buf; applyProc._buf = ""
            var m = out.match(/EXIT:(\d+)/)
            var ok = m && m[1] === "0"
            root.applying = false
            if (!ok) {
                root.activeProfile = applyProc._previousProfile
                root.hasError = true
                console.warn("thermal-profile falhou ao trocar para '" + applyProc._pendingId + "':\n" + out)
            }
            // NOVO: refresh só depois que o comando REALMENTE terminou,
            // não mais um timer de 800ms adivinhando o tempo
            refreshDelay.restart()
        }
    }

    // Delay pequeno só pra dar tempo do daemon/systemd assentar o estado
    // no sysfs/STATE_FILE após o processo já ter retornado — não é mais
    // o mecanismo principal de sincronização, é só uma margem de segurança
    Timer { id: refreshDelay; interval: 300; onTriggered: root.refresh() }

    Process {
        id: statusProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => statusProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var parts = statusProc._buf.split("---")
            statusProc._buf = ""
            root.loading = false

            var autoActive = parts.length > 0 && parts[0].trim() === "active"
            if (autoActive) {
                root.activeProfile = "auto"
                root.hasError = false
                return
            }

            var out = (parts[1] || "").trim()
            if (out === "") { root.hasError = true; return }
            try {
                var data = JSON.parse(out)
                root.activeProfile = (data.class || "").replace("-", "_")
            } catch (e) {
                root.hasError = true
            }
        }
    }

    Component.onCompleted: refresh()

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 6

        QsSkeleton {
            visible: root.loading
            active:  root.loading
            baseColor: root.colorTextDim
            Layout.preferredWidth: 110
            Layout.preferredHeight: 8
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
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                color: isActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                    : (pMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                border.color: isActive ? root.colorAccent : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                scale: pMA.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10; spacing: 8

                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24; radius: 12
                        color: isActive ? root.colorAccent : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: isActive ? "#1a1a1a" : root.colorText
                            font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
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
                    enabled: !root.applying
                    cursorShape: root.applying ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.setProfile(modelData.id) }
            }
        }
    }
}
