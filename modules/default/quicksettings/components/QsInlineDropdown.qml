import QtQuick
import QtQuick.Layouts

// ── QsInlineDropdown ──────────────────────────────────────────────────────────
// Dropdown inline, auto-contido — não depende de PopupWindow.
// Instancie diretamente dentro do módulo (QsNightMode, QsThermalSection, etc.)
//
// USO MÍNIMO:
//   QsInlineDropdown {
//       Layout.fillWidth: true
//       model:        ["off", "blue-light-filter", "vibrance"]
//       currentIndex: 0
//       onPicked: (i) => console.log("escolhido:", i)
//   }
//
// MODELO COM OBJETO (label + icon):
//   model: [
//       { label: "Performance", icon: "\uf0e7" },
//       { label: "Balanced",    icon: "\uf06c" },
//   ]
//   labelRole: "label"   // default
//   iconRole:  "icon"    // default
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    // ── API pública ────────────────────────────────────────────────────────
    property var    model:        []
    property string labelRole:    "label"
    property string iconRole:     "icon"
    property int    currentIndex: -1
    property bool   open:         false

    // Cores — sobrescreva para tematizar
    property color  colorBg:      "#2a2a2a"
    property color  colorBgItem:  "#323232"
    property color  colorBgHover: "#3a3a3a"
    property color  colorText:    "#e2e2e2"
    property color  colorTextDim: "#9a9a9a"
    property color  colorAccent:  "#ffb4a9"
    property color  colorBorder:  Qt.rgba(1, 1, 1, 0.10)

    property int    itemHeight:   32
    property int    maxVisible:   6          // itens antes de rolar

    signal picked(int index)

    // ── Altura dinâmica ────────────────────────────────────────────────────
    // O Item cresce/encolhe com animação — o ColumnLayout pai se ajusta.
    implicitHeight: header.height + body.height

    // ── Helpers ────────────────────────────────────────────────────────────
    function _label(entry) {
        if (typeof entry === "string") return entry
        if (typeof entry === "object" && entry !== null)
            return entry[root.labelRole] ?? String(entry)
        return String(entry)
    }
    function _icon(entry) {
        if (typeof entry === "object" && entry !== null)
            return entry[root.iconRole] ?? ""
        return ""
    }
    readonly property string _currentLabel: {
        if (currentIndex < 0 || currentIndex >= model.length) return "—"
        return _label(model[currentIndex])
    }
    readonly property string _currentIcon: {
        if (currentIndex < 0 || currentIndex >= model.length) return ""
        return _icon(model[currentIndex])
    }

    // ── Header (botão que abre/fecha) ──────────────────────────────────────
    Rectangle {
        id: header
        width: parent.width
        height: 30
        radius: root.open ? 6 : 6
        color: headerMA.containsMouse
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.10)
            : Qt.rgba(1, 1, 1, 0.06)
        border.color: root.open
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.55)
            : root.colorBorder
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Zap dos cantos inferiores enquanto aberto — une header ao body
        Rectangle {
            visible: root.open
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 7
            color: header.color
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6

            // Ícone do item selecionado (opcional)
            Text {
                visible: root._currentIcon.length > 0
                text:    root._currentIcon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                color:   root.colorAccent
            }

            // Label do item selecionado
            Text {
                text:  root._currentLabel
                color: root.currentIndex >= 0 ? root.colorAccent : root.colorTextDim
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Chevron animado
            Text {
                text: "\uf078"
                font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                color: root.open
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.8)
                    : root.colorTextDim
                rotation: root.open ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color    { ColorAnimation  { duration: 150 } }
            }
        }

        MouseArea {
            id: headerMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // ── Body (lista expansível) ────────────────────────────────────────────
    Item {
        id: body
        width:  parent.width
        y:      header.height
        // Altura animada: 0 quando fechado, altura real quando aberto
        height: root.open ? listContent.implicitHeight : 0
        clip:   true
        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            // Mesmo fundo do header, sem cantos superiores
            color:        Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.04)
            border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.55)
            border.width: 1
            Rectangle {
                // Tampa a borda do topo para unir visualmente ao header
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.04)
            }

            radius: 6

            // Topo sem radius (encosta no header)
            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: 8
                color:  parent.color
            }
        }

        // Scroll quando itens > maxVisible
        Flickable {
            anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
            clip:            true
            contentHeight:   listContent.implicitHeight
            boundsMovement:  Flickable.StopAtBounds
            // Limita altura visível
            implicitHeight:  Math.min(
                listContent.implicitHeight,
                root.maxVisible * root.itemHeight
            )

            ColumnLayout {
                id: listContent
                width: parent.width
                spacing: 1

                Repeater {
                    model: root.model

                    delegate: Rectangle {
                        id: dItem
                        required property var modelData
                        required property int index

                        readonly property bool   isActive:  index === root.currentIndex
                        readonly property string itemLabel: root._label(modelData)
                        readonly property string itemIcon:  root._icon(modelData)

                        Layout.fillWidth: true
                        height: root.itemHeight
                        radius: 4
                        color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                            : (dMA.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            // Bolinha indicadora
                            Rectangle {
                                width: 5; height: 5; radius: 2.5
                                color: dItem.isActive
                                    ? root.colorAccent
                                    : "transparent"
                                border.color: dItem.isActive
                                    ? root.colorAccent
                                    : Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.2)
                                border.width: 1
                                Behavior on color        { ColorAnimation { duration: 80 } }
                                Behavior on border.color { ColorAnimation { duration: 80 } }
                            }

                            // Ícone (se existir)
                            Text {
                                visible: dItem.itemIcon.length > 0
                                text:    dItem.itemIcon
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                color: dItem.isActive ? root.colorAccent : root.colorTextDim
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            // Label
                            Text {
                                text: dItem.itemLabel
                                font.pixelSize: 11
                                color: dItem.isActive ? root.colorAccent : root.colorText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            // Check mark
                            Text {
                                visible: dItem.isActive
                                text: "\uf00c"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                                color: root.colorAccent
                            }
                        }

                        MouseArea {
                            id: dMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentIndex = dItem.index
                                root.open = false
                                root.picked(dItem.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
