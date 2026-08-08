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
    property var   parentWindow: null
    readonly property bool menuOpen: trayLoader.status === Loader.Ready
                                     ? (trayLoader.item.menuOpen ?? false) : false

    // Quantidade de itens válidos no tray — lida direto do componente carregado
    // (validItems já existe lá como readonly property, reaproveitado aqui só
    // pra saber a largura natural e poder centralizar a fileira de ícones).
    readonly property int trayCount: trayLoader.status === Loader.Ready && trayLoader.item.validItems
        ? trayLoader.item.validItems.length : 0

    // 32px por ícone + 6px de espaçamento (mesmos valores do Flow interno),
    // menos 1 espaçamento sobrando no fim. Limitado à largura disponível —
    // se não couber tudo numa linha, o Flow interno quebra e o clip protege
    // (nesse caso deixa de estar "centralizado", mas evita cortar ícone).
    readonly property int _naturalWidth: root.trayCount > 0 ? (root.trayCount * 38 - 6) : 0

    Loader {
        id: trayLoader
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width:  Math.min(root._naturalWidth, root.width)
        height: parent.height
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
    Binding { target: trayLoader.item; property: "parentWindow"; value: root.parentWindow; when: trayLoader.status === Loader.Ready }

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
