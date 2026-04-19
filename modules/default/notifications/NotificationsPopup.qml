import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── NotificationsPopup ────────────────────────────────────────────────────────
// PopupWindow que hospeda o NotificationsContent.
// Segue exatamente o padrão de ClockPopup / QuickSettingsPopup.
// Registrado em Bar.qml da mesma forma que os outros painéis.

PopupWindow {
    id: popup

    // ── Dimensões ──────────────────────────────────────────────────────────
    property int popupW: 360
    property int popupH: 560

    // ── Service ────────────────────────────────────────────────────────────
    property var service: null   // NotificationService

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorPanelBg:  "#1e1e2e"
    property color colorText:     "#cdd6f4"
    property color colorTextDim:  "#9399b2"
    property color colorAccent:   "#89b4fa"
    property color colorMuted:    "#f38ba8"
    property color colorProgressBg: "#313244"
    property color colorDivider:  "#313244"

    // ── Estado ─────────────────────────────────────────────────────────────
    property bool panelOpen: false
    property real slideProgress: 0.0

    color:         "transparent"
    implicitWidth:  popupW
    implicitHeight: popupH

    visible: slideProgress > 0.0

    signal closeRequested()

    // ── Animação ───────────────────────────────────────────────────────────
    Behavior on slideProgress {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    onPanelOpenChanged: {
        slideProgress = panelOpen ? 1.0 : 0.0
        // Ao abrir o painel, marca tudo como lido
        if (panelOpen && service) service.markAllRead()
    }

    // ── Foco ───────────────────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows:   [ popup ]
        active:    popup.panelOpen
        onCleared: popup.closeRequested()
    }

    // ── Visual ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       12
        opacity:      Math.min(1.0, popup.slideProgress * 2)
        color:        Qt.rgba(popup.colorPanelBg.r, popup.colorPanelBg.g, popup.colorPanelBg.b, 0.95)

        // Sombra via layer semi-transparente
        layer.enabled: true

        NotificationsContent {
            anchors.fill:  parent
            service:       popup.service
            colorPanelBg:  popup.colorPanelBg
            colorText:     popup.colorText
            colorTextDim:  popup.colorTextDim
            colorAccent:   popup.colorAccent
            colorMuted:    popup.colorMuted
            colorDivider:  popup.colorDivider
            onCloseRequested: popup.closeRequested()
        }
    }
}
