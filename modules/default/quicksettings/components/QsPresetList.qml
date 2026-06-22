import QtQuick

// ── QsPresetList ──────────────────────────────────────────────────────────────
// Lista de presets do EasyEffects (saída ou entrada). Extraído do component
// PresetList interno do BarTabVolume.qml, para ser reaproveitado fora do
// painel de configuração (ex.: aba Mídia do QuickSettings).
Rectangle {
    id: root

    required property var    profiles
    required property string activeProfile
    required property color  colorAccent
    required property color  colorTextDim
    required property color  colorText

    signal selected(string name)

    implicitHeight: Math.max(40, pCol.implicitHeight + 16)
    radius: 8; color: Qt.rgba(1, 1, 1, 0.03)
    border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

    Column {
        id: pCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 3

        Repeater {
            model: root.profiles.length > 0 ? root.profiles : ["(nenhum preset encontrado)"]
            delegate: Rectangle {
                required property string modelData
                required property int    index
                readonly property bool isActive:      root.activeProfile === modelData
                readonly property bool isPlaceholder: root.profiles.length === 0
                width: parent.width; height: 30; radius: 5
                color: isActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                    : (pH.containsMouse && !isPlaceholder ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.color: isActive
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4)
                    : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }
                Row {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter
                        text: isActive ? "\uf111" : "\uf10c"
                        color: isActive ? root.colorAccent : root.colorTextDim
                        font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData
                        color: isPlaceholder ? root.colorTextDim : root.colorText
                        font.pixelSize: 10; elide: Text.ElideRight }
                }
                MouseArea { id: pH; anchors.fill: parent; hoverEnabled: true
                    enabled: !parent.isPlaceholder
                    onClicked: root.selected(modelData) }
            }
        }
    }
}
