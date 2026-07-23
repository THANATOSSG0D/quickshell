import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ── QsMediaPlayerFull ─────────────────────────────────────────────────────────
// Player completo para a aba Mídia: capa maior, título/artista/álbum,
// prev/play/next. Mesma regra de seleção de player do QsMiniPlayer/
// MediaPlayer.qml da barra (ignora "playerctld", prioriza quem está tocando).
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

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

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 10

        // ── Sem player ──────────────────────────────────────────────────────
        Rectangle {
            visible: root.player === null
            Layout.fillWidth: true; Layout.preferredHeight: 100; radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            Column {
                anchors.centerIn: parent; spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf001"; color: root.colorTextDim
                    font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; opacity: 0.4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nenhuma mídia em reprodução"; color: root.colorTextDim
                    font.pixelSize: 10; opacity: 0.7
                }
            }
        }

        // ── Com player ───────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.player !== null
            Layout.fillWidth: true; spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 12

                // ── Capa ──────────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 64; Layout.preferredHeight: 64; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.08)
                    clip: true

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
                        font.pixelSize: 22
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                // ── Título / artista / álbum ────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || root.player.identity || "—") : ""
                        color: root.colorText
                        font.pixelSize: 12; font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.player && (root.player.trackArtist || "") !== ""
                        text: root.player ? (root.player.trackArtist || "") : ""
                        color: root.colorAccent
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.player && (root.player.trackAlbum || "") !== ""
                        text: root.player ? (root.player.trackAlbum || "") : ""
                        color: root.colorTextDim
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }

            // ── Controles ────────────────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18

                Text {
                    text: "\uf048"   // prev
                    color: root.colorText
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    opacity: root.player && root.player.canGoPrevious ? 1.0 : 0.35
                    scale: prevMA.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    MouseArea { id: prevMA; anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.player) root.player.previous() } }
                }

                Rectangle {
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                    color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
                    border.color: root.colorAccent; border.width: 1
                    scale: playMA.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    Text {
                        anchors.centerIn: parent
                        text: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                        color: root.colorAccent
                        font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    }
                    MouseArea { id: playMA; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.player) root.player.togglePlaying() } }
                }

                Text {
                    text: "\uf051"   // next
                    color: root.colorText
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    opacity: root.player && root.player.canGoNext ? 1.0 : 0.35
                    scale: nextMA.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    MouseArea { id: nextMA; anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.player) root.player.next() } }
                }
            }
        }
    }
}
