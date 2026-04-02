import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsNightMode ──────────────────────────────────────────────────────────────
// Coloque em: components/QsNightMode.qml

Item {
    id: root

    property bool  panelOpen:       false
    property color colorAccent:     "#ffb4a9"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"
    property color colorPanelBg:    "#1f1f1f"

    implicitHeight: col.implicitHeight

    // ─────────────────────────────────────────────────────────────────────────
    // Estado — escrito apenas por onRead/onExited, nunca bindado a proc.stdout
    // ─────────────────────────────────────────────────────────────────────────

    property string shaderCurrent:    ""
    property bool   shaderAutoActive: false
    property bool   shaderDaemonOn:   false   // qualquer serviço do shader ativo
    property var    shaderList:       []
    property var    _shaderBuf:       []

    property bool   tempAutoActive:   false
    property bool   tempDaemonOn:     false   // hyprsunset-daemon.service ativo
    property int    tempFromLog:      0
    property string tempPhase:        ""
    property int    tempFromFile:     0

    property int    tempSlider:       4500
    property bool   _userControl:     false

    property bool   shaderDropOpen:   false

    // ─────────────────────────────────────────────────────────────────────────
    // Processo de status único — checa tudo num único bash para evitar
    // condição de corrida entre múltiplos processos paralelos
    // Formato de saída (uma linha cada):
    //   SHADER_CURRENT:<valor ou vazio>
    //   SHADER_TIMER:<active|inactive>
    //   SHADER_DAEMON:<active|inactive>
    //   TEMP_TIMER:<active|inactive>
    //   TEMP_DAEMON:<active|inactive>
    // ─────────────────────────────────────────────────────────────────────────

    Process {
        id: procStatus
        command: ["bash", "-c", [
            "echo \"SHADER_CURRENT:$(hyprshade current 2>/dev/null)\"",
            "echo \"SHADER_TIMER:$(systemctl --user is-active hyprshade.timer 2>/dev/null)\"",
            "echo \"SHADER_DAEMON:$(systemctl --user is-active hyprshader-updater.timer 2>/dev/null)\"",
            "echo \"TEMP_TIMER:$(systemctl --user is-active hyprsunset.timer 2>/dev/null)\"",
            "echo \"TEMP_DAEMON:$(systemctl --user is-active hyprsunset-daemon.service 2>/dev/null)\""
        ].join(" ; ")]
        stdout: SplitParser {
            onRead: line => {
                var sep = line.indexOf(":")
                if (sep < 0) return
                var key = line.substring(0, sep)
                var val = line.substring(sep + 1).trim()
                switch (key) {
                    case "SHADER_CURRENT":
                        root.shaderCurrent    = val; break
                    case "SHADER_TIMER":
                        root.shaderAutoActive = val === "active"; break
                    case "SHADER_DAEMON":
                        root.shaderDaemonOn   = val === "active"; break
                    case "TEMP_TIMER":
                        root.tempAutoActive   = val === "active"
                        if (val === "active") root._userControl = false
                        break
                    case "TEMP_DAEMON":
                        root.tempDaemonOn     = val === "active"; break
                }
            }
        }
    }

    // Shader ligado = há shader aplicado OU algum serviço rodando
    readonly property bool shaderOn: shaderCurrent.length > 0
                                  || shaderAutoActive
                                  || shaderDaemonOn

    // ─────────────────────────────────────────────────────────────────────────
    // Lista de shaders
    // ─────────────────────────────────────────────────────────────────────────

    Process {
        id: procShaderList
        command: ["bash", "-c",
            "hyprshade ls 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$'"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (t.length > 0 && !root._shaderBuf.includes(t))
                    root._shaderBuf = root._shaderBuf.concat([t])
            }
        }
        onExited: { root.shaderList = root._shaderBuf.slice(); root._shaderBuf = [] }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Log de temperatura
    // ─────────────────────────────────────────────────────────────────────────

    Process {
        id: procTempLog
        command: ["bash", "-c",
            "source ~/.config/hypr/noturne.config 2>/dev/null" +
            " && grep '| phase=' \"$HYPRSUNSET_LOG\" 2>/dev/null | tail -1"]
        property string _line: ""
        stdout: SplitParser { onRead: line => { procTempLog._line = line.trim() } }
        onExited: {
            var line = _line; _line = ""
            if (line.length === 0) return
            var mt = line.match(/\btemp=(\d+)K\b/)
            var mp = line.match(/\bphase=(\w+)\b/)
            if (mt) root.tempFromLog = parseInt(mt[1])
            if (mp) root.tempPhase   = mp[1]
            if (root.tempAutoActive && !root._userControl && root.tempFromLog > 0)
                root.tempSlider = root.tempFromLog
        }
    }

    Process {
        id: procTempManualFile
        command: ["bash", "-c", "cat /tmp/hyprnight-manual-temp 2>/dev/null"]
        property string _val: ""
        stdout: SplitParser { onRead: line => { procTempManualFile._val = line.trim() } }
        onExited: {
            var v = parseInt(_val); _val = ""
            if (!isNaN(v) && v > 0) {
                root.tempFromFile = v
                if (!root.tempAutoActive && !root._userControl)
                    root.tempSlider = v
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Processos de ação
    // ─────────────────────────────────────────────────────────────────────────

    // Shader: aplica manualmente e salva em ml4w/settings
    Process {
        id: procShaderApply
        onExited: { Qt.callLater(() => { if (!procStatus.running) procStatus.running = true }) }
    }

    // Delay para checar shader após serviço aplicar
    Timer {
        id: shaderRefreshTimer; interval: 1800; repeat: false
        onTriggered: { if (!procStatus.running) procStatus.running = true }
    }

    Process {
        id: procShaderEnableAuto
        command: ["bash", "-c",
            "systemctl --user start hyprshade.timer hyprshader-updater.timer hyprshade.service 2>/dev/null"]
        onExited: shaderRefreshTimer.restart()
    }

    Process {
        id: procShaderDisableAuto
        command: ["bash", "-c",
            "systemctl --user stop hyprshade.timer hyprshader-updater.timer hyprshade.service 2>/dev/null"]
        onExited: { if (!procStatus.running) procStatus.running = true }
    }

    // Toggle power do shader
    Process {
        id: procShaderToggle
        onExited: { if (!procStatus.running) procStatus.running = true }
    }

    function toggleShader() {
        if (root.shaderOn) {
            procShaderToggle.command = ["bash", "-c",
                "systemctl --user stop hyprshade.timer hyprshader-updater.timer hyprshade.service 2>/dev/null" +
                " ; hyprshade off 2>/dev/null" +
                " && echo 'hyprshade_filter=\"off\"' > ~/.config/ml4w/settings/hyprshade.sh"]
            if (!procShaderToggle.running) procShaderToggle.running = true
        } else {
            procShaderToggle.command = ["bash", "-c",
                "f=~/.config/ml4w/settings/hyprshade.sh" +
                " ; [ -f \"$f\" ] && source \"$f\" || hyprshade_filter=blue-light-filter" +
                " ; [ \"$hyprshade_filter\" = off ] && hyprshade_filter=blue-light-filter" +
                " ; hyprshade on \"$hyprshade_filter\" 2>/dev/null"]
            if (!procShaderToggle.running) procShaderToggle.running = true
        }
    }

    // Shader: seleciona manualmente
    function applyShader(name) {
        shaderDropOpen = false
        var save  = "echo 'hyprshade_filter=\"" + name + "\"' > ~/.config/ml4w/settings/hyprshade.sh"
        var apply = name === "off" ? "hyprshade off" : "hyprshade on \"" + name + "\""
        procShaderApply.command = ["bash", "-c", save + " && " + apply + " 2>/dev/null"]
        if (!procShaderApply.running) procShaderApply.running = true
    }

    // Temperatura: liga/desliga auto
    Process {
        id: procTempEnableAuto
        command: ["bash", "-c",
            "systemctl --user start hyprsunset-daemon.service 2>/dev/null" +
            " && sleep 0.4" +
            " && systemctl --user start hyprsunset.timer hyprsunset.service 2>/dev/null"]
        onExited: {
            if (!procStatus.running) procStatus.running = true
            if (!procTempLog.running) procTempLog.running = true
        }
    }

    Process {
        id: procTempDisableAuto
        command: ["bash", "-c",
            "systemctl --user stop hyprsunset.timer hyprsunset.service 2>/dev/null"]
        onExited: { if (!procStatus.running) procStatus.running = true }
    }

    // Toggle power da temperatura
    Process {
        id: procTempToggle
        onExited: {
            if (!procStatus.running) procStatus.running = true
            if (!procTempManualFile.running) procTempManualFile.running = true
        }
    }

    function toggleTemp() {
        if (root.tempDaemonOn) {
            procTempToggle.command = ["bash", "-c",
                "systemctl --user stop hyprsunset.timer hyprsunset.service hyprsunset-daemon.service 2>/dev/null" +
                " ; rm -f /tmp/hyprnight-manual-temp"]
            root.tempAutoActive = false
            root._userControl   = false
            root.tempSlider     = 6500
        } else {
            var lastTemp = root.tempFromFile > 0 ? root.tempFromFile
                         : root.tempFromLog  > 0 ? root.tempFromLog
                         : 4500
            procTempToggle.command = ["bash", "-c",
                "systemctl --user start hyprsunset-daemon.service 2>/dev/null" +
                " && sleep 0.3" +
                " && hyprctl hyprsunset temperature " + lastTemp + " 2>/dev/null" +
                " && echo " + lastTemp + " > /tmp/hyprnight-manual-temp"]
            root.tempSlider   = lastTemp
            root._userControl = true
        }
        if (!procTempToggle.running) procTempToggle.running = true
    }

    // Temperatura: aplica valor manual
    Process {
        id: procTempApply
        onExited: { if (!procTempManualFile.running) procTempManualFile.running = true }
    }

    function applyManualTemp(temp) {
        procTempApply.command = ["bash", "-c",
            "systemctl --user start hyprsunset-daemon.service 2>/dev/null" +
            " ; hyprctl hyprsunset temperature " + temp + " 2>/dev/null" +
            " && echo " + temp + " > /tmp/hyprnight-manual-temp"]
        if (!procTempApply.running) procTempApply.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers visuais
    // ─────────────────────────────────────────────────────────────────────────

    function tempPct(t) {
        if (t <= 0) return 0
        return Math.max(0, Math.min(1, (t - tempMin) / (tempMax - tempMin)))
    }
    function phaseColor(p) {
        if (p === "sunrise") return "#ff8a65"
        if (p === "day")     return "#ffd54f"
        if (p === "sunset")  return "#ff7043"
        if (p === "night")   return "#7986cb"
        return root.colorTextDim
    }

    readonly property int tempMin: 1000
    readonly property int tempMax: 6500

    // ─────────────────────────────────────────────────────────────────────────
    // Inicialização e polling
    // ─────────────────────────────────────────────────────────────────────────

    function refreshAll() {
        if (!procStatus.running)         procStatus.running         = true
        if (!procShaderList.running)     procShaderList.running     = true
        if (!procTempLog.running)        procTempLog.running        = true
        if (!procTempManualFile.running) procTempManualFile.running = true
    }

    Component.onCompleted: refreshAll()
    onPanelOpenChanged:    if (panelOpen) refreshAll()

    // Poll status e temp a cada 8s
    Timer { interval: 8000; running: true; repeat: true
        onTriggered: {
            if (!procStatus.running) procStatus.running = true
            if (!procTempLog.running) procTempLog.running = true
        }
    }

    // Sincroniza slider com log quando auto ativo
    onTempFromLogChanged: {
        if (tempAutoActive && !_userControl && tempFromLog > 0)
            tempSlider = tempFromLog
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 10

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║  SHADER                                                          ║
        // ╚══════════════════════════════════════════════════════════════════╝

        RowLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
                text: "\uf0eb"
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                color: root.shaderOn ? root.colorAccent : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text { text: "Shader"; color: root.colorText; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }

            // AUTO
            AutoPill {
                active: root.shaderAutoActive
                accentColor: root.colorAccent
                onClicked: root.shaderAutoActive
                    ? (procShaderDisableAuto.running ? null : (procShaderDisableAuto.running = true))
                    : (procShaderEnableAuto.running  ? null : (procShaderEnableAuto.running  = true))
            }

            // POWER toggle
            PowerButton {
                active: root.shaderOn
                onClicked: root.toggleShader()
            }
        }

        // Selector dropdown
        Item {
            Layout.fillWidth: true; implicitHeight: 28

            Rectangle {
                anchors.fill: parent; radius: 6
                color: selectorMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.07)
                border {
                    color: root.shaderDropOpen
                        ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.5)
                        : Qt.rgba(1,1,1,0.12)
                    width: 1
                }
                Behavior on color        { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text {
                        text: root.shaderCurrent.length > 0 ? root.shaderCurrent : "off"
                        color: root.shaderCurrent.length > 0 ? root.colorAccent : root.colorTextDim
                        font.pixelSize: 11
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: "\uf078"
                        font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                        color: root.colorTextDim
                        rotation: root.shaderDropOpen ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
            MouseArea {
                id: selectorMA; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.shaderDropOpen = !root.shaderDropOpen
                    if (root.shaderDropOpen && !procShaderList.running)
                        procShaderList.running = true
                }
            }
        }

        // Dropdown animado
        Item {
            Layout.fillWidth: true
            implicitHeight: dropH
            clip: true
            visible: dropH > 0

            property real dropH: 0
            readonly property real targetH: root.shaderDropOpen
                ? Math.min(dropContent.implicitHeight, 150) : 0
            Behavior on dropH { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            onTargetHChanged: dropH = targetH

            Rectangle {
                width: parent.width
                height: Math.min(dropContent.implicitHeight, 150)
                radius: 6
                color:  Qt.rgba(root.colorPanelBg.r, root.colorPanelBg.g, root.colorPanelBg.b, 0.97)
                border { color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25); width: 1 }
                clip: true

                Flickable {
                    anchors.fill: parent; clip: true
                    contentHeight: dropContent.implicitHeight
                    boundsMovement: Flickable.StopAtBounds

                    ColumnLayout {
                        id: dropContent; width: parent.width; spacing: 0

                        DropItem {
                            Layout.fillWidth: true; label: "off"
                            active: root.shaderCurrent === ""
                            accentColor: root.colorAccent; textColor: root.colorText; dimColor: root.colorTextDim
                            onPicked: root.applyShader("off")
                        }
                        Repeater {
                            model: root.shaderList
                            DropItem {
                                required property string modelData
                                Layout.fillWidth: true; label: modelData
                                active: root.shaderCurrent === modelData
                                accentColor: root.colorAccent; textColor: root.colorText; dimColor: root.colorTextDim
                                onPicked: root.applyShader(modelData)
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║  TEMPERATURA                                                     ║
        // ╚══════════════════════════════════════════════════════════════════╝

        RowLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
                text: "\uf2c9"
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                color: root.tempDaemonOn
                    ? (root.tempAutoActive ? root.phaseColor(root.tempPhase) : root.colorAccent)
                    : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            Text { text: "Temperatura"; color: root.colorText; font.pixelSize: 11 }

            Text {
                text: root.tempSlider + " K"
                color: root.colorAccent; font.pixelSize: 11; font.weight: Font.Light
            }

            Text {
                visible: root.tempAutoActive && root.tempPhase.length > 0
                text: "· " + root.tempPhase
                color: root.phaseColor(root.tempPhase); font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Item { Layout.fillWidth: true }

            // AUTO
            AutoPill {
                active: root.tempAutoActive
                accentColor: "#ff7043"
                onClicked: root.tempAutoActive
                    ? (procTempDisableAuto.running ? null : (procTempDisableAuto.running = true))
                    : (procTempEnableAuto.running  ? null : (procTempEnableAuto.running  = true))
            }

            // POWER toggle
            PowerButton {
                active: root.tempDaemonOn
                onClicked: root.toggleTemp()
            }
        }

        // Slider único
        Item {
            Layout.fillWidth: true; implicitHeight: 24

            Rectangle {
                id: tempTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: Qt.rgba(0.47, 0.52, 0.80, 0.22) }
                    GradientStop { position: 0.35; color: Qt.rgba(0.88, 0.49, 0.25, 0.22) }
                    GradientStop { position: 1.0;  color: Qt.rgba(1.0,  0.84, 0.31, 0.22) }
                }
            }

            Rectangle {
                anchors.verticalCenter: tempTrack.verticalCenter
                width: Math.max(tempThumb.width / 2,
                    root.tempPct(root.tempSlider) * tempTrack.width)
                height: tempTrack.height; radius: tempTrack.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "#7986cb" }
                    GradientStop { position: 0.35; color: "#e07c3f" }
                    GradientStop { position: 1.0;  color: "#ffd54f" }
                }
                Behavior on width { NumberAnimation { duration: sliderMA.pressed ? 0 : 500; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                id: tempThumb
                x: root.tempPct(root.tempSlider) * (tempTrack.width - width)
                anchors.verticalCenter: tempTrack.verticalCenter
                width: 14; height: 14; radius: 7
                color: "white"
                border { color: Qt.rgba(1,1,1,0.3); width: 1 }
                scale: sliderMA.pressed ? 1.2 : 1.0
                Behavior on x     { NumberAnimation { duration: sliderMA.pressed ? 0 : 500; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                id: sliderMA
                anchors { fill: tempTrack; margins: -10 }
                preventStealing: true
                cursorShape: Qt.SizeHorCursor
                onPressed:         m => _drag(m.x)
                onPositionChanged: m => _drag(m.x)
                onReleased: m => {
                    _drag(m.x)
                    root._userControl = true
                    if (root.tempAutoActive && !procTempDisableAuto.running)
                        procTempDisableAuto.running = true
                    root.applyManualTemp(root.tempSlider)
                }
                function _drag(mx) {
                    var r = Math.max(0, Math.min(1, mx / tempTrack.width))
                    root.tempSlider = Math.round(
                        (root.tempMin + r * (root.tempMax - root.tempMin)) / 100) * 100
                }
            }

            Text {
                anchors { left: tempTrack.left; top: tempTrack.bottom; topMargin: 4 }
                text: root.tempMin + " K"; font.pixelSize: 8
                color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.4)
            }
            Text {
                anchors { right: tempTrack.right; top: tempTrack.bottom; topMargin: 4 }
                text: root.tempMax + " K"; font.pixelSize: 8
                color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.4)
            }
        }

        Item { Layout.fillWidth: true; implicitHeight: 10 }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Componentes inline
    // ─────────────────────────────────────────────────────────────────────────

    component AutoPill: Item {
        id: pill
        required property bool  active
        required property color accentColor
        signal clicked()
        implicitWidth: pillTxt.implicitWidth + 14; implicitHeight: 18

        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: pill.active
                ? Qt.rgba(pill.accentColor.r, pill.accentColor.g, pill.accentColor.b, 0.22)
                : (pillMA.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07))
            border {
                color: pill.active
                    ? Qt.rgba(pill.accentColor.r, pill.accentColor.g, pill.accentColor.b, 0.6)
                    : Qt.rgba(1,1,1,0.15)
                width: 1
            }
            Behavior on color        { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }
        Text {
            id: pillTxt
            anchors.centerIn: parent
            text: "AUTO"
            font { pixelSize: 9; weight: Font.Medium; family: "JetBrainsMono Nerd Font" }
            color: pill.active
                ? pill.accentColor
                : Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.5)
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        MouseArea {
            id: pillMA; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component PowerButton: Item {
        id: pwrBtn
        required property bool active   // true = ligado (vermelho), false = desligado (cinza)
        signal clicked()
        implicitWidth: 18; implicitHeight: 18

        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: pwrBtn.active
                ? (pwrMA.containsMouse ? Qt.rgba(0.94, 0.32, 0.31, 0.35) : Qt.rgba(0.94, 0.32, 0.31, 0.18))
                : (pwrMA.containsMouse ? Qt.rgba(1,1,1,0.14)              : Qt.rgba(1,1,1,0.07))
            border {
                color: pwrBtn.active
                    ? Qt.rgba(0.94, 0.32, 0.31, 0.60)
                    : Qt.rgba(1,1,1,0.18)
                width: 1
            }
            Behavior on color        { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }
        Text {
            anchors.centerIn: parent
            text: "\uf011"
            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
            color: pwrBtn.active
                ? (pwrMA.containsMouse ? "#ef5350" : Qt.rgba(0.94, 0.32, 0.31, 0.85))
                : Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.40)
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        MouseArea {
            id: pwrMA; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: pwrBtn.clicked()
        }
    }

    component DropItem: Item {
        id: di
        required property string label
        required property bool   active
        required property color  accentColor
        required property color  textColor
        required property color  dimColor
        signal picked()
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            color: di.active
                ? Qt.rgba(di.accentColor.r, di.accentColor.g, di.accentColor.b, 0.12)
                : (diMA.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
            Behavior on color { ColorAnimation { duration: 80 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: di.active ? di.accentColor : "transparent"
                    border { color: di.active ? di.accentColor : Qt.rgba(1,1,1,0.2); width: 1 }
                }
                Text {
                    text: di.label; font.pixelSize: 11
                    color: di.active ? di.accentColor : di.textColor
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    visible: di.active; text: "\uf00c"
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    color: di.accentColor
                }
            }
        }
        MouseArea {
            id: diMA; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: di.picked()
        }
    }
}
