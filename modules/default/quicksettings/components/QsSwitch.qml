import QtQuick

// ── QsSwitch ──────────────────────────────────────────────────────────────────
// Switch on/off genérico, usado dentro das páginas de detalhe (Wi-Fi,
// Bluetooth, etc.) para o toggle real — diferente do tile da home, que só
// navega e não liga/desliga nada diretamente.
//
// USO:
//   QsSwitch { checked: root.wifiEnabled; colorAccent: ...; onToggled: ... }
//   QsSwitch { compact: true; checked: ...; onToggled: ... }   // versão pequena p/ tiles
Item {
    id: root

    property bool  checked:     false
    property color colorAccent: "#ffb4a9"
    // Versão reduzida — usada dentro de QsToggleTile, onde o espaço é apertado.
    property bool  compact:     false

    signal toggled()

    implicitWidth:  compact ? 26 : 36
    implicitHeight: compact ? 15 : 20

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

        // Leve "encolhida" no press — mesmo feedback tátil do resto do painel.
        scale: switchMa.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        MouseArea {
            id: switchMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // Impede que o clique "vaze" pro card por trás (ex.: QsToggleTile),
            // que abriria a subpágina ao mesmo tempo em que o switch alterna.
            onClicked: (mouse) => { root.toggled(); mouse.accepted = true }
        }
    }
}
