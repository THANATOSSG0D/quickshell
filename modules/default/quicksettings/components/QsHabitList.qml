import QtQuick
import QtQuick.Layouts

// ── QsHabitList ────────────────────────────────────────────────────────────────
// Lista compacta de hábitos de hoje (pra caber lado a lado com o calendário
// no Dashboard, ~140px de largura).
//   • "check": tocar a linha alterna feito/não feito.
//   • "count": tocar soma +1; scroll sobre a linha ajusta fino (+1 pra cima,
//     -1 pra baixo) — mesmo padrão de "scroll ajusta" já usado no volume e
//     no brilho em outros lugares do painel.
// Não fala com HabitsConfig diretamente — só recebe `habits` já resolvido
// (nome, cor em hex, status do dia) e devolve as ações via sinal.
Item {
    id: root

    // [{id, name, kind: "check"|"count", amount, target, status, colorHex, statusColorHex}]
    property var habits: []
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property int   maxVisible:   3

    signal toggleCheck(string id)
    signal logCount(string id, int delta)
    signal seeAllClicked()   // "+N" clicado — quem usa decide pra onde ir (ex.: abrir Habits)

    implicitHeight: col.implicitHeight
    implicitWidth:  120

    readonly property var _visible: habits.slice(0, maxVisible)
    readonly property int  _extra:  Math.max(0, habits.length - maxVisible)

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 6

        Repeater {
            model: root._visible
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 16

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

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
                        width: 13; height: 13; radius: 4
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
                    // count-kind: "3/8"
                    Text {
                        visible: modelData.kind === "count"
                        text: modelData.amount + "/" + modelData.target
                        color: modelData.statusColorHex !== "" ? modelData.statusColorHex : modelData.colorHex
                        font.pixelSize: 9
                    }
                }

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
