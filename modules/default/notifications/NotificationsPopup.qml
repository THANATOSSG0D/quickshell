import Quickshell
import QtQuick
import "../bar" as Bar

// ── NotificationsPopup ────────────────────────────────────────────────────────
// Herda de Bar.BarPopup (PanelWindow). barRef injetado por Bar.qml.

Bar.BarPopup {
    id: popup

    popupW: 360
    popupH: 560

    property var service: null

    property color colorText:    "#cdd6f4"
    property color colorTextDim: "#9399b2"
    property color colorAccent:  "#89b4fa"
    property color colorMuted:   "#f38ba8"
    property color colorDivider: "#313244"

    onPanelOpenChanged: {
        slideProgress = panelOpen ? 1.0 : 0.0
        if (panelOpen && service) service.markAllRead()
    }

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
