import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ── QsMiniPlayer ──────────────────────────────────────────────────────────────
// Resumo compacto da mídia atual para o Dashboard: capa pequena + título +
// artista + play/pause. Sem next/prev (intencional — versão resumida; o
// player completo com todos os controles vive na aba Mídia).
//
// Reaproveita a mesma regra de seleção de player do MediaPlayer.qml da barra:
// ignora instâncias "playerctld" (proxy duplicado) e prioriza quem está
// tocando no momento.
Item {
    id: root

    property color colorAccent:   "#ffb4a9"
    property color colorText:     "#e2e2e2"
    property color colorTextDim:  "#c6c6c6"

    property bool compact: false   // true = card menor, lado a lado com outro widget

    // ── Seleção de player — mesma regra do MediaPlayer.qml da barra ─────────
    readonly property var player: {
        var all = Mpris.players.values
        for (var j = 0; j < all.length; j++) {
            var je = (all[j].desktopEntry || all[j].identity || "").toLowerCase()
            if (!je.startsWith("playerctld") && all[j].isPlaying) return all[j]
        }
        for (var k = 0; k < all.length; k++) {
            var ke = (all[k].desktopEntry || all[k].identity || "").toLowerCase()
            if (!ke.startsWith("playerctld")) return all[k]
        }
        return null
    }

    // Em modo compacto, sempre ocupa espaço (placeholder "Sem mídia") para
    // manter simetria com o widget vizinho (ex.: clima) na mesma linha.
    // Fora do modo compacto, colapsa quando não há player.
    visible:        root.compact || player !== null
    implicitHeight: visible ? (root.compact ? 54 : 64) : 0

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.07)

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? 8 : 10
            spacing: root.compact ? 6 : 10

            // ── Capa ──────────────────────────────────────────────────────
            Item {
                visible: root.player !== null
                Layout.preferredWidth: root.compact ? 30 : 40
                Layout.preferredHeight: root.compact ? 30 : 40

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        id: artImg
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: (root.player && root.player.trackArtUrl && root.player.trackArtUrl.length > 0)
                            ? root.player.trackArtUrl : ""
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: artImg.status !== Image.Ready
                        text: "\uf001"
                        color: root.colorTextDim
                        font.pixelSize: root.compact ? 12 : 16
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            // Placeholder quando não há player (só relevante em modo compacto)
            Text {
                visible: root.player === null
                Layout.fillWidth: true
                text: "\uf001  Sem mídia"
                color: root.colorTextDim
                font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                opacity: 0.5
            }

            // ── Título + artista ──────────────────────────────────────────
            ColumnLayout {
                visible: root.player !== null
                Layout.fillWidth: true; spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackTitle || root.player.identity || "—") : ""
                    color: root.colorText
                    font.pixelSize: root.compact ? 10 : 11; font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: !root.compact && root.player && (root.player.trackArtist || "") !== ""
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: root.colorTextDim
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            // ── Play/Pause ────────────────────────────────────────────────
            Rectangle {
                visible: root.player !== null
                Layout.preferredWidth: root.compact ? 24 : 30
                Layout.preferredHeight: root.compact ? 24 : 30
                radius: width / 2
                color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                border.color: root.colorAccent; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                    color: root.colorAccent
                    font.pixelSize: root.compact ? 9 : 11
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.player) root.player.togglePlaying() }
                }
            }
        }
    }
}
