import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "." as QsComp

Item {
    id: root

    property color  colorAccent:  "#ffb4a9"
    property color  colorText:    "#e2e2e2"
    property color  colorTextDim: "#c6c6c6"
    property bool   panelOpen:    false

    onPanelOpenChanged: {
        if (panelOpen && !stateProc.running) stateProc.running = true
    }

    implicitHeight: col.implicitHeight

    Process {
        id: stateProc
        command: ["bash", "-c", "cat /tmp/cpu_profile_state 2>/dev/null || echo balanced"]
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
            if (!running) Qt.callLater(() => { if (!stateProc.running) stateProc.running = true })
        }
    }

    Component.onCompleted: stateProc.running = true

    property string currentProfile: "balanced"

    readonly property var profiles: [
        { id: "performance",   label: "Performance",   icon: "\uf0e7" },
        { id: "gaming",        label: "Gaming",        icon: "\uf11b" },
        { id: "balanced",      label: "Balanced",      icon: "\uf06c" },
        { id: "balanced_cool", label: "Balanced Cool", icon: "\uf72e" },
        { id: "cool",          label: "Cool / Silent", icon: "\uf2dc" }
    ]

    readonly property int currentIndex: {
        for (var i = 0; i < profiles.length; i++)
            if (profiles[i].id === currentProfile) return i
        return 2
    }

    function applyProfile(index) {
        if (applyProc.running) return
        var pid = profiles[index].id
        root.currentProfile = pid
        applyProc.command = ["bash", "-c",
            "thermal-profile \"" + pid + "\" 2>/dev/null || " +
            "sudo -n thermal-profile \"" + pid + "\" 2>/dev/null"]
        applyProc.running = true
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 4

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
                opacity: pulse.on ? 1.0 : 0.3
                Timer {
                    id: pulse; property bool on: true
                    interval: 350; repeat: true; running: applyProc.running
                    onTriggered: on = !on
                }
            }
        }

        QsInlineDropdown {
            id: profileDropdown
            Layout.fillWidth: true

            model:        root.profiles
            labelRole:    "label"
            iconRole:     "icon"
            currentIndex: root.currentIndex

            colorAccent:  root.colorAccent
            colorText:    root.colorText
            colorTextDim: root.colorTextDim
            colorBgItem:  Qt.rgba(1, 1, 1, 0.04)
            colorBgHover: Qt.rgba(1, 1, 1, 0.08)
            colorBorder:  Qt.rgba(1, 1, 1, 0.10)

            enabled: !applyProc.running
            opacity: applyProc.running ? 0.5 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            onPicked: (i) => root.applyProfile(i)
        }
    }
}
