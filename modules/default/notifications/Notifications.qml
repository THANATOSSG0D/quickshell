import QtQuick
import QtQuick.Layouts

// ── Notifications ─────────────────────────────────────────────────────────────
// Módulo da barra: ícone de sino com badge de não-lidas e indicador DND.
// Emite panelRequested() ao clicar → Bar.qml abre o NotificationsPopup.

Item {
    id: root

    // ── Config ─────────────────────────────────────────────────────────────
    property bool   isHorizontal: true
    property int    barPosition:  1

    // ── Cores ──────────────────────────────────────────────────────────────
    property color textColor:   "#cdd6f4"
    property color dimColor:    Qt.rgba(1, 1, 1, 0.5)
    property color accentColor: "#89b4fa"
    property color mutedColor:  "#f38ba8"

    // ── Service ────────────────────────────────────────────────────────────
    property var service: null

    // ── Sinal ──────────────────────────────────────────────────────────────
    signal panelRequested()

    // ── Dimensões ──────────────────────────────────────────────────────────
    implicitWidth:  isHorizontal ? row.implicitWidth + 10 : 28
    implicitHeight: isHorizontal ? 28 : row.implicitHeight + 10

    // ── Visual ─────────────────────────────────────────────────────────────
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        // Sino (DND = sino riscado)
        Text {
            id: bellIcon
            text: {
                if (root.service && root.service.doNotDisturb)
                    return "\uf1f6"   // bell-slash
                return "\uf0f3"      // bell
            }
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: {
                if (root.service && root.service.doNotDisturb)
                    return root.mutedColor
                if (root.service && root.service.unreadCount > 0)
                    return root.accentColor
                return root.textColor
            }
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 150 } }
        }

    }

    // ── MouseArea ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill:    parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Clique direito: toggle DND rápido
                if (root.service) root.service.toggleDnd()
            } else {
                root.panelRequested()
            }
        }
    }
}
