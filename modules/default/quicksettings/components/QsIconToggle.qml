import QtQuick
import QtQuick.Layouts

// ── QsIconToggle ──────────────────────────────────────────────────────────
// Botão circular com ícone + label embaixo, pro grid do dashboard compacto
// (WiFi / Bluetooth / Ethernet / Avião / DND / Idle / Shader / Perfil /
// Temp-Gamma). Clique esquerdo = `clicked()` (abre menu/subpágina, ou liga/
// desliga direto pros toggles simples). Clique direito = `rightClicked()`,
// ação rápida de "ligar/desligar o padrão" sem precisar abrir nada — quem
// usa decide o que isso significa em cada tile.
//
// `sub` é opcional: uma segunda linha bem pequena embaixo do label, pra
// mostrar informação de estado (rede conectada, perfil ativo, shader ativo,
// "4500K · 80%" etc.) sem precisar abrir nada.
Item {
    id: root

    property string icon:    ""
    property string label:   ""
    property string sub:     ""    // "" = não mostra a segunda linha
    property bool   active:  false
    property bool   enabled: true   // false → visualmente "disponível mas sem ação" (ex.: sem serviço)

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    signal clicked()
    signal rightClicked()

    implicitWidth:  64
    implicitHeight: root.sub !== "" ? 78 : 64

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Rectangle {
            id: badge
            Layout.alignment: Qt.AlignHCenter
            width: 44; height: 44; radius: 22

            color: root.active
                ? root.colorAccent
                : Qt.rgba(1, 1, 1, root.enabled ? 0.08 : 0.04)
            opacity: root.enabled ? 1.0 : 0.45
            Behavior on color { ColorAnimation { duration: 150 } }

            scale: ma.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.pixelSize: 15
                font.family: "JetBrainsMono Nerd Font"
                color: root.active ? "#1a1a1a" : root.colorText
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) root.rightClicked()
                    else root.clicked()
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.label
            color: root.active ? root.colorAccent : root.colorTextDim
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: root.sub !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.sub
            color: root.colorTextDim
            font.pixelSize: 7
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
