import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QuickSettings (trigger da barra) ─────────────────────────────────────────
Item {
    id: root

    property bool isHorizontal: true
    property int  barPosition:  1
    property color textColor:   "#e2e2e2"
    property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
    property color accentColor: "#ffb4a9"

    signal panelRequested()

    implicitWidth:  isHorizontal ? row.implicitWidth  + 10 : 28
    implicitHeight: isHorizontal ? row.implicitHeight + 4  : row.implicitHeight + 10

    // ── Estado de rede ─────────────────────────────────────────────────────
    // CORRIGIDO: lê stdout em onRunningChanged, não como binding reativo
    property bool hasNetwork: false

    Process {
        id: netCheckProc
        command: [ "bash", "-c", "nmcli networking 2>/dev/null" ]
        onRunningChanged: {
            if (!running)
                root.hasNetwork = (netCheckProc.stdout || "").trim() === "enabled"
        }
    }

    Component.onCompleted: netCheckProc.running = true

    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: { if (!netCheckProc.running) netCheckProc.running = true }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text:           "\uf0c9"
            color:          root.textColor
            font.pixelSize: 13
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill:    parent
        acceptedButtons: Qt.LeftButton
        onClicked:       root.panelRequested()
    }
}
