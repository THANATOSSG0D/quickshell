import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QuickSettings (trigger da barra) ─────────────────────────────────────────
// Ícone de hambúrguer na barra que emite panelRequested() ao clicar.
// Indicador de rede via `nmcli networking` — sem NetworkManager service.
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

    // ── Estado de rede via nmcli ───────────────────────────────────────────
    property bool hasNetwork: false

    Process {
        id: netCheckProc
        command: [ "nmcli", "networking" ]
    }

    readonly property bool netDetected: (netCheckProc.stdout || "").trim() === "enabled"
    onNetDetectedChanged: hasNetwork = netDetected

    Component.onCompleted: netCheckProc.running = true

    // Atualiza a cada 30s para manter o indicador correto
    Timer {
        interval: 30000
        repeat:   true
        running:  true
        onTriggered: netCheckProc.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // // ── Indicador de rede ──────────────────────────────────────────
        // Text {
        //     text:           "\uf1eb"
        //     color:          root.hasNetwork ? root.accentColor : root.dimColor
        //     opacity:        root.hasNetwork ? 1.0 : 0.4
        //     font.pixelSize: 12
        //     font.family:    "JetBrainsMono Nerd Font"
        //     anchors.verticalCenter: parent.verticalCenter
        //     Behavior on opacity { NumberAnimation { duration: 200 } }
        //     Behavior on color   { ColorAnimation  { duration: 200 } }
        // }
        //
        // ── Ícone principal ────────────────────────────────────────────
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
