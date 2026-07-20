import QtQuick
import QtQuick.Layouts

// ── QsHabitList ────────────────────────────────────────────────────────────────
// Lista compacta de hábitos de hoje (fica empilhada com o calendário no
// Dashboard das QuickSettings, largura cheia do card — Layout.fillWidth).
//   • "check": tocar a linha alterna feito/não feito.
//   • "count": botões "–" / "+" dedicados pra registrar progresso (mesmo
//     padrão do HabitsContent.qml, o widget grande). Tocar em qualquer
//     parte "vazia" da linha (nome, espaço) também soma +1, e scroll sobre
//     a linha ajusta fino (+1 pra cima, -1 pra baixo) — atalhos extras, não
//     o único caminho, já que dependiam só de clique-na-linha/scroll antes
//     e isso não dava pra registrar progresso de forma confiável (scroll
//     podia ser engolido pelo scroll do Dashboard, e não tinha "-" visível).
// Não fala com HabitsConfig diretamente — só recebe `habits` já resolvido
// (nome, cor em hex, status do dia) e devolve as ações via sinal.
Item {
    id: root

    // [{id, name, kind: "check"|"count", amount, target, status, colorHex, statusColorHex}]
    property var habits: []
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property int   maxVisible:   3   // 0 = sem limite, mostra a lista inteira

    signal toggleCheck(string id)
    signal logCount(string id, int delta)
    signal seeAllClicked()   // "+N" clicado — quem usa decide pra onde ir (ex.: abrir Habits)

    implicitHeight: col.implicitHeight
    implicitWidth:  120
    // Não dá pra confiar só em Layout.fillWidth aqui: dependendo de como o
    // QsCollapsibleCard implementa o slot de conteúdo (Layout de verdade vs.
    // Item com anchors manuais), o attached property pode ser ignorado e o
    // componente cai de volta pro implicitWidth de 120 — daí o nome cortado
    // ("Escovar os d...") e os botões +/- espremidos lá na esquerda, com um
    // vazio enorme sobrando à direita do card. Amarrar direto no parent.width
    // funciona nos dois casos, contanto que o parent já tenha a largura certa
    // (é o caso aqui: card usa anchors com margins, não Layout.fillWidth).
    width: parent ? parent.width : implicitWidth

    readonly property var _visible: root.maxVisible > 0 ? habits.slice(0, root.maxVisible) : habits
    readonly property int  _extra:  root.maxVisible > 0 ? Math.max(0, habits.length - root.maxVisible) : 0

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 8

        Repeater {
            model: root._visible
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 18

                // Área de fundo primeiro (fica ABAIXO da RowLayout na pilha de
                // z-order — QtQuick empilha irmãos na ordem declarada, o último
                // fica por cima). Assim ela captura cliques nas partes "vazias"
                // da linha (nome, espaço, checkbox), mas as MouseAreas menores
                // dos botões +/- de count, que são netas e ficam por cima dela,
                // continuam recebendo o clique primeiro. Na ordem antiga (essa
                // MouseArea depois da RowLayout) ela cobria a linha inteira por
                // cima e os botões +/- nunca recebiam clique nenhum.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.kind === "count"
                        ? root.logCount(modelData.id, 1)
                        : root.toggleCheck(modelData.id)
                    onWheel: (wheel) => {
                        if (modelData.kind !== "count") return
                        root.logCount(modelData.id, wheel.angleDelta.y > 0 ? 1 : -1)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: modelData.colorHex
                    }
                    Text {
                        text: modelData.name
                        color: root.colorText
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // check-kind: checkbox pequeno preenchido quando feito
                    Rectangle {
                        visible: modelData.kind !== "count"
                        width: 14; height: 14; radius: 4
                        color: modelData.status === "hit" ? modelData.colorHex : "transparent"
                        border.color: modelData.colorHex; border.width: 1.2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            visible: modelData.status === "hit"
                            anchors.centerIn: parent
                            text: "\uf00c"; font.pixelSize: 7; font.family: "JetBrainsMono Nerd Font"
                            color: "#1a1a1a"
                        }
                    }
                    // count-kind: "–" / "3/8" / "+" num pill só pra ele — bem
                    // separado do resto da linha, com fundo próprio pra cada
                    // botão em vez de texto solto (mesmo padrão do
                    // HabitsContent.qml, o widget grande, adaptado pro
                    // tamanho compacto daqui).
                    RowLayout {
                        visible: modelData.kind === "count"
                        spacing: 4

                        Rectangle {
                            width: 15; height: 15; radius: 7.5
                            color: decMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\uf068"   // nf-fa-minus
                                font.pixelSize: 6; font.family: "JetBrainsMono Nerd Font"
                                color: root.colorTextDim
                            }
                            MouseArea {
                                id: decMa
                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.logCount(modelData.id, -1)
                            }
                        }
                        Text {
                            text: modelData.amount + "/" + modelData.target
                            color: modelData.statusColorHex !== "" ? modelData.statusColorHex : modelData.colorHex
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 28   // largura fixa — número não "pula" o layout ao mudar de dígito
                        }
                        Rectangle {
                            width: 15; height: 15; radius: 7.5
                            color: incMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\uf067"   // nf-fa-plus
                                font.pixelSize: 6; font.family: "JetBrainsMono Nerd Font"
                                color: root.colorTextDim
                            }
                            MouseArea {
                                id: incMa
                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.logCount(modelData.id, 1)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.habits.length === 0
            text: "Nenhum hábito"
            color: root.colorTextDim
            font.pixelSize: 9; opacity: 0.6
        }

        Text {
            visible: root._extra > 0
            text: "+ " + root._extra + " · ver todos"
            color: root.colorTextDim
            font.pixelSize: 9; opacity: 0.75
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.seeAllClicked()
            }
        }
    }
}
