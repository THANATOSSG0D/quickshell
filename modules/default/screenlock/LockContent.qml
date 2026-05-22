import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../.."

Item {
    id: root

    property WlSessionLock sessionLock
    property bool isPrimary: true

    // ── Signals ───────────────────────────────────────────────────────────────
    signal unlockRequested()
    // Emitido em qualquer input do usuário — shell.qml usa para acordar DPMS.
    signal userActivity()

    readonly property string powerScript: Quickshell.env("HOME") + "/.config/hypr/scripts/power.sh"

    property bool authFailed:  false
    property bool authRunning: false
    property int  failCount:   0
    property bool capsLock:    false

    readonly property string password: isPrimary ? hiddenInput.text : ""

    property string timeString: Qt.formatTime(new Date(), "HH:mm")
    property string dateString: Qt.formatDate(new Date(), "dddd, d 'de' MMMM")

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.timeString = Qt.formatTime(new Date(), "HH:mm")
            root.dateString = Qt.formatDate(new Date(), "dddd, d 'de' MMMM")
        }
    }

    // ── Caps Lock ─────────────────────────────────────────────────────────────
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | head -1 || echo 0"]
        stdout: SplitParser {
            onRead: line => root.capsLock = (parseInt(line.trim()) > 0)
        }
    }

    // ── PAM ───────────────────────────────────────────────────────────────────
    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.password)
        }

        onCompleted: result => {
            pamWatchdog.stop()
            root.authRunning = false
            if (result === PamResult.Success)
                root.authSuccess()
            else
                root.authFailure()
        }

        onError: error => {
            pamWatchdog.stop()
            console.warn("[LockContent] PAM error:", error)
            root.authRunning = false
            root.authFailure()
        }
    }

    Timer {
        id: pamWatchdog; interval: 8000
        onTriggered: {
            console.warn("[LockContent] PAM watchdog: abortando")
            if (pam.active) pam.abort()
            root.authRunning = false
            hiddenInput.text = ""
            root.authFailed = true
            failTimer.restart()
        }
    }

    function authSuccess() {
        hiddenInput.text = ""
        failCount = 0
        // Libera o lock diretamente — sem fade — para evitar o flash preto
        // que ocorre quando WlSessionLock exibe o fundo do compositor enquanto
        // a superfície ainda está animando para opacity 0.
        root.unlockRequested()
    }

    function submitPassword() {
        if (authRunning || password.length === 0) return
        authRunning = true
        pamWatchdog.restart()
        pam.start()
    }

    function authFailure() {
        failCount++
        authFailed = true
        hiddenInput.text = ""
        shakeAnim.start()
        failTimer.restart()
        Qt.callLater(() => hiddenInput.forceActiveFocus())
    }

    Timer { id: failTimer; interval: 1400; onTriggered: root.authFailed = false }

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

    // ── TextInput de senha ────────────────────────────────────────────────────
    TextInput {
        id: hiddenInput
        opacity: 0; width: 0; height: 0
        enabled:  root.isPrimary
        focus:    root.isPrimary
        echoMode: TextInput.NoEcho
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText

        Keys.onPressed: event => {
            // Qualquer tecla = atividade (acorda DPMS se necessário).
            root.userActivity()

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submitPassword()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                hiddenInput.text = ""
                if (pam.active) pam.abort()
                pamWatchdog.stop()
                root.authRunning = false
                event.accepted = true
            } else if (event.key === Qt.Key_CapsLock) {
                root.capsLock = !root.capsLock
                capsProc.running = true
                event.accepted = false
            }
        }

        Component.onCompleted: {
            if (root.isPrimary)
                Qt.callLater(() => forceActiveFocus())
        }
    }

    // Re-foca só quando o foco foi genuinamente perdido.
    Connections {
        target: hiddenInput
        function onActiveFocusChanged() {
            if (root.isPrimary && !root.authRunning && !hiddenInput.activeFocus)
                Qt.callLater(() => hiddenInput.forceActiveFocus())
        }
    }

    // ── MouseArea principal ───────────────────────────────────────────────────
    // Cobre todo o lock screen; captura movimento e clique para:
    //   (a) acordar o DPMS se estiver apagado
    //   (b) forçar foco no input
    MouseArea {
        anchors.fill: parent
        z: -1
        // hoverEnabled desativado intencionalmente: onPositionChanged gerava
        // eventos sintéticos quando o Hyprland mudava estado do DPMS, causando
        // o ciclo liga/apaga imediato. Agora o cooldown em shell.qml + somente
        // onPressed/Keys.onPressed são suficientes para acordar o display.
        hoverEnabled: false

        onPressed: mouse => {
            root.userActivity()
            if (root.isPrimary) hiddenInput.forceActiveFocus()
            mouse.accepted = false
        }
    }

    // ── Processos de energia ──────────────────────────────────────────────────
    Process {
        id: procDpmsOff
        command: ["hyprctl", "dispatch", "hl.dsp.dpms({mode = \"off\"})"]
    }
    Process { id: procSuspend;  command: [root.powerScript, "suspend"]  }
    Process { id: procReboot;   command: [root.powerScript, "reboot"]   }
    Process { id: procShutdown; command: [root.powerScript, "shutdown"] }

    // ═════════════════════════════════════════════════════════════════════════
    // VISUAL
    // ═════════════════════════════════════════════════════════════════════════

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        z: -1
    }

    Image {
        anchors.fill: parent
        source:   "file://" + Quickshell.env("HOME") + "/.config/ml4w/cache/lockscreen/lock.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.55
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeString
            font.family: "Fira Sans"; font.pixelSize: 96; font.weight: Font.Light
            font.letterSpacing: -2; color: Colors.on_surface
            renderType: Text.NativeRendering
        }

        Item { width: 1; height: 12 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 80; height: 1; color: Colors.primary; opacity: 0.4
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateString
            font.family: "Fira Sans"; font.pixelSize: 16; font.weight: Font.Light
            font.letterSpacing: 2.5; color: Colors.on_surface_variant
            renderType: Text.NativeRendering
        }

        Item { width: 1; height: 40 }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width:   capsLockBadge.implicitWidth
            height:  root.isPrimary && root.capsLock ? 34 : 0
            visible: root.isPrimary; clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                id: capsLockBadge
                anchors.centerIn: parent
                width: capsLockRow.implicitWidth + 24; height: 28; radius: 14
                color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.12)
                border.color: Colors.error; border.width: 1
                Row {
                    id: capsLockRow
                    anchors.centerIn: parent; spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: "⇪"; font.pixelSize: 13; color: Colors.error }
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: "CAPS LOCK"; font.family: "Fira Sans"; font.pixelSize: 11
                           font.letterSpacing: 1.8; font.weight: Font.Medium; color: Colors.error }
                }
            }
        }

        Item { width: 1; height: 12; visible: root.isPrimary }

        Item {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320; height: 56; visible: root.isPrimary
            property real baseX: 0
            Component.onCompleted: baseX = x

            Rectangle {
                anchors.fill: parent; radius: 28
                color: Qt.rgba(Colors.surface_container.r,
                               Colors.surface_container.g,
                               Colors.surface_container.b, 0.35)
            }
            Rectangle {
                anchors.fill: parent; radius: 28; color: "transparent"
                border.color: root.authFailed  ? Colors.error
                            : root.authRunning ? Colors.tertiary
                            : root.password.length > 0 ? Colors.primary
                            : Colors.on_surface
                border.width: 1
                opacity: root.authFailed  ? 1.0
                       : root.authRunning ? 0.85
                       : root.password.length > 0 ? 0.75
                       : 0.22
                Behavior on border.color { ColorAnimation  { duration: 200 } }
                Behavior on opacity      { NumberAnimation { duration: 200 } }
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.authFailed ? "󰟐" : root.authRunning ? "󱄤" : "󰍁"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                color: root.authFailed  ? Colors.error
                     : root.authRunning ? Colors.tertiary
                     : root.password.length > 0 ? Colors.primary
                     : Colors.outline
                Behavior on color { ColorAnimation { duration: 200 } }
                RotationAnimation on rotation {
                    running: root.authRunning
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                }
            }
            Row {
                anchors.centerIn: parent; spacing: 7
                Repeater {
                    model: Math.min(root.password.length, 24)
                    Rectangle {
                        width: 7; height: 7; radius: 4
                        color: root.authFailed ? Colors.error : Colors.primary
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
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: root.password.length > 0 && !root.authRunning
                text: "↵"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                color: Colors.primary; opacity: 0.7
            }
        }

        Item { width: 1; height: 14; visible: root.isPrimary }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.isPrimary && root.authFailed
            text: root.failCount > 2
                ? "Senha incorreta (" + root.failCount + " tentativas)"
                : "Senha incorreta"
            font.family: "Fira Sans"; font.pixelSize: 13
            font.letterSpacing: 1.5; color: Colors.error; opacity: 0.88
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.isPrimary && !root.authFailed && root.password.length === 0
            text: Quickshell.env("USER")
            font.family: "Fira Sans"; font.pixelSize: 13
            font.letterSpacing: 1.5; color: Colors.outline
        }
    }

    // ── Botões de energia ─────────────────────────────────────────────────────
    Row {
        visible: root.isPrimary
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        spacing: 10

        component PowerButton: Item {
            id: btn
            property string icon:      ""
            property string label:     ""
            property color  iconColor: Colors.on_surface_variant
            signal clicked()
            width: 44; height: 44

            Rectangle {
                anchors.fill: parent; radius: 22
                color: Colors.surface_container_high
                opacity: ma.containsMouse ? 0.75 : 0.32
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            Text {
                anchors.centerIn: parent
                text: btn.icon
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                color: ma.containsMouse ? Colors.on_surface : btn.iconColor
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Rectangle {
                anchors.bottom: parent.top; anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ma.containsMouse && btn.label !== ""
                width: ttText.implicitWidth + 16; height: 24; radius: 6
                color: Colors.surface_container_highest
                Text {
                    id: ttText; anchors.centerIn: parent; text: btn.label
                    font.family: "Fira Sans"; font.pixelSize: 11
                    font.letterSpacing: 1.2; color: Colors.on_surface_variant
                }
            }
            MouseArea {
                id: ma; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: btn.clicked()
            }
        }

        PowerButton { icon: "󰹑"; label: "Apagar tela"; iconColor: Colors.secondary
                      onClicked: procDpmsOff.running = true }
        Rectangle { anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 24; color: Colors.outline_variant; opacity: 0.5 }
        PowerButton { icon: "󰒲"; label: "Suspender"
                      onClicked: procSuspend.running = true }
        PowerButton { icon: "󰑓"; label: "Reiniciar"
                      onClicked: procReboot.running = true }
        PowerButton { icon: "󰐥"; label: "Desligar"
                      iconColor: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.8)
                      onClicked: procShutdown.running = true }
    }

    // ── Animações de entrada e saída ──────────────────────────────────────────
    opacity: 0
    Component.onCompleted: {
        fadeIn.start()
        if (root.isPrimary) {
            capsProc.running = true
            Qt.callLater(() => hiddenInput.forceActiveFocus())
        }
    }

    NumberAnimation on opacity {
        id: fadeIn
        from: 0; to: 1
        duration: 500; easing.type: Easing.OutCubic
    }

}
