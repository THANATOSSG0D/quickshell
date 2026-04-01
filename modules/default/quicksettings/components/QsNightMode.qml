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
    // Estado explícito — nunca bindado direto a proc.stdout
    // (SplitParser.onRead → variável local → UI vincula à variável)
    // ─────────────────────────────────────────────────────────────────────────

    // Shader
    property string shaderCurrent:    ""       // o que hyprshade current retorna agora
    property bool   shaderAutoActive: false    // hyprshade.timer está active?
    property var    shaderList:       []       // hyprshade ls

    // Temperatura
    property bool   tempAutoActive:   false    // hyprsunset.timer está active?
    property int    tempFromLog:      0        // última temp lida do log automático
    property string tempPhase:        ""       // phase= do log
    property int    tempFromFile:     0        // temp salva manualmente em /tmp

    // Slider — fonte de verdade para a UI
    property int    tempSlider:       4500
    // Flag: usuário arrastou o slider → não sobrescrever até auto reativar
    property bool   _userControl:     false

    // Dropdown do shader
    property bool   shaderDropOpen:   false

    // Buffer para acumular linhas do hyprshade ls
    property var _shaderBuf: []

    // ─────────────────────────────────────────────────────────────────────────
    // Processos de leitura — TODOS usam SplitParser para garantir reatividade
    // ─────────────────────────────────────────────────────────────────────────

    // hyprshade current — uma linha ou vazio (sem shader ativo)
    Process {
        id: procShaderCurrent
        command: ["bash", "-c", "hyprshade current 2>/dev/null; true"]
        property string _pending: ""
        stdout: SplitParser {
            onRead: line => { procShaderCurrent._pending = line.trim() }
        }
        onExited: {
            root.shaderCurrent = _pending   // "" se vazio = sem shader
            _pending = ""
        }
    }

    // hyprshade ls — acumula linhas, publica em onExited
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
        onExited: {
            root.shaderList = root._shaderBuf.slice()
            root._shaderBuf = []
        }
    }

    // systemctl --user is-active hyprshade.timer
    Process {
        id: procShaderAutoCheck
        command: ["bash", "-c", "systemctl --user is-active hyprshade.timer 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => { root.shaderAutoActive = line.trim() === "active" }
        }
    }

    // Log do hyprsunset.sh — última linha de sumário
    // Formato: "YYYY-MM-DD HH:MM:SS | phase=X | ... | temp=XXXK | gamma=Y"
    Process {
        id: procTempLog
        command: ["bash", "-c",
            "source ~/.config/hypr/noturne.config 2>/dev/null" +
            " && grep '| phase=' \"$HYPRSUNSET_LOG\" 2>/dev/null | tail -1"]
        property string _line: ""
        stdout: SplitParser {
            onRead: line => { procTempLog._line = line.trim() }
        }
        onExited: {
            var line = _line; _line = ""
            if (line.length === 0) return
            var mt = line.match(/\btemp=(\d+)K\b/)
            var mp = line.match(/\bphase=(\w+)\b/)
            if (mt) root.tempFromLog = parseInt(mt[1])
            if (mp) root.tempPhase   = mp[1]
            // Sincroniza slider com valor do log SÓ se auto ativo e usuário não arrastou
            if (root.tempAutoActive && !root._userControl && root.tempFromLog > 0)
                root.tempSlider = root.tempFromLog
        }
    }

    // /tmp/hyprnight-manual-temp — temp definida manualmente
    Process {
        id: procTempManualFile
        command: ["bash", "-c", "cat /tmp/hyprnight-manual-temp 2>/dev/null"]
        property string _pending: ""
        stdout: SplitParser {
            onRead: line => { procTempManualFile._pending = line.trim() }
        }
        onExited: {
            var v = parseInt(_pending); _pending = ""
            if (!isNaN(v) && v > 0) {
                root.tempFromFile = v
                // Atualiza slider só se em controle manual pelo usuário
                // (não sobrescreve se o auto acabou de ser desligado e slider já tem valor)
                if (!root.tempAutoActive && root._userControl)
                    root.tempSlider = v
            }
        }
    }

    // systemctl --user is-active hyprsunset.timer
    Process {
        id: procTempAutoCheck
        command: ["bash", "-c", "systemctl --user is-active hyprsunset.timer 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                var wasAuto = root.tempAutoActive
                root.tempAutoActive = line.trim() === "active"
                // Ao reativar auto: libera controle do usuário e sincroniza slider
                if (!wasAuto && root.tempAutoActive) {
                    root._userControl = false
                    if (root.tempFromLog > 0) root.tempSlider = root.tempFromLog
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Processos de ação
    // ─────────────────────────────────────────────────────────────────────────

    Process {
        id: procShaderApply
        onExited: {
            // Pequeno delay para o hyprshade aplicar antes de checar
            Qt.callLater(() => _run(procShaderCurrent))
        }
    }

    // Bug 3 fix: timer de delay para checar shader depois que o serviço aplicou
    Timer {
        id: shaderAutoRefreshTimer
        interval: 1800; repeat: false
        onTriggered: _run(procShaderCurrent)
    }

    Process {
        id: procShaderEnableAuto
        command: ["bash", "-c",
            "systemctl --user start hyprshade.timer hyprshader-updater.timer hyprshade.service 2>/dev/null"]
        onExited: {
            _run(procShaderAutoCheck)
            shaderAutoRefreshTimer.restart()  // aguarda hyprshade aplicar o shader
        }
    }

    Process {
        id: procShaderDisableAuto
        command: ["bash", "-c",
            "systemctl --user stop hyprshade.timer hyprshader-updater.timer hyprshade.service 2>/dev/null"]
        onExited: { _run(procShaderAutoCheck); _run(procShaderCurrent) }
    }

    Process {
        id: procTempEnableAuto
        command: ["bash", "-c",
            "systemctl --user start hyprsunset-daemon.service 2>/dev/null" +
            " && sleep 0.4" +
            " && systemctl --user start hyprsunset.timer hyprsunset.service 2>/dev/null"]
        onExited: { _run(procTempAutoCheck); _run(procTempLog) }
    }

    Process {
        id: procTempDisableAuto
        command: ["bash", "-c",
            "systemctl --user stop hyprsunset.timer hyprsunset.service 2>/dev/null"]
        onExited: { _run(procTempAutoCheck) }
    }

    // Aplica temperatura via hyprctl e salva em /tmp para leitura futura
    Process {
        id: procTempApply
        onExited: { _run(procTempManualFile) }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Funções
    // ─────────────────────────────────────────────────────────────────────────

    function _run(proc) { if (!proc.running) proc.running = true }

    function applyShader(name) {
        shaderDropOpen = false
        var save  = "echo 'hyprshade_filter=\"" + name + "\"' > ~/.config/ml4w/settings/hyprshade.sh"
        var apply = name === "off" ? "hyprshade off" : "hyprshade on \"" + name + "\""
        procShaderApply.command = ["bash", "-c", save + " && " + apply + " 2>/dev/null"]
        _run(procShaderApply)
    }

    // Aplica temperatura manualmente e persiste em /tmp
    function applyManualTemp(temp) {
        procTempApply.command = ["bash", "-c",
            "systemctl --user start hyprsunset-daemon.service 2>/dev/null" +
            " ; hyprctl hyprsunset temperature " + temp + " 2>/dev/null" +
            " && echo " + temp + " > /tmp/hyprnight-manual-temp"]
        _run(procTempApply)
    }

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
        _run(procShaderCurrent); _run(procShaderAutoCheck); _run(procShaderList)
        _run(procTempAutoCheck); _run(procTempLog); _run(procTempManualFile)
    }

    Component.onCompleted: refreshAll()
    onPanelOpenChanged:    if (panelOpen) refreshAll()

    // Poll shader atual e log de temp
    Timer { interval: 10000; running: true; repeat: true
        onTriggered: { _run(procShaderCurrent); _run(procTempLog) } }
    // Poll estado dos serviços (menos frequente)
    Timer { interval: 30000; running: true; repeat: true
        onTriggered: { _run(procShaderAutoCheck); _run(procTempAutoCheck) } }

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
                color: root.shaderCurrent.length > 0 ? root.colorAccent : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text { text: "Shader"; color: root.colorText; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            AutoPill {
                active: root.shaderAutoActive
                accentColor: root.colorAccent
                onClicked: root.shaderAutoActive ? _run(procShaderDisableAuto) : _run(procShaderEnableAuto)
            }
        }

        // Selector — mostra shader atual, abre dropdown ao clicar
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
                    if (root.shaderDropOpen) _run(procShaderList)
                }
            }
        }

        // Dropdown — altura animada
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
                        id: dropContent
                        width: parent.width; spacing: 0

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
                color: root.tempAutoActive ? root.phaseColor(root.tempPhase) : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            Text { text: "Temperatura"; color: root.colorText; font.pixelSize: 11 }

            // Valor exibido: o do slider (que já sincroniza com o log/arquivo)
            Text {
                text: root.tempSlider + " K"
                color: root.colorAccent; font.pixelSize: 11; font.weight: Font.Light
            }

            // Fase atual (só no modo auto)
            Text {
                visible: root.tempAutoActive && root.tempPhase.length > 0
                text: "· " + root.tempPhase
                color: root.phaseColor(root.tempPhase); font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Item { Layout.fillWidth: true }

            AutoPill {
                active: root.tempAutoActive
                accentColor: "#ff7043"
                onClicked: root.tempAutoActive ? _run(procTempDisableAuto) : _run(procTempEnableAuto)
            }
        }

        // Slider único — leitura e controle
        Item {
            Layout.fillWidth: true; implicitHeight: 24

            // Track com gradiente de temperatura
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

            // Fill colorido até o thumb
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
                // Animação suave somente quando não está arrastando
                Behavior on width {
                    NumberAnimation { duration: sliderMA.pressed ? 0 : 500; easing.type: Easing.OutCubic }
                }
            }

            // Thumb
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
                    // Marca controle do usuário — impede que o log auto sobrescreva o slider
                    root._userControl = true
                    // Se auto estava ativo, para o timer (mantém daemon rodando)
                    if (root.tempAutoActive) _run(procTempDisableAuto)
                    root.applyManualTemp(root.tempSlider)
                }

                function _drag(mx) {
                    var r = Math.max(0, Math.min(1, mx / tempTrack.width))
                    root.tempSlider = Math.round(
                        (root.tempMin + r * (root.tempMax - root.tempMin)) / 100) * 100
                }
            }

            // Labels min/max
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

        // Espaço para os labels min/max
        Item { Layout.fillWidth: true; implicitHeight: 10 }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Componentes inline
    // ─────────────────────────────────────────────────────────────────────────

    // Pílula AUTO — destaque quando ativo
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

    // Linha do dropdown de shaders
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
