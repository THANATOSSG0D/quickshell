import QtQuick

// ── QsSwitch ──────────────────────────────────────────────────────────────────
// Switch on/off genérico, usado dentro das páginas de detalhe (Wi-Fi,
// Bluetooth, etc.) para o toggle real — diferente do tile da home, que só
// navega e não liga/desliga nada diretamente.
//
// USO:
//   QsSwitch { checked: root.wifiEnabled; colorAccent: ...; onToggled: ... }
Item {
    id: root

    property bool  checked:     false
    property color colorAccent: "#ffb4a9"

    signal toggled()

    implicitWidth:  36
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.colorAccent : Qt.rgba(1, 1, 1, 0.18)
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: parent.height - 4; height: parent.height - 4; radius: width / 2
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.toggled()
        }
    }
}
