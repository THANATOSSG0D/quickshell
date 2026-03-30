import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── Seção de perfil térmico ──────────────────────────────────────────────────
// Lê /tmp/cpu_profile_state para o perfil atual.
// Chama `thermal-profile <id>` ao selecionar.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property bool  panelOpen:    false

    onPanelOpenChanged: { if (panelOpen) thermalStatusProc.running = true }

    height: col.implicitHeight

    Process {
        id: thermalStatusProc
        command: [ "cat", "/tmp/cpu_profile_state" ]
    }
    Process { id: applyProc }

    Component.onCompleted: thermalStatusProc.running = true

    property string currentProfile: (thermalStatusProc.stdout || "").trim() || "balanced"

    // Ícones: todos dentro do BMP (4 dígitos hex) para compatibilidade total
    // \uf0e7 = fa-bolt  \uf11b = fa-gamepad  \uf06c = fa-leaf
    // \uf72e = fa-wind  \uf2dc = fa-snowflake-o
    readonly property var profiles: [
        { id: "performance",   label: "Performance",   icon: "\uf0e7" },
        { id: "gaming",        label: "Gaming",         icon: "\uf11b" },
        { id: "balanced",      label: "Balanced",       icon: "\uf06c" },
        { id: "balanced_cool", label: "Balanced Cool",  icon: "\uf72e" },
        { id: "cool",          label: "Cool / Silent",  icon: "\uf2dc" }
    ]

    ColumnLayout {
        id: col
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: 4

        Text {
            text:                "Perfil Térmico"
            color:               root.colorTextDim
            font.pixelSize:      9
            font.capitalization: Font.AllUppercase
            Layout.bottomMargin: 2
        }

        Repeater {
            model: root.profiles

            delegate: Rectangle {
                id: profileBtn
                required property var modelData
                required property int index

                readonly property bool active: root.currentProfile === profileBtn.modelData.id

                Layout.fillWidth: true
                height: 34; radius: 8
                color: profileBtn.active
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                    : Qt.rgba(1, 1, 1, 0.06)
                border.color: profileBtn.active ? root.colorAccent : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill:    parent
                    anchors.margins: 10
                    spacing: 8

                    Rectangle {
                        width: 7; height: 7; radius: 3.5
                        color:        profileBtn.active ? root.colorAccent : "transparent"
                        border.color: root.colorTextDim
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text:           profileBtn.modelData.icon
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color:          profileBtn.active ? root.colorAccent : root.colorText
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text:             profileBtn.modelData.label
                        font.pixelSize:   10
                        color:            profileBtn.active ? root.colorAccent : root.colorText
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        applyProc.command = [ "thermal-profile", profileBtn.modelData.id ]
                        applyProc.running = true
                        root.currentProfile = profileBtn.modelData.id
                    }
                }
            }
        }
    }
}
