import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// ── Aba: System Tray ─────────────────────────────────────────────────────────
// Sem ToolTip (requer QtQuick.Controls — não disponível aqui).
// Filtra itens sem title E sem icon para evitar entradas fantasma.
Item {
    id: root

    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    // Filtra itens válidos (remove entradas vazias que causam "item a mais")
    readonly property var validItems: {
        var all = SystemTray.items.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            var it = all[i]
            if (!it) continue
            var hasTitle = it.title  && it.title.trim()  !== ""
            var hasIcon  = it.icon   && it.icon.trim()   !== ""
            if (hasTitle || hasIcon) out.push(it)
        }
        return out
    }

    Flow {
        anchors.fill: parent
        spacing: 6; clip: true

        Repeater {
            model: root.validItems

            delegate: Rectangle {
                id: td
                required property var modelData
                required property int index

                // Captura local para evitar bug de binding em closures
                readonly property var trayItem: td.modelData

                width: 32; height: 32; radius: 8
                color: tdMA.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.07)
                Behavior on color { ColorAnimation { duration: 100 } }

                Image {
                    id: trayImg
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source:   td.trayItem.icon || ""
                    fillMode: Image.PreserveAspectFit
                    visible:  status === Image.Ready
                    smooth:   true
                }
                Text {
                    anchors.centerIn: parent
                    visible:        trayImg.status !== Image.Ready
                    text:           "\uf1e6"
                    color:          root.colorTextDim
                    font.pixelSize: 12
                    font.family:    "JetBrainsMono Nerd Font"
                }

                // Título como texto pequeno abaixo (substitui ToolTip)
                Text {
                    anchors.top:              parent.bottom
                    anchors.topMargin:        2
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible:        tdMA.containsMouse && (td.trayItem.title || "") !== ""
                    text:           td.trayItem.title || ""
                    color:          root.colorTextDim
                    font.pixelSize: 8
                    opacity:        0.8
                    z:              10
                }

                MouseArea {
                    id: tdMA
                    anchors.fill:    parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled:    true
                    onClicked: (mouse) => {
                        var it = td.trayItem
                        if (!it) return
                        if (mouse.button === Qt.LeftButton) {
                            if (typeof it.activate === "function")
                                it.activate(td.x, td.y)
                            else if (typeof it.trigger === "function")
                                it.trigger()
                        } else {
                            if (typeof it.secondaryActivate === "function")
                                it.secondaryActivate(td.x, td.y)
                            else if (it.menu && typeof it.menu.open === "function")
                                it.menu.open()
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible:        root.validItems.length === 0
        text:           "\uf1e6  Tray vazio"
        color:          root.colorTextDim
        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.5
    }
}
