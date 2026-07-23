import Quickshell
import QtQuick
import "../bar" as Bar

// ── QuickSettingsPopup ───────────────────────────────────────────────────────
// Herda de Bar.BarPopup (PanelWindow). barRef injetado por Bar.qml.
// O focusGrab é suspenso enquanto um menu de tray estiver aberto.

Bar.BarPopup {
    id: popup
    objectName: "QuickSettingsPopup"

    popupW: 320
    popupH: 620

    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    // Opcional — conecte a partir do Bar.qml pra habilitar o botão de Não
    // Perturbe no cabeçalho (mesmo padrão do QuickSettingsPanel.qml).
    property var notifService: null

    // Suspende o focus grab enquanto menu de tray estiver aberto.
    // Quando trayMenuOpen=true, focusGrabActive=false → onCleared não dispara
    // → closeRequested não é emitido → painel permanece aberto.
    // Não é necessário nenhum Connections adicional: o signal closeRequested
    // já é roteado para bar.closeAllPanels() pelo Bar.qml (onCloseRequested).
    focusGrabActive: panelOpen && !qsContent.trayMenuOpen

    QuickSettingsContent {
        id: qsContent
        anchors.fill:    parent
        panelOpen:       popup.panelOpen
        parentWindow:    popup
        notifService:    popup.notifService
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
