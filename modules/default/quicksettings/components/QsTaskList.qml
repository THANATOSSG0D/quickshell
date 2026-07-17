import QtQuick
import QtQuick.Layouts

// ── QsTaskList ────────────────────────────────────────────────────────────────
// Lista compacta de tarefas — pensada pra "hoje + atrasadas" no Dashboard,
// mas genérica: só recebe `tasks` já filtrado/ordenado pelo chamador e
// devolve o clique no checkbox via sinal `toggle(id)`. Não fala com o
// TodoConfig diretamente — quem instancia decide a fonte dos dados.
Item {
    id: root

    property var tasks: []   // [{id, text, priority, overdue}]
    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property var priorityColor: ({ alta: "#e5484d", media: "#f5a524", baixa: "#45a249" })
    property int  maxVisible: 4   // além disso, só o contador "+N" aparece
    property string emptyText: "Nenhuma tarefa por hoje"

    signal toggle(string id)
    signal seeAllClicked()   // "+N" clicado — quem usa decide pra onde ir (ex.: abrir Todo)

    implicitHeight: col.implicitHeight
    implicitWidth:  200

    readonly property var _visible: tasks.slice(0, maxVisible)
    readonly property int  _extra:  Math.max(0, tasks.length - maxVisible)

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 5

        Repeater {
            model: root._visible
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true; spacing: 8

                Rectangle {
                    width: 15; height: 15; radius: 4.5
                    color: modelData.done
                        ? (root.priorityColor[modelData.priority] || root.colorAccent)
                        : "transparent"
                    border.color: root.priorityColor[modelData.priority] || root.colorTextDim
                    border.width: 1.4
                    scale: checkMa.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        visible: modelData.done
                        anchors.centerIn: parent
                        text: "\uf00c"   // nf-fa-check
                        font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font"
                        color: "#1a1a1a"
                    }

                    MouseArea {
                        id: checkMa
                        anchors.fill: parent; anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(modelData.id)
                    }
                }

                Text {
                    text: modelData.text
                    color: modelData.done ? root.colorTextDim : root.colorText
                    font.pixelSize: 10
                    font.strikeout: modelData.done === true
                    opacity: modelData.done ? 0.6 : 1.0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: modelData.overdue
                    text: "atrasada"
                    color: "#e5484d"
                    font.pixelSize: 8
                    opacity: 0.85
                }
            }
        }

        Text {
            visible: root.tasks.length === 0
            text: root.emptyText
            color: root.colorTextDim
            font.pixelSize: 9
            opacity: 0.6
        }

        Text {
            visible: root._extra > 0
            text: "+ " + root._extra + " tarefa" + (root._extra > 1 ? "s" : "") + " · ver todas"
            color: root.colorAccent
            font.pixelSize: 9
            opacity: 0.85
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.seeAllClicked()
            }
        }
    }
}
