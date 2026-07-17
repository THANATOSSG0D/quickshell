import QtQuick
import QtQuick.Layouts

// ── Tile de toggle genérico (WiFi, Bluetooth, Caffeine, etc.) ───────────────
// Dois alvos de clique, sem gestos escondidos:
//   • Switch (canto superior direito) → liga/desliga na hora, sem navegar.
//   • Resto do card                   → abre a subpágina de detalhe, se houver.
// Se o tile não tem subpágina (ex.: Caffeine), o card inteiro alterna direto
// e o switch não é exibido — não faz sentido duplicar o alvo.
//
// Expõe: icon, label, badge, active, showSwitch,
//        onClicked() (card), onSwitchToggled() (switch), onRightClicked() (legado)
Item {
    id: root

    // ── Props de conteúdo ──────────────────────────────────────────────────
    property string icon:       ""
    property string label:      ""
    property string badge:      ""   // texto pequeno abaixo do label (ex.: SSID)
    property bool   active:     false
    // true → mostra switch dedicado no canto e um chevron sutil (tile navega
    //        para uma subpágina de detalhe além de poder ligar/desligar).
    // false → card inteiro é o alvo de clique único (ex.: Caffeine).
    property bool   showSwitch: false

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorMuted:   "#cf6679"

    signal clicked()         // card (fora do switch) — navega ou alterna, conforme showSwitch
    signal switchToggled()   // switch — sempre liga/desliga na hora
    signal rightClicked()    // mantido por compatibilidade; não é mais o único caminho

    implicitHeight: 56

    // ── Visual ─────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 12

        color: root.active
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
            : Qt.rgba(1, 1, 1, 0.07)

        border.color: root.active ? root.colorAccent
                    : (root.showSwitch ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.25) : "transparent")
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Leve "encolhida" no press do card — mesmo feedback tátil do switch.
        scale: cardMa.pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 10
            spacing: 3

            RowLayout {
                Layout.fillWidth: true; spacing: 6

                Text {
                    text:            root.icon
                    color:           root.active ? root.colorAccent : root.colorText
                    font.pixelSize:  13
                    font.family:     "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    text:           root.label
                    color:          root.active ? root.colorAccent : root.colorText
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // ── Switch dedicado — só quando o tile também navega ────────────
                QsSwitch {
                    visible:     root.showSwitch
                    compact:     true
                    checked:     root.active
                    colorAccent: root.colorAccent
                    onToggled:   root.switchToggled()
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 4

                Text {
                    visible:        root.badge !== ""
                    text:           root.badge
                    color:          root.active ? root.colorAccent : root.colorTextDim
                    font.pixelSize: 8
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }

                // Chevron sutil — só indica "tem mais aqui dentro" quando há subpágina.
                Text {
                    visible:        root.showSwitch
                    text:           "\uf105"   // nf-fa-chevron_right
                    color:          root.colorTextDim
                    opacity:        0.5
                    font.pixelSize: 8
                    font.family:    "JetBrainsMono Nerd Font"
                }
            }

            Item { Layout.fillHeight: true }
        }

        MouseArea {
            id: cardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    root.rightClicked()
                else
                    root.clicked()
            }
        }
    }
}
