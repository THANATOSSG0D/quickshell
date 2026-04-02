import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ── QsDropdownPopup ──────────────────────────────────────────────────────────
// Deve ser declarado como filho DIRETO do PanelWindow.
// Todas as propriedades são declarativas — sem API imperativa.
//
// USO:
//   // No PanelWindow:
//   QsComp.QsDropdownPopup {
//       id: sharedDropdown
//       anchorItem:   someRect      // sete antes de open = true
//       model:        [...]
//       currentIndex: 0
//       onPicked: (i) => { ... }
//   }

PopupWindow {
    id: root

    // ── API pública ────────────────────────────────────────────────────────
    property Item   anchorItem:   null
    property var    model:        []
    property string labelRole:    "label"
    property string iconRole:     "icon"
    property int    currentIndex: -1
    property bool   open:         false
    // Quem abriu o dropdown — usado pelos módulos para filtrar onPicked
    property QtObject owner:      null

    property color  colorBg:      "#2a2a2a"
    property color  colorBgItem:  "#323232"
    property color  colorBgHover: "#3a3a3a"
    property color  colorText:    "#e2e2e2"
    property color  colorAccent:  "#ffb4a9"
    property color  colorBorder:  Qt.rgba(1, 1, 1, 0.12)
    property int    itemHeight:   34
    property int    maxVisible:   6

    signal picked(int index)

    function toggle(item, mdl, cur) {
        if (item !== undefined) root.anchorItem   = item
        if (mdl   !== undefined) root.model       = mdl
        if (cur   !== undefined) root.currentIndex = cur
        root.open = !root.open
    }

    // ── Dimensões ──────────────────────────────────────────────────────────
    width:  anchorItem ? anchorItem.width : 200
    height: Math.min(model.length, maxVisible) * itemHeight + 16

    // ── Posicionamento manual via mapToGlobal ─────────────────────────────
    // anchor.item só funciona com filhos diretos do PanelWindow.
    // Como anchorItem vive dentro de clipContainer, calculamos a posição global.
    function _reposition() {
        if (!anchorItem) return
        // Ponto global do canto inferior esquerdo do anchorItem
        var pt = anchorItem.mapToGlobal(0, anchorItem.height)
        root.x = pt.x
        root.y = pt.y
    }

    onAnchorItemChanged: _reposition()
    onOpenChanged:       if (open) _reposition()

    // ── Visibilidade ───────────────────────────────────────────────────────
    color:   "transparent"
    visible: root.open && root.anchorItem !== null

    onVisibleChanged: if (!visible) root.open = false

    // ── Helpers ────────────────────────────────────────────────────────────
    function _label(item) {
        if (typeof item === "string") return item
        if (typeof item === "object" && item !== null)
            return item[root.labelRole] ?? String(item)
        return String(item)
    }
    function _icon(item) {
        if (typeof item === "object" && item !== null)
            return item[root.iconRole] ?? ""
        return ""
    }

    // ── Conteúdo ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        root.colorBg
        radius:       8
        border.color: root.colorBorder
        border.width: 1

        Flickable {
            anchors { fill: parent; margins: 8 }
            clip:           true
            contentHeight:  listCol.implicitHeight
            boundsMovement: Flickable.StopAtBounds

            ColumnLayout {
                id: listCol
                width: parent.width; spacing: 2

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
                        radius: 6

                        color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                            : (dMA.containsMouse ? root.colorBgHover : root.colorBgItem)
                        border.color: isActive
                            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.5)
                            : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: dItem.isActive ? root.colorAccent : "transparent"
                                border.color: dItem.isActive
                                    ? root.colorAccent
                                    : Qt.rgba(root.colorText.r, root.colorText.g, root.colorText.b, 0.3)
                                border.width: 1
                            }
                            Text {
                                visible: dItem.itemIcon.length > 0
                                text:    dItem.itemIcon
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                color:   dItem.isActive ? root.colorAccent : root.colorText
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            Text {
                                text: dItem.itemLabel; font.pixelSize: 11
                                color: dItem.isActive ? root.colorAccent : root.colorText
                                Layout.fillWidth: true; elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            Text {
                                visible: dItem.isActive; text: "\uf00c"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                                color: root.colorAccent
                            }
                        }

                        MouseArea {
                            id: dMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.picked(dItem.index)
                                root.open = false
                            }
                        }
                    }
                }
            }
        }
    }
}
