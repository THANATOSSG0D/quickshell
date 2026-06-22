import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// ── QsEasyEffects ─────────────────────────────────────────────────────────────
// Status, bypass e presets de saída/entrada do EasyEffects — réplica da
// lógica equivalente em BarTabVolume.qml (painel de configuração), agora
// disponível na aba Mídia do QuickSettings runtime.
//
// Auto-contido: busca o estado ao carregar e expõe refresh()/applyPreset()/
// toggleBypass() para os controles internos.
Item {
    id: root

    property color colorAccent:   "#ffb4a9"
    property color colorText:     "#e2e2e2"
    property color colorTextDim:  "#c6c6c6"
    property color colorError:    "#f38ba8"

    // ── Estado ────────────────────────────────────────────────────────────
    property bool   eeRunning:        false
    property bool   eeBypassed:       false
    property string eeActiveOutput:   ""
    property string eeActiveInput:    ""
    property var    eeOutputProfiles: []
    property var    eeInputProfiles:  []

    Process {
        id: eeStatusProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => eeStatusProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var out = eeStatusProc._buf.trim(); eeStatusProc._buf = ""
            root.eeRunning = out !== "" && !out.includes("not running")
            var lines = out.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (l.startsWith("output:")) root.eeActiveOutput = l.replace("output:", "").trim()
                if (l.startsWith("input:"))  root.eeActiveInput  = l.replace("input:",  "").trim()
            }
        }
    }

    Process {
        id: eeListProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => eeListProc._buf += l + "\n" }
        onRunningChanged: {
            if (running) return
            var raw = eeListProc._buf.trim(); eeListProc._buf = ""
            var lines = raw.split("\n")
            var outputs = []; var inputs = []; var inInput = false
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i]
                if (l.includes("saída") || l.toLowerCase().includes("output")) { inInput = false; continue }
                if (l.includes("entrada") || l.toLowerCase().includes("input")) { inInput = true;  continue }
                var m = l.match(/^\s*\d+\s+(.+)$/)
                if (m) {
                    var name = m[1].trim()
                    if (inInput) inputs.push(name)
                    else         outputs.push(name)
                }
            }
            root.eeOutputProfiles = outputs
            root.eeInputProfiles  = inputs
        }
    }

    Process { id: eeApplyProc }
    Process { id: eeBypassProc }

    function refresh() {
        if (!eeStatusProc.running) { eeStatusProc.command = ["easyeffects", "-s"]; eeStatusProc.running = true }
        if (!eeListProc.running)   { eeListProc.command   = ["easyeffects", "-p"]; eeListProc.running   = true }
    }

    function applyPreset(type, name) {
        eeApplyProc.command = ["easyeffects", "-l", name]; eeApplyProc.running = true
        if (type === "output") root.eeActiveOutput = name
        else                   root.eeActiveInput  = name
    }

    function toggleBypass() {
        eeBypassProc.command = ["easyeffects", "--bypass-toggle"]; eeBypassProc.running = true
        root.eeBypassed = !root.eeBypassed
    }

    Component.onCompleted: refresh()

    // ── UI ─────────────────────────────────────────────────────────────────
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        // ── Status + bypass + refresh ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 8
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.eeRunning ? "#a6e3a1" : "#6c7086"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: root.eeRunning
                        ? (root.eeBypassed ? "EasyEffects (bypass ativo)" : "EasyEffects ativo")
                        : "EasyEffects não detectado"
                    color: root.colorTextDim; font.pixelSize: 10; Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.eeRunning
                    height: 26; width: bypassLbl.implicitWidth + 14; radius: 5
                    color: bypassHov.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: root.eeBypassed
                        ? Qt.rgba(root.colorError.r, root.colorError.g, root.colorError.b, 0.5)
                        : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        id: bypassLbl; anchors.centerIn: parent
                        text: root.eeBypassed ? "\uf074  Bypass ON" : "\uf074  Bypass OFF"
                        color: root.eeBypassed ? root.colorError : root.colorTextDim
                        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                    }
                    MouseArea { id: bypassHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBypass() }
                }

                Rectangle {
                    height: 26; width: 26; radius: 5
                    color: refreshHov.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "\uf021"
                        color: root.colorTextDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: refreshHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh() }
                }
            }
        }

        Text {
            visible: root.eeRunning
            text: "PRESET SAÍDA"; color: root.colorTextDim
            font.pixelSize: 9; font.weight: Font.Medium
        }
        QsPresetList {
            visible: root.eeRunning
            Layout.fillWidth: true
            profiles:      root.eeOutputProfiles
            activeProfile: root.eeActiveOutput
            colorAccent:   root.colorAccent
            colorTextDim:  root.colorTextDim
            colorText:     root.colorText
            onSelected: (name) => root.applyPreset("output", name)
        }

        Text {
            visible: root.eeRunning
            text: "PRESET ENTRADA"; color: root.colorTextDim
            font.pixelSize: 9; font.weight: Font.Medium
        }
        QsPresetList {
            visible: root.eeRunning
            Layout.fillWidth: true
            profiles:      root.eeInputProfiles
            activeProfile: root.eeActiveInput
            colorAccent:   root.colorAccent
            colorTextDim:  root.colorTextDim
            colorText:     root.colorText
            onSelected: (name) => root.applyPreset("input", name)
        }
    }
}
