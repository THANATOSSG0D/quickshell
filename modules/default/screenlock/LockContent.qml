import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Item {
    id: root

    property WlSessionLock sessionLock
    property bool isPrimary: true

    property bool authFailed:  false
    property bool authRunning: false
    property int  failCount:   0

    // Senha lida diretamente do TextInput — sem propriedade intermediária
    readonly property string password: isPrimary ? hiddenInput.text : ""

    // ── PAM ──────────────────────────────────────────────────────────────────
    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            console.log("[ScreenLock] PAM message, responseRequired:", pam.responseRequired, "pwdLen:", root.password.length)
            if (pam.responseRequired)
                pam.respond(root.password)
        }

        onCompleted: result => {
            console.log("[ScreenLock] PAM completed, result:", result, "success:", result === PamResult.Success)
            pamWatchdog.stop()
            root.authRunning = false
            if (result === PamResult.Success)
                root.authSuccess()
            else
                root.authFailure()
        }

        onError: error => {
            pamWatchdog.stop()
            console.warn("[ScreenLock] PAM error:", error)
            root.authRunning = false
            root.authFailure()
        }
    }

    Timer {
        id: pamWatchdog
        interval: 8000
        onTriggered: {
            console.warn("[ScreenLock] PAM watchdog: abortando")
            if (pam.active) pam.abort()
            root.authRunning = false
            hiddenInput.text = ""
            root.authFailed = true
            failTimer.restart()
        }
    }

    // Escreve "unlocked" direto do LockContent — evita ReferenceError
    // de referência cruzada ao chamar sessionLock.writeUnlockedState()
    Process {
        id: writeUnlockedProc
        command: ["bash", "-c",
            "echo unlocked > " + Quickshell.env("HOME") + "/.cache/quickshell-lockstate"
        ]
    }

    function submitPassword() {
        if (authRunning || password.length === 0) return
        console.log("[ScreenLock] submitPassword: len=" + password.length)
        authRunning = true
        pamWatchdog.restart()
        pam.start()
    }

    function authSuccess() {
        console.log("[ScreenLock] authSuccess — desbloqueando")
        writeUnlockedProc.running = true      // escreve state file localmente
        sessionLock.lockRequested = false     // pede unlock ao compositor
        hiddenInput.text = ""
        failCount = 0
    }

    function authFailure() {
        console.log("[ScreenLock] authFailure — tentativas:", failCount + 1)
        failCount++
        authFailed = true
        hiddenInput.text = ""
        shakeAnim.start()
        failTimer.restart()
    }

    Timer {
        id: failTimer
        interval: 1400
        onTriggered: root.authFailed = false
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX - 14; duration: 50 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX + 14; duration: 50 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX - 10; duration: 50 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX + 10; duration: 50 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX -  6; duration: 40 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX +  6; duration: 40 }
        NumberAnimation { target: capsule; property: "x"; to: capsule.baseX;      duration: 40 }
    }

    // ── Relógio ──────────────────────────────────────────────────────────────
    property string timeString: Qt.formatTime(new Date(), "HH:mm")
    property string dateString: Qt.formatDate(new Date(), "dddd, d 'de' MMMM")

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.timeString = Qt.formatTime(new Date(), "HH:mm")
            root.dateString = Qt.formatDate(new Date(), "dddd, d 'de' MMMM")
        }
    }

    // ── TextInput invisível — âncora de foco + captura de senha ──────────────
    // echoMode: NoEcho → o Qt gerencia o texto nativamente, sem loops de sinal.
    // Keys especiais (Enter/Esc) são tratados aqui mesmo.
    TextInput {
        id: hiddenInput
        // visible:false bloqueia foco no Qt — usa opacity+dimensões zero
        // para ficar tecnicamente visível mas invisível ao usuário
        opacity: 0
        width:   0
        height:  0
        enabled:  root.isPrimary
        focus:    root.isPrimary
        echoMode: TextInput.NoEcho
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submitPassword()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                hiddenInput.text = ""
                if (pam.active) pam.abort()
                pamWatchdog.stop()
                root.authRunning = false
                event.accepted = true
            }
            // Backspace e caracteres normais: o TextInput gerencia nativamente
        }

        Component.onCompleted: {
            if (root.isPrimary)
                Qt.callLater(() => forceActiveFocus())
        }
    }

    // ── Visual ───────────────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source:   "file://" + Quickshell.env("HOME") + "/.config/ml4w/cache/lockscreen/lock.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }

    Rectangle { anchors.fill: parent; color: "#000"; opacity: 0.55 }

    // (Canvas de ruído removido — rodava na main thread e congelava o relógio)

    Column {
        anchors.centerIn: parent
        spacing: 0

        // Relógio
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           root.timeString
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 120
            font.weight:    Font.Light
            color:          "#f0ebe8"
            renderType:     Text.NativeRendering
            lineHeight:     0.9
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true; blur: 0.08; blurMax: 8
                colorization: 1.0; colorizationColor: "#ffb4ac"
            }
        }

        Item { width: 1; height: 12 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80; height: 1; color: "#ffb4ac"; opacity: 0.4
        }

        Item { width: 1; height: 14 }

        // Data
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:               root.dateString
            font.family:        "Fira Sans"
            font.pixelSize:     16
            font.weight:        Font.Light
            font.letterSpacing: 2.5
            color:              "#c6c6c6"
            renderType:         Text.NativeRendering
        }

        Item { width: 1; height: 52 }

        // Cápsula de senha
        Item {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320; height: 56
            visible: root.isPrimary

            property real baseX: 0
            Component.onCompleted: baseX = x

            // Borda
            Rectangle {
                anchors.fill: parent; radius: 28; color: "transparent"
                border.color: root.authFailed  ? "#ffb4ab"
                            : root.authRunning ? "#e0c38c"
                            : root.password.length > 0 ? "#ffb4ac" : "#ffffff"
                border.width: 1
                opacity: root.authFailed  ? 1.0
                       : root.authRunning ? 0.9
                       : root.password.length > 0 ? 0.75 : 0.22
                Behavior on border.color { ColorAnimation  { duration: 200 } }
                Behavior on opacity      { NumberAnimation { duration: 200 } }
            }

            // Ícone
            Text {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.authFailed  ? "󰟐"
                    : root.authRunning ? "󱄤"
                    : "󰍁"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                color: root.authFailed  ? "#ffb4ab"
                     : root.authRunning ? "#e0c38c"
                     : root.password.length > 0 ? "#ffb4ac" : "#919191"
                Behavior on color { ColorAnimation { duration: 200 } }
                RotationAnimation on rotation {
                    running: root.authRunning
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                }
            }

            // Pontos de senha
            Row {
                anchors.centerIn: parent; spacing: 7
                Repeater {
                    model: Math.min(root.password.length, 24)
                    Rectangle {
                        width: 7; height: 7; radius: 4
                        color: root.authFailed ? "#ffb4ab" : "#ffb4ac"
                        opacity: 0.9
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: 0
                        Component.onCompleted: popIn.start()
                        NumberAnimation on scale {
                            id: popIn; from: 0; to: 1
                            duration: 120; easing.type: Easing.OutBack
                        }
                    }
                }
            }

            // Hint ↵
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: root.password.length > 0 && !root.authRunning
                text: "↵"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                color: "#ffb4ac"; opacity: 0.7
            }
        }

        Item { width: 1; height: 14; visible: root.isPrimary }

        // Erro
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.isPrimary && root.authFailed
            text: root.failCount > 2
                ? "Senha incorreta (" + root.failCount + " tentativas)"
                : "Senha incorreta"
            font.family: "Fira Sans"; font.pixelSize: 13
            font.letterSpacing: 1.5; color: "#ffb4ab"; opacity: 0.85
        }

        Item { width: 1; height: 8; visible: root.isPrimary }

        // Usuário
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.isPrimary && !root.authFailed && root.password.length === 0
            text: Quickshell.env("USER")
            font.family: "Fira Sans"; font.pixelSize: 13
            font.letterSpacing: 1.5; color: "#919191"
        }
    }

    opacity: 0
    Component.onCompleted: appearAnim.start()
    NumberAnimation on opacity {
        id: appearAnim; from: 0; to: 1
        duration: 500; easing.type: Easing.OutCubic
    }
}
