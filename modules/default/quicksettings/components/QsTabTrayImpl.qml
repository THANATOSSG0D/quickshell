import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// ── Implementação real do Tray ────────────────────────────────────────────────
// Carregada via Loader no QsTabTray para isolamento de import.
// API do Quickshell SystemTray: activate(x,y) e secondaryActivate(x,y)
// diretamente no item — sem .display intermediário.
Item {
    id: root

    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    Flow {
        anchors.fill: parent
        spacing:      6
        clip:         true

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem
                required property var modelData

                width: 32; height: 32; radius: 8
                color: trayMa.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.14)
                    : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: 100 } }

                Image {
                    id: trayImg
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source:   trayItem.modelData.icon || ""
                    fillMode: Image.PreserveAspectFit
                    visible:  status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible:        trayImg.status !== Image.Ready
                    text:           "\uf1e6"
                    color:          root.colorTextDim
                    font.pixelSize: 13
                    font.family:    "JetBrainsMono Nerd Font"
                }

                MouseArea {
                    id: trayMa
                    anchors.fill:    parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled:    true
                    onClicked: (mouse) => {
                        var item = trayItem.modelData
                        // API direta no item — sem .display intermediário
                        if (mouse.button === Qt.LeftButton) {
                            if (typeof item.activate === "function")
                                item.activate(mouseX, mouseY)
                        } else {
                            if (typeof item.secondaryActivate === "function")
                                item.secondaryActivate(mouseX, mouseY)
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible:        SystemTray.items.values.length === 0
        text:           "\uf1e6  Tray vazio"
        color:          root.colorTextDim
        font.pixelSize: 10
        font.family:    "JetBrainsMono Nerd Font"
        opacity:        0.5
    }
}
