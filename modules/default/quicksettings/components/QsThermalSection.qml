import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Seção de perfil térmico ──────────────────────────────────────────────────
// Mostra o perfil atual em um botão; ao clicar abre dropdown com os outros.
// thermal-profile deve estar no sudoers com NOPASSWD:
//   %wheel ALL=(ALL) NOPASSWD: /usr/local/bin/thermal-profile
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property bool  panelOpen:    false

    onPanelOpenChanged: {
        if (panelOpen && !stateProc.running) stateProc.running = true
        if (!panelOpen) dropdownOpen = false
    }

    property bool dropdownOpen: false

    height: col.implicitHeight

    // ── Processos ─────────────────────────────────────────────────────────
    Process {
        id: stateProc
        command: [ "bash", "-c", "cat /tmp/cpu_profile_state 2>/dev/null || echo balanced" ]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s !== "") root.currentProfile = s
            }
        }
    }

    Process {
        id: applyProc
        onRunningChanged: {
            if (!running) Qt.callLater(function() {
                if (!stateProc.running) stateProc.running = true
            })
        }
    }

    Component.onCompleted: stateProc.running = true

    // ── Estado ────────────────────────────────────────────────────────────
    property string currentProfile: "balanced"

    readonly property var profiles: [
        { id: "performance",   label: "Performance",   icon: "\uf0e7" },
        { id: "gaming",        label: "Gaming",        icon: "\uf11b" },
        { id: "balanced",      label: "Balanced",      icon: "\uf06c" },
        { id: "balanced_cool", label: "Balanced Cool", icon: "\uf72e" },
        { id: "cool",          label: "Cool / Silent", icon: "\uf2dc" }
    ]

    readonly property var activeProfileObj: {
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].id === currentProfile) return profiles[i]
        }
        return profiles[2]
    }

    readonly property var otherProfiles: {
        var arr = []
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].id !== currentProfile) arr.push(profiles[i])
        }
        return arr
    }

    function applyProfile(profileId) {
        if (applyProc.running) return
        root.dropdownOpen = false
        root.currentProfile = profileId
        applyProc.command = [ "bash", "-c",
            "thermal-profile \"" + profileId + "\" 2>/dev/null || " +
            "sudo -n thermal-profile \"" + profileId + "\" 2>/dev/null" ]
        applyProc.running = true
    }

    // ── Layout principal ──────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 4

        // ── Label de seção + spinner ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.bottomMargin: 2
            Text {
                text: "Perfil Térmico"; color: root.colorTextDim
                font.pixelSize: 9; font.capitalization: Font.AllUppercase
                Layout.fillWidth: true
            }
            Rectangle {
                visible: applyProc.running
                width: 8; height: 8; radius: 4; color: root.colorAccent
                opacity: pulseTimer.on ? 1.0 : 0.3
                Timer {
                    id: pulseTimer; property bool on: true
                    interval: 350; repeat: true
                    running: applyProc.running
                    onTriggered: on = !on
                }
            }
        }

        // ── Botão do perfil ativo ──────────────────────────────────────
        Rectangle {
            id: activeBtn
            Layout.fillWidth: true; height: 36; radius: 8
            color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
            border.color: root.colorAccent; border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: root.colorAccent
                }
                Text {
                    text: root.activeProfileObj.icon
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: root.colorAccent
                }
                Text {
                    text: root.activeProfileObj.label
                    font.pixelSize: 10; color: root.colorAccent
                    Layout.fillWidth: true
                }
                Text {
                    text: root.dropdownOpen ? "\uf077" : "\uf078"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                    color: root.colorAccent; opacity: 0.7
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !applyProc.running
                onClicked: root.dropdownOpen = !root.dropdownOpen
            }
        }

        // ── Dropdown com os outros perfis ─────────────────────────────
        // Layout.preferredHeight controla o espaço no ColumnLayout.
        // Vai a 0 quando fechado — sem espaço residual.
        Rectangle {
            id: dropWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: root.dropdownOpen ? dropdownCol.implicitHeight : 0
            clip: true
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.25)

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: dropdownCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 3

                Repeater {
                    model: root.otherProfiles
                    delegate: Rectangle {
                        id: dBtn
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true; height: 32; radius: 8
                        color: dHover.containsMouse
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.10)
                            : Qt.rgba(1, 1, 1, 0.05)
                        border.color: dHover.containsMouse
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4)
                            : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        opacity: root.dropdownOpen ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8

                            Item { width: 7; height: 7 }

                            Text {
                                text: dBtn.modelData.icon
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                color: dHover.containsMouse ? root.colorAccent : root.colorText
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Text {
                                text: dBtn.modelData.label; font.pixelSize: 10
                                color: dHover.containsMouse ? root.colorAccent : root.colorText
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: dHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !applyProc.running
                            onClicked: root.applyProfile(dBtn.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
