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
    property var   parentWindow: null

    // Contador de menus abertos — incrementado/decrementado por cada delegate.
    // Lido pelo QuickSettingsPopup para suspender HyprlandFocusGrab.
    property int _openMenuCount: 0
    readonly property bool menuOpen: _openMenuCount > 0

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

                readonly property var trayItem: td.modelData

                width: 32; height: 32; radius: 8
                color: tdMA.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.07)
                Behavior on color { ColorAnimation { duration: 100 } }
                scale: tdMA.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

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

                // ── Menu SNI via QsMenuAnchor ─────────────────────────────
                // Usado no clique direito quando o item expõe um menu DBus.
                // anchor.window é a janela pai (resolvida via Window.window).
                QsMenuAnchor {
                    id: trayMenuAnchor
                    menu: td.trayItem && td.trayItem.menu ? td.trayItem.menu : null
                    anchor.window: root.parentWindow
                    // mapToItem(null) converte para coordenadas de cena (relativas à janela)
                    anchor.rect: {
                        var p = td.mapToItem(null, 0, 0)
                        return Qt.rect(p.x, p.y, td.width, td.height)
                    }
                    onOpened: root._openMenuCount++
                    onClosed: root._openMenuCount = Math.max(0, root._openMenuCount - 1)
                }

                MouseArea {
                    id: tdMA
                    anchors.fill:    parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled:    true
                    cursorShape:     Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        var it = td.trayItem
                        if (!it) return

                        if (mouse.button === Qt.LeftButton) {
                            // Clique esquerdo: ação primária (toggle, play/pause, etc.)
                            it.activate()

                        } else if (mouse.button === Qt.RightButton) {
                            // Clique direito: menu de contexto
                            // Preferência: QsMenuAnchor (menu DBus nativo)
                            // Fallback: display() (menu de plataforma via SNI)
                            if (it.menu) {
                                trayMenuAnchor.open()
                            } else if (typeof it.display === "function") {
                                var pos = td.mapToItem(null, 0, 0)
                                it.display(td.Window.window, pos.x, pos.y)
                            }

                        } else if (mouse.button === Qt.MiddleButton) {
                            // Clique do meio: ação secundária
                            it.secondaryActivate()
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
