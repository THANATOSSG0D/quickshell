import Quickshell
import QtQuick
import "../bar" as Bar

// ── NotificationsPopup ────────────────────────────────────────────────────────
// Herda de Bar.BarPopup (PanelWindow). barRef injetado por Bar.qml.
// Animação gerenciada inteiramente pelo BarPopup (_animProg).

Bar.BarPopup {
    id: popup
    objectName: "NotificationsPopup"

    popupW: 360
    popupH: 560

    property var service: null

    // Cores herdadas do Bar.BarPopup — ver nota em VolumePopupTabbed.qml
    property int   cardRadius:    10
    property int   defaultUrgencyFilter: 0

    onPanelOpenChanged: {
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
        cardRadius:    popup.cardRadius
        defaultUrgencyFilter: popup.defaultUrgencyFilter
        onCloseRequested: popup.closeRequested()
    }
}
