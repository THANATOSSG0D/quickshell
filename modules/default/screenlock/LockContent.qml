import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../.."

// Widgets reaproveitados do sistema de desktop — importados via o symlink
// local `widgets/` (screenlock/widgets -> ../../widgets), porque o
// Quickshell recusa import por caminho relativo que saia da pasta passada
// pro `-c` (mesmo motivo do Colors.qml já ser um symlink aqui).
import "widgets/todo"
import "widgets/calendar"
import "widgets/weather"
import "widgets/cpu"
import "widgets/ram"
import "widgets/gpu"
import "widgets/network"
import "widgets/disk"
import "widgets/system"
import "widgets/process"
import "widgets/bluetooth"
import "widgets/habits"
import "widgets/mediaplayer"
import "widgets/favorites"

Item {
    id: root

    property WlSessionLock sessionLock
    property bool isPrimary: true

    // ScreenLockConfig — opcional. Sem config, cai nos defaults hardcoded de
    // sempre (mesmo padrão defensivo do PowerMenu: nunca quebra se usado sem
    // essa integração).
    property var config: null

    function _g(key, def) { return root.config ? root.config.get(key, def) : def }
    function _c(key, fallback) { return root.config ? root.config.getColor(key) : fallback }

    // ── Posicionamento em grid de 9 pontos — cada GRUPO usa isso pra
    // resolver x/y a partir de position+edgeMargin+offsetX/Y (idêntico ao
    // WidgetHost.qml do desktop). idx: 0-8, linha a linha, igual PositionGrid.
    readonly property var _grid9: [
        { h: Qt.AlignLeft,    v: Qt.AlignTop     },
        { h: Qt.AlignHCenter, v: Qt.AlignTop     },
        { h: Qt.AlignRight,   v: Qt.AlignTop     },
        { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
        { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
        { h: Qt.AlignRight,   v: Qt.AlignVCenter },
        { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
        { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
        { h: Qt.AlignRight,   v: Qt.AlignBottom  },
    ]
    function _gridX(idx, margin, offsetX, itemW, totalW) {
        const p = root._grid9[idx] || root._grid9[4]
        let base
        if (p.h === Qt.AlignLeft)       base = margin
        else if (p.h === Qt.AlignRight) base = totalW - itemW - margin
        else                             base = (totalW - itemW) / 2
        return base + offsetX
    }
    function _gridY(idx, margin, offsetY, itemH, totalH) {
        const p = root._grid9[idx] || root._grid9[4]
        let base
        if (p.v === Qt.AlignTop)         base = margin
        else if (p.v === Qt.AlignBottom) base = totalH - itemH - margin
        else                              base = (totalH - itemH) / 2
        return base + offsetY
    }

    // ── Signals ───────────────────────────────────────────────────────────────
    signal unlockRequested()
    signal userActivity()        // qualquer input — shell.qml usa para acordar DPMS
    signal displayOffRequested() // botão "Apagar tela" — shell.qml gerencia estado
    signal shakeRequested()      // pede pro capsule (dentro do authComp) balançar

    property bool authFailed:  false
    property bool authRunning: false
    property int  failCount:   0
    property bool capsLock:    false

    readonly property string password: isPrimary ? hiddenInput.text : ""

    property string timeString: Qt.formatTime(new Date(), "HH:mm")
    property string dateString: Qt.formatDate(new Date(), "dddd, d 'de' MMMM")

    // ── Botões de energia — vindos do config (label/ícone/ação/confirmação
    // editáveis pela aba Screenlock do ConfigWindow), só os visíveis. ──────────
    readonly property string _powerScriptFallback: Quickshell.env("HOME") + "/.config/hypr/scripts/power.sh"

    readonly property var _buttons: (root.config ? root.config.getButtons() : [
        { id: "dpms",     icon: "󰹑", label: "Apagar tela", action: "__displayOff",                              confirm: false, visible: true },
        { id: "suspend",  icon: "󰒲", label: "Suspender",   action: root._powerScriptFallback + " suspend",  confirm: false, visible: true },
        { id: "reboot",   icon: "󰑓", label: "Reiniciar",   action: root._powerScriptFallback + " reboot",   confirm: true,  visible: true },
        { id: "shutdown", icon: "󰐥", label: "Desligar",    action: root._powerScriptFallback + " shutdown", confirm: true,  visible: true },
      ]).filter(function(b) { return b.visible !== false })

    // Botão aguardando um segundo clique de confirmação (ações destrutivas).
    property string _pendingBtnId: ""

    Timer {
        id: pendingBtnTimer
        interval: root._g("confirmTimeoutMs", 4000)
        onTriggered: root._pendingBtnId = ""
    }

    function requestButtonAction(btn) {
        root.userActivity()
        if (btn.confirm === true && root._pendingBtnId !== btn.id) {
            root._pendingBtnId = btn.id
            pendingBtnTimer.restart()
            return
        }
        root._pendingBtnId = ""

        if (btn.action === "__displayOff") {
            root.displayOffRequested()
        } else {
            execProc.command = ["bash", "-c", btn.action]
            execProc.running = true
        }
    }

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
        id: pamWatchdog; interval: root._g("pamWatchdogMs", 8000)
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
        if (root._g("shakeOnFail", true)) root.shakeRequested()
        failTimer.restart()
        Qt.callLater(() => hiddenInput.forceActiveFocus())
    }

    Timer { id: failTimer; interval: 1400; onTriggered: root.authFailed = false }

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
                root._pendingBtnId = ""
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

    // ── Processo genérico dos botões de energia ───────────────────────────────
    Process { id: execProc; running: false }

    // ═════════════════════════════════════════════════════════════════════════
    // COMPONENTES — clock/auth/buttons entram no mesmo mapeamento id→Component
    // que os widgets, então podem ser membros de QUALQUER grupo junto deles.
    // ═════════════════════════════════════════════════════════════════════════

    // "clock" — relógio + divisor + data. Sem posição/fundo própria — quem
    // controla isso agora é o GRUPO em que ele estiver.
    Component {
        id: clockComp
        Column {
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeString
                font.family: "Fira Sans"; font.pixelSize: root._g("clockPixelSize", 96); font.weight: Font.Light
                font.letterSpacing: -2; color: root._c("colorClockText", Colors.on_surface)
                renderType: Text.NativeRendering
            }
            Item { width: 1; height: 12 }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 80; height: 1; color: root._c("colorAccent", Colors.primary); opacity: 0.4
            }
            Item { width: 1; height: 14 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateString
                font.family: "Fira Sans"; font.pixelSize: root._g("datePixelSize", 16); font.weight: Font.Light
                font.letterSpacing: 2.5; color: root._c("colorDateText", Colors.on_surface_variant)
                renderType: Text.NativeRendering
            }
        }
    }

    // "auth" — badge de caps lock + cápsula de senha + texto de erro/usuário.
    Component {
        id: authComp
        Column {
            visible: root.isPrimary
            spacing: 0

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width:   capsLockBadge.implicitWidth
                height:  root.capsLock ? 34 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: capsLockBadge
                    anchors.centerIn: parent
                    width: capsLockRow.implicitWidth + 24; height: 28; radius: 14
                    color: Qt.rgba(root._c("colorError", Colors.error).r, root._c("colorError", Colors.error).g, root._c("colorError", Colors.error).b, 0.12)
                    border.color: root._c("colorError", Colors.error); border.width: 1
                    Row {
                        id: capsLockRow
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter
                               text: "⇪"; font.pixelSize: 13; color: root._c("colorError", Colors.error) }
                        Text { anchors.verticalCenter: parent.verticalCenter
                               text: "CAPS LOCK"; font.family: "Fira Sans"; font.pixelSize: 11
                               font.letterSpacing: 1.8; font.weight: Font.Medium; color: root._c("colorError", Colors.error) }
                    }
                }
            }

            Item { width: 1; height: 12 }

            Item {
                id: capsule
                anchors.horizontalCenter: parent.horizontalCenter
                width: root._g("capsuleWidth", 320); height: root._g("capsuleHeight", 56)
                property real baseX: 0
                Component.onCompleted: baseX = x

                // shakeRequested vem do root (authFailure()) — não dá pra usar
                // "target: capsule" de fora do Component, então a animação
                // mora aqui dentro e escuta o signal.
                Connections {
                    target: root
                    function onShakeRequested() { shakeAnim.start() }
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

                Rectangle {
                    anchors.fill: parent; radius: parent.height / 2
                    readonly property color _bg: root._c("colorCapsuleBg", Colors.surface_container)
                    color: Qt.rgba(_bg.r, _bg.g, _bg.b, 0.35)
                }
                Rectangle {
                    anchors.fill: parent; radius: parent.height / 2; color: "transparent"
                    border.color: root.authFailed  ? root._c("colorError", Colors.error)
                                : root.authRunning ? root._c("colorRunning", Colors.tertiary)
                                : root.password.length > 0 ? root._c("colorAccent", Colors.primary)
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
                    color: root.authFailed  ? root._c("colorError", Colors.error)
                         : root.authRunning ? root._c("colorRunning", Colors.tertiary)
                         : root.password.length > 0 ? root._c("colorAccent", Colors.primary)
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
                            color: root.authFailed ? root._c("colorError", Colors.error) : root._c("colorAccent", Colors.primary)
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
                    color: root._c("colorAccent", Colors.primary); opacity: 0.7
                }
            }

            Item { width: 1; height: 14 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.authFailed
                text: (root._g("showFailCount", true) && root.failCount > 2)
                    ? "Senha incorreta (" + root.failCount + " tentativas)"
                    : "Senha incorreta"
                font.family: "Fira Sans"; font.pixelSize: 13
                font.letterSpacing: 1.5; color: root._c("colorError", Colors.error); opacity: 0.88
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.authFailed && root.password.length === 0 && root._g("showUsername", true)
                text: Quickshell.env("USER")
                font.family: "Fira Sans"; font.pixelSize: 13
                font.letterSpacing: 1.5; color: Colors.outline
            }
        }
    }

    // "buttons" — fileira de botões de energia com divisores.
    Component {
        id: buttonsComp
        Row {
            visible: root.isPrimary
            spacing: root._g("buttonSpacing", 10)

            Repeater {
                model: root._buttons

                Row {
                    required property var modelData
                    required property int index
                    spacing: root._g("buttonSpacing", 10)

                    LockPowerButton {
                        icon:       modelData.icon
                        label:      modelData.label
                        size:       root._g("buttonSize", 44)
                        iconColor:  modelData.id === "shutdown"
                                      ? Qt.rgba(root._c("colorError", Colors.error).r, root._c("colorError", Colors.error).g, root._c("colorError", Colors.error).b, 0.8)
                                      : Colors.on_surface_variant
                        bgColor:    root._c("colorButtonBg", Colors.surface_container_high)
                        errorColor: root._c("colorError", Colors.error)
                        pending:    root._pendingBtnId === modelData.id
                        onClicked:  root.requestButtonAction(modelData)
                    }

                    Rectangle {
                        visible: index < root._buttons.length - 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: 24; color: Colors.outline_variant; opacity: 0.5
                    }
                }
            }
        }
    }

    // ── Widgets reaproveitados do sistema de desktop ────────────────────────
    Component { id: todoComp;        TodoContent        { grouped: true } }
    Component { id: calendarComp;    CalendarContent    { grouped: true } }
    Component { id: weatherComp;     WeatherContent     { grouped: true } }
    Component { id: cpuComp;         CpuContent         { grouped: true } }
    Component { id: ramComp;         RamContent         { grouped: true } }
    Component { id: gpuComp;         GpuContent         { grouped: true } }
    Component { id: networkComp;     NetworkContent     { grouped: true } }
    Component { id: diskComp;        DiskContent        { grouped: true } }
    Component { id: systemComp;      SystemContent      { grouped: true } }
    Component { id: processComp;     ProcessContent     { grouped: true } }
    Component { id: bluetoothComp;   BluetoothContent   { grouped: true } }
    Component { id: habitsComp;      HabitsContent      { grouped: true } }
    Component { id: mediaPlayerComp; MediaPlayerContent { grouped: true } }
    Component { id: favoritesComp;   FavoritesContent   { grouped: true } }

    function componentFor(id) {
        switch (id) {
            case "clock":       return clockComp
            case "auth":        return authComp
            case "buttons":     return buttonsComp
            case "todo":        return todoComp
            case "calendar":    return calendarComp
            case "weather":     return weatherComp
            case "cpu":         return cpuComp
            case "ram":         return ramComp
            case "gpu":         return gpuComp
            case "network":     return networkComp
            case "disk":        return diskComp
            case "system":      return systemComp
            case "process":     return processComp
            case "bluetooth":   return bluetoothComp
            case "habits":      return habitsComp
            case "mediaplayer": return mediaPlayerComp
            case "favorites":   return favoritesComp
        }
        return null
    }

    // Grupos configurados, na ordem de criação — vazio (config null) cai
    // num fallback mínimo que reproduz o visual de sempre.
    readonly property var _groups: root.config ? root.config.getGroups() : [
        { id: "fallback-main", position: 4, edgeMargin: 48, offsetX: 0, offsetY: -20,
          columns: 1, memberColumns: {}, members: ["clock", "auth"],
          bgEnabled: false, bgColor: "surface_container", bgOpacity: 0.55,
          borderColor: "outline_variant", borderOpacity: 0.4, borderWidth: 1, radius: 16,
          columnSpacing: 20, itemSpacing: 26, padding: 20 },
        { id: "fallback-buttons", position: 7, edgeMargin: 40, offsetX: 0, offsetY: 0,
          columns: 1, memberColumns: {}, members: ["buttons"],
          bgEnabled: false, bgColor: "surface_container", bgOpacity: 0.45,
          borderColor: "outline_variant", borderOpacity: 0.4, borderWidth: 1, radius: 22,
          columnSpacing: 20, itemSpacing: 10, padding: 12 },
    ]

    // Quebra os members de um grupo nas colunas configuradas (mesma ideia
    // de "alvenaria"/masonry simplificada — sem span de linha inteira,
    // o lock screen normalmente não precisa disso). "auth"/"buttons" somem
    // quando isPrimary=false (telas secundárias não pedem senha).
    function _groupColumns(group) {
        const cols = Math.max(1, group.columns || 1)
        const result = Array.from({ length: cols }, () => [])
        const members = (group.members || []).filter(id =>
            root.isPrimary || (id !== "auth" && id !== "buttons"))
        for (const id of members) {
            let c = (group.memberColumns && group.memberColumns[id]) || 1
            if (c < 1) c = 1
            if (c > cols) c = cols
            result[c - 1].push(id)
        }
        return result
    }

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
        source: root._g("useSystemWallpaper", true)
            ? ("file://" + Quickshell.env("HOME") + "/.config/ml4w/cache/lockscreen/lock.png")
            : ("file://" + root._g("customWallpaperPath", ""))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root._g("useSystemWallpaper", true) || root._g("customWallpaperPath", "") !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: root._g("scrimOpacity", 0.55)
    }

    // ── Grupos — cada um é um card independente, posicionado por grid de 9
    // pontos + margem + offset, com N colunas em masonry. Mesmo mecanismo
    // pros 3 elementos "especiais" (clock/auth/buttons) e pros widgets do
    // desktop — dá pra misturar todos no mesmo grupo, ou espalhar em vários. ──
    Repeater {
        model: root._groups
        delegate: Item {
            id: groupItem
            required property var modelData
            readonly property var group: modelData
            readonly property var _cols: root._groupColumns(group)

            width:  card.width
            height: card.height
            x: root._gridX(group.position ?? 4, group.edgeMargin ?? 48, group.offsetX ?? 0, width, parent.width)
            y: root._gridY(group.position ?? 4, group.edgeMargin ?? 48, group.offsetY ?? 0, height, parent.height)

            Rectangle {
                id: card
                width:  layout.implicitWidth  + (group.bgEnabled ? (group.padding ?? 20) * 2 : 0)
                height: layout.implicitHeight + (group.bgEnabled ? (group.padding ?? 20) * 2 : 0)
                radius: group.radius ?? 14
                visible: group.bgEnabled === true
                readonly property color _bg: root.config ? root.config.resolve(group.bgColor || "surface_container") : Colors.surface_container
                readonly property color _bd: root.config ? root.config.resolve(group.borderColor || "outline_variant") : Colors.outline_variant
                color: Qt.rgba(_bg.r, _bg.g, _bg.b, group.bgOpacity ?? 0.55)
                border.width: group.borderWidth ?? 1
                border.color: Qt.rgba(_bd.r, _bd.g, _bd.b, group.borderOpacity ?? 0.4)
            }

            RowLayout {
                id: layout
                anchors.centerIn: card
                spacing: group.columnSpacing ?? 20

                Repeater {
                    model: groupItem._cols
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: group.itemSpacing ?? 20

                        Repeater {
                            model: modelData
                            delegate: Loader {
                                required property string modelData
                                Layout.alignment: Qt.AlignHCenter
                                sourceComponent: root.componentFor(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

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
        duration: root._g("fadeInMs", 500); easing.type: Easing.OutCubic
    }

}
