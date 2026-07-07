import QtQuick
import QtQuick.Layouts

// ── Notifications ─────────────────────────────────────────────────────────────
// Módulo da barra: ícone de sino com badge de não-lidas e indicador DND.
// Emite panelRequested() ao clicar → Bar.qml abre o NotificationsPopup.
// Hover mostra o NotifTooltip (estado DND + prévia das últimas notificações),
// mesmo padrão de VolumeTooltip/QsTooltip/WsTooltip. NotifTooltip mora no
// mesmo módulo (qmldir local), por isso não precisa de import qualificado.

Item {
    id: root

    // ── Config ─────────────────────────────────────────────────────────────
    property bool   isHorizontal: true
    property int    barPosition:  1
    // Multiplicador global de escala (ver Bar.qml::_applyConfig →
    // barState.config.moduleScale). Afeta o glyph do sino e o tamanho do
    // próprio módulo, já que aqui não havia nenhuma prop de tamanho exposta
    // antes — só existia o valor fixo 13px.
    property real   fontScale:    1.0

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
    implicitWidth:  isHorizontal ? row.implicitWidth + Math.round(10 * root.fontScale) : Math.round(28 * root.fontScale)
    implicitHeight: isHorizontal ? Math.round(28 * root.fontScale) : row.implicitHeight + Math.round(10 * root.fontScale)

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
            font.pixelSize: Math.round(13 * root.fontScale)
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
        id: bellArea
        anchors.fill:    parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled:    true
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Clique direito: toggle DND rápido
                if (root.service) root.service.toggleDnd()
            } else {
                root.panelRequested()
            }
            NotifTooltip.hide()
        }
        onContainsMouseChanged: {
            if (containsMouse)
                NotifTooltip.show(root, root.service, root.barPosition)
            else
                NotifTooltip.hide()
        }
    }
}
