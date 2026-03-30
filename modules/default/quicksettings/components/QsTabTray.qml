import Quickshell
import QtQuick
import QtQuick.Layouts

// ── Aba: Tray ────────────────────────────────────────────────────────────────
// Tenta usar Quickshell.Services.SystemTray dinamicamente via Loader.
// Se o módulo não estiver disponível, exibe um placeholder informativo.
// Desta forma o resto do painel carrega normalmente mesmo sem SystemTray.
Item {
    id: root

    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"
    property color colorAccent:  "#ffb4a9"

    Loader {
        id: trayLoader
        anchors.fill: parent
        // Tenta carregar o componente real; se falhar, cai no placeholder
        source:      "QsTabTrayImpl.qml"
        onLoaded:    placeholder.visible = false
        onStatusChanged: {
            if (status === Loader.Error) {
                placeholder.visible = true
            }
        }
    }

    // Passa cores para o componente carregado
    Binding { target: trayLoader.item; property: "colorText";    value: root.colorText;    when: trayLoader.status === Loader.Ready }
    Binding { target: trayLoader.item; property: "colorTextDim"; value: root.colorTextDim; when: trayLoader.status === Loader.Ready }

    // ── Placeholder (visível enquanto carrega ou se falhar) ────────────────
    Item {
        id: placeholder
        anchors.centerIn: parent
        visible:          trayLoader.status !== Loader.Ready

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "\uf0c9"
                color:          root.colorTextDim
                font.pixelSize: 18
                font.family:    "JetBrainsMono Nerd Font"
                opacity:        0.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "Tray não disponível"
                color:          root.colorTextDim
                font.pixelSize: 10
                opacity:        0.6
            }
        }
    }
}
