import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// ── QsAudioDevices ────────────────────────────────────────────────────────────
// Mostra e permite trocar o dispositivo de saída (sink) e entrada (source)
// padrão via Pipewire. Lista apenas dispositivos reais (isStream === false),
// não streams de aplicativos.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }

    readonly property var outputDevices: {
        var all = Pipewire.nodes.values
        var result = []
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isStream || !n.isSink || !n.audio) continue
            result.push(n)
        }
        return result
    }
    readonly property var inputDevices: {
        var all = Pipewire.nodes.values
        var result = []
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isStream || n.isSink || !n.audio) continue
            result.push(n)
        }
        return result
    }

    function _label(node) {
        if (!node) return ""
        return node.description || node.nickname || node.name || ""
    }

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        // ── Saída ────────────────────────────────────────────────────────────
        Text { text: "DISPOSITIVO DE SAÍDA"; color: root.colorTextDim
            font.pixelSize: 9; font.weight: Font.Medium }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(40, outCol.implicitHeight + 16)
            radius: 8; color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

            Column {
                id: outCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 3

                Repeater {
                    model: root.outputDevices.length > 0 ? root.outputDevices : [null]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isActive: modelData !== null &&
                            Pipewire.defaultAudioSink && modelData.id === Pipewire.defaultAudioSink.id
                        width: parent.width; height: 30; radius: 5
                        color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                            : (outMA.containsMouse && modelData !== null ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        scale: (modelData !== null && outMA.pressed) ? 0.985 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6
                            Text {
                                text: isActive ? "\uf111" : "\uf10c"
                                color: isActive ? root.colorAccent : root.colorTextDim
                                font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
                            Text {
                                Layout.fillWidth: true
                                text: modelData === null ? "(nenhum dispositivo encontrado)" : root._label(modelData)
                                color: modelData === null ? root.colorTextDim : root.colorText
                                font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        MouseArea { id: outMA; anchors.fill: parent; hoverEnabled: true
                            enabled: modelData !== null; cursorShape: Qt.PointingHandCursor
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData }
                    }
                }
            }
        }

        // ── Entrada ──────────────────────────────────────────────────────────
        Text { text: "DISPOSITIVO DE ENTRADA"; color: root.colorTextDim
            font.pixelSize: 9; font.weight: Font.Medium }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(40, inCol.implicitHeight + 16)
            radius: 8; color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

            Column {
                id: inCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 3

                Repeater {
                    model: root.inputDevices.length > 0 ? root.inputDevices : [null]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isActive: modelData !== null &&
                            Pipewire.defaultAudioSource && modelData.id === Pipewire.defaultAudioSource.id
                        width: parent.width; height: 30; radius: 5
                        color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                            : (inMA.containsMouse && modelData !== null ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        scale: (modelData !== null && inMA.pressed) ? 0.985 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6
                            Text {
                                text: isActive ? "\uf111" : "\uf10c"
                                color: isActive ? root.colorAccent : root.colorTextDim
                                font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
                            Text {
                                Layout.fillWidth: true
                                text: modelData === null ? "(nenhum dispositivo encontrado)" : root._label(modelData)
                                color: modelData === null ? root.colorTextDim : root.colorText
                                font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        MouseArea { id: inMA; anchors.fill: parent; hoverEnabled: true
                            enabled: modelData !== null; cursorShape: Qt.PointingHandCursor
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData }
                    }
                }
            }
        }
    }
}
