import Quickshell
import QtQuick
import "../bar" as Bar

// ── QuickSettingsPopup ───────────────────────────────────────────────────────
// Herda de Bar.BarPopup (PanelWindow). barRef injetado por Bar.qml.
// O focusGrab é suspenso enquanto um menu de tray estiver aberto.

Bar.BarPopup {
    id: popup

    popupW: 320
    popupH: 540

    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    // Suspende o focus grab enquanto menu de tray estiver aberto
    focusGrabActive: panelOpen && !qsContent.trayMenuOpen

    // Sobrescreve o onCleared para ignorar enquanto tray está aberto
    Connections {
        target: popup
        function onCloseRequested() {
            if (qsContent.trayMenuOpen) return
            popup.closeRequested()
        }
    }

    QuickSettingsContent {
        id: qsContent
        anchors.fill:    parent
        panelOpen:       popup.panelOpen
        parentWindow:    popup
        colorPanelBg:    popup.colorPanelBg
        colorText:       popup.colorText
        colorTextDim:    popup.colorTextDim
        colorAccent:     popup.colorAccent
        colorMuted:      popup.colorMuted
        colorProgressBg: popup.colorProgressBg
        colorDivider:    popup.colorDivider
        onCloseRequested: popup.closeRequested()
    }
}
