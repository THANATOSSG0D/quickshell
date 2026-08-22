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

    // colorText/colorTextDim/colorAccent/colorMuted/colorProgressBg/colorDivider
    // NÃO são redeclaradas aqui de propósito — são herdadas do Bar.BarPopup,
    // que já resolve essas cores reativamente a partir do PopupConfig (com
    // fallback pro tema via Colors). Redeclarar aqui com valor fixo cria uma
    // property NOVA que sombreia a herdada: o Binding on colorX de dentro do
    // BarPopup.qml continua resolvendo certinho *internamente*, mas quem lê
    // popup.colorAccent de fora (QuickSettingsContent) enxerga essa cópia
    // estática aqui, nunca o valor resolvido pelo PopupConfig.

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
